import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

class CnpjScannerPage extends StatefulWidget {
  const CnpjScannerPage({super.key});
  @override
  State<CnpjScannerPage> createState() => _CnpjScannerPageState();
}

class _CnpjScannerPageState extends State<CnpjScannerPage> {
  String? _cnpj;
  final MobileScannerController _qrController = MobileScannerController();
  final TextRecognizer _textRecognizer = TextRecognizer();
  final ImagePicker _picker = ImagePicker();

  Future<void> _recognizeText(InputImage image) async {
    final recognizedText = await _textRecognizer.processImage(image);
    final text = recognizedText.text;
    final match = RegExp(r'\d{2}\.\d{3}\.\d{3}/\d{4}-\d{2}').firstMatch(text);
    if (match != null) {
      setState(() => _cnpj = match.group(0));
    }
  }

  Future<void> _captureText() async {
    final x = await _picker.pickImage(source: ImageSource.camera, imageQuality: 80);
    if (x == null) return;
    final image = InputImage.fromFilePath(x.path);
    await _recognizeText(image);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scanner de CNPJ'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: MobileScanner(
              controller: _qrController,
              onDetect: (capture) {
                final barcode = capture.barcodes.firstOrNull;
                final val = barcode?.rawValue;
                if (val != null && RegExp(r'\d{14}').hasMatch(val)) {
                  setState(() => _cnpj = val);
                }
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Text(_cnpj == null ? 'Posicione o documento para leitura' : 'CNPJ: $_cnpj'),
                const SizedBox(height: 12),
                ElevatedButton(onPressed: _captureText, child: const Text('Capturar texto (OCR)')),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _cnpj == null ? null : () => Navigator.pop(context, _cnpj),
                  child: const Text('Usar este CNPJ'),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
