import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';

import 'package:flutter_app/src/features/board/models/board_models.dart';

/// 看板标签（领域模型，与 DTO 解耦）。
class KanbanLabel {
  final int id;
  final int boardId;
  final String name;
  final String color;

  const KanbanLabel({
    required this.id,
    required this.boardId,
    required this.name,
    required this.color,
  });

  factory KanbanLabel.fromJson(Map<String, dynamic> j) => KanbanLabel(
        id: (j['id'] as num).toInt(),
        boardId: (j['boardId'] as num?)?.toInt() ?? 0,
        name: j['name'] as String? ?? '',
        color: j['color'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'boardId': boardId,
        'name': name,
        'color': color,
      };
}

/// 手写标签 API 客户端。
///
/// 生成器仅产出 list 方法，get/create/update/delete/setCardLabels/getCardLabels
/// 缺失。此客户端以 dio 直调覆盖全部操作。
class LabelApi {
  final Dio _dio = GetIt.instance<Dio>();

  /// 拉取看板级标签全集。
  Future<List<KanbanLabel>> listByBoard(int boardId) async {
    final resp = await _dio.get<Map<String, dynamic>>(
      '/app/v1/labels',
      queryParameters: {'no_paging': true},
    );
    final items = (resp.data?['items'] as List? ?? []);
    // 服务端 list 不按 board 过滤；客户端侧过滤
    return items
        .map((e) => KanbanLabel.fromJson((e as Map).cast<String, dynamic>()))
        .where((l) => l.boardId == boardId)
        .toList();
  }

  /// 创建标签。
  Future<KanbanLabel> create(int boardId, String name, String color) async {
    final resp = await _dio.post<Map<String, dynamic>>(
      '/app/v1/labels',
      data: {'data': {'name': name, 'color': color, 'board_id': boardId}},
    );
    return KanbanLabel.fromJson((resp.data as Map).cast<String, dynamic>());
  }

  /// 更新标签。
  Future<void> update(int id, String name, String color) async {
    await _dio.put(
      '/app/v1/labels/$id',
      data: {
        'data': {'name': name, 'color': color},
        'update_mask': 'name,color',
      },
    );
  }

  /// 删除标签。
  Future<void> delete(int id) async {
    await _dio.delete('/app/v1/labels/$id');
  }

  /// 查询卡片标签集合。
  Future<List<KanbanLabel>> getCardLabels(int cardId) async {
    final resp = await _dio.get<Map<String, dynamic>>(
      '/app/v1/cards/$cardId/labels',
    );
    final items = (resp.data?['items'] as List? ?? []);
    return items
        .map((e) => KanbanLabel.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  /// 设置卡片标签集合（全量替换）。
  Future<void> setCardLabels(int cardId, List<int> labelIds) async {
    await _dio.post(
      '/app/v1/cards/$cardId:set-labels',
      data: {'label_ids': labelIds},
    );
  }
}
