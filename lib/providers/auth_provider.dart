import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:suika_multi_player/models/user.dart';
import 'package:suika_multi_player/services/api_service.dart';
import 'package:suika_multi_player/utils/storage.dart';

final apiServiceProvider = Provider<ApiService>((ref) => ApiService());

final storageServiceProvider = Provider<StorageService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return StorageService(prefs);
});

enum AuthStatus { unknown, loggedIn, loggedOut }

class AuthState {
  final AuthStatus status;
  final User? user;
  final String? error;

  const AuthState({
    this.status = AuthStatus.unknown,
    this.user,
    this.error,
  });

  AuthState copyWith({AuthStatus? status, User? user, String? error}) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      error: error,
    );
  }

  bool get isLoggedIn => status == AuthStatus.loggedIn;
}

class AuthNotifier extends StateNotifier<AuthState> {
  final ApiService _api;
  final StorageService _storage;

  AuthNotifier(this._api, this._storage) : super(const AuthState());

  Future<void> tryAutoLogin() async {
    final uuid = _storage.userUuid;
    if (uuid == null) {
      state = state.copyWith(status: AuthStatus.loggedOut);
      return;
    }
    try {
      final user = await _api.fetchUser(uuid);
      state = AuthState(status: AuthStatus.loggedIn, user: user);
    } catch (_) {
      state = state.copyWith(status: AuthStatus.loggedOut, error: null);
    }
  }

  Future<void> login(String userName, String pwd) async {
    state = state.copyWith(error: null);
    try {
      final user = await _api.login(userName: userName, pwd: pwd);
      await _storage.setUserUuid(user.userUuid);
      final fullUser = await _api.fetchUser(user.userUuid);
      state = AuthState(status: AuthStatus.loggedIn, user: fullUser);
    } catch (e) {
      state = state.copyWith(error: e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> register(String userName, String pwd, String nickname) async {
    state = state.copyWith(error: null);
    try {
      final user = await _api.register(
        userName: userName,
        pwd: pwd,
        nickname: nickname,
      );
      await _storage.setUserUuid(user.userUuid);
      final fullUser = await _api.fetchUser(user.userUuid);
      state = AuthState(status: AuthStatus.loggedIn, user: fullUser);
    } catch (e) {
      state = state.copyWith(error: e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> logout() async {
    if (state.user != null) {
      try {
        await _api.logout(state.user!.userUuid);
      } catch (_) {}
    }
    await _storage.clearUserUuid();
    state = const AuthState(status: AuthStatus.loggedOut);
  }

  Future<void> refreshUser() async {
    if (state.user == null) return;
    try {
      final user = await _api.fetchUser(state.user!.userUuid);
      state = AuthState(status: AuthStatus.loggedIn, user: user);
    } catch (_) {}
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

final authProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final api = ref.watch(apiServiceProvider);
  final storage = ref.watch(storageServiceProvider);
  return AuthNotifier(api, storage);
});

