import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../services/pdf_generator_service.dart';

class RelatorioInspecaoSanitariaPdfPage extends StatefulWidget {
  const RelatorioInspecaoSanitariaPdfPage({super.key});

  @override
  State<RelatorioInspecaoSanitariaPdfPage> createState() => _RelatorioInspecaoSanitariaPdfPageState();
}

class _RelatorioInspecaoSanitariaPdfPageState extends State<RelatorioInspecaoSanitariaPdfPage> {
  Timer? _timer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _timer?.cancel();
    final rawArgs = ModalRoute.of(context)?.settings.arguments;
    final args = rawArgs is Map ? rawArgs.cast<String, dynamic>() : <String, dynamic>{};
    final autoReturn = args['autoReturnToList'] == true;
    if (!autoReturn) return;
    _timer = Timer(const Duration(seconds: 5), () {
      if (!mounted) return;
      Navigator.of(context).popUntil((route) {
        final name = route.settings.name;
        if (name == '/auto-termo' || name == '/auto') return true;
        return route.isFirst;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rawArgs = ModalRoute.of(context)?.settings.arguments;
    final args = rawArgs is Map ? rawArgs.cast<String, dynamic>() : <String, dynamic>{};
    final rawPayload = args['payload'];
    final payload = rawPayload is Map ? rawPayload.cast<String, dynamic>() : const <String, dynamic>{};
    final service = PdfGeneratorService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Relatório de Inspeção Sanitária (PDF)'),
      ),
      body: PdfPreview(
        build: (format) async {
          final Uint8List bytes = await service.gerarRelatorioInspecaoSanitariaPdf(payload);
          return bytes;
        },
      ),
    );
  }
}

