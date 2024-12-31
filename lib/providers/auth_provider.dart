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

  // 添加新的属性来跟踪上次刷新时间
  static const String _lastRefreshKey = 'lastCookieRefreshDate';

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
    await _savePassword(password);
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

  Future<void> _savePassword(String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('password', password);
  }

  // 添加一个方法来异步获取最新的cookies
  Future<String> getLatestCookies() async {
    _cookies = await _authRepository.cookies;
    return _cookies;
  }

  // 新增：检查是否需要刷新 cookie
  Future<bool> _shouldRefreshCookie() async {
    final prefs = await SharedPreferences.getInstance();
    final lastRefreshStr = prefs.getString(_lastRefreshKey);

    if (lastRefreshStr == null) return true;

    final lastRefresh = DateTime.parse(lastRefreshStr);
    final today = DateTime.now();

    // 如果不是同一天，则需要刷新
    return lastRefresh.year != today.year ||
        lastRefresh.month != today.month ||
        lastRefresh.day != today.day;
  }

  // 新增：记录刷新时间
  Future<void> _updateLastRefreshTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastRefreshKey, DateTime.now().toIso8601String());
  }

  // 新增：静默刷新 cookie
  Future<bool> silentlyRefreshCookie() async {
    try {
      // 检查是否需要刷新
      if (!await _shouldRefreshCookie()) {
        return true;
      }

      // 获取保存的凭据
      final prefs = await SharedPreferences.getInstance();
      final savedUsername = prefs.getString('username');
      final savedPassword = prefs.getString('password');

      if (savedUsername == null || savedPassword == null) {
        return false;
      }

      // 尝试重新登录
      await login(savedUsername, savedPassword);
      await _updateLastRefreshTime();
      return true;
    } catch (e) {
      print('静默刷新 cookie 失败: $e');
      return false;
    }
  }
}
