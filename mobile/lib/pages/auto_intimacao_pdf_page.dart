import 'dart:typed_data';
import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../services/pdf_generator_service.dart';

class AutoIntimacaoPdfPage extends StatelessWidget {
  const AutoIntimacaoPdfPage({super.key});

  static const String _debugServerUrl = 'http://127.0.0.1:7777/event';
  static const String _debugSessionId = 'generate-pdf-freeze';

  Future<void> _debugReport({
    required String hypothesisId,
    required String msg,
    Map<String, dynamic>? data,
    String runId = 'pre-fix',
  }) async {
    if (!kDebugMode) return;
    try {
      await Dio(
        BaseOptions(
          connectTimeout: const Duration(milliseconds: 800),
          receiveTimeout: const Duration(milliseconds: 800),
          sendTimeout: const Duration(milliseconds: 800),
        ),
      ).post(
        _debugServerUrl,
        data: {
          'sessionId': _debugSessionId,
          'runId': runId,
          'hypothesisId': hypothesisId,
          'location': 'auto_intimacao_pdf_page.dart:PdfPreview.build',
          'msg': msg,
          'data': data ?? const <String, dynamic>{},
          'ts': DateTime.now().millisecondsSinceEpoch,
        },
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ?? {};
    final payload = (args['payload'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    final service = PdfGeneratorService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Auto de Intimação (PDF)'),
      ),
      body: PdfPreview(
        build: (format) async {
          final sw = Stopwatch()..start();
          // #region debug-point P:pdf-preview
          unawaited(
            _debugReport(
              hypothesisId: 'P',
              msg: '[DEBUG] Inicio gerarAutoIntimacaoPdf (PdfPreview)',
              data: {
                'payload_keys': payload.keys.take(30).toList(),
                'payload_json_len': () {
                  try {
                    return JsonEncoder().convert(payload).length;
                  } catch (_) {
                    return -1;
                  }
                }(),
              },
            ),
          );
          // #endregion
          final Uint8List bytes = await service.gerarAutoIntimacaoPdf(payload);
          // #region debug-point P:pdf-preview
          unawaited(
            _debugReport(
              hypothesisId: 'P',
              msg: '[DEBUG] Fim gerarAutoIntimacaoPdf (PdfPreview)',
              data: {
                'ms': sw.elapsedMilliseconds,
                'bytes_len': bytes.length,
              },
            ),
          );
          // #endregion
          return bytes;
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, {'action': 'back_to_list'}),
                  child: const Text('Voltar para lista'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, {'action': 'finalize'}),
                  child: const Text('Finalizar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
