import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:marchkov_flutter/models/user.dart';

class AuthService extends ChangeNotifier {
  User? _user;
  String _loginResponse = '';

  bool get isLoggedIn => _user != null;
  String get username => _user?.username ?? '';
  String get loginResponse => _loginResponse;

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
        await _saveUsername(username);
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
    await _removeUsername();
    notifyListeners();
  }

  Future<void> _saveUsername(String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('username', username);
  }

  Future<void> _removeUsername() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('username');
  }

  Future<void> loadUsername() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUsername = prefs.getString('username');
    if (savedUsername != null) {
      _user = User(username: savedUsername, token: '');
      notifyListeners();
    }
  }
}
