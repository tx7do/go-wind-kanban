import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_app/src/core/constants/index.dart' as constants;

import 'package:get_it/get_it.dart';
import 'package:flutter_app/src/core/repositories/user_auth_cache.dart';
import 'package:flutter_app/src/core/widgets/not_found_page.dart';
import 'package:flutter_app/src/core/widgets/web_shell_layout.dart';
import 'package:flutter_app/src/features/auth/pages/login_page.dart';
import 'package:flutter_app/src/features/auth/pages/profile_page.dart';
import 'package:flutter_app/src/features/board/pages/board_home_page.dart';
import 'package:flutter_app/src/features/board/pages/board_list_page.dart';
import 'package:flutter_app/src/core/utils/responsive_utils.dart';

/// 看板应用路由
class AppRouter {
  static const initial = constants.AppRoutePath.initial;

  static final router = GoRouter(
    initialLocation: initial,
    redirect: _guard,
    refreshListenable:
        GetIt.instance<UserAuthCache>().loginStateNotifier,
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
          // 看板列表（在线拉取，断网回落缓存）
          GoRoute(
            path: constants.AppRoutePath.initial,
            builder: (context, state) => const BoardListPage(),
          ),
          // 看板详情（宽屏多列 / 窄屏分页）
          GoRoute(
            path: '/board/:id',
            builder: (context, state) => BoardHomePage(
              boardId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
            ),
          ),
          // 个人中心（顶栏"我的"登录态入口）
          GoRoute(
            path: constants.AppRoutePath.profile,
            builder: (context, state) => const ProfilePage(),
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
    // 登录态由 UserAuthCache 维护：其 accessToken 字段在 init() 中从持久层恢复，
    // loginStateNotifier 在令牌保存/清除时触发，经 refreshListenable 让本守卫重新求值。
    // 这里只做软校验（有无令牌），令牌有效性由后端 auth 中间件裁定——
    // 无效令牌会以 401 返回，由 AuthenticationInterceptor 处理。
    final loggedIn =
        GetIt.instance<UserAuthCache>().hasLogin;
    final isLoginRoute = state.matchedLocation == constants.AppRoutePath.login;

    // 已登录仍停留在登录页 → 送回首页；未登录访问受保护页 → 送往登录页。
    if (loggedIn && isLoginRoute) {
      return constants.AppRoutePath.initial;
    }
    if (!loggedIn && !isLoginRoute) {
      return constants.AppRoutePath.login;
    }
    return null;
  }
}
