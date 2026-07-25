enum AuthVerificationType {
  none,
  sms,
  otp,
}

class AuthChallenge {
  final AuthVerificationType type;
  final bool canRememberDevice;
  final bool emailVerification;

  const AuthChallenge({
    required this.type,
    this.canRememberDevice = false,
    this.emailVerification = false,
  });

  const AuthChallenge.none()
      : type = AuthVerificationType.none,
        canRememberDevice = false,
        emailVerification = false;

  bool get requiresVerification => type != AuthVerificationType.none;

  factory AuthChallenge.fromIaaaResponse(Map<String, dynamic> json) {
    if (!_asBool(json['success'])) {
      return const AuthChallenge.none();
    }

    if (!_asBool(json['isMobileAuthen'])) {
      return const AuthChallenge.none();
    }

    final mode = json['authenMode']?.toString().toUpperCase();
    final type = switch (mode) {
      'SMS' => AuthVerificationType.sms,
      'OTP' => AuthVerificationType.otp,
      _ => AuthVerificationType.none,
    };

    return AuthChallenge(
      type: type,
      canRememberDevice: _asBool(json['isUnuAuth']),
      emailVerification: _asBool(json['emailSuitable']),
    );
  }
}

class AuthVerification {
  final AuthVerificationType type;
  final String code;
  final bool rememberDevice;

  const AuthVerification({
    required this.type,
    required this.code,
    this.rememberDevice = false,
  });
}

bool _asBool(dynamic value) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  if (value is String) {
    return value.toLowerCase() == 'true' || value == '1';
  }
  return false;
}
