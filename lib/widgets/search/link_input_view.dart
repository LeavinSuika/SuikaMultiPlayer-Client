import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:suika_multi_player/models/room.dart';
import 'package:suika_multi_player/providers/room_provider.dart';
import 'package:suika_multi_player/providers/websocket_provider.dart';
import 'package:suika_multi_player/utils/center_toast.dart';

class LinkInputView extends ConsumerStatefulWidget {
  final VoidCallback? onClose;
  const LinkInputView({super.key, this.onClose});

  @override
  ConsumerState<LinkInputView> createState() => _LinkInputViewState();
}

class _LinkInputViewState extends ConsumerState<LinkInputView> {
  final _linkCtrl = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _linkCtrl.dispose();
    super.dispose();
  }

  String? _parseSongId(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return null;
    try {
      final uri = Uri.parse(trimmed);
      if (uri.host.contains('music.163.com') || uri.host.contains('163cn.tv')) {
        return uri.queryParameters['id'];
      }
      final idMatch = RegExp(r'[?&]id=(\d+)').firstMatch(trimmed);
      return idMatch?.group(1);
    } catch (_) {
      final idMatch = RegExp(r'[?&]id=(\d+)').firstMatch(trimmed);
      return idMatch?.group(1);
    }
  }

  Future<void> _submit() async {
    final songId = _parseSongId(_linkCtrl.text);
    if (songId == null || songId.isEmpty) {
      showCenterToast(
        context,
        message: '解析失败',
        backgroundColor: Colors.redAccent.withValues(alpha: 0.85),
        duration: const Duration(seconds: 4),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final room = ref.read(roomProvider);
      if (room.currentRoom == null) {
        showCenterToast(context, message: '请先加入或创建房间');
        return;
      }

      ref.read(websocketProvider).sendPlaylistAdd([
        {'track_id': songId}
      ]);
      final newList = [...room.playlist, PlaylistEntry(trackId: songId)];
      ref.read(roomProvider.notifier).updatePlaylist(newList);
      showCenterToast(context, message: '已添加歌曲');
      if (mounted) {
        Navigator.pop(context);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  '输入分享链接',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              if (widget.onClose != null)
                IconButton(
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.close_rounded, size: 20),
                  color: Colors.white.withValues(alpha: 0.5),
                  tooltip: '关闭',
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: TextField(
            controller: _linkCtrl,
            autofocus: true,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: '粘贴网易云分享链接...',
              hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.35),
                  fontSize: 14),
              prefixIcon: Icon(Icons.link_rounded,
                  size: 20, color: Colors.white.withValues(alpha: 0.4)),
              suffixIcon: _linkCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () {
                        _linkCtrl.clear();
                        setState(() {});
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              isDense: true,
            ),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _submit(),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, 4),
          child: Text(
            '支持 music.163.com 分享链接，自动提取歌曲 ID',
            style: TextStyle(fontSize: 11, color: Colors.white38),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('解析并添加'),
            ),
          ),
        ),
      ],
    );
  }
}

void showLinkInputOverlay(BuildContext context) {
  showDialog(
    context: context,
    barrierColor: Colors.black54,
    builder: (_) => Dialog(
      backgroundColor: const Color(0xFF1E1E1E),
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 80, vertical: 60),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: LinkInputView(onClose: () => Navigator.pop(context)),
    ),
  );
}
