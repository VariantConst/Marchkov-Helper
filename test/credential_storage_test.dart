import 'package:flutter_test/flutter_test.dart';
import 'package:marchkov_helper/services/credential_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MemorySecureStore implements SecureValueStore {
  final values = <String, String>{};

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('migrates and deletes the legacy plaintext password', () async {
    SharedPreferences.setMockInitialValues({
      'username': 'test-user',
      'password': 'legacy-password',
    });
    final secureStore = _MemorySecureStore();
    final storage = CredentialStorage(secureStore: secureStore);

    final credentials = await storage.readCredentials();
    final preferences = await SharedPreferences.getInstance();

    expect(credentials?.username, 'test-user');
    expect(credentials?.password, 'legacy-password');
    expect(secureStore.values['iaaa_password'], 'legacy-password');
    expect(preferences.containsKey('password'), isFalse);
  });

  test('new credentials never write a plaintext password', () async {
    SharedPreferences.setMockInitialValues({});
    final secureStore = _MemorySecureStore();
    final storage = CredentialStorage(secureStore: secureStore);

    await storage.save('test-user', 'secure-password');
    final preferences = await SharedPreferences.getInstance();

    expect(preferences.getString('username'), 'test-user');
    expect(preferences.containsKey('password'), isFalse);
    expect(secureStore.values['iaaa_password'], 'secure-password');
  });

  test('clear removes secure and legacy credentials', () async {
    SharedPreferences.setMockInitialValues({
      'username': 'test-user',
      'password': 'legacy-password',
    });
    final secureStore = _MemorySecureStore()
      ..values['iaaa_password'] = 'secure-password';
    final storage = CredentialStorage(secureStore: secureStore);

    await storage.clear();
    final preferences = await SharedPreferences.getInstance();

    expect(secureStore.values, isEmpty);
    expect(preferences.containsKey('username'), isFalse);
    expect(preferences.containsKey('password'), isFalse);
  });
}
