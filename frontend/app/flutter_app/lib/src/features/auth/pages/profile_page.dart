import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_app/generated/l10n.dart';
import 'package:flutter_app/src/core/constants/router_paths.dart';
import 'package:flutter_app/src/core/repositories/user_auth_cache.dart';
import 'package:flutter_app/src/features/auth/services/authentication_service.dart';

/// 个人中心页面
///
/// Web 端顶栏"我的"按钮的登录态跳转目标：
/// 展示当前登录账号，提供退出登录入口。
/// 完整的个人资料编辑能力随看板产品需求另行设计。
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _authService = AuthenticationService();

  @override
  void initState() {
    super.initState();
    // 全局路由守卫尚未启用；直接访问 /profile 时未登录跳回登录页
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!GetIt.instance<UserAuthCache>().hasLogin) {
        context.go(AppRoutePath.login);
      }
    });
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(S.of(dialogContext).logout),
        content: Text(S.of(dialogContext).logoutConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(S.of(dialogContext).cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(S.of(dialogContext).confirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await _authService.logoutMutation().mutate(null);
    } catch (_) {
      // 服务端登出失败时也清除本地令牌，保证本地登出状态一致
      await GetIt.instance<UserAuthCache>().clearTokens();
    }
    if (!mounted) return;
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = S.of(context);
    final authCache = GetIt.instance<UserAuthCache>();

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha((0.06 * 255).round()),
                blurRadius: 32,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.person_outline,
                  size: 36,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                loc.me,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${loc.userID}: ${authCache.userId}',
                style: TextStyle(
                  fontSize: 14,
                  color: theme.colorScheme.onSurface.withAlpha(140),
                ),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: _handleLogout,
                  icon: const Icon(Icons.logout),
                  label: Text(
                    loc.logout,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
