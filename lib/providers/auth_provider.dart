// lib/providers/auth_provider.dart
import 'package:flutter/material.dart';
import '../repositories/auth_repository.dart';
import '../models/user.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider with ChangeNotifier {
  final AuthRepository _authRepository = AuthRepository();
  User? _user;
  String _loginResponse = '';
  String _cookies = '';

  bool get isLoggedIn => _user != null;
  String get username => _user?.username ?? '';
  String get loginResponse => _loginResponse;
  String get cookies => _cookies;
  String get password => _authRepository.password;

  Future<void> login(String username, String password) async {
    await _authRepository.login(username, password);
    _user = User(username: username, token: '');
    _loginResponse = _authRepository.loginResponse;
    _cookies = _authRepository.cookies;
    // 确保打印完整的 cookie 字符串
    print('Full cookies: $_cookies');
    await _saveLoginState(true);
    await _saveUsername(username);
    notifyListeners();
  }

  Future<void> logout() async {
    await _authRepository.logout();
    _user = null;
    _loginResponse = '';
    _cookies = '';
    await _saveLoginState(false);
    notifyListeners();
  }

  Future<void> loadUsername() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUsername = prefs.getString('username') ?? '';
    _user = User(username: savedUsername, token: '');
    await _authRepository.loadUsername();
    _loginResponse = _authRepository.loginResponse;
    notifyListeners();
  }

  Future<void> _saveLoginState(bool isLoggedIn) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', isLoggedIn);
  }

  Future<bool> checkLoginState() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

    // 无论是否登录，都尝试加载用户名
    await loadUsername();

    if (isLoggedIn) {
      _user = User(username: username, token: '');
    }
    return isLoggedIn;
  }

  Future<void> _saveUsername(String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('username', username);
  }

  Future<void> loadCredentials() async {
    await _authRepository.loadCredentials();
    _user = User(username: _authRepository.username, token: '');
    _loginResponse = _authRepository.loginResponse;
    _cookies = _authRepository.cookies;
    notifyListeners();
  }
}
