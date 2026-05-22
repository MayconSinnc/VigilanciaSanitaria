import 'package:flutter/material.dart';
import 'dart:async';
import 'package:dio/dio.dart';
import 'pages/login_page.dart';
import 'pages/dashboard_page.dart';
import 'pages/new_inspection_page.dart';
import 'pages/search_establishment_page.dart';
import 'pages/evidence_page.dart';
import 'pages/signature_page.dart';
import 'pages/qr_scan_page.dart';
import 'ui/theme.dart';
import 'pages/inspection_form_page.dart';
import 'pages/sanitary_map_page.dart';
import 'pages/risk_profile_page.dart';
import 'pages/cnpj_scanner_page.dart';
import 'pages/invoice_ocr_page.dart';
import 'pages/establishments_page.dart';
import 'pages/inspections_page.dart';
import 'pages/licenses_page.dart';
import 'pages/habite_se_page.dart';
import 'pages/professionals_page.dart';
import 'pages/reports_page.dart';
import 'pages/inspection_actions_page.dart';
import 'pages/establishment_detail_page.dart';
import 'pages/establishment_form_page.dart';
import 'pages/inspection_checklist_page.dart';
import 'pages/auto_form_page.dart';
import 'pages/auto_pdf_page.dart';
import 'pages/auto_infracao_page.dart';
import 'pages/imposicao_penalidade_page.dart';
import 'pages/auto_coleta_page.dart';
import 'pages/auto_termo_page.dart';
import 'pages/profile_page.dart';
import 'pages/cnpj_lookup_page.dart';
import 'pages/settings_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  // #region debug-point A:evidencias-route
  void _debugRoute(String stage, Object? args, int? inspecaoId) {
    unawaited(Dio()
        .post(
          'http://127.0.0.1:7777/event',
          data: {
            'sessionId': 'web-evidence-save',
            'runId': 'pre-fix',
            'hypothesisId': 'A',
            'location': 'main.dart:/evidencias',
            'msg': '[DEBUG] Evidence route resolved',
            'data': {
              'stage': stage,
              'argsType': args.runtimeType.toString(),
              'hasArgs': args != null,
              'inspecaoId': inspecaoId,
            },
            'ts': DateTime.now().millisecondsSinceEpoch,
          },
        )
        .then<void>((_) {}, onError: (_) {}));
  }
  // #endregion

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vigilância Sanitária Balneário Camboriú',
      theme: buildTheme(),
      debugShowCheckedModeBanner: false,
      home: const _SplashPage(),
      routes: {
        '/login': (_) => const LoginPage(),
        '/dashboard': (_) => const DashboardPage(),
        '/nova-inspecao': (_) => const NewInspectionPage(),
        '/buscar-estabelecimento': (_) => const SearchEstablishmentPage(),
        '/evidencias': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          int? inspecaoId;
          _debugRoute('route-entry', args, null);
          if (args is Map) {
            final v = args['inspecaoId'];
            if (v is int) inspecaoId = v;
            if (v is num) inspecaoId = v.toInt();
            if (v is String) inspecaoId = int.tryParse(v);
          }
          _debugRoute('route-resolved', args, inspecaoId);
          return EvidencePage(inspecaoId: inspecaoId);
        },
        '/assinatura': (_) => const SignaturePage(),
        '/qr': (_) => const QrScanPage(),
        '/formulario': (_) => const InspectionFormPage(),
        '/mapa': (_) => const SanitaryMapPage(),
        '/perfil-sanitario': (_) => const RiskProfilePage(),
        '/scanner-cnpj': (_) => const CnpjScannerPage(),
        '/ocr-nota': (_) => const InvoiceOcrPage(),
        '/estabelecimentos': (_) => const EstablishmentsPage(),
        '/inspecoes': (_) => const InspectionsPage(),
        '/licencas': (_) => const LicensesPage(),
        '/habite-se': (_) => const HabiteSePage(),
        '/profissionais': (_) => const ProfessionalsPage(),
        '/relatorios': (_) => const ReportsPage(),
        '/acoes-inspecao': (_) => const InspectionActionsPage(),
        '/ficha-estabelecimento': (_) => const EstablishmentDetailPage(),
        '/cadastro-estabelecimento': (_) => const EstablishmentFormPage(),
        '/buscar-cnpj': (_) => const CnpjLookupPage(),
        '/checklist': (_) => const InspectionChecklistPage(),
        '/auto': (_) => const AutoFormPage(),
        '/auto-termo': (_) => const AutoTermoPage(),
        '/auto-infracao': (_) => const AutoInfracaoPage(),
        '/imposicao-penalidade': (_) => const ImposicaoPenalidadePage(),
        '/auto-coleta': (_) => const AutoColetaPage(),
        '/auto-pdf': (_) => const AutoPdfPage(),
        '/perfil': (_) => const ProfilePage(),
        '/configuracoes': (_) => const SettingsPage(),
      },
    );
  }
}

class _SplashPage extends StatefulWidget {
  const _SplashPage();

  @override
  State<_SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<_SplashPage> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _timer = Timer(const Duration(milliseconds: 1800), () {
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/login');
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 280),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Image.asset('public/logo.png', fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}
