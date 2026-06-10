import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api.dart';
import '../storage/db.dart';

class EvidencePage extends StatefulWidget {
  final int? inspecaoId;
  const EvidencePage({super.key, this.inspecaoId});

  @override
  State<EvidencePage> createState() => _EvidencePageState();
}

class _EvidencePageState extends State<EvidencePage> {
  final ImagePicker _picker = ImagePicker();
  final List<Uint8List> _images = [];
  final _api = ApiService();
  bool _saving = false;

  void _voltarOuDashboard() {
    Navigator.of(context).maybePop();
  }

  @override
  void initState() {
    super.initState();
  }

  Future<void> _addFromCamera() async {
    if (_saving) return;
    final x = await _picker.pickImage(source: ImageSource.camera, imageQuality: 75);
    if (x != null) {
      final bytes = await x.readAsBytes();
      setState(() {
        _images.add(bytes);
      });
    }
  }

  Future<void> _addFromGallery() async {
    if (_saving) return;
    final x = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
    if (x != null) {
      final bytes = await x.readAsBytes();
      setState(() {
        _images.add(bytes);
      });
    }
  }

  Future<void> _saveAll() async {
    if (_saving) return;
    if (_images.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adicione pelo menos uma foto.')),
      );
      return;
    }
    setState(() {
      _saving = true;
    });
    try {
      for (final bytes in _images) {
        final b64 = base64Encode(bytes);
        if (kIsWeb) {
          final inspecaoId = widget.inspecaoId;
          if (inspecaoId == null || inspecaoId <= 0) {
            throw StateError('missing_inspecao_id');
          }
          final iso = DateTime.now().toIso8601String();
          await _api.init();
          final ok = await _api.enviarFotoInspecao(
            inspecaoId: inspecaoId,
            url: b64,
            data: iso,
          );
          if (!ok) throw StateError('upload_failed');
        } else {
          final db = await LocalDb.instance;
          await db.insert('fotos', {
            'inspecao_id': widget.inspecaoId ?? 0,
            'url': b64,
            'data': DateTime.now().toIso8601String(),
            'gps': ''
          });
        }
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      final msg = (e is StateError && e.message == 'missing_inspecao_id')
          ? 'Abra as evidências a partir do Formulário Oficial.'
          : 'Não foi possível salvar as evidências.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Evidências Fotográficas'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _voltarOuDashboard,
        ),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8),
        itemCount: _images.length,
        itemBuilder: (ctx, i) => Image.memory(_images[i], fit: BoxFit.cover),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(child: ElevatedButton(onPressed: _saving ? null : _addFromCamera, child: const Text('Tirar foto'))),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton(onPressed: _saving ? null : _addFromGallery, child: const Text('Selecionar'))),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton(onPressed: _saving ? null : _saveAll, child: const Text('Salvar'))),
          ],
        ),
      ),
    );
  }
}
