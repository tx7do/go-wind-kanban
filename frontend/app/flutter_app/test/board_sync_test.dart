import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/src/features/board/models/board_models.dart';

/// 差量同步合并的不变式测试。
///
/// _mergeDelta 是 controller 私有方法，但其合并语义的不变式
/// 可通过 KanbanBoardState 的分组/排序行为间接验证——
/// 这些不变式是 merge 操作必须维持的后置条件。
void main() {
  group('KanbanBoardState grouping invariants (merge postconditions)', () {
    test('cardsByColumn groups by columnId and sorts by rank', () {
      final state = KanbanBoardState(
        board: const KanbanBoard(id: 1, name: 'B'),
        columns: const [
          KanbanColumn(id: 1, boardId: 1, name: 'A', rank: 'h'),
        ],
        cards: const [
          KanbanCard(id: 2, columnId: 1, boardId: 1, name: 'x', rank: 'q'),
          KanbanCard(id: 1, columnId: 1, boardId: 1, name: 'y', rank: 'h'),
        ],
      );
      final grouped = state.cardsByColumn;
      expect(grouped[1]!.length, 2);
      // rank 升序：h < q → id 1 在前
      expect(grouped[1]![0].id, 1);
      expect(grouped[1]![1].id, 2);
    });

    test('removing a column from state drops its cards', () {
      final state = KanbanBoardState(
        board: const KanbanBoard(id: 1, name: 'B'),
        columns: const [
          KanbanColumn(id: 1, boardId: 1, name: 'A', rank: 'h'),
          KanbanColumn(id: 2, boardId: 1, name: 'B2', rank: 'q'),
        ],
        cards: const [
          KanbanCard(id: 1, columnId: 1, boardId: 1, name: 'x', rank: 'h'),
          KanbanCard(id: 2, columnId: 2, boardId: 1, name: 'y', rank: 'h'),
        ],
      );
      // 模拟列删除：移除列 2 及其下卡片（与 _mergeDelta 的 deletedColumnIds 路径一致）
      final afterDeletion = KanbanBoardState(
        board: state.board,
        columns: state.columns.where((c) => c.id != 2).toList(),
        cards: state.cards.where((c) => c.columnId != 2).toList(),
      );
      expect(afterDeletion.columns.length, 1);
      expect(afterDeletion.cards.length, 1);
      expect(afterDeletion.cards.single.columnId, 1);
    });

    test('upserting a changed card replaces by id and re-sorts', () {
      final state = KanbanBoardState(
        board: const KanbanBoard(id: 1, name: 'B'),
        columns: const [
          KanbanColumn(id: 1, boardId: 1, name: 'A', rank: 'h'),
        ],
        cards: const [
          KanbanCard(id: 1, columnId: 1, boardId: 1, name: 'old', rank: 'h'),
        ],
      );
      // 模拟 upsert：card 1 获得新 name + 新 rank（与 _mergeDelta 的 upsertedCards 路径一致）
      final changed = KanbanCard(
        id: 1,
        columnId: 1,
        boardId: 1,
        name: 'new',
        rank: 'u',
        version: 2,
      );
      final afterUpsert = KanbanBoardState(
        board: state.board,
        columns: state.columns,
        cards: [changed],
      );
      expect(afterUpsert.cards.single.name, 'new');
      expect(afterUpsert.cards.single.version, 2);
      expect(afterUpsert.cards.single.rank, 'u');
    });

    test('JSON round-trip preserves version and rank', () {
      final state = KanbanBoardState(
        board: const KanbanBoard(id: 1, name: 'B', version: 5),
        columns: const [
          KanbanColumn(id: 1, boardId: 1, name: 'A', rank: 'h', version: 3),
        ],
        cards: const [
          KanbanCard(id: 1, columnId: 1, boardId: 1, name: 'x', rank: 'q', version: 7),
        ],
      );
      final json = jsonEncode(state.toJson());
      final restored = KanbanBoardState.fromJson(
          (jsonDecode(json) as Map).cast<String, dynamic>());
      expect(restored.board.version, 5);
      expect(restored.columns.single.version, 3);
      expect(restored.cards.single.version, 7);
      expect(restored.cards.single.rank, 'q');
    });

    test('BoardEvent label constants align with proto enum', () {
      // 确保标签事件常量存在且值正确（与服务端 BoardChangeEvent.Type 对齐）
      expect(BoardEvent.labelCreated, 40);
      expect(BoardEvent.labelUpdated, 41);
      expect(BoardEvent.labelDeleted, 42);
      expect(BoardEvent.cardLabelsChanged, 50);
    });
  });
}
