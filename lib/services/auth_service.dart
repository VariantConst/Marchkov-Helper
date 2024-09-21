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
  final http.Client _client = http.Client();
  String _password = '';
  late PersistCookieJar _cookieJar;

  AuthService() {
    _initCookieJar();
  }

  Future<void> _initCookieJar() async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final appDocPath = appDocDir.path;
    _cookieJar = PersistCookieJar(
      ignoreExpires: true,
      storage: FileStorage("$appDocPath/.cookies/"),
    );
  }

  bool get isLoggedIn => _user != null;
  String get username => _user?.username ?? '';
  String get loginResponse => _loginResponse;
  String get password => _password;

  // 添加 cookies getter
  Future<String> get cookies async {
    final iaaaCookies =
        await _cookieJar.loadForRequest(Uri.parse('https://iaaa.pku.edu.cn'));
    final wprocCookies =
        await _cookieJar.loadForRequest(Uri.parse('https://wproc.pku.edu.cn'));
    final allCookies = [...iaaaCookies, ...wprocCookies];
    return allCookies
        .map((cookie) => '${cookie.name}=${cookie.value}')
        .join('; ');
  }

  Future<void> login(String username, String password) async {
    try {
      // 第一步: 初始登录请求
      final response = await _client.post(
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

      // 打印初始请求的响应信息和 cookies
      print('初始请求响应状态码: ${response.statusCode}');
      print('初始请求响应体: ${response.body}');
      print('初始 Set-Cookie: ${response.headers['set-cookie']}');

      _loginResponse = const JsonEncoder.withIndent('  ')
          .convert(json.decode(response.body));

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        final token = jsonResponse['token'];
        _user = User(username: username, token: token);
        _password = password;

        // 保存第一步的 cookies
        final setCookieHeader = response.headers['set-cookie'];
        final cookies = _parseCookies(setCookieHeader);
        await _cookieJar.saveFromResponse(
            Uri.parse('https://iaaa.pku.edu.cn'), cookies);

        // 第二步: 追随重定向获取完整 cookies
        final redirectUrl = Uri.parse(
            'https://wproc.pku.edu.cn/site/login/cas-login?redirect_url=https://wproc.pku.edu.cn/v2/reserve/&_rand=0.6441813796046802&token=$token');

        final redirectResponse = await _client.get(redirectUrl, headers: {
          'Cookie': cookies
              .map((cookie) => '${cookie.name}=${cookie.value}')
              .join('; '),
          'User-Agent':
              'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
        });

        // 打印重定向请求的响应信息和 cookies
        print('重定向请求响应状态码: ${redirectResponse.statusCode}');
        print('重定向请求响应体: ${redirectResponse.body}');
        print('重定向 Set-Cookie: ${redirectResponse.headers['set-cookie']}');

        if (redirectResponse.statusCode == 200) {
          // 保���重定向后的 cookies
          final redirectSetCookie = redirectResponse.headers['set-cookie'];
          if (redirectSetCookie != null) {
            final redirectCookies = _parseCookies(redirectSetCookie);
            await _cookieJar.saveFromResponse(redirectUrl, redirectCookies);
            print('重定向后的 cookies 已保存到 cookie jar 中。');
          } else {
            print('重定向响应中没有新的 cookies。');
          }

          // 打印所有保存的 cookies
          final savedCookies = cookies;
          print('所有保存的 cookies: $savedCookies');

          await _saveCredentials(username, password);
          notifyListeners();
        } else {
          print('重定向请求失败: ${redirectResponse.statusCode}');
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

  List<Cookie> _parseCookies(String? setCookieHeader) {
    if (setCookieHeader == null) return [];
    final cookies = <Cookie>[];
    final cookiePattern = RegExp(r'(?<=^|,)\s*([^=]+)=([^;]*)');
    for (final match in cookiePattern.allMatches(setCookieHeader)) {
      if (match.groupCount == 2) {
        final name = match.group(1)?.trim();
        final value = match.group(2)?.trim();
        if (name != null && value != null) {
          cookies.add(Cookie(name, value));
        }
      }
    }
    return cookies;
  }

  Future<void> logout() async {
    _user = null;
    _loginResponse = '';
    await _clearCredentials();
    await _cookieJar.deleteAll();
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

  Future<http.Response> get(Uri url) async {
    final cookies = await _cookieJar.loadForRequest(url);
    final cookieString =
        cookies.map((cookie) => '${cookie.name}=${cookie.value}').join('; ');

    return await _client.get(
      url,
      headers: {
        'Cookie': cookieString,
        'User-Agent':
            'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
      },
    );
  }
}
