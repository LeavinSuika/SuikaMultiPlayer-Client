import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:suika_multi_player/providers/server_config_provider.dart';
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Suika Multi Player',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.9))),
                  const SizedBox(height: 4),
                  Text('v1.0.0',
                      style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.45))),
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
