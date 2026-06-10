import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../services/pdf_generator_service.dart';

class AutoImposicaoPenalidadePdfPage extends StatelessWidget {
  const AutoImposicaoPenalidadePdfPage({super.key});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ?? {};
    final payload = (args['payload'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    final service = PdfGeneratorService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Auto de Imposição de Penalidade (PDF)'),
      ),
      body: PdfPreview(
        build: (format) async {
          final Uint8List bytes = await service.gerarImposicaoPenalidadePdf(payload);
          return bytes;
        },
      ),
    );
  }
}

