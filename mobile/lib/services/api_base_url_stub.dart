import 'package:flutter/foundation.dart';

const String _releaseDefaultApiBaseUrl = String.fromEnvironment(
  'DEFAULT_API_BASE_URL',
  defaultValue: 'https://exploring-thriving-germinate.ngrok-free.dev',
);

String resolveDefaultApiBaseUrl({int port = 3000}) {
  if (kReleaseMode) {
    return _releaseDefaultApiBaseUrl;
  }
  if (defaultTargetPlatform == TargetPlatform.android) {
    return 'http://10.0.2.2:$port';
  }
  return 'http://localhost:$port';
}

String normalizeSavedApiBaseUrl(String? saved, {int port = 3000}) {
  if (saved == null || saved.trim().isEmpty) {
    return resolveDefaultApiBaseUrl(port: port);
  }
  final normalized = saved.trim().replaceAll(RegExp(r'/*$'), '');
  try {
    final uri = Uri.parse(normalized);
    final host = uri.host.toLowerCase();
    final isLocalHost = host == 'localhost' || host == '127.0.0.1' || host == '10.0.2.2';
    if (isLocalHost && uri.port == 0) return '${uri.scheme}://$host:$port';
  } catch (_) {
    return resolveDefaultApiBaseUrl(port: port);
  }
  return normalized;
}
