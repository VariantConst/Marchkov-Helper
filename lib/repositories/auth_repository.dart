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
}
