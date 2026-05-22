import 'package:flutter/material.dart';
import '../widgets/action_button.dart';

class InspectionActionsPage extends StatelessWidget {
  const InspectionActionsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final nome = args?['nome'] ?? 'Estabelecimento';
    final cnpj = args?['cnpj'] ?? '-';
    final estabelecimentoId = args?['estabelecimentoId'];
    final estabelecimento = args?['estabelecimento'];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emitir Documento Sanitário'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('INSPEÇÃO SANITÁRIA', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(nome),
                    Text('CNPJ: $cnpj'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            ActionButton(label: 'AUTO DE INTIMAÇÃO', color: const Color(0xFF1E88E5), icon: Icons.info, onPressed: () => Navigator.pushNamed(context, '/auto', arguments: {'tipo': 'INT', 'nome': nome, 'cnpj': cnpj, 'estabelecimentoId': estabelecimentoId, 'estabelecimento': estabelecimento})),
            const SizedBox(height: 8),
            ActionButton(label: 'AUTO DE INFRAÇÃO', color: const Color(0xFFE53935), icon: Icons.report, onPressed: () => Navigator.pushNamed(context, '/auto', arguments: {'tipo': 'INF', 'nome': nome, 'cnpj': cnpj, 'estabelecimentoId': estabelecimentoId, 'estabelecimento': estabelecimento})),
            const SizedBox(height: 8),
            ActionButton(label: 'IMPOSIÇÃO DE PENALIDADE', color: const Color(0xFFFB8C00), icon: Icons.gavel, onPressed: () => Navigator.pushNamed(context, '/auto', arguments: {'tipo': 'PEN', 'nome': nome, 'cnpj': cnpj, 'estabelecimentoId': estabelecimentoId, 'estabelecimento': estabelecimento})),
            const SizedBox(height: 8),
            ActionButton(label: 'AUTO DE COLETA PARA AMOSTRA', color: const Color(0xFF43A047), icon: Icons.biotech, onPressed: () => Navigator.pushNamed(context, '/auto', arguments: {'tipo': 'COL', 'nome': nome, 'cnpj': cnpj, 'estabelecimentoId': estabelecimentoId, 'estabelecimento': estabelecimento})),
          ],
        ),
      ),
    );
  }
}
