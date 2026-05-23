import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:suika_multi_player/models/room.dart';
import 'package:suika_multi_player/models/track.dart';
import 'package:suika_multi_player/providers/music_provider.dart';
import 'package:suika_multi_player/providers/room_provider.dart';
import 'package:suika_multi_player/providers/websocket_provider.dart';
import 'package:suika_multi_player/utils/center_toast.dart';

class SearchView extends ConsumerStatefulWidget {
  const SearchView({super.key});

  @override
  ConsumerState<SearchView> createState() => _SearchViewState();
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
          padding: const EdgeInsets.all(20),
          child: TextField(
            controller: _searchCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: '搜索歌曲...',
              prefixIcon: Icon(Icons.search_rounded, color: Colors.white.withValues(alpha: 0.4)),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(icon: const Icon(Icons.clear_rounded, size: 18), onPressed: () {
                      _searchCtrl.clear();
                      ref.read(searchProvider.notifier).clear();
                      setState(() {});
                    })
                  : null,
            ),
            onSubmitted: (v) {
              if (v.trim().isNotEmpty) {
                ref.read(searchProvider.notifier).search(v.trim());
              }
            },
            onChanged: (_) => setState(() {}),
          ),
        ),
        Expanded(
          child: results.when(
            data: (tracks) => tracks.isEmpty
                ? Center(
                    child: Text(
                      _searchCtrl.text.isNotEmpty ? '无搜索结果' : '输入关键词搜索歌曲',
                      style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.35)),
                    ),
                  )
                : ListView.builder(
                    itemCount: tracks.length,
                    itemBuilder: (_, i) => _TrackTile(track: tracks[i], onAdd: () => _addTrack(tracks[i])),
                  ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('搜索出错', style: TextStyle(color: Colors.redAccent.withValues(alpha: 0.7)))),
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
