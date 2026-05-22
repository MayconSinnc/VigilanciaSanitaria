import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class InvoiceOcrPage extends StatefulWidget {
  const InvoiceOcrPage({super.key});
  @override
  State<InvoiceOcrPage> createState() => _InvoiceOcrPageState();
}

class _InvoiceOcrPageState extends State<InvoiceOcrPage> {
  final ImagePicker _picker = ImagePicker();
  final TextRecognizer _textRecognizer = TextRecognizer();
  String? _numero;
  String? _cnpj;
  String? _data;
  String? _produto;
  String? _quantidade;

  Future<void> _capture() async {
    final x = await _picker.pickImage(source: ImageSource.camera, imageQuality: 80);
    if (x == null) return;
    final image = InputImage.fromFilePath(x.path);
    final recognized = await _textRecognizer.processImage(image);
    final text = recognized.text;
    final cnpjMatch = RegExp(r'\d{2}\.\d{3}\.\d{3}/\d{4}-\d{2}').firstMatch(text);
    final numeroMatch = RegExp(r'NF *(\d{3,})').firstMatch(text);
    final dataMatch = RegExp(r'(\d{2}/\d{2}/\d{4})').firstMatch(text);
    final produtoMatch = RegExp(r'Produto[:\- ]*(.+)', caseSensitive: false).firstMatch(text);
    final qtdMatch = RegExp(r'Quantidade[:\- ]*(\d+)', caseSensitive: false).firstMatch(text);
    setState(() {
      _cnpj = cnpjMatch?.group(0);
      _numero = numeroMatch?.group(1);
      _data = dataMatch?.group(1);
      _produto = produtoMatch?.group(1);
      _quantidade = qtdMatch?.group(1);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('OCR Nota Fiscal'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ElevatedButton(onPressed: _capture, child: const Text('Capturar Nota')),
            const SizedBox(height: 16),
            Text('Fornecedor (CNPJ): ${_cnpj ?? '-'}'),
            Text('Número NF: ${_numero ?? '-'}'),
            Text('Data: ${_data ?? '-'}'),
            Text('Produto: ${_produto ?? '-'}'),
            Text('Quantidade: ${_quantidade ?? '-'}'),
            const Spacer(),
            ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Confirmar')),
          ],
        ),
      ),
    );
  }
}
