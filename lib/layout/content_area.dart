import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:suika_multi_player/providers/room_provider.dart';
import 'package:suika_multi_player/providers/sidebar_provider.dart';
import 'package:suika_multi_player/widgets/player/lyrics_view.dart';
import 'package:suika_multi_player/widgets/room/room_list_view.dart';
import 'package:suika_multi_player/screens/profile_screen.dart';
import 'package:suika_multi_player/screens/settings_screen.dart';

class ContentArea extends ConsumerWidget {
  const ContentArea({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(sidebarTabProvider);
    final roomState = ref.watch(roomProvider);
    final isViewingEnteredRoom = roomState.enteredRoomId != null &&
        roomState.currentRoom?.roomId == roomState.enteredRoomId;

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: switch (tab) {
        SidebarTab.player => isViewingEnteredRoom ? const LyricsView() : const RoomListView(),
        SidebarTab.profile => const ProfileScreen(),
        SidebarTab.settings => const SettingsScreen(),
        _ => const LyricsView(),
      },
    );
  }
}
