import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:suika_multi_player/models/room.dart';
import 'package:suika_multi_player/models/track.dart';
import 'package:suika_multi_player/providers/music_provider.dart';
import 'package:suika_multi_player/providers/room_provider.dart';
import 'package:suika_multi_player/providers/websocket_provider.dart';
import 'package:suika_multi_player/utils/center_toast.dart';
import 'package:suika_multi_player/widgets/search/link_input_view.dart';

class SearchView extends ConsumerStatefulWidget {
  final VoidCallback? onClose;
  const SearchView({super.key, this.onClose});

  @override
  ConsumerState<SearchView> createState() => _SearchViewState();
}

void showSearchOverlay(BuildContext context) {
  showDialog(
    context: context,
    barrierColor: Colors.black54,
    builder: (_) => Dialog(
      backgroundColor: const Color(0xFF1E1E1E),
      insetPadding: const EdgeInsets.symmetric(horizontal: 80, vertical: 60),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SearchView(onClose: () => Navigator.pop(context)),
    ),
  );
}

class _SearchViewState extends ConsumerState<SearchView> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _addTrack(Track track) {
    final room = ref.read(roomProvider);
    if (room.currentRoom == null) {
      showCenterToast(context, message: '请先加入或创建房间');
      return;
    }
    ref.read(trackCacheProvider.notifier).cache(track);
    ref.read(websocketProvider).sendPlaylistAdd([
      {'track_id': track.id, 'duration': track.durationMs ?? 0}
    ]);
    final newList = [...room.playlist, PlaylistEntry(trackId: track.id)];
    ref.read(roomProvider.notifier).updatePlaylist(newList);
    showCenterToast(context, message: '已添加: ${track.name}');
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(searchProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: '搜索歌曲...',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 14),
                    prefixIcon: Icon(Icons.search_rounded, size: 20, color: Colors.white.withValues(alpha: 0.4)),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              ref.read(searchProvider.notifier).clear();
                              setState(() {});
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    isDense: true,
                  ),
                  onSubmitted: (v) {
                    if (v.trim().isNotEmpty) {
                      ref.read(searchProvider.notifier).search(v.trim());
                    }
                  },
                  onChanged: (_) => setState(() {}),
                ),
              ),
              if (widget.onClose != null) ...[
                const SizedBox(width: 4),
                IconButton(
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.close_rounded, size: 20),
                  color: Colors.white.withValues(alpha: 0.5),
                  tooltip: '关闭',
                ),
              ],
            ],
          ),
        ),
        Flexible(
          child: results.when(
            data: (tracks) => tracks.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(40),
                    child: Text(
                      _searchCtrl.text.isNotEmpty ? '无搜索结果' : '输入关键词搜索歌曲',
                      style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.35)),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: tracks.length,
                    itemBuilder: (_, i) => _TrackTile(track: tracks[i], onAdd: () => _addTrack(tracks[i])),
                  ),
            loading: () => const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (err, _) => Padding(
              padding: const EdgeInsets.all(40),
              child: Center(child: Text('搜索出错', style: TextStyle(color: Colors.redAccent.withValues(alpha: 0.7)))),
            ),
          ),
        ),
      ],
    );
  }
}

class _TrackTile extends StatelessWidget {
  final Track track;
  final VoidCallback onAdd;

  const _TrackTile({required this.track, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
        ),
        child: track.coverUrl != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  track.coverUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Icon(Icons.music_note_rounded, size: 20, color: Colors.white.withValues(alpha: 0.5)),
                ),
              )
            : Icon(Icons.music_note_rounded, size: 20, color: Colors.white.withValues(alpha: 0.5)),
      ),
      title: Text(track.name, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.9))),
      subtitle: Text('${track.artist}${track.album != null ? ' · ${track.album}' : ''}',
          maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.4))),
      trailing: IconButton(
        icon: Icon(Icons.add_circle_outline_rounded, size: 22, color: theme.colorScheme.primary),
        onPressed: onAdd,
        tooltip: '添加到歌单',
      ),
    );
  }
}

void showAddSongDialog(BuildContext context) {
  showDialog(
    context: context,
    barrierColor: Colors.black54,
    builder: (ctx) => Dialog(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 280,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '添加歌曲',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    showSearchOverlay(context);
                  },
                  icon: const Icon(Icons.search_rounded, size: 20),
                  label: const Text('搜索歌曲'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    showLinkInputOverlay(context);
                  },
                  icon: const Icon(Icons.link_rounded, size: 20),
                  label: const Text('输入链接'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    ),
  );
}
