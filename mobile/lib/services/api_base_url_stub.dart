import 'package:flutter/foundation.dart';

String resolveDefaultApiBaseUrl({int port = 3000}) {
  if (defaultTargetPlatform == TargetPlatform.android) {
    return 'http://10.0.2.2:$port';
  }
  return 'http://localhost:$port';
}

String normalizeSavedApiBaseUrl(String? saved, {int port = 3000}) {
  if (saved == null || saved.trim().isEmpty) {
    return resolveDefaultApiBaseUrl(port: port);
  }
  return saved.trim().replaceAll(RegExp(r'/*$'), '');
}
