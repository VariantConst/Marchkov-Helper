// lib/repositories/auth_repository.dart
import '../services/auth_service.dart';
import '../models/auth_challenge.dart';

class AuthRepository {
  final AuthService _authService = AuthService();

  Future<AuthChallenge> prepareLogin(String username) {
    return _authService.prepareLogin(username);
  }

  Future<String> sendVerificationCode(String username) {
    return _authService.sendVerificationCode(username);
  }

  Future<void> login(
    String username,
    String password, {
    AuthVerification? verification,
  }) {
    return _authService.login(
      username,
      password,
      verification: verification,
    );
  }

  Future<void> logout() {
    return _authService.logout();
  }

  Future<void> loadUsername() {
    return _authService.loadUsername();
  }

  String get loginResponse => _authService.loginResponse;

  // 修改这里，返回 Future<String>
  Future<String> get cookies => _authService.cookies;

  String get password => _authService.password;
  String get username => _authService.username;

  Future<void> loadCredentials() {
    return _authService.loadCredentials();
  }
}
