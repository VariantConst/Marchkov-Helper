import 'dart:convert';
import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:pointycastle/asymmetric/api.dart';

import '../models/auth_challenge.dart';
import '../models/auth_exception.dart';
import '../models/user.dart';
import '../utils/iaaa_response_parser.dart';
import 'credential_storage.dart';

class AuthService extends ChangeNotifier {
  static const _userAgent =
      'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/126.0.0.0 Mobile Safari/537.36';
  static const _wprocRedirectUrl =
      'https://wproc.pku.edu.cn/site/login/cas-login'
      '?redirect_url=https%3A%2F%2Fwproc.pku.edu.cn%2Fv2%2Fsite%2Findex';

  static final _iaaaOrigin = Uri.parse('https://iaaa.pku.edu.cn');
  static final _wprocCookieUri =
      Uri.parse('https://wproc.pku.edu.cn/site/reservation/');
  static const _allowedAuthHosts = {
    'iaaa.pku.edu.cn',
    'wproc.pku.edu.cn',
  };
  static final _oauthPageUri = Uri.https(
    'iaaa.pku.edu.cn',
    '/iaaa/oauth.jsp',
    {
      'appID': 'wproc',
      'appName': '办事大厅预约版',
      'redirectUrl': _wprocRedirectUrl,
    },
  );

  final http.Client _client;
  final HttpClient Function() _httpClientFactory;
  final CredentialStorage _credentialStorage;
  late final Future<PersistCookieJar> _cookieJarFuture;

  User? _user;
  String _loginResponse = '';
  String _password = '';
  String? _preparedUsername;
  String? _publicKeyPem;
  AuthChallenge _preparedChallenge = const AuthChallenge.none();

  AuthService({
    http.Client? client,
    HttpClient Function()? httpClientFactory,
    Future<PersistCookieJar> Function()? cookieJarFactory,
    CredentialStorage? credentialStorage,
  })  : _client = client ?? http.Client(),
        _httpClientFactory = httpClientFactory ?? HttpClient.new,
        _credentialStorage = credentialStorage ?? CredentialStorage() {
    _cookieJarFuture = cookieJarFactory?.call() ?? _createCookieJar();
  }

  Future<PersistCookieJar> _createCookieJar() async {
    final appDocDir = await getApplicationDocumentsDirectory();
    return PersistCookieJar(
      storage: FileStorage('${appDocDir.path}/.cookies/'),
    );
  }

  bool get isLoggedIn => _user != null;
  String get username => _user?.username ?? '';
  String get loginResponse => _loginResponse;
  String get password => _password;

  Future<String> get cookies async {
    final cookieJar = await _cookieJarFuture;
    final wprocCookies = await cookieJar.loadForRequest(_wprocCookieUri);
    return wprocCookies
        .map((cookie) => '${cookie.name}=${cookie.value}')
        .join('; ');
  }

  Future<AuthChallenge> prepareLogin(String username) async {
    final normalizedUsername = username.trim();
    if (normalizedUsername.isEmpty) {
      throw const AuthException('请输入账号');
    }

    final cookieJar = await _cookieJarFuture;
    await cookieJar.delete(_iaaaOrigin, true);
    _clearPreparedLogin();

    final httpClient = _httpClientFactory();
    try {
      await _send(httpClient, 'GET', _oauthPageUri);

      final captchaResponse = await _getJson(
        httpClient,
        Uri.parse('https://iaaa.pku.edu.cn/iaaa/isShowCode.do'),
        'IAAA 验证码检查',
      );
      if (captchaResponse['success'] == true) {
        throw const AuthException(
          '登录需要图形验证码，请先在 IAAA 网页完成一次登录后重试',
          code: 'E03',
        );
      }

      final publicKeyResponse = await _getJson(
        httpClient,
        Uri.parse('https://iaaa.pku.edu.cn/iaaa/getPublicKey.do'),
        'IAAA 公钥请求',
      );
      final publicKey = publicKeyResponse['key'];
      if (publicKeyResponse['success'] != true ||
          publicKey is! String ||
          publicKey.isEmpty) {
        throw const AuthException('无法获取 IAAA 登录公钥，请稍后重试');
      }

      final mobileAuthUri = Uri.https(
        'iaaa.pku.edu.cn',
        '/iaaa/isMobileAuthen.do',
        {
          'userName': normalizedUsername,
          'appId': 'wproc',
          '_rand': _requestNonce(),
        },
      );
      final mobileAuthResponse = await _getJson(
        httpClient,
        mobileAuthUri,
        'IAAA 二次认证检查',
      );

      _preparedUsername = normalizedUsername;
      _publicKeyPem = publicKey;
      _preparedChallenge = AuthChallenge.fromIaaaResponse(mobileAuthResponse);
      return _preparedChallenge;
    } catch (_) {
      _clearPreparedLogin();
      rethrow;
    } finally {
      httpClient.close(force: true);
    }
  }

  Future<String> sendVerificationCode(String username) async {
    _ensurePreparedFor(username);
    if (_preparedChallenge.type != AuthVerificationType.sms) {
      throw const AuthException('当前账号不需要短信或邮件验证码');
    }

    final httpClient = _httpClientFactory();
    try {
      final uri = Uri.https(
        'iaaa.pku.edu.cn',
        '/iaaa/sendSMSCode.do',
        {
          'userName': username.trim(),
          'appId': 'wproc',
          '_rand': _requestNonce(),
        },
      );
      final json = await _getJson(httpClient, uri, '验证码发送请求');
      if (json['success'] != true) {
        throw AuthException.fromIaaaResponse(json);
      }

      final target = json['mobileMask']?.toString().trim();
      if (target != null && target.isNotEmpty) {
        return '验证码已发送至 $target';
      }
      return _preparedChallenge.emailVerification ? '邮件验证码已发送' : '短信验证码已发送';
    } finally {
      httpClient.close(force: true);
    }
  }

  Future<void> login(
    String username,
    String password, {
    AuthVerification? verification,
  }) async {
    final normalizedUsername = username.trim();
    if (_preparedUsername != normalizedUsername || _publicKeyPem == null) {
      await prepareLogin(normalizedUsername);
    }
    _validateVerification(verification);

    final httpClient = _httpClientFactory();
    try {
      final encryptedPassword = encryptPassword(password, _publicKeyPem!);
      final response = await _send(
        httpClient,
        'POST',
        Uri.parse('https://iaaa.pku.edu.cn/iaaa/oauthlogin.do'),
        form: {
          'appid': 'wproc',
          'userName': normalizedUsername,
          'password': encryptedPassword,
          'randCode': '',
          'smsCode': verification?.type == AuthVerificationType.sms
              ? verification!.code.trim()
              : '',
          'otpCode': verification?.type == AuthVerificationType.otp
              ? verification!.code.trim()
              : '',
          'remTrustChk': (verification?.rememberDevice ?? false).toString(),
          'redirUrl': _wprocRedirectUrl,
        },
      );
      final json = _decodeJson(response, 'IAAA 登录');
      final token = requireIaaaToken(json);

      await _fetchWprocCookies(httpClient, token);
      await _validateWprocSession(httpClient);

      _user = User(username: normalizedUsername, token: '');
      _password = password;
      _loginResponse = '登录成功';
      await _saveCredentials(normalizedUsername, password);
      _clearPreparedLogin();
      notifyListeners();
    } on AuthException {
      rethrow;
    } on SocketException {
      throw const AuthException('无法连接登录服务器，请检查网络后重试');
    } on HandshakeException {
      throw const AuthException('登录服务器的安全连接失败，请检查系统时间和网络');
    } on FormatException {
      throw const AuthException('登录服务器返回了无法识别的数据，请稍后重试');
    } catch (error) {
      throw AuthException('登录失败：$error');
    } finally {
      httpClient.close(force: true);
    }
  }

  @visibleForTesting
  static String encryptPassword(String password, String publicKeyPem) {
    final parsedKey =
        encrypt.RSAKeyParser().parse(publicKeyPem) as RSAPublicKey;
    final encrypter = encrypt.Encrypter(
      encrypt.RSA(
        publicKey: parsedKey,
        encoding: encrypt.RSAEncoding.PKCS1,
      ),
    );
    return encrypter.encrypt(password).base64;
  }

  Future<void> _fetchWprocCookies(
    HttpClient httpClient,
    String token,
  ) async {
    var uri = Uri.https(
      'wproc.pku.edu.cn',
      '/site/login/cas-login',
      {
        'redirect_url': 'https://wproc.pku.edu.cn/v2/site/index',
        '_rand': _requestNonce(),
        'token': token,
      },
    );

    for (var redirectCount = 0; redirectCount < 5; redirectCount++) {
      final response = await _send(httpClient, 'GET', uri);
      if (!_isRedirect(response.statusCode) || response.location == null) {
        return;
      }
      uri = uri.resolve(response.location!);
    }
    throw const AuthException('WProc 登录跳转次数过多，请稍后重试');
  }

  Future<void> _validateWprocSession(HttpClient httpClient) async {
    final now = DateTime.now();
    final date = '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    final uri = Uri.https(
      'wproc.pku.edu.cn',
      '/site/reservation/list-page',
      {
        'hall_id': '1',
        'time': date,
        'p': '1',
        'page_size': '0',
      },
    );
    final response = await _send(httpClient, 'GET', uri);
    final json = _decodeJson(response, 'WProc 登录验证');
    if (!isSuccessfulWprocResponse(json)) {
      final message = json['m']?.toString();
      throw AuthException(
        message == null || message.isEmpty ? 'WProc 会话建立失败' : message,
        code: json['e']?.toString(),
      );
    }
  }

  Future<Map<String, dynamic>> _getJson(
    HttpClient httpClient,
    Uri uri,
    String context,
  ) async {
    final response = await _send(httpClient, 'GET', uri);
    return _decodeJson(response, context);
  }

  Map<String, dynamic> _decodeJson(_NetworkResponse response, String context) {
    if (response.statusCode != HttpStatus.ok) {
      throw AuthException('$context失败，状态码 ${response.statusCode}');
    }
    try {
      return requireJsonObject(jsonDecode(response.body), context);
    } on FormatException {
      throw AuthException('$context返回了非 JSON 数据');
    }
  }

  Future<_NetworkResponse> _send(
    HttpClient httpClient,
    String method,
    Uri uri, {
    Map<String, String>? form,
  }) async {
    if (uri.scheme != 'https' || !_allowedAuthHosts.contains(uri.host)) {
      throw const AuthException('登录服务器返回了不安全的跳转地址');
    }

    final request = await httpClient.openUrl(method, uri);
    request.followRedirects = false;
    request.headers.set(HttpHeaders.userAgentHeader, _userAgent);
    request.headers.set(
      HttpHeaders.acceptHeader,
      'application/json, text/javascript, */*; q=0.01',
    );
    request.cookies.addAll(
      await (await _cookieJarFuture).loadForRequest(uri),
    );

    if (form != null) {
      request.headers.contentType =
          ContentType('application', 'x-www-form-urlencoded', charset: 'utf-8');
      request.write(Uri(queryParameters: form).query);
    }

    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();
    await (await _cookieJarFuture).saveFromResponse(uri, response.cookies);
    return _NetworkResponse(
      statusCode: response.statusCode,
      body: responseBody,
      location: response.headers.value(HttpHeaders.locationHeader),
    );
  }

  void _validateVerification(AuthVerification? verification) {
    if (!_preparedChallenge.requiresVerification) {
      return;
    }
    if (verification == null ||
        verification.type != _preparedChallenge.type ||
        verification.code.trim().isEmpty) {
      final label = _preparedChallenge.type == AuthVerificationType.sms
          ? (_preparedChallenge.emailVerification ? '邮件验证码' : '短信验证码')
          : '手机令牌';
      throw AuthException('请输入$label');
    }
  }

  void _ensurePreparedFor(String username) {
    if (_preparedUsername != username.trim() || _publicKeyPem == null) {
      throw const AuthException('登录会话已失效，请重新开始登录');
    }
  }

  void _clearPreparedLogin() {
    _preparedUsername = null;
    _publicKeyPem = null;
    _preparedChallenge = const AuthChallenge.none();
  }

  static bool _isRedirect(int statusCode) =>
      statusCode == HttpStatus.movedPermanently ||
      statusCode == HttpStatus.found ||
      statusCode == HttpStatus.seeOther ||
      statusCode == HttpStatus.temporaryRedirect ||
      statusCode == HttpStatus.permanentRedirect;

  static String _requestNonce() =>
      DateTime.now().microsecondsSinceEpoch.toString();

  Future<void> logout() async {
    _user = null;
    _loginResponse = '';
    _password = '';
    _clearPreparedLogin();
    await _clearCredentials();
    await (await _cookieJarFuture).deleteAll();
    notifyListeners();
  }

  Future<void> _saveCredentials(String username, String password) async {
    await _credentialStorage.save(username, password);
  }

  Future<void> _clearCredentials() async {
    await _credentialStorage.clear();
  }

  Future<void> loadUsername() async {
    final savedUsername = await _credentialStorage.readUsername();
    if (savedUsername != null) {
      _user = User(username: savedUsername, token: '');
      notifyListeners();
    }
  }

  Future<void> loadCredentials() async {
    final credentials = await _credentialStorage.readCredentials();
    if (credentials != null) {
      _user = User(username: credentials.username, token: '');
      _password = credentials.password;
      notifyListeners();
    }
  }

  Future<http.Response> get(Uri url) async {
    return _client.get(
      url,
      headers: {
        'Cookie': await cookies,
        'User-Agent': _userAgent,
      },
    );
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }
}

class _NetworkResponse {
  final int statusCode;
  final String body;
  final String? location;

  const _NetworkResponse({
    required this.statusCode,
    required this.body,
    required this.location,
  });
}
