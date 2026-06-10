import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../services/pdf_generator_service.dart';

class AutoColetaAmostraPdfPage extends StatefulWidget {
  const AutoColetaAmostraPdfPage({super.key});

  @override
  State<AutoColetaAmostraPdfPage> createState() => _AutoColetaAmostraPdfPageState();
}

class _AutoColetaAmostraPdfPageState extends State<AutoColetaAmostraPdfPage> {
  int _via = 2;

  @override
  Widget build(BuildContext context) {
    final rawArgs = ModalRoute.of(context)?.settings.arguments;
    final args = rawArgs is Map ? rawArgs.cast<String, dynamic>() : <String, dynamic>{};
    final rawPayload = args['payload'];
    final payload = rawPayload is Map ? rawPayload.cast<String, dynamic>() : const <String, dynamic>{};
    final initialVia = args['via'];
    if (initialVia is int && initialVia != _via) {
      _via = initialVia;
    }
    final service = PdfGeneratorService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Auto de Coleta de Amostra (PDF)'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: ToggleButtons(
              isSelected: [_via == 1, _via == 2],
              onPressed: (i) => setState(() => _via = i == 0 ? 1 : 2),
              children: const [
                Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('1ª Via')),
                Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('2ª Via')),
              ],
            ),
          ),
        ],
      ),
      body: PdfPreview(
        build: (format) async {
          final Uint8List bytes = await service.gerarAutoColetaAmostraPdf(payload, via: _via);
          return bytes;
        },
      ),
    );
  }
}

