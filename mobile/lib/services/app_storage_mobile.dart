import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AppStorage {
  static const _secure = FlutterSecureStorage();

  static Future<void> write(String key, String value) async {
    await _secure.write(key: key, value: value);
  }

  static Future<String?> read(String key) async {
    return _secure.read(key: key);
  }

  static Future<void> delete(String key) async {
    await _secure.delete(key: key);
  }
}
