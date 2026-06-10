// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

import 'api_base_url_stub.dart' as stub;

/// Na web, a API do app roda na porta 3000 (backend Fastify/Prisma do app).
String resolveDefaultApiBaseUrl({int port = 3000}) {
  final protocol = html.window.location.protocol;
  final rawHostname = html.window.location.hostname;
  final hostname = rawHostname == 'localhost' ? '127.0.0.1' : rawHostname;
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
  final rawHostname = html.window.location.hostname ?? '';
  final effectiveHost =
      rawHostname.isNotEmpty ? (rawHostname == 'localhost' ? '127.0.0.1' : rawHostname) : '127.0.0.1';
  final scheme = html.window.location.protocol.isNotEmpty ? html.window.location.protocol : 'http:';
  final directCurrent = '$scheme//$effectiveHost:$port';

  final currentPort = int.tryParse(html.window.location.port) ?? 0;

  Uri? uri;
  try {
    uri = Uri.parse(normalized);
  } catch (_) {
    return directCurrent;
  }

  if (uri.host.isEmpty) return directCurrent;

  final hostLower = uri.host.toLowerCase();
  final isLocalHost = hostLower == 'localhost' || hostLower == '127.0.0.1' || hostLower == effectiveHost.toLowerCase();

  if (currentPort != 0 && uri.hasPort && uri.port == currentPort) {
    return directCurrent;
  }

  if (isLocalHost) {
    if (uri.hasPort) {
      if (uri.port == 8080) return directCurrent;
      return '$scheme//$effectiveHost:${uri.port}';
    }
    return directCurrent;
  }

  return normalized;
}
