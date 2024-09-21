import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:path_provider/path_provider.dart';

class AuthService extends ChangeNotifier {
  User? _user;
  String _loginResponse = '';
  String _cookies = '';
  final http.Client _client = http.Client();
  String _password = '';
  late PersistCookieJar _cookieJar;

  AuthService() {
    _initCookieJar();
  }

  Future<void> _initCookieJar() async {
    final tempDir = await getTemporaryDirectory();
    final tempPath = tempDir.path;
    _cookieJar = PersistCookieJar(
      ignoreExpires: true,
      storage: FileStorage(tempPath),
    );
  }

  bool get isLoggedIn => _user != null;
  String get username => _user?.username ?? '';
  String get loginResponse => _loginResponse;
  String get cookies => _cookies;
  String get password => _password;

  Future<void> login(String username, String password) async {
    try {
      // 第一步: 初始登录请求
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
        final token = jsonResponse['token'];
        _user = User(username: username, token: token);
        _password = password;

        // 保存第一步的cookies
        _updateCookies(response);

        // 第二步: 追随重定向获取完整cookie
        final redirectUrl = Uri.parse(
            'https://wproc.pku.edu.cn/site/login/cas-login?redirect_url=https://wproc.pku.edu.cn/v2/reserve/&_rand=0.6441813796046802&token=$token');

        final redirectResponse = await http.get(redirectUrl, headers: {
          'Cookie': _cookies,
          'User-Agent':
              'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
        });

        if (redirectResponse.statusCode == 200) {
          // 更新cookies，包括重定向后的新cookies
          _updateCookies(redirectResponse);
          await _saveCredentials(username, password);
          await _saveCookies(_cookies);
          print('Full cookies after redirect: $_cookies');
          notifyListeners();
        } else {
          throw Exception('重定向请求失败: ${redirectResponse.statusCode}');
        }
      } else {
        throw Exception('登录失败: ${response.statusCode}');
      }
    } catch (e) {
      print('登录过程中发生错误: $e');
      throw Exception('登录失败: $e');
    }
  }

  void _updateCookies(http.Response response) {
    final rawCookies = response.headers['set-cookie'];
    if (rawCookies != null) {
      final newCookies = rawCookies
          .split(',')
          .map((cookie) => cookie.split(';')[0].trim())
          .toList();
      final cookieMap = Map.fromEntries(newCookies.map((cookie) {
        final parts = cookie.split('=');
        return MapEntry(parts[0], parts.sublist(1).join('='));
      }));

      // 更新现有的cookies
      final existingCookies = _cookies.isNotEmpty
          ? Map.fromEntries(_cookies.split('; ').map((cookie) {
              final parts = cookie.split('=');
              return MapEntry(parts[0], parts.sublist(1).join('='));
            }))
          : <String, String>{};

      existingCookies.addAll(cookieMap);

      _cookies =
          existingCookies.entries.map((e) => '${e.key}=${e.value}').join('; ');
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
    // 从cookie jar加载cookies
    final cookies = await _cookieJar.loadForRequest(url);
    final cookieString =
        cookies.map((cookie) => '${cookie.name}=${cookie.value}').join('; ');

    return await _client.get(
      url,
      headers: {
        'Cookie': cookieString,
        // ... 其他headers ...
      },
    );
  }
}
