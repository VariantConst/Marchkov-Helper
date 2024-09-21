// lib/providers/auth_provider.dart
import 'package:flutter/material.dart';
import '../repositories/auth_repository.dart';
import '../models/user.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider with ChangeNotifier {
  final AuthRepository _authRepository = AuthRepository();
  User? _user;
  String _loginResponse = '';
  String _cookies = ''; // 保留这个属性,但我们会异步更新它

  bool get isLoggedIn => _user != null;
  String get username => _user?.username ?? '';
  String get loginResponse => _loginResponse;
  String get cookies => _cookies; // 同步获取cookies
  String get password => _authRepository.password;

  Future<void> login(String username, String password) async {
    await _authRepository.login(username, password);
    _user = User(username: username, token: '');
    _loginResponse = _authRepository.loginResponse;
    _cookies = await _authRepository.cookies; // 异步获取cookies并更新
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
    await _authRepository.loadUsername();
    final username = _authRepository.username;
    if (username.isNotEmpty) {
      _user = User(username: username, token: '');
      notifyListeners();
    }
  }

  Future<bool> checkLoginState() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    if (isLoggedIn) {
      await loadUsername();
      _cookies = await _authRepository.cookies; // 异步获取cookies并更新
    }
    return isLoggedIn;
  }

  Future<void> _saveLoginState(bool isLoggedIn) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', isLoggedIn);
  }

  Future<void> _saveUsername(String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('username', username);
  }

  // 添加一个方法来异步获取最新的cookies
  Future<String> getLatestCookies() async {
    _cookies = await _authRepository.cookies;
    return _cookies;
  }
}
