import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import '../models/server_config.dart';
import '../services/services.dart';
import '../services/groovy_api_service.dart';

enum AuthState {
  unknown,
  unauthenticated,
  authenticating,
  authenticated,
  offlineMode,
  error,
}

class AuthProvider extends ChangeNotifier {
  final StorageService _storageService;
  final GroovyApiService _apiService = GroovyApiService();

  AuthState _state = AuthState.unknown;
  String? _error;
  GroovyUser? _currentUser;
  String? _token;

  AuthProvider(dynamic unusedSubsonicService, this._storageService) {
    _loadSavedSession();
  }

  AuthState get state => _state;
  String? get error => _error;
  ServerConfig? get config => null;
  GroovyUser? get currentUser => _currentUser;
  String? get token => _token;
  bool get isAuthenticated => _state == AuthState.authenticated;
  bool get hasOfflineContent => false;

  Future<void> _loadSavedSession() async {
    _state = AuthState.authenticating;
    notifyListeners();

    try {
      final savedToken = await _storageService.getUserToken();
      final savedProfile = await _storageService.getUserProfile();

      if (savedToken != null && savedToken.isNotEmpty && savedProfile != null) {
        _token = savedToken;
        _currentUser = GroovyUser.fromJson(savedProfile);
        _state = AuthState.authenticated;
        notifyListeners();

        // Refresh user profile in background from MySQL database
        _refreshUserProfile();
      } else {
        _state = AuthState.unauthenticated;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[AuthProvider] Error loading saved session: $e');
      _state = AuthState.unauthenticated;
      notifyListeners();
    }
  }

  Future<void> _refreshUserProfile() async {
    if (_token == null) return;
    try {
      final user = await _apiService.getMe(_token!);
      if (user != null) {
        _currentUser = user;
        await _storageService.saveUserAuth(token: _token!, userJson: user.toJson());
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[AuthProvider] Refresh profile error: $e');
    }
  }

  Future<bool> registerUser({
    required String name,
    required String email,
    required String password,
  }) async {
    _state = AuthState.authenticating;
    _error = null;
    notifyListeners();

    final response = await _apiService.register(
      name: name,
      email: email,
      password: password,
    );

    if (response.success && response.token != null && response.user != null) {
      _token = response.token;
      _currentUser = response.user;
      await _storageService.saveUserAuth(token: _token!, userJson: _currentUser!.toJson());

      _state = AuthState.authenticated;
      notifyListeners();
      return true;
    } else {
      _error = response.error ?? 'Error al registrar usuario.';
      _state = AuthState.error;
      notifyListeners();
      return false;
    }
  }

  Future<bool> loginUser({
    required String email,
    required String password,
  }) async {
    _state = AuthState.authenticating;
    _error = null;
    notifyListeners();

    final response = await _apiService.login(
      email: email,
      password: password,
    );

    if (response.success && response.token != null && response.user != null) {
      _token = response.token;
      _currentUser = response.user;
      await _storageService.saveUserAuth(token: _token!, userJson: _currentUser!.toJson());

      _state = AuthState.authenticated;
      notifyListeners();
      return true;
    } else {
      _error = response.error ?? 'Correo o contraseña incorrectos.';
      _state = AuthState.error;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateUserProfile({
    required String name,
    String? avatarUrl,
  }) async {
    _error = null;
    if (_currentUser == null) return false;

    // 1. If online and has token, sync with backend
    if (_token != null && _token!.isNotEmpty) {
      final response = await _apiService.updateProfile(
        token: _token!,
        name: name,
        avatarUrl: avatarUrl,
      );
      if (response.success && response.user != null) {
        _currentUser = response.user;
        await _storageService.saveUserAuth(token: _token!, userJson: _currentUser!.toJson());
        notifyListeners();
        return true;
      }
    }

    // 2. Local fallback update
    _currentUser = GroovyUser(
      id: _currentUser?.id ?? 1,
      name: name.trim(),
      email: _currentUser?.email ?? '',
      avatarUrl: avatarUrl ?? _currentUser?.avatarUrl,
      createdAt: _currentUser?.createdAt,
    );

    if (_token != null) {
      await _storageService.saveUserAuth(token: _token!, userJson: _currentUser!.toJson());
    } else {
      await _storageService.saveUserProfile(_currentUser!.toJson());
    }
    notifyListeners();
    return true;
  }

  void enterOfflineMode() {
    OfflineService().setOfflineMode(true);
    _state = AuthState.offlineMode;
    notifyListeners();
  }

  Future<void> logout() async {
    final offlineService = OfflineService();
    if (offlineService.isBackgroundDownloadActive) {
      offlineService.cancelBackgroundDownload();
    }

    try {
      await DefaultCacheManager().emptyCache();
    } catch (_) {}
    try {
      await BpmAnalyzerService().clearCache();
    } catch (_) {}
    try {
      await offlineService.deleteAllDownloads();
    } catch (_) {}

    await _storageService.clearUserAuth();
    _currentUser = null;
    _token = null;
    _state = AuthState.unauthenticated;
    notifyListeners();
  }

  Future<void> disconnect() => logout();

  bool get isLocalOnlyMode => false;

  Future<List<ServerConfig>> getSavedProfiles() async => [];

  Future<void> switchProfile(ServerConfig profile) async {}

  Future<void> updateSelectedMusicFolderIds(List<String> ids) async {}
}
