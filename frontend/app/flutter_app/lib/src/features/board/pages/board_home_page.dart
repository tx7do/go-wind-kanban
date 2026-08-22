import 'package:flutter/material.dart';

import 'package:flutter_app/generated/l10n.dart' as l10n;

/// 看板主页（占位）。
///
/// CMS 功能树已移除；此处为看板 UI 的挂载点，
/// 后续将接入 GetBoardSnapshot → appflowy_board 渲染。
class BoardHomePage extends StatelessWidget {
  const BoardHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.view_kanban_outlined, size: 64),
            const SizedBox(height: 16),
            Text(
              l10n.S.of(context).appName,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              '看板模块开发中（Board / Column / Card API 已就绪）',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
