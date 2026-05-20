import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:suika_multi_player/models/user.dart';
import 'package:suika_multi_player/providers/auth_provider.dart';
import 'package:suika_multi_player/services/api_service.dart';

class UserCache extends StateNotifier<Map<String, User>> {
  final ApiService _api;

  UserCache(this._api) : super({});

  User? getUser(String uuid) => state[uuid];

  Future<void> fetchUser(String uuid) async {
    if (state.containsKey(uuid)) return;
    try {
      final user = await _api.fetchUser(uuid);
      state = {...state, uuid: user};
    } catch (_) {}
  }

  void cacheUser(User user) {
    state = {...state, user.userUuid: user};
  }
}

final userCacheProvider =
    StateNotifierProvider<UserCache, Map<String, User>>((ref) {
  return UserCache(ref.watch(apiServiceProvider));
});
