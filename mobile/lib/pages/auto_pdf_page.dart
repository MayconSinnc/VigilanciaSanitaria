import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class AutoPdfPage extends StatelessWidget {
  const AutoPdfPage({super.key});

  String _tituloDescricao(String tipo) {
    switch (tipo) {
      case 'INT':
        return 'DESCRIÇÃO DA IRREGULARIDADE';
      default:
        return 'DESCRIÇÃO DA INFRAÇÃO';
    }
  }

  String _tituloMedidas(String tipo) {
    switch (tipo) {
      case 'INT':
        return 'MEDIDAS E PRAZOS';
      default:
        return 'PENALIDADE / MEDIDAS';
    }
  }

  void _voltarOuDashboard(BuildContext context) {
    Navigator.of(context).maybePop();
  }

  Future<pw.Document> _buildDoc(Map<String, dynamic> args) async {
    final doc = pw.Document();
    final brasaoBytes = await rootBundle.load('public/brasao.png');
    final brasao = pw.MemoryImage(brasaoBytes.buffer.asUint8List());

    final evidencias = (args['evidencias'] as List?)?.whereType<Map>().toList() ?? const <Map>[];
    final tipo = '${args['tipo'] ?? 'INT'}';
    doc.addPage(
      pw.Page(
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Image(brasao, width: 54, height: 54),
                pw.SizedBox(width: 12),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('PREFEITURA MUNICIPAL DE BALNEÁRIO CAMBORIÚ', style: pw.TextStyle(fontSize: 12)),
                      pw.SizedBox(height: 2),
                      pw.Text('VIGILÂNCIA SANITÁRIA MUNICIPAL', style: pw.TextStyle(fontSize: 14)),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 12),
            pw.Text('${args['titulo'] ?? 'AUTO'} Nº ${args['numero'] ?? ''}', style: pw.TextStyle(fontSize: 16)),
            pw.SizedBox(height: 8),
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('DADOS DO ESTABELECIMENTO', style: pw.TextStyle(fontSize: 12)),
                  pw.SizedBox(height: 6),
                  pw.Text('CNPJ: ${args['cnpj'] ?? ''}'),
                  pw.Text('Razão Social: ${args['razaoSocial'] ?? ''}'),
                  pw.Text('Nome Fantasia: ${args['nome'] ?? ''}'),
                  pw.Text('Endereço: ${args['endereco'] ?? ''}'),
                  pw.Text('CNAE: ${args['cnae'] ?? ''}'),
                  pw.Text('Atividade: ${args['atividade'] ?? ''}'),
                  pw.Text('Situação do alvará: ${args['statusAlvara'] ?? ''}'),
                  pw.Text('Possui débito vencido: ${args['debitoVencido'] == true ? 'Sim' : (args['debitoVencido'] == false ? 'Não' : '-')}'),
                ],
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('RESPONSÁVEL PRESENTE', style: pw.TextStyle(fontSize: 12)),
                  pw.SizedBox(height: 6),
                  pw.Text('Nome: ${args['responsavelNome'] ?? ''}'),
                  pw.Text('CPF: ${args['responsavelCpf'] ?? ''}'),
                  pw.Text('Cargo/Função: ${args['responsavelCargo'] ?? ''}'),
                  pw.Text('Telefone: ${args['responsavelTelefone'] ?? ''}'),
                ],
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('DADOS DA INSPEÇÃO', style: pw.TextStyle(fontSize: 12)),
                  pw.SizedBox(height: 6),
                  pw.Text('Fiscal: ${args['fiscalNome'] ?? ''}'),
                  pw.Text('Matrícula: ${args['fiscalMatricula'] ?? ''}'),
                  pw.Text('Data/Hora: ${args['dataInspecao'] ?? ''} ${args['horaInspecao'] ?? ''}'),
                  pw.Text('Tipo: ${args['tipoInspecao'] ?? ''}'),
                ],
              ),
            ),
            pw.SizedBox(height: 12),
            pw.Text(_tituloDescricao(tipo), style: pw.TextStyle(fontSize: 12)),
            pw.SizedBox(height: 6),
            pw.Text('${args['descricao'] ?? ''}'),
            pw.SizedBox(height: 8),
            pw.Text('FUNDAMENTAÇÃO LEGAL', style: pw.TextStyle(fontSize: 12)),
            pw.SizedBox(height: 6),
            pw.Text('${args['fundamentacao'] ?? ''}'),
            if ((args['descricaoLegal'] ?? '').toString().isNotEmpty) pw.Text('${args['descricaoLegal'] ?? ''}'),
            pw.SizedBox(height: 8),
            pw.Text('OBSERVAÇÕES', style: pw.TextStyle(fontSize: 12)),
            pw.SizedBox(height: 6),
            pw.Text('${args['observacoes'] ?? ''}'),
            pw.SizedBox(height: 10),
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(_tituloMedidas(tipo), style: pw.TextStyle(fontSize: 12)),
                  pw.SizedBox(height: 6),
                  if (tipo == 'INT') ...[
                    pw.Text('Medidas exigidas: ${args['medidasExigidas'] ?? ''}'),
                    pw.Text('Prazo para cumprimento: ${args['prazoCumprimento'] ?? ''}'),
                    pw.Text('Advertência de penalidade: ${args['advertenciaPenalidade'] ?? ''}'),
                  ] else ...[
                    pw.Text('Classificação: ${args['classificacao'] ?? ''}'),
                    pw.Text('Tipo de medida: ${args['tipoMedida'] ?? ''}'),
                    pw.Text('Apreensão: ${args['apreensao'] == true ? 'Sim' : 'Não'}'),
                    pw.Text('Interdição: ${args['interdicao'] == true ? 'Sim' : 'Não'}'),
                    pw.Text('Prazo de regularização (dias): ${args['prazoRegularizacao'] ?? ''}'),
                    pw.Text('Valor da multa: ${args['valorMulta'] ?? ''}'),
                  ],
                ],
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('GEOLOCALIZAÇÃO', style: pw.TextStyle(fontSize: 12)),
                  pw.SizedBox(height: 6),
                  pw.Text('Latitude: ${args['latitude'] ?? ''}'),
                  pw.Text('Longitude: ${args['longitude'] ?? ''}'),
                  if ((args['enderecoGps'] ?? '').toString().isNotEmpty) pw.Text('Endereço GPS: ${args['enderecoGps']}'),
                ],
              ),
            ),
            pw.SizedBox(height: 16),
            if (evidencias.isNotEmpty) ...[
              pw.Text('EVIDÊNCIAS', style: pw.TextStyle(fontSize: 12)),
              pw.SizedBox(height: 8),
              pw.Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final ev in evidencias.take(6))
                    pw.Container(
                      width: 160,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          if (ev['bytes'] != null) pw.Image(pw.MemoryImage(ev['bytes']), height: 110, fit: pw.BoxFit.cover),
                          pw.SizedBox(height: 4),
                          pw.Text('${ev['descricao'] ?? ''}', style: pw.TextStyle(fontSize: 9)),
                        ],
                      ),
                    ),
                ],
              ),
              pw.SizedBox(height: 16),
            ],
            if (args['assinaturaFiscal'] != null || args['assinaturaResponsavel'] != null) ...[
              pw.Text('ASSINATURAS', style: pw.TextStyle(fontSize: 12)),
              pw.SizedBox(height: 8),
              pw.Row(children: [
                if (args['assinaturaFiscal'] != null) pw.Expanded(child: pw.Column(children: [pw.Text('Fiscal'), pw.SizedBox(height: 4), pw.Image(pw.MemoryImage(args['assinaturaFiscal']))])),
                if (args['assinaturaResponsavel'] != null) pw.SizedBox(width: 12),
                if (args['assinaturaResponsavel'] != null) pw.Expanded(child: pw.Column(children: [pw.Text('Responsável'), pw.SizedBox(height: 4), pw.Image(pw.MemoryImage(args['assinaturaResponsavel']))])),
              ])
            ],
          ],
        ),
      ),
    );
    return doc;
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ?? {};
    final titulo = (() {
      switch (args['tipo']) {
        case 'INF':
          return 'AUTO DE INFRAÇÃO';
        case 'PEN':
          return 'IMPOSIÇÃO DE PENALIDADE';
        case 'COL':
          return 'AUTO DE COLETA PARA AMOSTRA';
        default:
          return 'AUTO DE INTIMAÇÃO';
      }
    })();
    args['titulo'] = titulo;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Visualizar Documento'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _voltarOuDashboard(context),
        ),
      ),
      body: PdfPreview(build: (format) async {
        final doc = await _buildDoc(args);
        return doc.save();
      }),
    );
  }
}
