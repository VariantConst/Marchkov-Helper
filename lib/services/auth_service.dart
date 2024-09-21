// lib/services/auth_service.dart
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';

class AuthService extends ChangeNotifier {
  User? _user;
  String _loginResponse = '';
  String _cookies = '';
  final http.Client _client = http.Client();
  String _password = '';

  bool get isLoggedIn => _user != null;
  String get username => _user?.username ?? '';
  String get loginResponse => _loginResponse;
  String get cookies => _cookies;
  String get password => _password;

  Future<void> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('https://iaaa.pku.edu.cn/iaaa/oauthlogin.do'),
        body: {
          'appid': 'wproc',
          'userName': username,
          'password': password,
          'redirUrl':
              'https://wproc.pku.edu.cn/site/login/cas-login?redirect_url=https://wproc.pku.edu.cn/v2/reserve/',
        },
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
        },
      );

      _loginResponse = const JsonEncoder.withIndent('  ')
          .convert(json.decode(response.body));

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        _user = User(username: username, token: jsonResponse['token']);
        _cookies = response.headers['set-cookie'] ?? '';
        _password = password; // 保存密码
        await _saveCredentials(username, password);
        await _saveCookies(_cookies);
        print('Cookies: $_cookies'); // 输出到调试控制台
        notifyListeners();
      } else {
        throw Exception('登录失败');
      }
    } catch (e) {
      throw Exception('登录失败: $e');
    }
  }

  Future<void> logout() async {
    _user = null;
    _loginResponse = '';
    _cookies = '';
    await _clearCredentials();
    await _clearCookies();
    notifyListeners();
  }

  Future<void> _saveCredentials(String username, String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('username', username);
    await prefs.setString('password', password);
  }

  Future<void> _clearCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('username');
    await prefs.remove('password');
  }

  Future<void> _saveCookies(String cookies) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cookies', cookies);
  }

  Future<void> _clearCookies() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('cookies');
  }

  Future<void> loadUsername() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUsername = prefs.getString('username');
    if (savedUsername != null) {
      _user = User(username: savedUsername, token: '');
      notifyListeners();
    }
  }

  Future<void> loadCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUsername = prefs.getString('username');
    final savedPassword = prefs.getString('password');
    if (savedUsername != null && savedPassword != null) {
      _user = User(username: savedUsername, token: '');
      _password = savedPassword;
      notifyListeners();
    }
  }

  // 添加 get 方法
  Future<http.Response> get(Uri url) async {
    // 如果需要，可以在这里添加认证逻辑
    // 例如，添加 token 到请求头
    String? token = _user?.token;
    Map<String, String> headers = {};
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    return await _client.get(url, headers: headers);
  }
}
