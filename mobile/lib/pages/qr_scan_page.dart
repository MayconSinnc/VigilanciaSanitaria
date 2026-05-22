import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QrScanPage extends StatefulWidget {
  const QrScanPage({super.key});

  @override
  State<QrScanPage> createState() => _QrScanPageState();
}

class _QrScanPageState extends State<QrScanPage> {
  String? _code;

  void _voltarOuDashboard() {
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QR Code'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _voltarOuDashboard,
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: MobileScanner(onDetect: (capture) {
              final barcode = capture.barcodes.firstOrNull;
              final value = barcode?.rawValue;
              if (value != null && _code != value) {
                setState(() => _code = value);
              }
            }),
          ),
          if (_code != null) Padding(padding: const EdgeInsets.all(12), child: Text('Detectado: $_code'))
        ],
      ),
    );
  }
}
