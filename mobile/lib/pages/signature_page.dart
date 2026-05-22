import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:signature/signature.dart';

class SignaturePage extends StatefulWidget {
  final int? inspecaoId;
  const SignaturePage({super.key, this.inspecaoId});

  @override
  State<SignaturePage> createState() => _SignaturePageState();
}

class _SignaturePageState extends State<SignaturePage> {
  final SignatureController _controller = SignatureController(penStrokeWidth: 3, penColor: Colors.black);

  void _voltarOuDashboard() {
    Navigator.of(context).maybePop();
  }

  Future<void> _save() async {
    final ui.Image? img = await _controller.toImage();
    if (img == null) return;
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) return;
    if (!mounted) return;
    Navigator.pop(context, bytes.buffer.asUint8List());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assinatura Digital'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _voltarOuDashboard,
        ),
      ),
      body: Column(
        children: [
          Expanded(child: Signature(controller: _controller, backgroundColor: Colors.white)),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(child: ElevatedButton(onPressed: _save, child: const Text('Salvar'))),
                const SizedBox(width: 12),
                Expanded(child: ElevatedButton(onPressed: _controller.clear, child: const Text('Limpar'))),
              ],
            ),
          )
        ],
      ),
    );
  }
}
