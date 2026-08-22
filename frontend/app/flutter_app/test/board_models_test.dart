import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/src/features/board/models/board_models.dart';

void main() {
  test('KanbanBoardState JSON round-trip', () {
    final state = KanbanBoardState(
      board: const KanbanBoard(id: 1, name: 'B', version: 3),
      columns: const [KanbanColumn(id: 5, boardId: 1, name: 'Todo', rank: 'h')],
      cards: const [
        KanbanCard(id: 9, columnId: 5, boardId: 1, name: 'C1', rank: 'q', version: 2),
        KanbanCard(id: 10, columnId: 5, boardId: 1, name: 'C2', rank: 'u'),
      ],
    );
    final restored = KanbanBoardState.fromJson(
        (jsonDecode(jsonEncode(state.toJson())) as Map).cast<String, dynamic>());
    expect(restored.board.id, 1);
    expect(restored.board.version, 3);
    expect(restored.columns.single.rank, 'h');
    expect(restored.cards.length, 2);
    expect(restored.cards.first.version, 2);
  });

  test('BoardEvent parses server protojson frame', () {
    const frame = '{"type":33,"boardId":1,"actorId":2,'
        '"occurredAt":{"seconds":1787392259,"nanos":805986100},'
        '"payload":{"card":{"id":5,"name":"Card E","rank":"w","version":2,'
        '"columnId":1,"boardId":1,"tenantId":1}}}';
    final ev = BoardEvent.fromJson(
        (jsonDecode(frame) as Map).cast<String, dynamic>());
    expect(ev.type, BoardEvent.cardMoved);
    expect(ev.boardId, 1);
    expect(ev.actorId, 2);
    expect(ev.card?.id, 5);
    expect(ev.card?.rank, 'w');
    expect(ev.card?.columnId, 1);
  });

  test('cardsByColumn groups and keeps rank order', () {
    final state = KanbanBoardState(
      board: const KanbanBoard(id: 1, name: 'B'),
      columns: const [
        KanbanColumn(id: 1, boardId: 1, name: 'A', rank: 'h'),
        KanbanColumn(id: 2, boardId: 1, name: 'B2', rank: 'q'),
      ],
      cards: const [
        KanbanCard(id: 2, columnId: 1, boardId: 1, name: 'x', rank: 'q'),
        KanbanCard(id: 1, columnId: 1, boardId: 1, name: 'y', rank: 'h'),
        KanbanCard(id: 3, columnId: 2, boardId: 1, name: 'z', rank: 'h'),
      ],
    );
    final grouped = state.cardsByColumn;
    expect(grouped[1]!.map((c) => c.id), [1, 2]);
    expect(grouped[2]!.single.id, 3);
  });
}
