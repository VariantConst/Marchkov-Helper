// lib/repositories/auth_repository.dart
import '../services/auth_service.dart';

class AuthRepository {
  final AuthService _authService = AuthService();

  Future<void> login(String username, String password) {
    return _authService.login(username, password);
  }

  Future<void> logout() {
    return _authService.logout();
  }

  Future<void> loadUsername() {
    return _authService.loadUsername();
  }

  String get loginResponse => _authService.loginResponse;
  String get cookies => _authService.cookies;
  String get password => _authService.password;
  String get username => _authService.username; // 添加这行

  Future<void> loadCredentials() {
    return _authService.loadCredentials();
  }
}
