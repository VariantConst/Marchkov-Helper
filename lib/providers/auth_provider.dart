// lib/providers/auth_provider.dart
import 'package:flutter/material.dart';
import '../repositories/auth_repository.dart';
import '../models/user.dart';

class AuthProvider with ChangeNotifier {
  final AuthRepository _authRepository = AuthRepository();
  User? _user;
  String _loginResponse = '';

  bool get isLoggedIn => _user != null;
  String get username => _user?.username ?? '';
  String get loginResponse => _loginResponse;

  Future<void> login(String username, String password) async {
    await _authRepository.login(username, password);
    // 假设 AuthService 会在登录后更新_user和_loginResponse
    // 这里需要从AuthService获取最新状态
    // 例如：
    // _user = _authRepository.authService.user;
    // _loginResponse = _authRepository.authService.loginResponse;
    notifyListeners();
  }

  Future<void> logout() async {
    await _authRepository.logout();
    _user = null;
    _loginResponse = '';
    notifyListeners();
  }

  Future<void> loadUsername() async {
    await _authRepository.loadUsername();
    // 同样需要从AuthService获取最新状态
    notifyListeners();
  }
}
