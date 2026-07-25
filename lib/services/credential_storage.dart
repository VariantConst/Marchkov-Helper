import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StoredCredentials {
  final String username;
  final String password;

  const StoredCredentials({
    required this.username,
    required this.password,
  });
}

abstract interface class SecureValueStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

class PlatformSecureValueStore implements SecureValueStore {
  final FlutterSecureStorage _storage;

  PlatformSecureValueStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            FlutterSecureStorage(
              aOptions: AndroidOptions(migrateWithBackup: true),
            );

  @override
  Future<String?> read(String key) {
    if (kIsWeb) {
      return Future.value();
    }
    return _storage.read(key: key);
  }

  @override
  Future<void> write(String key, String value) {
    if (kIsWeb) {
      return Future.value();
    }
    return _storage.write(key: key, value: value);
  }

  @override
  Future<void> delete(String key) {
    if (kIsWeb) {
      return Future.value();
    }
    return _storage.delete(key: key);
  }
}

class CredentialStorage {
  static const _securePasswordKey = 'iaaa_password';
  static const _legacyPasswordKey = 'password';
  static const _usernameKey = 'username';

  final SecureValueStore _secureStore;
  final Future<SharedPreferences> Function() _preferencesFactory;

  CredentialStorage({
    SecureValueStore? secureStore,
    Future<SharedPreferences> Function()? preferencesFactory,
  })  : _secureStore = secureStore ?? PlatformSecureValueStore(),
        _preferencesFactory =
            preferencesFactory ?? SharedPreferences.getInstance;

  Future<void> save(String username, String password) async {
    final preferences = await _preferencesFactory();
    await _secureStore.write(_securePasswordKey, password);
    await preferences.setString(_usernameKey, username);
    await preferences.remove(_legacyPasswordKey);
  }

  Future<String?> readUsername() async {
    final preferences = await _preferencesFactory();
    return preferences.getString(_usernameKey);
  }

  Future<StoredCredentials?> readCredentials() async {
    final preferences = await _preferencesFactory();
    final username = preferences.getString(_usernameKey);
    if (username == null || username.isEmpty) {
      return null;
    }

    var password = await _secureStore.read(_securePasswordKey);
    final legacyPassword = preferences.getString(_legacyPasswordKey);
    if ((password == null || password.isEmpty) &&
        legacyPassword != null &&
        legacyPassword.isNotEmpty) {
      await _secureStore.write(_securePasswordKey, legacyPassword);
      password = legacyPassword;
    }
    await preferences.remove(_legacyPasswordKey);

    if (password == null || password.isEmpty) {
      return null;
    }
    return StoredCredentials(username: username, password: password);
  }

  Future<void> clear() async {
    final preferences = await _preferencesFactory();
    await _secureStore.delete(_securePasswordKey);
    await preferences.remove(_usernameKey);
    await preferences.remove(_legacyPasswordKey);
  }
}
