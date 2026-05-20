import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:suika_multi_player/providers/sidebar_provider.dart';
import 'package:suika_multi_player/widgets/player/lyrics_view.dart';
import 'package:suika_multi_player/widgets/search/search_view.dart';
import 'package:suika_multi_player/screens/profile_screen.dart';
import 'package:suika_multi_player/screens/settings_screen.dart';

class ContentArea extends ConsumerWidget {
  const ContentArea({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(sidebarTabProvider);

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: switch (tab) {
        SidebarTab.player => const LyricsView(),
        SidebarTab.search => const SearchView(),
        SidebarTab.profile => const ProfileScreen(),
        SidebarTab.settings => const SettingsScreen(),
      },
    );
  }
}
