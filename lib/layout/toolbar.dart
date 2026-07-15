import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'package:suika_multi_player/providers/auth_provider.dart';
import 'package:suika_multi_player/widgets/user_avatar.dart';

class Toolbar extends ConsumerWidget implements PreferredSizeWidget {
  const Toolbar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(40);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final user = auth.user;
    final theme = Theme.of(context);

    return GestureDetector(
      onPanStart: (_) => windowManager.startDragging(),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withValues(alpha: 0.95),
          border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
        ),
        child: Row(
          children: [
            const SizedBox(width: 12),
            Image.asset('assets/images/icon_clear.png', width: 20, height: 20),
            const SizedBox(width: 6),
            Text('Suika Multi Player',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
            const SizedBox(width: 24),
            if (user != null) ...[
              UserAvatar(
                avatarUrl: user.avatarUrl,
                fallback: user.nickname.isNotEmpty ? user.nickname[0].toUpperCase() : 'U',
                radius: 12,
              ),
              const SizedBox(width: 8),
              Text(user.nickname.isNotEmpty ? user.nickname : user.userName,
                style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withValues(alpha: 0.8))),
              const SizedBox(width: 6),
              Text('#${user.userUuid.substring(0, 6)}',
                style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.4))),
            ],
            const Spacer(),
          ],
        ),
      ),
    );
  }
}
