import '../models/auth_exception.dart';

Map<String, dynamic> requireJsonObject(dynamic decoded, String context) {
  if (decoded is Map<String, dynamic>) {
    return decoded;
  }
  if (decoded is Map) {
    return Map<String, dynamic>.from(decoded);
  }
  throw AuthException('$context返回了无法识别的数据');
}

String requireIaaaToken(Map<String, dynamic> json) {
  final token = json['token'];
  if (json['success'] == true && token is String && token.isNotEmpty) {
    return token;
  }
  throw AuthException.fromIaaaResponse(json);
}

bool isSuccessfulWprocResponse(Map<String, dynamic> json) {
  final errorCode = json['e'];
  return errorCode == 0 || errorCode?.toString() == '0';
}
