import 'package:flutter/material.dart';
import '../services/api.dart';
import '../ui/theme.dart';

class SearchEstablishmentPage extends StatefulWidget {
  const SearchEstablishmentPage({super.key});

  @override
  State<SearchEstablishmentPage> createState() => _SearchEstablishmentPageState();
}

class _SearchEstablishmentPageState extends State<SearchEstablishmentPage> {
  final _q = TextEditingController();
  final _api = ApiService();
  List<dynamic> _results = [];
  bool _loading = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final tipo = ModalRoute.of(context)?.settings.arguments as String?;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buscar Estabelecimento'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: _q, decoration: const InputDecoration(labelText: 'Nome ou CNPJ')),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                setState(() {
                  _loading = true;
                  _results = [];
                  _error = null;
                });
                await _api.init();
                try {
                  final data = await _api.buscarEstabelecimentos(_q.text);
                  setState(() {
                    _results = data;
                    _loading = false;
                    _error = data.isEmpty ? 'Falha no servidor (500). Tente novamente mais tarde.' : null;
                  });
                } catch (e) {
                  setState(() {
                    _loading = false;
                    _error = 'Erro na requisição. Verifique a API.';
                  });
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.azulInstitucional, foregroundColor: Colors.white),
              child: const Text('Buscar'),
            ),
            const SizedBox(height: 16),
            if (_loading) const CircularProgressIndicator(),
            if (_error != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.red.shade50, border: Border.all(color: Colors.red.shade200)),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            Expanded(
              child: ListView.separated(
                itemCount: _results.length,
                separatorBuilder: (ctx, i) => const Divider(),
                itemBuilder: (ctx, i) {
                  final e = _results[i] as Map<String, dynamic>;
                  return ListTile(
                    leading: const Icon(Icons.business),
                    title: Text('${e['nome'] ?? e['razao_social'] ?? ''}'),
                    subtitle: Text('${e['cnpj'] ?? ''} • ${e['endereco'] ?? ''}'),
                    trailing: ElevatedButton(
                      onPressed: () => Navigator.pushNamed(context, '/formulario'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.azulClaro, foregroundColor: Colors.white),
                      child: const Text('Inspecionar'),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(onPressed: () {}, child: Text('Prosseguir com $tipo'))
          ],
        ),
      ),
    );
  }
}
