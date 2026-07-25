import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:marchkov_helper/models/auth_challenge.dart';
import 'package:marchkov_helper/models/auth_exception.dart';
import 'package:marchkov_helper/services/auth_service.dart';
import 'package:marchkov_helper/utils/iaaa_response_parser.dart';

const _testPublicKey = '''
-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAqw9PsMk8v9ED/LiLT62I
DnelyIA/s8blyxqNmbgXT4xtq+Y64Bd+THYPZ4dUIRuFmMvPowQm9wL27W3PEtQy
C8VN+TzW/nPzc74fy9cRxgaSh1FXNQBqYZtltb6G5YvwBvZlYdKhE3Oo3noUD0FJ
JC11Nmcy2/x1V2pwXHRy2DHKaWB1EEtQ9dRxuMZolZIpEwWnT4CHfwEvth83kNRp
E8471KJEqyQqmqJt3JRerH4X4p41zQFIxCsrznAwku3b1qm0vgGLQ8t7XEiCjDX0
m5yIJEuW5t1YcteutuJX5+5oXxe2Fo04Wkn1pO6+QoJopqHcHJD5C+7GlnPOLB1c
DQIDAQAB
-----END PUBLIC KEY-----
''';

void main() {
  group('IAAA challenge parsing', () {
    test('detects SMS verification and trusted-device support', () {
      final challenge = AuthChallenge.fromIaaaResponse({
        'success': true,
        'isMobileAuthen': true,
        'authenMode': 'SMS',
        'isUnuAuth': true,
        'emailSuitable': false,
      });

      expect(challenge.type, AuthVerificationType.sms);
      expect(challenge.requiresVerification, isTrue);
      expect(challenge.canRememberDevice, isTrue);
      expect(challenge.emailVerification, isFalse);
    });

    test('detects OTP verification', () {
      final challenge = AuthChallenge.fromIaaaResponse({
        'success': true,
        'isMobileAuthen': true,
        'authenMode': 'OTP',
      });

      expect(challenge.type, AuthVerificationType.otp);
    });

    test('treats failed capability lookup as no challenge', () {
      final challenge = AuthChallenge.fromIaaaResponse({
        'success': false,
        'errors': {'code': 'E07'},
      });

      expect(challenge.type, AuthVerificationType.none);
    });
  });

  group('IAAA response parsing', () {
    test('accepts a successful non-empty token', () {
      expect(
        requireIaaaToken({'success': true, 'token': 'test-token'}),
        'test-token',
      );
    });

    test('turns a missing token into a useful auth error', () {
      expect(
        () => requireIaaaToken({
          'success': false,
          'errors': {
            'code': 'E01',
            'msg': 'User ID or Password is NOT correct.',
          },
        }),
        throwsA(
          isA<AuthException>()
              .having((error) => error.code, 'code', 'E01')
              .having((error) => error.message, 'message', '账号或密码错误'),
        ),
      );
    });

    test('normalizes numeric and string WProc success codes', () {
      expect(isSuccessfulWprocResponse({'e': 0}), isTrue);
      expect(isSuccessfulWprocResponse({'e': '0'}), isTrue);
      expect(isSuccessfulWprocResponse({'e': '10042'}), isFalse);
    });
  });

  test('encrypts the password with RSA PKCS#1 v1.5', () {
    final encrypted = AuthService.encryptPassword(
      'not-a-real-password',
      _testPublicKey,
    );

    expect(base64Decode(encrypted), hasLength(256));
    expect(encrypted, isNot(contains('not-a-real-password')));
  });
}
