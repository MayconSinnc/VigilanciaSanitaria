import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

class PdfBytesPreviewPage extends StatelessWidget {
  const PdfBytesPreviewPage({super.key, required this.title, required this.bytes});

  final String title;
  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: PdfPreview(
        build: (_) async => bytes,
      ),
    );
  }
}

