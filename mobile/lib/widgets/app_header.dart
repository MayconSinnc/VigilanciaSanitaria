import 'dart:async';

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../ui/theme.dart';

class AppHeader extends StatelessWidget {
  final String fiscal;
  const AppHeader({super.key, required this.fiscal});

  static const String _debugServerUrl = 'http://127.0.0.1:7777/event';
  static const bool _debugReportingEnabled = bool.fromEnvironment('DEBUG_REPORT', defaultValue: false);

  Future<void> _debugReport({
    required String msg,
    Map<String, dynamic>? data,
  }) async {
    if (!_debugReportingEnabled) return;
    try {
      await Dio(
        BaseOptions(
          connectTimeout: const Duration(milliseconds: 800),
          receiveTimeout: const Duration(milliseconds: 800),
          sendTimeout: const Duration(milliseconds: 800),
        ),
      ).post(
        _debugServerUrl,
        data: {
          'sessionId': 'sync-never-finishes',
          'runId': 'pre-fix',
          'hypothesisId': 'S',
          'location': 'app_header.dart:sync_button',
          'msg': msg,
          'data': data ?? const <String, dynamic>{},
          'ts': DateTime.now().millisecondsSinceEpoch,
        },
      );
    } catch (_) {}
  }

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
          onPressed: () async {
            // #region debug-point S:sync
            unawaited(_debugReport(msg: '[DEBUG] Clique no icone de sincronizacao do AppHeader'));
            // #endregion
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sincronização iniciada')));
            final result = await Navigator.pushNamed(
              context,
              '/auto-termo',
              arguments: const <String, dynamic>{
                'auto_sync_on_open': true,
                'auto_sync_pop_on_finish': true,
              },
            );
            if (!context.mounted) return;
            if (result is Map) {
              if (result['skipped'] == true) {
                final reason = (result['reason'] ?? '').toString().trim();
                final msg = reason == 'already_syncing'
                    ? 'Sincronização já em andamento.'
                    : reason == 'login_cancelled'
                        ? 'Sincronização cancelada (login SINNC).'
                        : 'Sincronização não concluída.';
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
                return;
              }
              final ok = (result['ok'] as int?) ?? 0;
              final erro = (result['erro'] as int?) ?? 0;
              final firstError = (result['firstError'] ?? '').toString().trim();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    firstError.isEmpty
                        ? 'Sincronização concluída: $ok ok, $erro erro(s).'
                        : 'Sincronização concluída: $ok ok, $erro erro(s). Primeiro erro: $firstError',
                  ),
                ),
              );
            }
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
