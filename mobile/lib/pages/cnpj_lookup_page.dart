import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api.dart';
import '../ui/theme.dart';

class CnpjLookupPage extends StatefulWidget {
  const CnpjLookupPage({super.key});
  @override
  State<CnpjLookupPage> createState() => _CnpjLookupPageState();
}

class _CnpjLookupPageState extends State<CnpjLookupPage> {
  final _cnpj = TextEditingController();
  final _api = ApiService();
  Map<String, dynamic>? _data;
  bool _loading = false;
  String? _error;

  Future<void> _buscar() async {
    setState(() {
      _loading = true;
      _error = null;
      _data = null;
    });
    await _api.init();
    try {
      final d = await _api.buscarEstabelecimentoPorCnpj(_cnpj.text);
      setState(() {
        _data = d;
        _loading = false;
        if (d == null) _error = 'CNPJ inválido ou não encontrado';
      });
    } catch (_) {
      setState(() {
        _loading = false;
        _error = 'Erro ao consultar CNPJ';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buscar CNPJ'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final maxW = constraints.maxWidth < 700 ? constraints.maxWidth : 700.0;
          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxW),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextField(
                    controller: _cnpj,
                    keyboardType: TextInputType.number,
                    inputFormatters: [CnpjInputFormatter()],
                    decoration: InputDecoration(
                      labelText: 'CNPJ',
                      suffixIcon: IconButton(icon: const Icon(Icons.search), onPressed: _buscar),
                    ),
                    onSubmitted: (_) => _buscar(),
                  ),
                  const SizedBox(height: 12),
                  if (_loading) const LinearProgressIndicator(),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                  ],
                  const SizedBox(height: 12),
                  if (_data != null) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${_data!['razaoSocial'] ?? _data!['razao_social'] ?? ''}', style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 6),
                            Text('Nome Fantasia: ${_data!['nomeFantasia'] ?? _data!['nome_fantasia'] ?? ''}'),
                            Text('CNPJ: ${_data!['cnpj'] ?? ''}'),
                            Text('Endereço: ${_data!['endereco'] ?? _data!['logradouro'] ?? ''}, ${_data!['numero'] ?? ''}'),
                            Text('Bairro: ${_data!['bairro'] ?? ''}'),
                            Text('Cidade: ${_data!['cidade'] ?? _data!['municipio'] ?? ''} - ${_data!['estado'] ?? _data!['uf'] ?? ''}'),
                            Text('CEP: ${_data!['cep'] ?? ''}'),
                            Text('CNAE: ${_data!['cnaeDescricao'] ?? _data!['cnae_fiscal_descricao'] ?? ''}'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => Navigator.pushNamed(context, '/cadastro-estabelecimento', arguments: _data),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.azulInstitucional, foregroundColor: Colors.white),
                      child: const Text('Confirmar Cadastro'),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class CnpjInputFormatter extends TextInputFormatter {
  static String format(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    final limited = digits.length > 14 ? digits.substring(0, 14) : digits;
    final b = StringBuffer();
    for (var i = 0; i < limited.length; i++) {
      if (i == 2 || i == 5) b.write('.');
      if (i == 8) b.write('/');
      if (i == 12) b.write('-');
      b.write(limited[i]);
    }
    return b.toString();
  }

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final next = format(newValue.text);
    return TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
  }
}
