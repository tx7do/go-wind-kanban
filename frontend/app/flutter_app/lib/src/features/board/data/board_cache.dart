import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import 'package:flutter_app/src/features/board/models/board_models.dart';

/// 看板快照本地缓存（Hive）。
///
/// 离线优先：打开看板时先出缓存立即渲染，再网络刷新；
/// 断网时缓存即唯一数据源，本地修改进入 Pending Queue，
/// 联网后重放（见 PendingOps）。
class BoardCache {
  static const _boxName = 'go_wind_kanban_boards';

  final Box<String> _box;

  BoardCache._(this._box);

  static Future<BoardCache> open() async {
    final box = await Hive.openBox<String>(_boxName);
    return BoardCache._(box);
  }

  /// 写入看板状态快照（按 board id 键）。
  Future<void> save(KanbanBoardState state) async {
    await _box.put('board_${state.board.id}', jsonEncode(state.toJson()));
  }

  /// 读取缓存快照；无缓存返回 null。
  KanbanBoardState? read(int boardId) {
    final raw = _box.get('board_$boardId');
    if (raw == null) return null;
    try {
      return KanbanBoardState.fromJson(
          (jsonDecode(raw) as Map).cast<String, dynamic>());
    } catch (_) {
      return null;
    }
  }

  /// 列出全部已缓存看板的元信息（离线看板列表页用）。
  List<KanbanBoard> listBoards() {
    final result = <KanbanBoard>[];
    for (final key in _box.keys) {
      if (key is! String || !key.startsWith('board_')) continue;
      final raw = _box.get(key);
      if (raw == null) continue;
      try {
        final j = (jsonDecode(raw) as Map).cast<String, dynamic>();
        result.add(KanbanBoard.fromJson((j['board'] as Map).cast<String, dynamic>()));
      } catch (_) {
        // 损坏条目跳过
      }
    }
    return result;
  }
}

/// 离线待同步操作队列（Hive 持久化）。
///
/// 断网期间本地执行的移动/重命名等操作按序入队；
/// 联网后按 FIFO 重放到服务端。重放失败的冲突操作
/// （如乐观锁版本不符）交给上层以最新服务端状态裁决。
class PendingOps {
  static const _boxName = 'go_wind_kanban_pending_ops';

  final Box<String> _box;

  PendingOps._(this._box);

  static Future<PendingOps> open() async {
    final box = await Hive.openBox<String>(_boxName);
    return PendingOps._(box);
  }

  /// 离线操作载荷：按 MoveCard 请求的字段裁剪。
  static Map<String, dynamic> moveCardOp({
    required int cardId,
    int? targetColumnId,
    int? beforeId,
    int? afterId,
    int? expectedVersion,
  }) =>
      {
        'op': 'card.move',
        'cardId': cardId,
        if (targetColumnId != null) 'targetColumnId': targetColumnId,
        if (beforeId != null) 'beforeId': beforeId,
        if (afterId != null) 'afterId': afterId,
        if (expectedVersion != null) 'expectedVersion': expectedVersion,
      };

  static Map<String, dynamic> renameCardOp(
      {required int cardId, required String name, int? expectedVersion}) => {
        'op': 'card.rename',
        'cardId': cardId,
        'name': name,
        if (expectedVersion != null) 'expectedVersion': expectedVersion,
      };

  static Map<String, dynamic> createCardOp({
    required int columnId,
    required String name,
    int? tempId,
  }) =>
      {
        'op': 'card.create',
        'columnId': columnId,
        'name': name,
        if (tempId != null) 'tempId': tempId,
      };

  static Map<String, dynamic> deleteCardOp({required int cardId}) => {
        'op': 'card.delete',
        'cardId': cardId,
      };

  /// 入队（追加尾部）。
  Future<void> enqueue(Map<String, dynamic> op) async {
    await _box.add(jsonEncode(op));
  }

  /// 待重放操作数。
  int get length => _box.length;

  bool get isEmpty => _box.isEmpty;

  /// 自队首弹出一条（重放成功后调用）。
  Future<Map<String, dynamic>?> dequeue() async {
    if (_box.isEmpty) return null;
    final key = _box.keys.first;
    final raw = _box.get(key);
    await _box.delete(key);
    if (raw == null) return null;
    return (jsonDecode(raw) as Map).cast<String, dynamic>();
  }

  /// 清空队列（用户主动放弃离线修改时）。
  Future<void> clear() async {
    await _box.clear();
  }
}
