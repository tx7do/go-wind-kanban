import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_app/generated/l10n.dart';
import 'package:flutter_app/src/core/constants/router_paths.dart';
import 'package:flutter_app/src/core/preference/user_preference_cache.dart';
import 'package:flutter_app/src/core/repositories/user_auth_cache.dart';

/// Web 端持久化顶部导航栏 Shell 布局
///
/// 包裹所有 Web 端页面，提供一致的顶部导航栏。
/// 移动端由 ShellRoute 直接返回 child，不经过此组件。
///
/// 导航域已移除；导航项改为静态配置，
/// 服务端驱动的导航随看板产品需求另行设计。
class WebShellLayout extends StatefulWidget {
  final Widget child;
  final String currentPath;

  const WebShellLayout({
    super.key,
    required this.child,
    required this.currentPath,
  });

  @override
  State<WebShellLayout> createState() => _WebShellLayoutState();
}

class _WebShellLayoutState extends State<WebShellLayout> {
  /// 获取当前用户语言偏好（保留：后续看板 i18n 复用）
  // ignore: unused_element
  String? get _currentLocale {
    try {
      final lang = GetIt.instance<UserPreferenceCache>().language;
      if (lang.isEmpty) return null;
      return lang.replaceAll('_', '-');
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        title: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => context.go('/'),
            child: Text(
              S.of(context).appName,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ),
        centerTitle: false,
        actions: [
          const SizedBox(width: 8),
          // 登录/个人中心
          ValueListenableBuilder<bool>(
            valueListenable: GetIt.instance<UserAuthCache>().loginStateNotifier,
            builder: (context, hasLogin, _) {
              return MouseRegion(
                cursor: SystemMouseCursors.click,
                child: OutlinedButton(
                  onPressed: () => context.go(AppRoutePath.login),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(hasLogin ? S.of(context).me : S.of(context).login),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: widget.child,
    );
  }
}
