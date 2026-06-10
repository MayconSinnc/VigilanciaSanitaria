import 'dart:convert';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class PdfGeneratorService {
  static const _cienciaAutoIntimacao =
      'ESTOU CIENTE DE QUE O DESCUMPRIMENTO DAS EXIGÊNCIAS CONTIDAS NESTE AUTO PERMITIRÁ A APLICAÇÃO DAS SANÇÕES PREVISTAS PELO ART. 4º DA LEI COMPLEMENTAR Nº 40/19, SEM PREJUÍZO DE OUTRAS MEDIDAS LEGAIS E REGULAMENTARES. ESTOU CIENTE, AINDA, DE QUE PODEREI SOLICITAR PRORROGAÇÃO DO PRAZO AQUI ESTABELECIDO, UMA ÚNICA VEZ, JUSTIFICADAMENTE, À DIRETORIA DE VIGILÂNCIA SANITÁRIA DO MUNICÍPIO DE BALNEÁRIO CAMBORIÚ, NOS TERMOS DO §3º DO ART. 125 DA REFERIDA LEI.';
  static const _cienciaImposicaoPenalidade =
      'ESTOU CIENTE DE QUE PODEREI INTERPOR RECURSO POR ESCRITO NO PRAZO DE 15 (QUINZE) DIAS, A PARTIR DESTA NOTIFICAÇÃO, AO SECRETÁRIO MUNICIPAL DE SAÚDE, NOS TERMOS DO INCISO VI DO ART. 141 DA LEI COMPLEMENTAR Nº 40/19. ESGOTADOS OS PRAZOS LEGAIS, O DÉBITO SERÁ ENCAMINHADO À SECRETARIA DA FAZENDA PARA INSCRIÇÃO EM DÍVIDA ATIVA, COBRANÇA EM INSTITUIÇÃO BANCÁRIA E, SE FOR O CASO, PROTESTO EXTRAJUDICIAL E POSTERIOR PROVOCAÇÃO DO PODER JUDICIÁRIO PARA COBRANÇA COERCITIVA.';
  static const _observacaoImposicaoPenalidade =
      'NA PENALIDADE DE MULTA O AUTUADO TEM PRAZO DE 30 (TRINTA) DIAS PARA PAGAMENTO, A CONTAR DESTA NOTIFICAÇÃO, SOB PENA DE COBRANÇA JUDICIAL, NOS TERMOS DO INCISO III DO ART. 142 DA LEI COMPLEMENTAR Nº 40/19. SE O PAGAMENTO DA MULTA FOR EFETUADO EM 10 (DEZ) DIAS CONTADOS DESTA NOTIFICAÇÃO, COM DESISTÊNCIA TÁCITA DO RECURSO, O AUTUADO GOZARÁ DA REDUÇÃO DE 20% (VINTE POR CENTO) NO VALOR DA MULTA, CONFORME O INCISO IV DO ART. 142 DA REFERIDA LEI. O RECOLHIMENTO DA MULTA DEVERÁ SER FEITO, OBRIGATORIAMENTE, ATRAVÉS DE INSTITUIÇÃO BANCÁRIA. O NÃO PAGAMENTO DA MULTA, DEPOIS DE ESGOTADOS OS RECURSOS NO PRAZO LEGAL, IMPEDIRÁ QUE A DIVISÃO DE VIGILÂNCIA SANITÁRIA CONCEDA ALVARÁ DE QUALQUER NATUREZA AO AUTUADO, NOS TERMOS DO INCISO V DO ART. 52 DO DECRETO ESTADUAL Nº 23.663/84.';
  static const _cienciaAutoColeta =
      'ESTOU CIENTE DE QUE A COLETA AQUI REGISTRADA FOI REALIZADA CONFORME OS PROCEDIMENTOS LEGAIS E REGULAMENTARES (ART. 67 DA LEI ESTADUAL Nº 6.320/83 E ART. 40 DO DECRETO ESTADUAL Nº 23.663/84), BEM COMO ATESTO QUE TODOS OS DADOS LANÇADOS NO PRESENTE SÃO VERDADEIROS. ADEMAIS, TAMBÉM ESTOU CIENTE DE QUE O EXTRAVIO, VIOLAÇÃO E/OU ALTERAÇÃO DAS AMOSTRAS EM MEU PODER ELIMINARÁ A POSSIBILIDADE DE REALIZAÇÃO DE PERÍCIA DE CONTRAPROVA, SUJEITANDO O DETENTOR (FIEL DEPOSITÁRIO) ÀS PENALIDADES PREVISTAS NA LEGISLAÇÃO SANITÁRIA.';
  static const _laboratorioAutoColeta =
      'LABORATÓRIO CENTRAL DE SAÚDE PÚBLICA (LACEN/SC)\nRua Felipe Schmidt, nº 788 – Centro – Florianópolis/SC\nFone: (48) 3664-7800\nE-Mail: lacen@saude.sc.gov.br';
  static const _cabecalhoRis =
      'ESTADO DE SANTA CATARINA\nPREFEITURA DE BALNEÁRIO CAMBORIÚ\nSECRETARIA DE SAÚDE E SANEAMENTO\nDIVISÃO DE VIGILÂNCIA SANITÁRIA';

  Future<Uint8List> gerarAutoIntimacaoPdf(Map<String, dynamic> payload) async {
    final doc = pw.Document();

    final ai = (payload['auto_intimacao'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    final autuado = (ai['autuado'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    final receb = (ai['recebimento'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    final recusa = (ai['recusa'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    final dadosVisa = (ai['dados_visa'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    final autoridades = (ai['autoridades_saude'] is List)
        ? (ai['autoridades_saude'] as List).whereType<Map>().map((e) => e.cast<String, dynamic>()).toList()
        : const <Map<String, dynamic>>[];
    final basesLegais = (ai['bases_legais'] is List)
        ? (ai['bases_legais'] as List).whereType<Map>().map((e) => e.cast<String, dynamic>()).toList()
        : const <Map<String, dynamic>>[];
    final baseLegalLegacy = (ai['base_legal'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};

    pw.MemoryImage? assinaturaReceb;
    pw.MemoryImage? assinaturaT1;
    pw.MemoryImage? assinaturaT2;

    Uint8List? decodeB64(dynamic v) {
      if (v == null) return null;
      if (v is Uint8List) return v;
      final s = v.toString().trim();
      if (s.isEmpty) return null;
      try {
        return base64Decode(s);
      } catch (_) {
        return null;
      }
    }

    final aReceb = decodeB64(receb['assinatura_base64']);
    final aT1 = decodeB64(recusa['assinatura_testemunha_1_base64']);
    final aT2 = decodeB64(recusa['assinatura_testemunha_2_base64']);
    if (aReceb != null) assinaturaReceb = pw.MemoryImage(aReceb);
    if (aT1 != null) assinaturaT1 = pw.MemoryImage(aT1);
    if (aT2 != null) assinaturaT2 = pw.MemoryImage(aT2);
 
    String formatDate(String v) {
      final s = v.trim();
      final m = RegExp(r'^(\\d{4})-(\\d{2})-(\\d{2})$').firstMatch(s);
      if (m != null) return '${m.group(3)}/${m.group(2)}/${m.group(1)}';
      return s;
    }

    pw.Widget field(String label, String value) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 4),
        child: pw.RichText(
          text: pw.TextSpan(
            children: [
              pw.TextSpan(text: '$label ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.TextSpan(text: value),
            ],
          ),
        ),
      );
    }

    pw.Widget sectionTitle(String title) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(top: 8, bottom: 6),
        child: pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
      );
    }

    pw.Widget assinaturaBlock(String label, pw.MemoryImage? img) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
          pw.SizedBox(height: 4),
          pw.Container(
            height: 60,
            decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
            child: img == null
                ? pw.Center(child: pw.Text(''))
                : pw.Center(child: pw.Image(img, fit: pw.BoxFit.contain)),
          ),
        ],
      );
    }

    final numero = (ai['numero_auto'] ?? '').toString().trim();
    final setor = ((dadosVisa['setor'] ?? ai['departamento_vigilancia']) ?? '').toString().trim().toUpperCase();
    final telefoneVisa = ((dadosVisa['telefone'] ?? ai['telefone_visa']) ?? '').toString().trim();
    final emailVisa = ((dadosVisa['email'] ?? ai['email_visa']) ?? '').toString().trim();
    final prazoDias = (ai['prazo_dias'] ?? '').toString().trim();
    final dataLavratura = formatDate((ai['data_lavratura'] ?? '').toString());
    final dataVencimento = formatDate((ai['data_vencimento'] ?? '').toString());
    final prazosItens = <Map<String, dynamic>>[];
    final prazosRaw = ai['prazos_exigencias'];
    if (prazosRaw is List) {
      for (final p in prazosRaw) {
        if (p is Map) prazosItens.add(p.cast<String, dynamic>());
      }
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (ctx) => [
          pw.Text('ESTADO DE SANTA CATARINA', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Text('PREFEITURA DE BALNEÁRIO CAMBORIÚ', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Text('SECRETARIA MUNICIPAL DE SAÚDE', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Text('DIVISÃO DE VIGILÂNCIA SANITÁRIA', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          if (setor.isNotEmpty) pw.Text(setor, textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Text(
            'Avenida Palestina, nº 150,\nesquina com Rua Suíça –\nBairro das Nações –\nBalneário Camboriú/SC',
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 10),
          pw.Row(
            children: [
              pw.Expanded(child: pw.Text('AUTO DE INTIMAÇÃO', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13))),
              pw.Text(numero, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
            ],
          ),
          pw.Divider(),
          sectionTitle('AUTUADO'),
          field('Nome da Pessoa Física/Jurídica:', (autuado['nome'] ?? '').toString()),
          field('CNPJ/CPF:', (autuado['cnpj_cpf_formatado'] ?? autuado['cnpj_cpf'] ?? '').toString()),
          field('Denominação Comercial / Nome Fantasia:', (autuado['nome_fantasia'] ?? '').toString()),
          field('Endereço Completo:', (autuado['endereco_completo'] ?? '').toString()),
          field('Número:', (autuado['numero'] ?? '').toString()),
          field('Bairro:', (autuado['bairro'] ?? '').toString()),
          field('Município:', (autuado['municipio'] ?? '').toString()),
          field('UF:', (autuado['uf'] ?? '').toString()),
          field('Proprietário e/ou Responsável:', (autuado['proprietario_responsavel'] ?? '').toString()),
          field('Tipo de Estabelecimento / Negócio / Atividade:', (autuado['tipo_atividade'] ?? '').toString()),
          field('Pasta VISA:', (autuado['alvara_pasta_visa'] ?? '').toString()),
          pw.Divider(),
          sectionTitle('Enquadramento Legal (Legislação sanitária infringida que autoriza a medida):'),
          if (basesLegais.isNotEmpty)
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                for (final b in basesLegais)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 4),
                    child: pw.Text(
                      [
                        ((b['grupo'] ?? b['grupo_descricao'] ?? b['grupo_id']) ?? '').toString().trim(),
                        ((b['subgrupo'] ?? b['subgrupo_descricao'] ?? b['subgrupo_id']) ?? '').toString().trim(),
                        (b['base_legal'] ?? '').toString().trim(),
                        (b['artigo'] ?? '').toString().trim().isEmpty ? '' : 'Art. ${(b['artigo'] ?? '').toString().trim()}',
                        (b['descricao'] ?? '').toString().trim(),
                      ].where((e) => e.isNotEmpty).join(' • '),
                    ),
                  ),
              ],
            )
          else
            pw.Paragraph(text: (baseLegalLegacy['enquadramento_legal'] ?? baseLegalLegacy['base_legal'] ?? '').toString()),
          pw.SizedBox(height: 10),
          sectionTitle('Descrição das Irregularidades:'),
          pw.Paragraph(text: (ai['descricao_irregularidades'] ?? '').toString()),
          pw.SizedBox(height: 10),
          sectionTitle('Descrição das Providências / Exigências / Outras Informações:'),
          pw.Paragraph(text: (ai['descricao_providencias'] ?? '').toString()),
          pw.SizedBox(height: 10),
          sectionTitle('Prazo(s) para Cumprimento das Exigências:'),
          if (prazosItens.isNotEmpty) ...[
            ...prazosItens.map((p) {
              final ref = (p['referencia'] ?? '').toString().trim();
              final dias = (p['prazo_dias'] ?? '').toString().trim();
              final venc = formatDate((p['data_vencimento'] ?? '').toString());
              return pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 4),
                child: pw.Text(
                  [
                    ref.isEmpty ? '' : 'Itens $ref',
                    dias.isEmpty ? '' : '$dias dias',
                    venc.isEmpty ? '' : 'vencimento $venc',
                  ].where((e) => e.isNotEmpty).join(' — '),
                ),
              );
            }),
          ] else ...[
            pw.Text(prazoDias.isEmpty ? '' : '$prazoDias dias'),
            pw.SizedBox(height: 6),
            field('Data de vencimento do prazo:', dataVencimento),
          ],
          pw.Divider(),
          sectionTitle('CIÊNCIA'),
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromInt(0xFFFFF3CD),
              border: pw.Border.all(width: 0.8, color: PdfColor.fromInt(0xFFFFC107)),
            ),
            child: pw.Paragraph(text: _cienciaAutoIntimacao, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          ),
          pw.SizedBox(height: 10),
          field('Data da lavratura do Auto de Intimação:', dataLavratura),
          field('Telefone da VISA:', telefoneVisa),
          field('E-mail da VISA:', emailVisa),
          pw.Divider(),
          sectionTitle('RECEBIMENTO'),
          field('Recebido em:', (receb['data'] ?? '').toString()),
          field('Horário:', (receb['hora'] ?? '').toString()),
          field('Responsável:', (receb['responsavel'] ?? '').toString()),
          pw.SizedBox(height: 6),
          assinaturaBlock('Assinatura:', assinaturaReceb),
          pw.Divider(),
          sectionTitle('EM CASO DE RECUSA DO RESPONSÁVEL'),
          if (recusa['responsavel_recusou_assinatura'] == true) ...[
            field('1ª testemunha:', (recusa['testemunha_1'] ?? '').toString()),
            assinaturaBlock('Assinatura (1ª testemunha):', assinaturaT1),
            pw.SizedBox(height: 8),
            field('2ª testemunha:', (recusa['testemunha_2'] ?? '').toString()),
            assinaturaBlock('Assinatura (2ª testemunha):', assinaturaT2),
          ] else
            pw.Text(''),
          pw.Divider(),
          sectionTitle('AUTORIDADE DE SAÚDE'),
          if (autoridades.isEmpty)
            pw.Text('')
          else
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                for (final a in autoridades) ...[
                  field('Autoridade de Saúde:', (a['nome'] ?? '').toString()),
                  field('Função:', (a['funcao'] ?? '').toString()),
                  pw.SizedBox(height: 6),
                  assinaturaBlock('Assinatura:', (() {
                    final bytes = decodeB64(a['assinatura_base64']);
                    return bytes == null ? null : pw.MemoryImage(bytes);
                  })()),
                  pw.SizedBox(height: 10),
                ],
              ],
            ),
        ],
      ),
    );

    return doc.save();
  }

  Future<Uint8List> gerarImposicaoPenalidadePdf(Map<String, dynamic> payload) async {
    final doc = pw.Document();

    final ip = (payload['imposicao_penalidade'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    final autuado = (ip['autuado'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    final receb = (ip['recebimento'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    final recusa = (ip['recusa'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    final autoridade = (ip['autoridade_saude'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    final baseLegal = (ip['base_legal'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    final penalidade = (ip['penalidade'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};

    pw.MemoryImage? assinaturaReceb;
    pw.MemoryImage? assinaturaT1;
    pw.MemoryImage? assinaturaT2;
    pw.MemoryImage? assinaturaAutoridade;

    Uint8List? decodeB64(dynamic v) {
      if (v == null) return null;
      if (v is Uint8List) return v;
      final s = v.toString().trim();
      if (s.isEmpty) return null;
      try {
        return base64Decode(s);
      } catch (_) {
        return null;
      }
    }

    final aReceb = decodeB64(receb['assinatura_base64']);
    final aT1 = decodeB64(recusa['assinatura_testemunha_1_base64']);
    final aT2 = decodeB64(recusa['assinatura_testemunha_2_base64']);
    final aAut = decodeB64(autoridade['assinatura_base64']);
    if (aReceb != null) assinaturaReceb = pw.MemoryImage(aReceb);
    if (aT1 != null) assinaturaT1 = pw.MemoryImage(aT1);
    if (aT2 != null) assinaturaT2 = pw.MemoryImage(aT2);
    if (aAut != null) assinaturaAutoridade = pw.MemoryImage(aAut);

    pw.Widget field(String label, String value) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 4),
        child: pw.RichText(
          text: pw.TextSpan(
            children: [
              pw.TextSpan(text: '$label ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.TextSpan(text: value),
            ],
          ),
        ),
      );
    }

    pw.Widget sectionTitle(String title) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(top: 8, bottom: 6),
        child: pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
      );
    }

    pw.Widget assinaturaBlock(String label, pw.MemoryImage? img) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
          pw.SizedBox(height: 4),
          pw.Container(
            height: 60,
            decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
            child: img == null
                ? pw.Center(child: pw.Text(''))
                : pw.Center(child: pw.Image(img, fit: pw.BoxFit.contain)),
          ),
        ],
      );
    }

    final numero = (ip['numero_auto'] ?? payload['numero_ano'] ?? '').toString().trim();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (ctx) => [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Text('ESTADO DE SANTA CATARINA', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text('PREFEITURA DE BALNEÁRIO CAMBORIÚ', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text('SECRETARIA MUNICIPAL DE SAÚDE', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text('DIVISÃO DE VIGILÂNCIA SANITÁRIA', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              pw.Text(
                'Avenida Palestina, nº 150,\nesquina com Rua Suíça –\nBairro das Nações –\nBalneário Camboriú/SC',
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 10),
              pw.Row(
                children: [
                  pw.Expanded(
                    child: pw.Text('AUTO DE IMPOSIÇÃO DE PENALIDADE', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
                  ),
                  pw.Text(numero, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
                ],
              ),
              pw.Divider(),
              field('Data da lavratura do Auto de Imposição de Penalidade:', (ip['data_lavratura'] ?? '').toString()),
              field('Nome do setor da Vigilância Sanitária:', (ip['setor_vigilancia'] ?? '').toString()),
              field('Telefone da VISA:', (ip['telefone_visa'] ?? '').toString()),
              field('E-mail da VISA:', (ip['email_visa'] ?? '').toString()),
              field('Número do Processo Administrativo Sanitário (PAS) / Ano:', (ip['pas_numero'] ?? '').toString()),
              pw.Divider(),
              sectionTitle('AUTOS RELACIONADOS'),
              for (final a in ((ip['autos_intimacao_relacionados'] as List?)?.cast<dynamic>() ?? const <dynamic>[])) ...[
                if (a is Map)
                  field(
                    'Auto de Intimação:',
                    '${(a['numero_ano'] ?? '').toString()}${(a['data_recebimento'] ?? '').toString().trim().isEmpty ? '' : ' — recebido em ${(a['data_recebimento'] ?? '').toString()}'}',
                  ),
              ],
              for (final a in (() {
                final list = (ip['autos_infracao_relacionados'] as List?)?.cast<dynamic>();
                if (list != null && list.isNotEmpty) return list;
                final single = ip['auto_infracao_relacionado'];
                if (single is Map) return [single];
                return const <dynamic>[];
              })()) ...[
                if (a is Map)
                  field(
                    'Auto de Infração:',
                    '${(a['numero_ano'] ?? '').toString()}${(a['data_recebimento'] ?? '').toString().trim().isEmpty ? '' : ' — recebido em ${(a['data_recebimento'] ?? '').toString()}'}',
                  ),
              ],
              pw.Divider(),
              sectionTitle('AUTUADO'),
              field('Nome da Pessoa Física/Jurídica:', (autuado['nome'] ?? '').toString()),
              field('CNPJ/CPF:', (autuado['cnpj_cpf_formatado'] ?? autuado['cnpj_cpf'] ?? '').toString()),
              field('Denominação Comercial / Nome Fantasia:', (autuado['nome_fantasia'] ?? '').toString()),
              field('Endereço Completo:', (autuado['endereco_completo'] ?? '').toString()),
              field('Número:', (autuado['numero'] ?? '').toString()),
              field('Bairro:', (autuado['bairro'] ?? '').toString()),
              field('Município:', (autuado['municipio'] ?? '').toString()),
              field('UF:', (autuado['uf'] ?? '').toString()),
              field('Proprietário e/ou Responsável:', (autuado['proprietario_responsavel'] ?? '').toString()),
              field('Tipo de Estabelecimento / Negócio / Atividade:', (autuado['tipo_atividade'] ?? '').toString()),
              field('Pasta VISA:', (autuado['alvara_pasta_visa'] ?? '').toString()),
              pw.Divider(),
              sectionTitle('Enquadramento Legal (Legislação sanitária infringida que autoriza a medida):'),
              pw.Text((baseLegal['enquadramento_legal'] ?? baseLegal['base_legal'] ?? '').toString()),
              pw.SizedBox(height: 10),
              sectionTitle('Ato ou Fato Constitutivo da Infração Cometida:'),
              pw.Text((ip['ato_ou_fato'] ?? '').toString()),
              pw.SizedBox(height: 10),
              sectionTitle('Especificação Detalhada da Penalidade Imposta:'),
              pw.Text((penalidade['texto'] ?? '').toString()),
              pw.SizedBox(height: 6),
              field('Tipo de penalidade:', (penalidade['tipo'] ?? '').toString()),
              field('Quantidade de UFM:', (penalidade['ufm'] ?? '').toString()),
              field('Valor da multa:', (penalidade['valor'] ?? '').toString()),
              field('Valor por extenso:', (penalidade['valor_extenso'] ?? '').toString()),
              pw.SizedBox(height: 10),
              sectionTitle('Comentário sobre a Fiscalização:'),
              pw.Text((ip['comentario_fiscalizacao'] ?? '').toString()),
              pw.Divider(),
              sectionTitle('CIÊNCIA'),
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFFFFF3CD),
                  border: pw.Border.all(width: 0.8, color: PdfColor.fromInt(0xFFFFC107)),
                ),
                child: pw.Text(_cienciaImposicaoPenalidade, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              ),
              pw.SizedBox(height: 10),
              sectionTitle('OBSERVAÇÃO:'),
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFFE7F1FF),
                  border: pw.Border.all(width: 0.8, color: PdfColor.fromInt(0xFF0D6EFD)),
                ),
                child: pw.Text(_observacaoImposicaoPenalidade),
              ),
              pw.Divider(),
              sectionTitle('RECEBIMENTO'),
              field('Recebido em:', (receb['data'] ?? '').toString()),
              field('Horário:', (receb['hora'] ?? '').toString()),
              field('Responsável:', (receb['responsavel'] ?? '').toString()),
              pw.SizedBox(height: 6),
              assinaturaBlock('Assinatura:', assinaturaReceb),
              pw.Divider(),
              sectionTitle('EM CASO DE RECUSA DO RESPONSÁVEL'),
              if (recusa['responsavel_recusou_assinatura'] == true) ...[
                field('1ª testemunha:', (recusa['testemunha_1'] ?? '').toString()),
                assinaturaBlock('Assinatura (1ª testemunha):', assinaturaT1),
                pw.SizedBox(height: 8),
                field('2ª testemunha:', (recusa['testemunha_2'] ?? '').toString()),
                assinaturaBlock('Assinatura (2ª testemunha):', assinaturaT2),
              ] else
                pw.Text(''),
              pw.Divider(),
              sectionTitle('AUTORIDADE DE SAÚDE'),
              field('Autoridade de Saúde:', (autoridade['nome'] ?? '').toString()),
              field('Função:', (autoridade['funcao'] ?? '').toString()),
              pw.SizedBox(height: 6),
              assinaturaBlock('Assinatura:', assinaturaAutoridade),
            ],
          ),
        ],
      ),
    );

    return doc.save();
  }

  Future<Uint8List> gerarAutoColetaAmostraPdf(
    Map<String, dynamic> payload, {
    required int via,
  }) async {
    final doc = pw.Document();

    final col = (payload['auto_coleta_amostra'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    final det = (col['detentor'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    final prodSingle = (col['produto'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    final prodListRaw = (col['produtos'] as List?)?.cast<dynamic>();
    final produtos = <Map<String, dynamic>>[
      if (prodListRaw != null)
        for (final p in prodListRaw)
          if (p is Map) Map<String, dynamic>.from(p),
    ];
    if (produtos.isEmpty && prodSingle.isNotEmpty) produtos.add(Map<String, dynamic>.from(prodSingle));
    final receb = (col['recebimento'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    final recusa = (col['recusa'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    final autoridade = (col['autoridade_saude'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};

    pw.MemoryImage? assinaturaReceb;
    pw.MemoryImage? assinaturaT1;
    pw.MemoryImage? assinaturaT2;
    pw.MemoryImage? assinaturaAutoridade;

    Uint8List? decodeB64(dynamic v) {
      if (v == null) return null;
      if (v is Uint8List) return v;
      final s = v.toString().trim();
      if (s.isEmpty) return null;
      try {
        return base64Decode(s);
      } catch (_) {
        return null;
      }
    }

    final aReceb = decodeB64(receb['assinatura_base64']);
    final aT1 = decodeB64(recusa['assinatura_testemunha_1_base64']);
    final aT2 = decodeB64(recusa['assinatura_testemunha_2_base64']);
    final aAut = decodeB64(autoridade['assinatura_base64']);
    if (aReceb != null) assinaturaReceb = pw.MemoryImage(aReceb);
    if (aT1 != null) assinaturaT1 = pw.MemoryImage(aT1);
    if (aT2 != null) assinaturaT2 = pw.MemoryImage(aT2);
    if (aAut != null) assinaturaAutoridade = pw.MemoryImage(aAut);

    pw.Widget field(String label, String value) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 4),
        child: pw.RichText(
          text: pw.TextSpan(
            children: [
              pw.TextSpan(text: '$label ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.TextSpan(text: value),
            ],
          ),
        ),
      );
    }

    pw.Widget sectionTitle(String title) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(top: 8, bottom: 6),
        child: pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
      );
    }

    pw.Widget assinaturaBlock(String label, pw.MemoryImage? img) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
          pw.SizedBox(height: 4),
          pw.Container(
            height: 60,
            decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
            child: img == null
                ? pw.Center(child: pw.Text(''))
                : pw.Center(child: pw.Image(img, fit: pw.BoxFit.contain)),
          ),
        ],
      );
    }

    final numero = (col['numero_auto'] ?? payload['numero_ano'] ?? '').toString().trim();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (ctx) => [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Text('ESTADO DE SANTA CATARINA', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text('PREFEITURA DE BALNEÁRIO CAMBORIÚ', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text('SECRETARIA MUNICIPAL DE SAÚDE', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text('DIVISÃO DE VIGILÂNCIA SANITÁRIA', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              pw.Text(
                'Avenida Palestina, nº 150,\nesquina com Rua Suíça –\nBairro das Nações –\nBalneário Camboriú/SC',
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 10),
              pw.Row(
                children: [
                  pw.Expanded(
                    child: pw.Text(
                      'AUTO DE COLETA DE AMOSTRA PARA ANÁLISE — $viaª VIA',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13),
                    ),
                  ),
                  pw.Text(numero, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
                ],
              ),
              pw.Divider(),
              field('Tipo de Amostra:', (col['tipo_amostra'] ?? '').toString()),
              field('Data da lavratura:', (col['data_lavratura'] ?? '').toString()),
              field('Nome do setor da Vigilância Sanitária:', (col['setor_vigilancia'] ?? '').toString()),
              field('Telefone da VISA:', (col['telefone_visa'] ?? '').toString()),
              field('E-mail da VISA:', (col['email_visa'] ?? '').toString()),
              pw.Divider(),
              sectionTitle('LABORATÓRIO DE DESTINO'),
              pw.Text(_laboratorioAutoColeta),
              pw.Divider(),
              sectionTitle('DETENTOR'),
              field('Nome da Pessoa Física/Jurídica:', (det['nome'] ?? '').toString()),
              field('CNPJ/CPF:', (det['cnpj_cpf_formatado'] ?? det['cnpj_cpf'] ?? '').toString()),
              field('Denominação Comercial / Nome Fantasia:', (det['nome_fantasia'] ?? '').toString()),
              field('Endereço Completo:', (det['endereco_completo'] ?? '').toString()),
              field('Número:', (det['numero'] ?? '').toString()),
              field('Bairro:', (det['bairro'] ?? '').toString()),
              field('CEP:', (det['cep'] ?? '').toString()),
              field('Proprietário / Responsável:', (det['proprietario_responsavel'] ?? '').toString()),
              field('Município:', (det['municipio'] ?? '').toString()),
              field('UF:', (det['uf'] ?? '').toString()),
              field('Tipo de Estabelecimento / Negócio / Atividade:', (det['tipo_atividade'] ?? '').toString()),
              field('Número Alvará Sanitário:', (det['alvara_sanitario'] ?? '').toString()),
              pw.Divider(),
              for (var i = 0; i < produtos.length; i++) ...[
                sectionTitle(produtos.length > 1 ? 'PRODUTO COLETADO (${i + 1}/${produtos.length})' : 'PRODUTO COLETADO'),
                field('Nome do Produto:', (produtos[i]['nome_produto'] ?? '').toString()),
                field('Marca:', (produtos[i]['marca'] ?? '').toString()),
                field('Quantidade:', (produtos[i]['quantidade'] ?? '').toString()),
                field('Peso / Volume:', (produtos[i]['peso_volume'] ?? '').toString()),
                field('Lote / Partida:', (produtos[i]['lote'] ?? '').toString()),
                field('Número de Registro do Produto:', (produtos[i]['registro_produto'] ?? '').toString()),
                field('Data de Fabricação:', (produtos[i]['data_fabricacao'] ?? '').toString()),
                field('Data de Validade:', (produtos[i]['data_validade'] ?? '').toString()),
                field('Indústria Produtora / Produtor / Importador:', (produtos[i]['produtor_nome'] ?? '').toString()),
                field('CNPJ/CPF do Produtor:', (produtos[i]['produtor_cnpj_cpf'] ?? '').toString()),
                field(
                  'Endereço Completo:',
                  (produtos[i]['produtor_endereco_completo'] ?? produtos[i]['produtor_endereco_cep'] ?? '').toString(),
                ),
                field('CEP:', (produtos[i]['produtor_cep'] ?? '').toString()),
                field(
                  'Município:',
                  (produtos[i]['produtor_municipio'] ?? produtos[i]['produtor_municipio_estado'] ?? '').toString(),
                ),
                field('UF:', (produtos[i]['produtor_uf'] ?? '').toString()),
                field('Informações adicionais:', (produtos[i]['informacoes_adicionais'] ?? '').toString()),
                field('Motivo da Coleta:', (produtos[i]['motivo_coleta'] ?? '').toString()),
                field('Temperatura / Conservação:', (produtos[i]['temperatura_conservacao'] ?? '').toString()),
                field('Número dos Lacres (Detentor/Fiel Depositário):', (produtos[i]['lacres_detentor'] ?? '').toString()),
                field('Número dos Lacres (Laboratório):', (produtos[i]['lacres_laboratorio'] ?? '').toString()),
                if (i < produtos.length - 1) pw.Divider(),
              ],
              pw.Divider(),
              sectionTitle('CIÊNCIA'),
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFFFFF3CD),
                  border: pw.Border.all(width: 0.8, color: PdfColor.fromInt(0xFFFFC107)),
                ),
                child: pw.Text(_cienciaAutoColeta, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              ),
              pw.SizedBox(height: 10),
              if (via == 2) ...[
                sectionTitle('Comentário sobre a Fiscalização'),
                pw.Text((col['comentario_fiscalizacao'] ?? '').toString()),
                pw.SizedBox(height: 10),
              ],
              pw.Divider(),
              sectionTitle('RECEBIMENTO'),
              field('Recebi a 1ª via deste em:', (receb['data'] ?? '').toString()),
              field('Horário:', (receb['hora'] ?? '').toString()),
              field('Responsável:', (receb['responsavel'] ?? '').toString()),
              pw.SizedBox(height: 6),
              assinaturaBlock('Assinatura digital:', assinaturaReceb),
              pw.Divider(),
              sectionTitle('EM CASO DE RECUSA DO RESPONSÁVEL'),
              if (recusa['responsavel_recusou_assinatura'] == true) ...[
                field('1ª testemunha:', (recusa['testemunha_1'] ?? '').toString()),
                assinaturaBlock('Assinatura (1ª testemunha):', assinaturaT1),
                pw.SizedBox(height: 8),
                field('2ª testemunha:', (recusa['testemunha_2'] ?? '').toString()),
                assinaturaBlock('Assinatura (2ª testemunha):', assinaturaT2),
              ] else
                pw.Text(''),
              pw.Divider(),
              sectionTitle('AUTORIDADE DE SAÚDE'),
              field('Nome:', (autoridade['nome'] ?? '').toString()),
              field('Função:', (autoridade['funcao'] ?? '').toString()),
              pw.SizedBox(height: 6),
              assinaturaBlock('Assinatura digital:', assinaturaAutoridade),
            ],
          ),
        ],
      ),
    );

    return doc.save();
  }

  Future<Uint8List> gerarRelatorioInspecaoSanitariaPdf(Map<String, dynamic> payload) async {
    final doc = pw.Document();

    final ris = (payload['inspecao_sanitaria'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    final estab = (ris['estabelecimento'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    final equipe = (ris['equipe_fiscalizacao'] as List?)?.cast<dynamic>() ?? const [];

    Uint8List? decodeB64(dynamic v) {
      if (v == null) return null;
      if (v is Uint8List) return v;
      final s = v.toString().trim();
      if (s.isEmpty) return null;
      try {
        return base64Decode(s);
      } catch (_) {
        return null;
      }
    }

    pw.Widget field(String label, String value) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 4),
        child: pw.RichText(
          text: pw.TextSpan(
            children: [
              pw.TextSpan(text: '$label ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.TextSpan(text: value),
            ],
          ),
        ),
      );
    }

    pw.Widget sectionTitle(String title) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(top: 8, bottom: 6),
        child: pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
      );
    }

    pw.Widget assinaturaBox(pw.MemoryImage? img) {
      return pw.Container(
        height: 60,
        decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
        child: img == null ? pw.Center(child: pw.Text('')) : pw.Center(child: pw.Image(img, fit: pw.BoxFit.contain)),
      );
    }

    final numero = (ris['numero_relatorio'] ?? payload['numero_ano'] ?? '').toString().trim();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (ctx) => [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Text(_cabecalhoRis, textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              pw.Text(
                'Avenida Palestina, nº 150,\nesquina com Rua Suíça –\nBairro das Nações –\nBalneário Camboriú/SC',
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 10),
              pw.Row(
                children: [
                  pw.Expanded(
                    child: pw.Text(
                      'RELATÓRIO DE INSPEÇÃO SANITÁRIA',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13),
                    ),
                  ),
                  pw.Text(numero, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
                ],
              ),
              pw.Divider(),
              field('Data da lavratura do Relatório:', (ris['data_lavratura'] ?? '').toString()),
              field('Nome do setor da Vigilância Sanitária:', (ris['setor_vigilancia'] ?? '').toString()),
              field('Telefone da VISA:', (ris['telefone_visa'] ?? '').toString()),
              field('E-Mail da VISA:', (ris['email_visa'] ?? '').toString()),
              pw.Divider(),
              sectionTitle('IDENTIFICAÇÃO DO ESTABELECIMENTO INSPECIONADO'),
              field('Data / Período da Inspeção:', (estab['periodo_inspecao'] ?? '').toString()),
              field('Nome da Pessoa Física / Jurídica:', (estab['nome_pessoa'] ?? '').toString()),
              field('Denominação Comercial / Nome Fantasia:', (estab['nome_fantasia'] ?? '').toString()),
              field('Endereço:', (estab['endereco'] ?? '').toString()),
              field('CNPJ:', (estab['cnpj'] ?? '').toString()),
              field('Pasta VISA:', (estab['alvara_pasta_visa'] ?? '').toString()),
              field('Telefone:', (estab['telefone'] ?? '').toString()),
              field('E-Mail:', (estab['email'] ?? '').toString()),
              field('Representante Legal:', (estab['representante_legal'] ?? '').toString()),
              sectionTitle('Pessoas Contatadas'),
              pw.Text((estab['pessoas_contatadas'] ?? '').toString()),
              sectionTitle('Outras Observações'),
              pw.Text((estab['outras_observacoes'] ?? '').toString()),
              pw.Divider(),
              sectionTitle('Motivo da Inspeção'),
              pw.Text((ris['motivo_inspecao'] ?? '').toString()),
              sectionTitle('Histórico do Estabelecimento'),
              pw.Text((ris['historico_estabelecimento'] ?? '').toString()),
              sectionTitle('Situação Encontrada'),
              pw.Text((ris['situacao_encontrada'] ?? '').toString()),
              sectionTitle('Medida Adotada'),
              pw.Text((ris['medida_adotada'] ?? '').toString()),
              pw.Divider(),
              sectionTitle('Equipe de Fiscalização'),
              if (equipe.isEmpty)
                pw.Text('')
              else
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: equipe.map((e) {
                    final map = (e as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
                    final nome = (map['nome'] ?? '').toString();
                    final funcao = (map['funcao'] ?? '').toString();
                    final ass = decodeB64(map['assinatura_base64']);
                    final img = ass == null ? null : pw.MemoryImage(ass);
                    return pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 10),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                        children: [
                          field('Nome:', nome),
                          field('Função:', funcao),
                          assinaturaBox(img),
                        ],
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
        ],
      ),
    );

    return doc.save();
  }
}
