import 'package:flutter/material.dart';
import '../ui/theme.dart';

class AppHeader extends StatelessWidget {
  final String fiscal;
  const AppHeader({super.key, required this.fiscal});

  @override
  Widget build(BuildContext context) {
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text(
          'Prefeitura de Balneário Camboriú',
          style: TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.bold),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          'Vigilância Sanitária',
          style: TextStyle(color: Colors.black54, fontSize: 14),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );

    final menuButton = IconButton(
      onPressed: () {
        final scaffold = Scaffold.maybeOf(context);
        if (scaffold != null && scaffold.hasDrawer) {
          scaffold.openDrawer();
        }
      },
      icon: const Icon(Icons.menu, color: AppColors.azulInstitucional),
    );

    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Fiscal: ', style: TextStyle(color: Colors.black87)),
        Text(fiscal, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(width: 8),
        IconButton(onPressed: () => Navigator.pushNamed(context, '/perfil'), icon: const Icon(Icons.person, color: AppColors.azulInstitucional)),
        IconButton(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sincronização iniciada')));
          },
          icon: const Icon(Icons.sync, color: AppColors.azulInstitucional),
        ),
      ],
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: AppColors.azulInstitucional, width: 4),
          bottom: BorderSide(color: AppColors.cinzaCampo),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 650;
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    menuButton,
                    const SizedBox(width: 4),
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(13),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(8),
                      child: Image.asset('public/brasao.png', fit: BoxFit.contain),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: title),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: actions,
                  ),
                ),
              ],
            );
          }

          return Row(
            children: [
              menuButton,
              const SizedBox(width: 4),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.cinzaCampo),
                ),
                padding: const EdgeInsets.all(8),
                child: Image.asset('public/brasao.png', fit: BoxFit.contain),
              ),
              const SizedBox(width: 12),
              Expanded(child: title),
              const SizedBox(width: 16),
              actions,
            ],
          );
        },
      ),
    );
  }
}
