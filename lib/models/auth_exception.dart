class AuthException implements Exception {
  final String message;
  final String? code;

  const AuthException(this.message, {this.code});

  factory AuthException.fromIaaaResponse(Map<String, dynamic> json) {
    final errors = json['errors'];
    final errorMap =
        errors is Map ? Map<String, dynamic>.from(errors) : <String, dynamic>{};
    final code = errorMap['code']?.toString();
    final serverMessage = errorMap['msg']?.toString().trim();
    final fallbackMessage = json['message']?.toString().trim();

    return AuthException(
      _friendlyMessage(code, serverMessage, fallbackMessage),
      code: code,
    );
  }

  static String _friendlyMessage(
    String? code,
    String? serverMessage,
    String? fallbackMessage,
  ) {
    switch (code) {
      case 'E01':
        return '账号或密码错误';
      case 'E03':
        return '登录需要图形验证码，请先在 IAAA 网页完成一次登录后重试';
      case 'E04':
        return '短信或邮件验证码错误或已过期';
      case 'E05':
        return '手机令牌错误或已过期';
      case 'E07':
        return '账号校验失败，请检查账号后重试';
    }

    if (serverMessage != null && serverMessage.isNotEmpty) {
      return serverMessage;
    }
    if (fallbackMessage != null && fallbackMessage.isNotEmpty) {
      return fallbackMessage;
    }
    return 'IAAA 登录失败，服务器未返回认证令牌';
  }

  @override
  String toString() => message;
}
