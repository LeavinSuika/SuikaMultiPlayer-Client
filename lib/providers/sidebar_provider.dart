import 'package:flutter_riverpod/flutter_riverpod.dart';

enum SidebarTab { player, search, profile, settings }

final sidebarTabProvider = StateProvider<SidebarTab>((ref) => SidebarTab.player);

/// When set, the sidebar room icon with matching roomId pulses (user just exited that room).
/// Cleared when the user enters any room.
final exitedRoomIdProvider = StateProvider<int?>((ref) => null);
