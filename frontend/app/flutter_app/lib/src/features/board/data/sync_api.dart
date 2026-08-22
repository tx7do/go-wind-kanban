import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';

import 'package:flutter_app/src/features/board/models/board_models.dart';

/// 差量同步结果（领域模型形态）。
class SyncDelta {
  final KanbanBoard? board;
  final List<KanbanColumn> upsertedColumns;
  final Set<int> deletedColumnIds;
  final List<KanbanCard> upsertedCards;
  final Set<int> deletedCardIds;

  const SyncDelta({
    this.board,
    this.upsertedColumns = const [],
    this.deletedColumnIds = const {},
    this.upsertedCards = const [],
    this.deletedCardIds = const {},
  });

  bool get isEmpty =>
      board == null &&
      upsertedColumns.isEmpty &&
      deletedColumnIds.isEmpty &&
      upsertedCards.isEmpty &&
      deletedCardIds.isEmpty;
}

/// 手写差量同步客户端。
///
/// 代码生成器（protoc-gen-dart-http）尚未支持 SyncBoard 的请求形态，
/// 此处以 dio 直调 POST /app/v1/boards/{id}:sync 并解析为领域模型；
/// 生成器支持后可切换回生成的 BoardServiceClient.syncBoard。
Future<SyncDelta> syncBoard({
  required int boardId,
  required int knownBoardVersion,
  required Map<int, int> knownColumnVersions,
  required Map<int, int> knownCardVersions,
}) async {
  final dio = GetIt.instance<Dio>();
  final resp = await dio.post<Map<String, dynamic>>(
    '/app/v1/boards/$boardId:sync',
    data: <String, dynamic>{
      'boardId': boardId,
      'knownBoardVersion': knownBoardVersion,
      'knownColumnVersions': [
        for (final e in knownColumnVersions.entries) {'id': e.key, 'version': e.value},
      ],
      'knownCardVersions': [
        for (final e in knownCardVersions.entries) {'id': e.key, 'version': e.value},
      ],
    },
  );

  final j = resp.data ?? const <String, dynamic>{};
  return SyncDelta(
    board: j['board'] is Map
        ? KanbanBoard.fromJson((j['board'] as Map).cast<String, dynamic>())
        : null,
    upsertedColumns: (j['upsertedColumns'] as List? ?? [])
        .map((e) => KanbanColumn.fromJson((e as Map).cast<String, dynamic>()))
        .toList(),
    deletedColumnIds: (j['deletedColumnIds'] as List? ?? [])
        .map((e) => (e as num).toInt())
        .toSet(),
    upsertedCards: (j['upsertedCards'] as List? ?? [])
        .map((e) => KanbanCard.fromJson((e as Map).cast<String, dynamic>()))
        .toList(),
    deletedCardIds: (j['deletedCardIds'] as List? ?? [])
        .map((e) => (e as num).toInt())
        .toSet(),
  );
}
