import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_app/src/core/constants/index.dart' as constants;

import 'package:flutter_app/src/core/widgets/not_found_page.dart';
import 'package:flutter_app/src/core/widgets/web_shell_layout.dart';
import 'package:flutter_app/src/features/auth/pages/login_page.dart';
import 'package:flutter_app/src/features/board/pages/board_home_page.dart';
import 'package:flutter_app/src/core/utils/responsive_utils.dart';

/// 看板应用路由
class AppRouter {
  static const initial = constants.AppRoutePath.initial;

  static final router = GoRouter(
    initialLocation: initial,
    redirect: _guard,
    errorBuilder: (context, state) => const NotFoundPage(),
    routes: [
      // Web 端持久化顶部导航栏 Shell
      ShellRoute(
        builder: (context, state, child) {
          if (ResponsiveUtils.isMobile(context)) {
            return child;
          }
          return WebShellLayout(
            currentPath: state.uri.path,
            child: child,
          );
        },
        routes: [
          // 看板主页（占位，后续接入 appflowy_board）
          GoRoute(
            path: constants.AppRoutePath.initial,
            builder: (context, state) => const BoardHomePage(),
          ),
        ],
      ),
      // 登录页（不在 Shell 内）
      GoRoute(
        path: constants.AppRoutePath.login,
        builder: (context, state) {
          return const LoginPage();
        },
      ),
    ],
  );

  static FutureOr<String?> _guard(BuildContext context, GoRouterState state) {
    // 看板数据需要登录访问；完整的 token 校验与跳转逻辑随离线同步任务一并实现。
    return null;
  }
}
