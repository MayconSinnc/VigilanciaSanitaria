import 'package:flutter/material.dart';
import '../ui/theme.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  void _go(BuildContext context, String route) {
    Navigator.pop(context); // Fecha o drawer
    final current = ModalRoute.of(context)?.settings.name;
    if (current == route) return;

    // Se for para o dashboard, remove tudo e vai para a raiz
    if (route == '/dashboard') {
      Navigator.pushNamedAndRemoveUntil(context, route, (route) => false);
    } else {
      // Para outras telas, faz o push normal para permitir o "voltar" via Navigator.pop
      Navigator.pushNamed(context, route);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      shadowColor: Colors.transparent,
      elevation: 0, // Remove sombra que pode parecer azulada
      child: Column(
        children: [
          // Header customizado com fundo branco
          Container(
            width: double.infinity,
            height: 180,
            decoration: const BoxDecoration(
              color: Colors.white,
            ),
            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
            child: Center(
              child: Container(
                width: 120,
                height: 120,
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                padding: const EdgeInsets.all(12),
                child: Image.asset(
                  'public/brasao.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          const Divider(height: 1, color: AppColors.cinzaCampo),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _item(context, Icons.dashboard, 'Dashboard', '/dashboard'),
                _item(context, Icons.store, 'Estabelecimentos', '/estabelecimentos'),
                _item(context, Icons.assignment, 'Auto/Termo', '/auto-termo'),
                const Divider(),
                _item(context, Icons.person, 'Meu Perfil', '/perfil'),
                _item(context, Icons.settings, 'Configurações', '/configuracoes'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _item(BuildContext context, IconData icon, String title, String route) {
    final current = ModalRoute.of(context)?.settings.name;
    final isSelected = current == route;
    return ListTile(
      leading: Icon(icon, color: isSelected ? AppColors.azulInstitucional : Colors.black87),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? AppColors.azulInstitucional : Colors.black87,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      onTap: () => _go(context, route),
      selected: isSelected,
      selectedTileColor: AppColors.azulInstitucional.withAlpha(26),
    );
  }
}
