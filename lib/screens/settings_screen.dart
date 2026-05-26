import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:suika_multi_player/models/user.dart';
import 'package:suika_multi_player/providers/auth_provider.dart';
import 'package:suika_multi_player/providers/server_config_provider.dart';
import 'package:suika_multi_player/utils/center_toast.dart';
import 'package:suika_multi_player/utils/log_buffer.dart';

Future<void> _exportLog(BuildContext context) async {
  try {
    final path = await LogBuffer.instance.saveToFile();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('日志已导出到 $path'),
        duration: const Duration(seconds: 4),
      ));
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('导出失败: $e'),
        duration: const Duration(seconds: 4),
      ));
    }
  }
}

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(serverConfigProvider);
    final user = ref.watch(authProvider.select((s) => s.user));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          Text(
            '设置',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white.withValues(alpha: 0.95),
            ),
          ),
          const SizedBox(height: 24),
          _SectionTitle('服务器配置'),
          const SizedBox(height: 12),
          _ServerConfigTile(
            host: config.host,
            port: config.port,
            onUpdate: (host, port) {
              ref.read(serverConfigProvider.notifier).update(host, port);
            },
          ),
          if (user?.isAdmin == true) ...[
            const SizedBox(height: 24),
            _SectionTitle('封禁管理'),
            const SizedBox(height: 12),
            _BanManagementCard(user: user!),
          ],
          const SizedBox(height: 24),
          _SectionTitle('调试'),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('导出运行日志',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.9))),
                  const SizedBox(height: 4),
                  Text(
                    '包含 HTTP 请求、WebSocket 消息等调试信息，导出到程序运行目录',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.4)),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _exportLog(context),
                      icon: const Icon(Icons.bug_report_rounded, size: 16),
                      label: const Text('导出日志'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _SectionTitle('关于'),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Suika Multi Player',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withValues(alpha: 0.9))),
                  const SizedBox(height: 4),
                  Text('v1.0.0',
                      style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.4))),
                  const SizedBox(height: 16),
                  Text('Powered by:',
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.2))),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 70,
                    child: Image.asset(
                      'assets/images/logo.png',
                      fit: BoxFit.contain,
                    ),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Colors.white.withValues(alpha: 0.45),
      ),
    );
  }
}

class _ServerConfigTile extends StatefulWidget {
  final String host;
  final int port;
  final void Function(String host, int port) onUpdate;

  const _ServerConfigTile({
    required this.host,
    required this.port,
    required this.onUpdate,
  });

  @override
  State<_ServerConfigTile> createState() => _ServerConfigTileState();
}

class _ServerConfigTileState extends State<_ServerConfigTile> {
  bool _editing = false;
  late TextEditingController _hostCtrl;
  late TextEditingController _portCtrl;

  @override
  void initState() {
    super.initState();
    _hostCtrl = TextEditingController(text: widget.host);
    _portCtrl = TextEditingController(text: widget.port.toString());
  }

  @override
  void didUpdateWidget(_ServerConfigTile old) {
    super.didUpdateWidget(old);
    if (!_editing) {
      _hostCtrl.text = widget.host;
      _portCtrl.text = widget.port.toString();
    }
  }

  @override
  void dispose() {
    _hostCtrl.dispose();
    _portCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            GestureDetector(
              onTap: () => setState(() => _editing = !_editing),
              child: Row(
                children: [
                  Icon(Icons.dns_rounded,
                      size: 20, color: Colors.white.withValues(alpha: 0.5)),
                  const SizedBox(width: 12),
                  Text(
                    '服务器地址',
                    style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.7)),
                  ),
                  const Spacer(),
                  Text(
                    '${widget.host}:${widget.port}',
                    style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.5)),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _editing
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                ],
              ),
            ),
            if (_editing) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _hostCtrl,
                      style:
                          const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: '主机地址',
                        hintStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.3),
                            fontSize: 13),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        isDense: true,
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text(':', style: TextStyle(color: Colors.white38)),
                  ),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _portCtrl,
                      keyboardType: TextInputType.number,
                      style:
                          const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: '端口',
                        hintStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.3),
                            fontSize: 13),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      final host = _hostCtrl.text.trim();
                      final port =
                          int.tryParse(_portCtrl.text.trim()) ?? 8001;
                      if (host.isNotEmpty) {
                        widget.onUpdate(host, port);
                        setState(() => _editing = false);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      child: const Icon(Icons.check_rounded,
                          size: 18, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BanManagementCard extends ConsumerStatefulWidget {
  final User user;
  const _BanManagementCard({required this.user});

  @override
  ConsumerState<_BanManagementCard> createState() =>
      _BanManagementCardState();
}

class _BanManagementCardState extends ConsumerState<_BanManagementCard> {
  List<Map<String, dynamic>>? _allUsers;
  List<Map<String, dynamic>>? _bannedUsers;
  List<Map<String, dynamic>>? _bannedIps;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(apiServiceProvider);
      final op = widget.user.userUuid;
      final results = await Future.wait([
        api.adminListUsers(op),
        api.adminListBannedUsers(op),
        api.adminListBannedIps(op),
      ]);
      if (!mounted) return;
      setState(() {
        _allUsers = results[0];
        _bannedUsers = results[1];
        _bannedIps = results[2];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _banUser(String userUuid) async {
    try {
      await ref.read(apiServiceProvider).banUser(
            operatorUuid: widget.user.userUuid,
            userUuid: userUuid,
          );
      if (!mounted) return;
      showCenterToast(context, message: '用户已封禁');
      _loadData();
    } catch (e) {
      if (!mounted) return;
      showCenterToast(context,
          message: '封禁失败: $e',
          backgroundColor: Colors.redAccent.withValues(alpha: 0.85));
    }
  }

  Future<void> _unbanUser(String userUuid) async {
    try {
      await ref.read(apiServiceProvider).unbanUser(
            operatorUuid: widget.user.userUuid,
            userUuid: userUuid,
          );
      if (!mounted) return;
      showCenterToast(context, message: '用户已解封');
      _loadData();
    } catch (e) {
      if (!mounted) return;
      showCenterToast(context,
          message: '解封失败: $e',
          backgroundColor: Colors.redAccent.withValues(alpha: 0.85));
    }
  }

  Future<void> _banIp(String ip) async {
    try {
      await ref.read(apiServiceProvider).banIp(
            operatorUuid: widget.user.userUuid,
            ip: ip,
          );
      if (!mounted) return;
      showCenterToast(context, message: 'IP 已封禁');
      _loadData();
    } catch (e) {
      if (!mounted) return;
      showCenterToast(context,
          message: '封禁IP失败: $e',
          backgroundColor: Colors.redAccent.withValues(alpha: 0.85));
    }
  }

  Future<void> _unbanIp(String ip) async {
    try {
      await ref.read(apiServiceProvider).unbanIp(
            operatorUuid: widget.user.userUuid,
            ip: ip,
          );
      if (!mounted) return;
      showCenterToast(context, message: 'IP 已解封');
      _loadData();
    } catch (e) {
      if (!mounted) return;
      showCenterToast(context,
          message: '解封IP失败: $e',
          backgroundColor: Colors.redAccent.withValues(alpha: 0.85));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_error != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text('加载失败: $_error',
                  style: const TextStyle(color: Colors.redAccent)),
              const SizedBox(height: 8),
              TextButton(
                  onPressed: _loadData, child: const Text('重试')),
            ],
          ),
        ),
      );
    }

    final allUsers = _allUsers ?? [];
    final bannedUsers = _bannedUsers ?? [];
    final bannedIps = _bannedIps ?? [];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('封禁管理',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.85))),
                ),
                IconButton(
                  onPressed: _loadData,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  tooltip: '刷新',
                  color: Colors.white.withValues(alpha: 0.4),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // 1. 所有用户列表
            Text('所有用户',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.45))),
            const SizedBox(height: 6),
            SizedBox(
              height: 200,
              child: allUsers.isEmpty
                  ? Center(
                      child: Text('暂无用户',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.3))),
                    )
                  : ListView.separated(
                      itemCount: allUsers.length,
                      separatorBuilder: (_, __) =>
                          Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),
                      itemBuilder: (_, i) {
                        final u = allUsers[i];
                        final uuid = u['user_uuid'] as String;
                        final name = u['nickname'] ?? u['user_name'] ?? '';
                        final ip = u['ip'] as String? ?? '';
                        final isBanned = u['is_banned'] == 1;
                        return ListTile(
                          dense: true,
                          visualDensity: VisualDensity.compact,
                          title: Text(name,
                              style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white.withValues(alpha: 0.8))),
                          subtitle: Text('$uuid  |  IP: $ip',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white.withValues(alpha: 0.3))),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!isBanned)
                                TextButton(
                                    onPressed: () => _banUser(uuid),
                                    child: const Text('封禁',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.redAccent))),
                              TextButton(
                                  onPressed: () => _banIp(ip),
                                  child: Text('封禁IP',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.orangeAccent
                                              .withValues(alpha: 0.8)))),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 16),
            // 2. 被封禁用户列表
            Text('被封禁用户',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.45))),
            const SizedBox(height: 6),
            SizedBox(
              height: 150,
              child: bannedUsers.isEmpty
                  ? Center(
                      child: Text('暂无被封禁用户',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.3))),
                    )
                  : ListView.separated(
                      itemCount: bannedUsers.length,
                      separatorBuilder: (_, __) =>
                          Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),
                      itemBuilder: (_, i) {
                        final u = bannedUsers[i];
                        final uuid = u['user_uuid'] as String;
                        final name = u['nickname'] ?? u['user_name'] ?? '';
                        final reason = u['ban_reason'] as String?;
                        return ListTile(
                          dense: true,
                          visualDensity: VisualDensity.compact,
                          title: Text(name,
                              style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white.withValues(alpha: 0.8))),
                          subtitle: Text(
                              reason != null && reason.isNotEmpty
                                  ? '$uuid  |  原因: $reason'
                                  : uuid,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white.withValues(alpha: 0.3))),
                          trailing: TextButton(
                              onPressed: () => _unbanUser(uuid),
                              child: const Text('解封',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.greenAccent))),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 16),
            // 3. 被封禁IP列表
            Text('被封禁IP',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.45))),
            const SizedBox(height: 6),
            SizedBox(
              height: 120,
              child: bannedIps.isEmpty
                  ? Center(
                      child: Text('暂无被封禁IP',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.3))),
                    )
                  : ListView.separated(
                      itemCount: bannedIps.length,
                      separatorBuilder: (_, __) =>
                          Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),
                      itemBuilder: (_, i) {
                        final entry = bannedIps[i];
                        final ip = entry['ip'] as String;
                        final reason = entry['ban_reason'] as String?;
                        return ListTile(
                          dense: true,
                          visualDensity: VisualDensity.compact,
                          title: Text(ip,
                              style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white.withValues(alpha: 0.8))),
                          subtitle: reason != null && reason.isNotEmpty
                              ? Text('原因: $reason',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.white.withValues(alpha: 0.3)))
                              : null,
                          trailing: TextButton(
                              onPressed: () => _unbanIp(ip),
                              child: const Text('解封',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.greenAccent))),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
