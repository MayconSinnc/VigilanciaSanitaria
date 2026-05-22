// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'api_base_url_stub.dart' as stub;

/// Na web, a API deve apontar diretamente para o backend na porta 3000.
String resolveDefaultApiBaseUrl({int port = 3000}) {
  final protocol = html.window.location.protocol;
  final hostname = html.window.location.hostname;
  if (hostname != null && hostname.isNotEmpty) {
    final scheme = protocol.isNotEmpty ? protocol : 'http:';
    return '$scheme//$hostname:$port';
  }
  return stub.resolveDefaultApiBaseUrl(port: port);
}

String normalizeSavedApiBaseUrl(String? saved, {int port = 3000}) {
  final current = resolveDefaultApiBaseUrl(port: port);
  if (saved == null || saved.trim().isEmpty) return current;

  final normalized = saved.trim().replaceAll(RegExp(r'/*$'), '');
  final hostname = html.window.location.hostname ?? '';
  final effectiveHost = hostname.isNotEmpty ? hostname : 'localhost';
  final scheme = html.window.location.protocol.isNotEmpty ? html.window.location.protocol : 'http:';
  final directCurrent = '$scheme//$effectiveHost:$port';

  if (normalized.contains(':8080')) {
    return directCurrent;
  }

  if (normalized.contains('localhost') || normalized.contains('127.0.0.1')) {
    return directCurrent;
  }

  try {
    final savedHost = Uri.parse(normalized).host;
    if (hostname.isNotEmpty &&
        savedHost.isNotEmpty &&
        savedHost.toLowerCase() != hostname.toLowerCase()) {
      return directCurrent;
    }
  } catch (_) {
    return directCurrent;
  }

  return normalized;
}
