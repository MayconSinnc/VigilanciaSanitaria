import 'dart:async';
import 'package:flutter/material.dart';
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
import 'pages/auto_intimacao_pdf_page.dart';
import 'pages/auto_infracao_page.dart';
import 'pages/auto_imposicao_penalidade_page.dart';
import 'pages/auto_imposicao_penalidade_pdf_page.dart';
import 'pages/auto_coleta_amostra_page.dart';
import 'pages/auto_coleta_amostra_pdf_page.dart';
import 'pages/auto_termo_page.dart';
import 'pages/relatorio_inspecao_sanitaria_page.dart';
import 'pages/relatorio_inspecao_sanitaria_pdf_page.dart';
import 'pages/profile_page.dart';
import 'pages/cnpj_lookup_page.dart';
import 'pages/settings_page.dart';
import 'pages/base_legal_page.dart';
import 'pages/visa_settings_page.dart';
import 'pages/infracao_bases_padrao_settings_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

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
          if (args is Map) {
            final v = args['inspecaoId'];
            if (v is int) inspecaoId = v;
            if (v is num) inspecaoId = v.toInt();
            if (v is String) inspecaoId = int.tryParse(v);
          }
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
        '/auto-termo': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          List<Map<String, dynamic>>? initialBases;
          String? initialTipoDocumento;
          Map<String, dynamic>? initialEstabelecimento;
          var autoSyncOnOpen = false;
          var autoSyncPopOnFinish = false;
          if (args is Map && args['bases_legais_vinculadas'] is List) {
            initialBases = (args['bases_legais_vinculadas'] as List)
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList();
          }
          if (args is Map) {
            initialTipoDocumento = (args['initial_tipo_documento'] ?? '').toString().trim();
            final rawEstab = args['estabelecimento'];
            if (rawEstab is Map) {
              initialEstabelecimento = rawEstab.cast<String, dynamic>();
            }
            autoSyncOnOpen = args['auto_sync_on_open'] == true;
            autoSyncPopOnFinish = args['auto_sync_pop_on_finish'] == true;
          }
          return AutoTermoPage(
            initialBasesLegaisVinculadas: initialBases,
            initialTipoDocumento: initialTipoDocumento?.isEmpty == true ? null : initialTipoDocumento,
            initialEstabelecimento: initialEstabelecimento,
            autoSyncOnOpen: autoSyncOnOpen,
            autoSyncPopOnFinish: autoSyncPopOnFinish,
          );
        },
        '/auto-infracao': (_) => const AutoInfracaoPage(),
        '/imposicao-penalidade': (_) => const AutoImposicaoPenalidadePage(),
        '/auto-imposicao-penalidade': (_) => const AutoImposicaoPenalidadePage(),
        '/auto-coleta': (_) => const AutoColetaAmostraPage(),
        '/auto-coleta-amostra': (_) => const AutoColetaAmostraPage(),
        '/auto-coleta-amostra-pdf': (_) => const AutoColetaAmostraPdfPage(),
        '/relatorio-inspecao-sanitario': (_) => const RelatorioInspecaoSanitariaPage(),
        '/relatorio-inspecao-sanitario-pdf': (_) => const RelatorioInspecaoSanitariaPdfPage(),
        '/auto-pdf': (_) => const AutoPdfPage(),
        '/auto-intimacao-pdf': (_) => const AutoIntimacaoPdfPage(),
        '/auto-imposicao-penalidade-pdf': (_) => const AutoImposicaoPenalidadePdfPage(),
        '/perfil': (_) => const ProfilePage(),
        '/configuracoes': (_) => const SettingsPage(),
        '/configuracoes/dados-visa': (_) => const VisaSettingsPage(),
        '/configuracoes/bases-padrao-infracao': (_) => const InfracaoBasesPadraoSettingsPage(),
        '/base-legal': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          final selectionMode = args is Map && args['selectionMode'] == true;
          return BaseLegalPage(selectionMode: selectionMode);
        },
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
