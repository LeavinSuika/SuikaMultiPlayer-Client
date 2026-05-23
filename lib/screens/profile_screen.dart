import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:suika_multi_player/providers/auth_provider.dart';
import 'package:suika_multi_player/screens/login_screen.dart';
import 'package:suika_multi_player/utils/center_toast.dart';
import 'package:suika_multi_player/widgets/crop_avatar_dialog.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _uploading = false;

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final user = auth.user;
    final theme = Theme.of(context);

    if (user == null) return const SizedBox.shrink();

    final hasAvatar =
        user.avatarUrl != null && user.avatarUrl!.isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 16),
          // 头像
          GestureDetector(
            onTap: _uploading ? null : () => _changeAvatar(),
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: hasAvatar
                    ? null
                    : LinearGradient(
                        colors: [
                          theme.colorScheme.primary,
                          theme.colorScheme.tertiary,
                        ],
                      ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: hasAvatar
                  ? ClipOval(
                      child: Image.network(
                        user.avatarUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _buildInitials(user.nickname, user.userName),
                      ),
                    )
                  : _buildInitials(user.nickname, user.userName),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            user.nickname,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.95),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '@${user.userName}',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.45),
            ),
          ),
          const SizedBox(height: 24),
          _InfoCard(
            title: '用户 ID',
            value: '#${user.userUuid.substring(0, 8)}...',
            icon: Icons.fingerprint_rounded,
          ),
          const SizedBox(height: 12),
          _InfoCard(
            title: '角色',
            value: user.isAdmin ? '管理员' : '普通用户',
            icon: user.isAdmin
                ? Icons.admin_panel_settings_rounded
                : Icons.person_rounded,
          ),
          const SizedBox(height: 24),
          _ActionButton(
            icon: Icons.camera_alt_rounded,
            label: '更换头像',
            onTap: _uploading ? null : () => _changeAvatar(),
          ),
          const SizedBox(height: 12),
          _ActionButton(
            icon: Icons.edit_rounded,
            label: '修改昵称',
            onTap: () => _showEditNickname(context, ref),
          ),
          const SizedBox(height: 12),
          _ActionButton(
            icon: Icons.lock_reset_rounded,
            label: '修改密码',
            onTap: () => _showChangePwd(context, ref),
          ),
          const SizedBox(height: 12),
          _ActionButton(
            icon: Icons.logout_rounded,
            label: '退出登录',
            onTap: () async {
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (_) => false,
                );
              }
            },
            isDestructive: true,
          ),
        ],
      ),
    );
  }

  Widget _buildInitials(String nickname, String userName) {
    final letter = nickname.isNotEmpty
        ? nickname[0].toUpperCase()
        : userName[0].toUpperCase();
    return Center(
      child: Text(
        letter,
        style: const TextStyle(
          fontSize: 36,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  Future<void> _changeAvatar() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.path == null) return;

      // 1:1 裁切
      final croppedPath = await CropAvatarDialog.show(context, file.path!);
      if (croppedPath == null || !mounted) return; // 用户取消

      setState(() => _uploading = true);

      final api = ref.read(apiServiceProvider);
      final upload = await api.uploadImage(croppedPath);
      final imageId = upload['image_id'] as String;
      final url = upload['url'] as String;

      await api.updateAvatar(
        userUuid: user.userUuid,
        avatarUrl: url,
        avatarKey: imageId,
      );

      await ref.read(authProvider.notifier).refreshUser();

      if (mounted) {
        showCenterToast(context, message: '头像已更新');
      }
    } catch (e) {
      if (mounted) {
        showCenterToast(
          context,
          message: '上传失败: $e',
          backgroundColor: Colors.redAccent.withValues(alpha: 0.85),
          duration: const Duration(seconds: 3),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _showEditNickname(BuildContext context, WidgetRef ref) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('修改昵称'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: '新昵称 (最多20字)'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消')),
          ElevatedButton(
            onPressed: () async {
              final name = ctrl.text.trim();
              if (name.isEmpty) return;
              final user = ref.read(authProvider).user;
              if (user == null) return;
              try {
                final api = ref.read(apiServiceProvider);
                await api.updateNickname(
                    userUuid: user.userUuid, nickname: name);
                ref.read(authProvider.notifier).refreshUser();
                Navigator.pop(ctx);
              } catch (_) {}
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showChangePwd(BuildContext context, WidgetRef ref) {
    final oldCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('修改密码'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: oldCtrl,
              obscureText: true,
              decoration: const InputDecoration(hintText: '旧密码'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newCtrl,
              obscureText: true,
              decoration: const InputDecoration(hintText: '新密码 (至少6位)'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消')),
          ElevatedButton(
            onPressed: () async {
              final user = ref.read(authProvider).user;
              if (user == null) return;
              try {
                final api = ref.read(apiServiceProvider);
                await api.resetPwd(
                  userUuid: user.userUuid,
                  oldPwd: oldCtrl.text,
                  newPwd: newCtrl.text,
                );
                Navigator.pop(ctx);
              } catch (_) {}
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _InfoCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Colors.white.withValues(alpha: 0.5)),
            const SizedBox(width: 12),
            Text(title,
                style: TextStyle(
                    fontSize: 13, color: Colors.white.withValues(alpha: 0.5))),
            const Spacer(),
            Text(value,
                style: TextStyle(
                    fontSize: 14, color: Colors.white.withValues(alpha: 0.8))),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool isDestructive;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon,
                  size: 20,
                  color: isDestructive
                      ? Colors.redAccent.withValues(alpha: 0.8)
                      : Colors.white.withValues(alpha: 0.6)),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: isDestructive
                      ? Colors.redAccent.withValues(alpha: 0.8)
                      : Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
