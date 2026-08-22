import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:flutter_app/generated/api/app/service/v1/index.dart' as api;
import 'package:flutter_app/src/core/repositories/user_auth_cache.dart';
import 'package:dio/dio.dart' show Dio;
import 'package:flutter_app/src/features/board/data/board_cache.dart';
import 'package:flutter_app/src/features/board/data/realtime_client.dart';
import 'package:flutter_app/src/features/board/data/sync_api.dart';
import 'package:flutter_app/src/features/board/models/board_models.dart';

import 'package:get_it/get_it.dart';

/// 看板状态机。
///
/// 数据流：Hive 缓存先渲染 → 网络快照刷新 → WS 事件增量维护。
/// 写路径：乐观本地更新 → API 提交（成功回填服务端 rank/version）；
/// 网络不可达时进入离线模式——本地保留修改并入 Pending Queue，
/// 联网后 [replayPending] 按 FIFO 重放。
///
/// 回声说明：服务端按 uid 抑制触发者自己的事件推送；本地乐观更新
/// 已即时反映自身操作，二者不冲突。同账号多设备的同步依赖
/// 重连时的快照刷新。
class BoardController extends Cubit<KanbanBoardState?> {
  final api.ApiClient _api;
  final BoardCache _cache;
  final PendingOps _pending;
  final RealtimeClient _realtime;

  StreamSubscription? _eventSub;
  StreamSubscription? _connSub;

  bool _offline = false;
  int _boardId = 0;

  BoardController({
    api.ApiClient? apiClient,
    required BoardCache cache,
    required PendingOps pending,
    RealtimeClient? realtime,
  })  : _api = apiClient ?? GetIt.instance<api.ApiClient>(),
        _cache = cache,
        _pending = pending,
        _realtime = realtime ??
            RealtimeClient(
              baseWsUrl: _wsBaseUrl(),
              tokenProvider: () =>
                  GetIt.instance<UserAuthCache>().accessToken ?? '',
            ),
        super(null) {
    _eventSub = _realtime.events.listen(applyEvent);
    _connSub = _realtime.connected.listen(_onConnection);
  }

  static String _wsBaseUrl() {
    final base = GetIt.instance<Dio>().options.baseUrl;
    return base.replaceFirst(RegExp(r'^http'), 'ws');
  }

  bool get isOffline => _offline;

  int get pendingCount => _pending.length;

  /// 加载看板：缓存先行 → 快照刷新 → WS 订阅。
  Future<void> load(int boardId) async {
    _boardId = boardId;

    final cached = _cache.read(boardId);
    if (cached != null) {
      emit(cached);
    }

    try {
      if (cached != null) {
        // 差量同步：已知版本对账，仅拉变化实体（手写客户端，见 sync_api.dart）
        final delta = await syncBoard(
          boardId: boardId,
          knownBoardVersion: cached.board.version,
          knownColumnVersions: {for (final c in cached.columns) c.id: c.version},
          knownCardVersions: {for (final c in cached.cards) c.id: c.version},
        );
        final merged = _mergeDelta(cached, delta);
        emit(merged);
        await _cache.save(merged);
      } else {
        final snap = await _api.boardService
            .getBoardSnapshot(api.BoardServiceV1GetBoardSnapshotRequest(boardId: boardId));
        final state = KanbanBoardState.fromSnapshot(snap);
        emit(state);
        await _cache.save(state);
      }
      _offline = false;
    } on DioException catch (e) {
      if (_isConnectionError(e)) {
        _offline = true;
        // 断网：缓存即数据源；无缓存则停留在空态。
        if (cached == null) emit(null);
      } else {
        rethrow;
      }
    }

    _realtime.subscribe(boardId);
  }

  /// 移动卡片（拖拽事件入口）。
  ///
  /// 乐观更新本地；在线提交 MoveCard（以目标位置邻卡为 anchor），
  /// 成功回填服务端 rank/version；离线入 Pending Queue。
  /// 返回 false 表示在线提交被服务端拒绝（UI 可提示并保持现状）。
  /// 移动列（列重排）。与 moveCard 同构的 anchor 语义。
  /// 离线时不支持列重排（列移动低频，且离线冲突语义复杂）。
  Future<bool> moveColumn(int columnId, int toIndex) async {
    final prev = state;
    if (prev == null || _offline) return false;

    final cols = List<KanbanColumn>.from(prev.columns)
      ..sort((a, b) => (a.rank ?? '').compareTo(b.rank ?? ''));
    final col = cols.where((c) => c.id == columnId).firstOrNull;
    if (col == null) return false;

    // 计算目标位置的邻列 anchor（基于移动前状态）。
    final others = cols.where((c) => c.id != columnId).toList();
    final clamped = toIndex.clamp(0, others.length).toInt();
    final afterId = clamped < others.length ? others[clamped].id : null;
    final beforeId = clamped > 0 ? others[clamped - 1].id : null;

    try {
      await _api.columnService.move(api.BoardServiceV1MoveColumnRequest(
        id: columnId,
        beforeId: beforeId,
        afterId: afterId,
      ));
      return true;
    } on DioException catch (e) {
      if (_isConnectionError(e)) {
        _offline = true;
        return false;
      }
      return false;
    }
  }

  Future<bool> moveCard(int cardId, int toColumnId, int toIndex) async {
    final prev = state;
    if (prev == null) return false;

    final card = prev.cards.where((c) => c.id == cardId).firstOrNull;
    if (card == null) return false;

    // ===== 计算目标位置的邻卡 anchor（基于移动前的状态）=====
    final targetCards =
        prev.cards.where((c) => c.columnId == toColumnId && c.id != cardId).toList()
          ..sort((a, b) => (a.rank ?? '').compareTo(b.rank ?? ''));
    final clamped = toIndex.clamp(0, targetCards.length).toInt();
    final afterId = clamped < targetCards.length ? targetCards[clamped].id : null;
    final beforeId = clamped > 0 ? targetCards[clamped - 1].id : null;

    // ===== 乐观本地更新（位置序临时以列表顺序表达）=====
    final optimistic = _applyLocalMove(prev, card, toColumnId, clamped);
    emit(optimistic);

    if (_offline) {
      await _pending.enqueue(PendingOps.moveCardOp(
          cardId: cardId,
          targetColumnId: toColumnId,
          beforeId: beforeId,
          afterId: afterId,
          expectedVersion: card.version));
      return true;
    }

    try {
      final updated = await _api.cardService.move(api.BoardServiceV1MoveCardRequest(
        id: cardId,
        targetColumnId: toColumnId,
        beforeId: beforeId,
        afterId: afterId,
        expectedVersion: card.version,
      ));
      _upsertCardDto(updated);
      return true;
    } on DioException catch (e) {
      if (_isConnectionError(e)) {
        _offline = true;
        await _pending.enqueue(PendingOps.moveCardOp(
            cardId: cardId, targetColumnId: toColumnId, beforeId: beforeId, afterId: afterId));
        return true;
      }
      // 服务端拒绝（如 anchor 失效）：回滚到移动前并上报失败。
      emit(prev);
      return false;
    }
  }

  /// 重命名卡片（在线直发 / 离线入队）。
  Future<bool> renameCard(int cardId, String name) async {
    final prev = state;
    if (prev == null) return false;
    final card = prev.cards.where((c) => c.id == cardId).firstOrNull;
    if (card == null) return false;

    emit(_mapCards(prev, (c) => c.id == cardId ? c.copyWith(name: name) : c));

    if (_offline) {
      await _pending.enqueue(
          PendingOps.renameCardOp(cardId: cardId, name: name, expectedVersion: card.version));
      return true;
    }
    try {
      await _api.cardService.update(api.BoardServiceV1UpdateCardRequest(
        id: cardId,
        data: api.BoardServiceV1Card(name: name),
        updateMask: 'name',
        expectedVersion: card.version,
      ));
      return true;
    } on DioException catch (e) {
      if (_isConnectionError(e)) {
        _offline = true;
        await _pending.enqueue(
            PendingOps.renameCardOp(cardId: cardId, name: name, expectedVersion: card.version));
        return true;
      }
      emit(prev);
      return false;
    }
  }

  /// 在指定列尾部建卡。
  Future<bool> createCard(int columnId, String name) async {
    final cur = state;
    if (cur == null) return false;

    if (_offline) {
      final tempId = -DateTime.now().millisecondsSinceEpoch;
      final temp = KanbanCard(
        id: tempId,
        columnId: columnId,
        boardId: cur.board.id,
        name: name,
        rank: 'zz$tempId',
      );
      emit(KanbanBoardState(
        board: cur.board,
        columns: cur.columns,
        cards: [...cur.cards, temp],
      ));
      await _pending.enqueue(PendingOps.createCardOp(columnId: columnId, name: name, tempId: tempId));
      return true;
    }
    try {
      final created = await _api.cardService.create(api.BoardServiceV1CreateCardRequest(
        data: api.BoardServiceV1Card(name: name, columnId: columnId),
      ));
      _upsertCardDto(created);
      return true;
    } on DioException catch (e) {
      if (_isConnectionError(e)) {
        _offline = true;
        return createCard(columnId, name);
      }
      return false;
    }
  }

  /// 删除卡片。
  Future<bool> deleteCard(int cardId) async {
    final prev = state;
    if (prev == null) return false;

    emit(KanbanBoardState(
      board: prev.board,
      columns: prev.columns,
      cards: prev.cards.where((c) => c.id != cardId).toList(),
    ));

    if (_offline) {
      await _pending.enqueue(PendingOps.deleteCardOp(cardId: cardId));
      return true;
    }
    try {
      await _api.cardService.delete(api.BoardServiceV1DeleteCardRequest(id: cardId));
      return true;
    } on DioException catch (e) {
      if (_isConnectionError(e)) {
        _offline = true;
        await _pending.enqueue(PendingOps.deleteCardOp(cardId: cardId));
        return true;
      }
      return false;
    }
  }

  /// 联网后重放离线队列（FIFO）。冲突项（服务端 4xx）跳过并刷新快照。
  Future<void> replayPending() async {
    if (_pending.isEmpty) return;
    while (true) {
      final op = await _pending.dequeue();
      if (op == null) break;
      try {
        await _replayOne(op);
      } on DioException catch (e) {
        if (_isConnectionError(e)) {
          // 再次断线：操作放回队首，等待下次重放。
          final box = op;
          await _pending.enqueue(box);
          _offline = true;
          return;
        }
        // 服务端拒绝（冲突/失效）：跳过该操作，最终以服务端为准。
      }
    }
    await load(_boardId);
  }

  Future<void> _replayOne(Map<String, dynamic> op) async {
    switch (op['op']) {
      case 'card.move':
        await _api.cardService.move(api.BoardServiceV1MoveCardRequest(
          id: op['cardId'],
          targetColumnId: op['targetColumnId'],
          beforeId: op['beforeId'],
          afterId: op['afterId'],
          expectedVersion: op['expectedVersion'],
        ));
      case 'card.rename':
        await _api.cardService.update(api.BoardServiceV1UpdateCardRequest(
          id: op['cardId'],
          data: api.BoardServiceV1Card(name: op['name']),
          updateMask: 'name',
          expectedVersion: op['expectedVersion'],
        ));
      case 'card.create':
        await _api.cardService.create(api.BoardServiceV1CreateCardRequest(
          data: api.BoardServiceV1Card(name: op['name'], columnId: op['columnId']),
        ));
      case 'card.delete':
        await _api.cardService.delete(api.BoardServiceV1DeleteCardRequest(id: op['cardId']));
    }
  }

  // ===== WS 事件维护 =====

  void applyEvent(BoardEvent ev) {
    final cur = state;
    if (cur == null || ev.boardId != cur.board.id) return;
    final board = cur.board;
    final columns = cur.columns;
    final cards = cur.cards;

    switch (ev.type) {
      case BoardEvent.cardCreated:
      case BoardEvent.cardUpdated:
      case BoardEvent.cardMoved:
        if (ev.card != null) _upsertCardDto(ev.card!);
      case BoardEvent.cardDeleted:
        if (ev.card != null) {
          emit(KanbanBoardState(
            board: board,
            columns: columns,
            cards: cards.where((c) => c.id != ev.card!.id).toList(),
          ));
        }
      // 标签相关事件（labelCreated/Updated/Deleted/cardLabelsChanged）：
      // 当前看板 UI 未实现标签展示，这些事件暂不驱动状态变更。
      // 标签 UI 落地后在此补全（拉取标签集合、刷新卡片标签关联）。
      case BoardEvent.labelCreated:
      case BoardEvent.labelUpdated:
      case BoardEvent.labelDeleted:
      case BoardEvent.cardLabelsChanged:
        break;
      case BoardEvent.columnCreated:
      case BoardEvent.columnUpdated:
      case BoardEvent.columnMoved:
        if (ev.column != null) {
          final col = KanbanColumn.fromDto(ev.column!);
          final rest = columns.where((c) => c.id != col.id).toList()..add(col);
          rest.sort((a, b) => (a.rank ?? '').compareTo(b.rank ?? ''));
          emit(KanbanBoardState(board: board, columns: rest, cards: cards));
        }
      case BoardEvent.columnDeleted:
        if (ev.column != null) {
          emit(KanbanBoardState(
            board: board,
            columns: columns.where((c) => c.id != ev.column!.id).toList(),
            cards: cards.where((c) => c.columnId != ev.column!.id).toList(),
          ));
        }
      case BoardEvent.boardUpdated:
      case BoardEvent.boardMoved:
        if (ev.board != null) {
          emit(KanbanBoardState(
            board: KanbanBoard.fromDto(ev.board!),
            columns: columns,
            cards: cards,
          ));
        }
      case BoardEvent.boardDeleted:
        emit(null);
      default:
        break;
    }

    // 事件驱动后顺手持久化缓存（离线可恢复到最新已知状态）。
    final after = state;
    if (after != null) {
      _cache.save(after);
    }
  }

void _onConnection(bool up) {
    if (up && _offline) {
      _offline = false;
      // 重连即重放离线队列并刷新快照。
      replayPending();
    } else if (up && !_offline && _boardId != 0) {
      load(_boardId);
    }
  }


  /// 差量合并：缓存状态 + SyncDelta → 最新状态。
  KanbanBoardState _mergeDelta(KanbanBoardState base, SyncDelta delta) {
    var board = base.board;
    if (delta.board != null) {
      board = delta.board!;
    }

    var columns = base.columns.where((c) => !delta.deletedColumnIds.contains(c.id)).toList();
    for (final c in delta.upsertedColumns) {
      columns = columns.where((e) => e.id != c.id).toList()..add(c);
    }
    columns.sort((a, b) => (a.rank ?? '').compareTo(b.rank ?? ''));

    var cards = base.cards.where((c) => !delta.deletedCardIds.contains(c.id)).toList();
    for (final c in delta.upsertedCards) {
      cards = cards.where((e) => e.id != c.id).toList()..add(c);
    }
    cards.sort((a, b) => (a.rank ?? '').compareTo(b.rank ?? ''));

    // 列删除连带清理其下卡片
    final liveColIds = columns.map((c) => c.id).toSet();
    cards = cards.where((c) => liveColIds.contains(c.columnId)).toList();

    return KanbanBoardState(board: board, columns: columns, cards: cards);
  }

  // ===== 内部工具 =====

  void _upsertCardDto(api.BoardServiceV1Card dto) {
    final state = this.state;
    if (state == null) return;
    final card = KanbanCard.fromDto(dto);
    final rest = state.cards.where((c) => c.id != card.id).toList()..add(card);
    rest.sort((a, b) => (a.rank ?? '').compareTo(b.rank ?? ''));
    emit(KanbanBoardState(board: state.board, columns: state.columns, cards: rest));
  }

  KanbanBoardState _mapCards(KanbanBoardState s, KanbanCard Function(KanbanCard) f) {
    return KanbanBoardState(board: s.board, columns: s.columns, cards: s.cards.map(f).toList());
  }

  KanbanBoardState _applyLocalMove(KanbanBoardState s, KanbanCard card, int toColumnId, int toIndex) {
    // 移动后该列的序列（无服务端 rank，按列表序临时排列；
    // 在线成功后由响应/事件回填真实 rank 恢复全序）。
    final others = s.cards.where((c) => c.columnId == toColumnId && c.id != card.id).toList()
      ..sort((a, b) => (a.rank ?? '').compareTo(b.rank ?? ''));
    final moved = card.copyWith(columnId: toColumnId);
    // 临时 rank：邻位之间取字典序中点的粗略近似（客户端仅用于展示排序，
    // 服务端响应到达后即被真实 rank 覆盖）。
    final lo = toIndex > 0 ? (others[toIndex - 1].rank ?? '') : '';
    final hi = toIndex < others.length ? (others[toIndex].rank ?? '') : '';
    final withRank = moved.copyWith(rank: _midRank(lo, hi));

    final rest = s.cards.where((c) => c.id != card.id).toList()..add(withRank);
    rest.sort((a, b) => (a.rank ?? '').compareTo(b.rank ?? ''));
    return KanbanBoardState(board: s.board, columns: s.columns, cards: rest);
  }

  /// 客户端侧 base-36 中点（展示用；服务端为权威）。
  static String _midRank(String lo, String hi) {
    const alphabet = '0123456789abcdefghijklmnopqrstuvwxyz';
    String pad(String s, int len) => s.padRight(len, '0');
    int val(String s, int i) => i < s.length ? alphabet.indexOf(s[i]) : 0;
    final len = lo.length > hi.length ? lo.length : hi.length;
    final a = pad(lo, len);
    final b = pad(hi.isEmpty ? 'z' * len : hi, len);
    final sb = StringBuffer();
    int carry = 0;
    for (int i = len - 1; i >= 0; i--) {
      final sum = val(a, i) + val(b, i) + carry;
      sb.write(alphabet[sum % 36]);
      carry = sum ~/ 36;
    }
    final rev = sb.toString().split('').reversed.join();
    final trimmed = rev.replaceAll(RegExp(r'0+$'), '');
    return trimmed.isEmpty ? '0' : trimmed;
  }

  static bool _isConnectionError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return true;
      default:
        return false;
    }
  }

  @override
  Future<void> close() {
    _eventSub?.cancel();
    _connSub?.cancel();
    _realtime.dispose();
    return super.close();
  }
}
