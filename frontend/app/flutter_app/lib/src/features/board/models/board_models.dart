import 'package:flutter_app/generated/api/app/service/v1/index.dart' as api;
import 'package:flutter_app/src/features/board/data/label_api.dart';

/// 看板领域模型（不可变）。
///
/// 与生成的 DTO（BoardServiceV1*）解耦：UI 只依赖本层，
/// DTO 仅在仓库层边界转换。`rank` 为 Lexorank 字典序字符串，
/// 排序恒以 `rank` 升序为准（服务端维护）。

class KanbanBoard {
  final int id;
  final String name;
  final String? description;
  final String? rank;
  final int version;

  const KanbanBoard({
    required this.id,
    required this.name,
    this.description,
    this.rank,
    this.version = 1,
  });

  factory KanbanBoard.fromDto(api.BoardServiceV1Board d) => KanbanBoard(
        id: d.id ?? 0,
        name: d.name ?? '',
        description: d.description,
        rank: d.rank,
        version: d.version ?? 1,
      );

  KanbanBoard copyWith({String? name, String? description, String? rank, int? version}) => KanbanBoard(
        id: id,
        name: name ?? this.name,
        description: description ?? this.description,
        rank: rank ?? this.rank,
        version: version ?? this.version,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'rank': rank,
        'version': version,
      };

  factory KanbanBoard.fromJson(Map<String, dynamic> j) => KanbanBoard(
        id: (j['id'] as num).toInt(),
        name: j['name'] as String? ?? '',
        description: j['description'] as String?,
        rank: j['rank'] as String?,
        version: (j['version'] as num?)?.toInt() ?? 1,
      );
}

class KanbanColumn {
  final int id;
  final int boardId;
  final String name;
  final String? color;
  final String? rank;
  final int version;

  const KanbanColumn({
    required this.id,
    required this.boardId,
    required this.name,
    this.color,
    this.rank,
    this.version = 1,
  });

  factory KanbanColumn.fromDto(api.BoardServiceV1Column d) => KanbanColumn(
        id: d.id ?? 0,
        boardId: d.boardId ?? 0,
        name: d.name ?? '',
        color: d.color,
        rank: d.rank,
        version: d.version ?? 1,
      );

  KanbanColumn copyWith({String? name, String? color, String? rank, int? version}) => KanbanColumn(
        id: id,
        boardId: boardId,
        name: name ?? this.name,
        color: color ?? this.color,
        rank: rank ?? this.rank,
        version: version ?? this.version,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'boardId': boardId,
        'name': name,
        'color': color,
        'rank': rank,
        'version': version,
      };

  factory KanbanColumn.fromJson(Map<String, dynamic> j) => KanbanColumn(
        id: (j['id'] as num).toInt(),
        boardId: (j['boardId'] as num?)?.toInt() ?? 0,
        name: j['name'] as String? ?? '',
        color: j['color'] as String?,
        rank: j['rank'] as String?,
        version: (j['version'] as num?)?.toInt() ?? 1,
      );
}

class KanbanCard {
  final int id;
  final int columnId;
  final int boardId;
  final String name;
  final String? description;
  final String? rank;
  final int version;

  const KanbanCard({
    required this.id,
    required this.columnId,
    required this.boardId,
    required this.name,
    this.description,
    this.rank,
    this.version = 1,
  });

  factory KanbanCard.fromDto(api.BoardServiceV1Card d) => KanbanCard(
        id: d.id ?? 0,
        columnId: d.columnId ?? 0,
        boardId: d.boardId ?? 0,
        name: d.name ?? '',
        description: d.description,
        rank: d.rank,
        version: d.version ?? 1,
      );

  KanbanCard copyWith({
    int? columnId,
    int? boardId,
    String? name,
    String? description,
    String? rank,
    int? version,
  }) =>
      KanbanCard(
        id: id,
        columnId: columnId ?? this.columnId,
        boardId: boardId ?? this.boardId,
        name: name ?? this.name,
        description: description ?? this.description,
        rank: rank ?? this.rank,
        version: version ?? this.version,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'columnId': columnId,
        'boardId': boardId,
        'name': name,
        'description': description,
        'rank': rank,
        'version': version,
      };

  factory KanbanCard.fromJson(Map<String, dynamic> j) => KanbanCard(
        id: (j['id'] as num).toInt(),
        columnId: (j['columnId'] as num?)?.toInt() ?? 0,
        boardId: (j['boardId'] as num?)?.toInt() ?? 0,
        name: j['name'] as String? ?? '',
        description: j['description'] as String?,
        rank: j['rank'] as String?,
        version: (j['version'] as num?)?.toInt() ?? 1,
      );
}

/// 看板完整状态（快照）：board + 列（rank 升序）+ 卡片（列内 rank 升序）+ 标签集合。
class KanbanBoardState {
  final KanbanBoard board;
  final List<KanbanColumn> columns;
  final List<KanbanCard> cards;
  final List<int> cardLabelIds;
  final List<KanbanLabel> labels;

  const KanbanBoardState({
    required this.board,
    required this.columns,
    required this.cards,
    this.cardLabelIds = const [],
    this.labels = const [],
  });

  factory KanbanBoardState.fromSnapshot(api.BoardServiceV1BoardSnapshot s) {
    final cols = (s.columns ?? [])
        .map(KanbanColumn.fromDto)
        .toList()
      ..sort((a, b) => (a.rank ?? '').compareTo(b.rank ?? ''));
    final cards = (s.cards ?? [])
        .map(KanbanCard.fromDto)
        .toList()
      ..sort((a, b) => (a.rank ?? '').compareTo(b.rank ?? ''));
    return KanbanBoardState(
      board: s.board != null
            ? KanbanBoard.fromDto(s.board!)
            : const KanbanBoard(id: 0, name: ''),
      columns: cols,
      cards: cards,
    );
  }

  /// 按列分组（保持列序与列内 rank 序）。
  Map<int, List<KanbanCard>> get cardsByColumn {
    final m = <int, List<KanbanCard>>{};
    for (final c in columns) {
      m[c.id] = [];
    }
    for (final card in cards) {
      m[card.columnId]?.add(card);
    }
    // 分组内恒按 rank 升序（与展示序一致）
    for (final k in m.keys) {
      m[k]!.sort((a, b) => (a.rank ?? '').compareTo(b.rank ?? ''));
    }
    return m;
  }

  Map<String, dynamic> toJson() => {
        'board': board.toJson(),
        'columns': columns.map((c) => c.toJson()).toList(),
        'cards': cards.map((c) => c.toJson()).toList(),
        'labels': labels.map((l) => l.toJson()).toList(),
      };

  factory KanbanBoardState.fromJson(Map<String, dynamic> j) => KanbanBoardState(
        board: KanbanBoard.fromJson((j['board'] as Map).cast<String, dynamic>()),
        columns: ((j['columns'] as List?) ?? [])
            .map((e) => KanbanColumn.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        cards: ((j['cards'] as List?) ?? [])
            .map((e) => KanbanCard.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        labels: ((j['labels'] as List?) ?? [])
            .map((e) => KanbanLabel.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
      );
}

/// 实时变更事件（服务端 protojson camelCase）。
class BoardEvent {
  final int type; // 与 BoardChangeEvent.Type 枚举值一致
  final int boardId;
  final int actorId;
  final api.BoardServiceV1Board? board;
  final api.BoardServiceV1Column? column;
  final api.BoardServiceV1Card? card;

  const BoardEvent({
    required this.type,
    required this.boardId,
    required this.actorId,
    this.board,
    this.column,
    this.card,
  });

  // 事件类型常量（与 board.service.v1.BoardChangeEvent.Type 对齐）
  static const boardCreated = 10;
  static const boardUpdated = 11;
  static const boardDeleted = 12;
  static const boardMoved = 13;
  static const columnCreated = 20;
  static const columnUpdated = 21;
  static const columnDeleted = 22;
  static const columnMoved = 23;
  static const cardCreated = 30;
  static const cardUpdated = 31;
  static const cardDeleted = 32;
  static const cardMoved = 33;
  static const labelCreated = 40;
  static const labelUpdated = 41;
  static const labelDeleted = 42;
  static const cardLabelsChanged = 50;

  factory BoardEvent.fromJson(Map<String, dynamic> j) {
    Map<String, dynamic>? payload;
    if (j['payload'] is Map) {
      payload = (j['payload'] as Map).cast<String, dynamic>();
    }
    return BoardEvent(
      type: (j['type'] as num?)?.toInt() ?? 0,
      boardId: (j['boardId'] as num?)?.toInt() ?? 0,
      actorId: (j['actorId'] as num?)?.toInt() ?? 0,
      board: payload == null || payload['board'] is! Map
          ? null
          : api.BoardServiceV1Board.fromJson((payload['board'] as Map).cast<String, dynamic>()),
      column: payload == null || payload['column'] is! Map
          ? null
          : api.BoardServiceV1Column.fromJson((payload['column'] as Map).cast<String, dynamic>()),
      card: payload == null || payload['card'] is! Map
          ? null
          : api.BoardServiceV1Card.fromJson((payload['card'] as Map).cast<String, dynamic>()),
    );
  }
}
