// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Armazenamento na web via localStorage (funciona em HTTP, ex. VPN 10.8.x).
class AppStorage {
  static Future<void> write(String key, String value) async {
    html.window.localStorage[key] = value;
  }

  static Future<String?> read(String key) async {
    return html.window.localStorage[key];
  }

  static Future<void> delete(String key) async {
    html.window.localStorage.remove(key);
  }
}
