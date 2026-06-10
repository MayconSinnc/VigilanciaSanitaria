import type { FastifyInstance } from 'fastify';
import PDFDocument from 'pdfkit';
import { z } from 'zod';
import { syncAutoTermoToSaude } from '../services/sinnc_saude_auto_termo_sync.js';

function pad6(n: number) {
  return String(n).padStart(6, '0');
}

function pad4(n: number) {
  return String(n).padStart(4, '0');
}

function getUserId(request: any): number | null {
  const id = request?.user?.userId;
  return typeof id === 'number' ? id : id ? Number(id) : null;
}

function normalizeString(value: unknown) {
  if (value === null || value === undefined) return '';
  return String(value).trim();
}

function flatten(obj: any, prefix = ''): Record<string, string> {
  if (obj === null || obj === undefined) return {};
  if (typeof obj !== 'object') return { [prefix || 'value']: normalizeString(obj) };
  if (Array.isArray(obj)) return { [prefix || 'value']: JSON.stringify(obj) };

  const out: Record<string, string> = {};
  for (const [k, v] of Object.entries(obj)) {
    const p = prefix ? `${prefix}.${k}` : k;
    if (v !== null && typeof v === 'object' && !Array.isArray(v)) {
      Object.assign(out, flatten(v, p));
    } else {
      out[p] = Array.isArray(v) ? JSON.stringify(v) : normalizeString(v);
    }
  }
  return out;
}

const cienciaTexto =
  'ESTOU CIENTE DE QUE PODEREI INTERPOR RECURSO POR ESCRITO NO PRAZO DE 15 (QUINZE) DIAS, A PARTIR DESTA NOTIFICAÇÃO, AO SECRETÁRIO MUNICIPAL DE SAÚDE, NOS TERMOS DO INCISO VI DO ART. 141 DA LEI COMPLEMENTAR Nº 40/19. ESGOTADOS OS PRAZOS LEGAIS, O DÉBITO SERÁ ENCAMINHADO À SECRETARIA DA FAZENDA PARA INSCRIÇÃO EM DÍVIDA ATIVA, COBRANÇA EM INSTITUIÇÃO BANCÁRIA E, SE FOR O CASO, PROTESTO EXTRAJUDICIAL E POSTERIOR PROVOCAÇÃO DO PODER JUDICIÁRIO PARA COBRANÇA COERCITIVA.';

const observacaoTexto =
  'NA PENALIDADE DE MULTA O AUTUADO TEM PRAZO DE 30 (TRINTA) DIAS PARA PAGAMENTO, A CONTAR DESTA NOTIFICAÇÃO, SOB PENA DE COBRANÇA JUDICIAL, NOS TERMOS DO INCISO III DO ART. 142 DA LEI COMPLEMENTAR Nº 40/19. SE O PAGAMENTO DA MULTA FOR EFETUADO EM 10 (DEZ) DIAS CONTADOS DESTA NOTIFICAÇÃO, COM DESISTÊNCIA TÁCITA DO RECURSO, O AUTUADO GOZARÁ DA REDUÇÃO DE 20% (VINTE POR CENTO) NO VALOR DA MULTA, CONFORME O INCISO IV DO ART. 142 DA REFERIDA LEI. O RECOLHIMENTO DA MULTA DEVERÁ SER FEITO, OBRIGATORIAMENTE, ATRAVÉS DE INSTITUIÇÃO BANCÁRIA. O NÃO PAGAMENTO DA MULTA, DEPOIS DE ESGOTADOS OS RECURSOS NO PRAZO LEGAL, IMPEDIRÁ QUE A DIVISÃO DE VIGILÂNCIA SANITÁRIA CONCEDA ALVARÁ DE QUALQUER NATUREZA AO AUTUADO, NOS TERMOS DO INCISO V DO ART. 52 DO DECRETO ESTADUAL Nº 23.663/84.';

export function registerAutoImposicaoPenalidadeDocumentoRoutes(app: FastifyInstance) {
  app.get('/api/imposicao-penalidade', { preValidation: [app.authenticate] }, async (request, reply) => {
    const qSchema = z.object({
      search: z.string().optional(),
      cnpj: z.string().optional(),
      status: z.string().optional(),
      data_inicio: z.string().optional(),
      data_fim: z.string().optional(),
    });
    const parsed = qSchema.safeParse(request.query);
    if (!parsed.success) return reply.code(400).send({ error: 'Parâmetros inválidos' });

    const q = (parsed.data.search ?? '').trim().toLowerCase();
    const cnpj = (parsed.data.cnpj ?? '').replace(/\D/g, '');
    const status = (parsed.data.status ?? '').trim().toUpperCase();
    const dataInicio = (parsed.data.data_inicio ?? '').trim();
    const dataFim = (parsed.data.data_fim ?? '').trim();
    const inicio = dataInicio ? new Date(`${dataInicio}T00:00:00`) : null;
    const fim = dataFim ? new Date(`${dataFim}T23:59:59`) : null;

    const docs = await app.prisma.autoImposicaoPenalidadeDocumento.findMany({
      orderBy: { createdAt: 'desc' },
    });

    const items = docs
      .map((d: any) => {
        const dados = (d.dados ?? {}) as any;
        const dadosEstab = (dados.dados_estabelecimento ?? {}) as any;
        const ip = (dados.imposicao_penalidade ?? {}) as any;
        const dataHora = normalizeString(dados.data_hora);
        return {
          id: d.id,
          tipo_auto: 'IMPOSICAO_DE_PENALIDADE',
          tipo_documento: 'IMPOSICAO_DE_PENALIDADE',
          numero_ano: d.numeroAuto,
          numero_auto: d.numeroAuto,
          estabelecimento: normalizeString(dadosEstab.nome_fantasia),
          estabelecimento_nome: normalizeString(dadosEstab.nome_fantasia),
          estabelecimento_cnpj: normalizeString(dadosEstab.cnpj),
          cnpj: normalizeString(dadosEstab.cnpj),
          pas_numero: normalizeString(ip.pas_numero),
          data_hora: dataHora,
          status: String(d.status ?? ''),
          payload: dados,
          pdf_url: `/api/imposicao-penalidade/${d.id}/pdf`,
        };
      })
      .filter((item: any) => {
        const raw = JSON.stringify(item).toLowerCase();
        const itemCnpj = String(item.cnpj ?? '').replace(/\D/g, '');
        const itemStatus = String(item.status ?? '').toUpperCase();
        const dataBruta = String(item.data_hora ?? '').trim();
        const dataItem = dataBruta ? new Date(dataBruta.replace(' ', 'T')) : null;

        if (q && !raw.includes(q)) return false;
        if (cnpj && !itemCnpj.includes(cnpj)) return false;
        if (status && status != 'TODOS' && itemStatus != status) return false;
        if (inicio != null && (dataItem == null || dataItem.getTime() < inicio.getTime())) return false;
        if (fim != null && (dataItem == null || dataItem.getTime() > fim.getTime())) return false;
        return true;
      });

    return reply.send(items);
  });

  app.get('/api/imposicao-penalidade/next-numero', { preValidation: [app.authenticate] }, async (request, reply) => {
    const qSchema = z.object({ ano: z.coerce.number().min(2000).max(2100) });
    const parsed = qSchema.safeParse(request.query);
    if (!parsed.success) return reply.code(400).send({ error: 'Parâmetros inválidos' });

    const ano = parsed.data.ano;
    const rec = await app.prisma.autoImposicaoPenalidadeSequence.upsert({
      where: { ano },
      create: { ano, lastSeq: 1 },
      update: { lastSeq: { increment: 1 } },
    });
    const numero = `PEN-${ano}-${pad6(rec.lastSeq)}`;
    return reply.send({ numero });
  });

  app.get('/api/imposicao-penalidade/next-pas', { preValidation: [app.authenticate] }, async (request, reply) => {
    const qSchema = z.object({ ano: z.coerce.number().min(2000).max(2100) });
    const parsed = qSchema.safeParse(request.query);
    if (!parsed.success) return reply.code(400).send({ error: 'Parâmetros inválidos' });

    const ano = parsed.data.ano;
    const rec = await app.prisma.autoImposicaoPenalidadePasSequence.upsert({
      where: { ano },
      create: { ano, lastSeq: 1 },
      update: { lastSeq: { increment: 1 } },
    });
    const pas_numero = `${pad4(rec.lastSeq)}/${ano}`;
    return reply.send({ pas_numero });
  });

  app.post('/api/imposicao-penalidade', { preValidation: [app.authenticate] }, async (request: any, reply) => {
    const bodySchema = z
      .object({
        ano: z.coerce.number().min(2000).max(2100),
        status: z.enum(['RASCUNHO', 'EM_EDICAO', 'FINALIZADO', 'SEM_EFEITO']).optional(),
        dados: z.record(z.any()),
        dispositivo: z.string().optional(),
      })
      .passthrough();
    const parsed = bodySchema.safeParse(request.body);
    if (!parsed.success) return reply.code(400).send({ error: 'Payload inválido' });

    const userId = getUserId(request);
    const ano = parsed.data.ano;
    const status = (parsed.data.status ?? 'RASCUNHO') as any;
    const dispositivo = parsed.data.dispositivo ?? request.headers['user-agent'] ?? null;

    const ip = (parsed.data.dados?.imposicao_penalidade ?? {}) as Record<string, unknown>;
    const est = (parsed.data.dados?.dados_estabelecimento ?? {}) as Record<string, unknown>;
    const pasNumero = normalizeString(ip['pas_numero']);

    if (!pasNumero) {
      return reply.code(400).send({ error: 'PAS é obrigatório.' });
    }
    if (!/^\d{4}\/\d{4}$/.test(pasNumero)) {
      return reply.code(400).send({ error: 'PAS inválido. Use o formato 0001/2026.' });
    }

    if (status === 'SEM_EFEITO' && !normalizeString(ip['sem_efeito_motivo'])) {
      return reply.code(400).send({ error: 'Justificativa é obrigatória para Sem Efeito.' });
    }

    const created = await app.prisma.$transaction(async (tx: any) => {
      const seqRec = await tx.autoImposicaoPenalidadeSequence.upsert({
        where: { ano },
        create: { ano, lastSeq: 1 },
        update: { lastSeq: { increment: 1 } },
      });
      const numeroAuto = `PEN-${ano}-${pad6(seqRec.lastSeq)}`;

      const doc = await tx.autoImposicaoPenalidadeDocumento.create({
        data: {
          ano,
          sequencia: seqRec.lastSeq,
          numeroAuto,
          status,
          dados: parsed.data.dados,
          estabelecimentoNome: normalizeString(est['nome_fantasia']),
          estabelecimentoCnpj: normalizeString(est['cnpj']),
          dataLavratura: normalizeString(ip['data_lavratura']),
          pasNumero: pasNumero,
          semEfeitoMotivo: normalizeString(ip['sem_efeito_motivo']) || null,
          semEfeitoUsuarioId: status === 'SEM_EFEITO' ? userId : null,
          semEfeitoDataHora: status === 'SEM_EFEITO' ? new Date() : null,
          createdByUsuarioId: userId,
          updatedByUsuarioId: userId,
        },
      });

      await tx.autoImposicaoPenalidadeLog.create({
        data: {
          autoId: doc.id,
          usuarioId: userId,
          campo: 'DOCUMENTO',
          valorAnterior: null,
          valorNovo: numeroAuto,
          acao: 'CRIAR',
          dispositivo,
        },
      });

      if (status === 'FINALIZADO') {
        await tx.autoImposicaoPenalidadeLog.create({
          data: {
            autoId: doc.id,
            usuarioId: userId,
            campo: 'status',
            valorAnterior: 'EM_EDICAO',
            valorNovo: 'FINALIZADO',
            acao: 'FINALIZAR',
            dispositivo,
          },
        });
      }

      if (status === 'SEM_EFEITO') {
        await tx.autoImposicaoPenalidadeLog.create({
          data: {
            autoId: doc.id,
            usuarioId: userId,
            campo: 'sem_efeito_motivo',
            valorAnterior: null,
            valorNovo: normalizeString(ip['sem_efeito_motivo']),
            acao: 'SEM_EFEITO',
            dispositivo,
          },
        });
      }

      return doc;
    });

    const usuario = userId ? await app.prisma.usuario.findUnique({ where: { id: userId } }) : null
    await syncAutoTermoToSaude({
      chave_origem: `vs:imposicao_penalidade:${created.id}`,
      tipo_documento: 'AUTO_DE_IMPOSICAO_DE_PENALIDADE',
      numero: created.numeroAuto,
      ano: created.ano,
      situacao: String(created.status || '').replace(/_/g, ' '),
      estabelecimento_nome: created.estabelecimentoNome || '',
      estabelecimento_cnpj_cpf: created.estabelecimentoCnpj || '',
      fiscal_nome: usuario?.nome || usuario?.cpf || '',
      conteudo: created.dados ?? {},
      dispositivo: dispositivo ?? null,
      data_lavratura: created.dataLavratura || null,
    })

    return reply.code(201).send({
      id: created.id,
      numero: created.numeroAuto,
      status: created.status,
    });
  });

  app.put('/api/imposicao-penalidade/:id', { preValidation: [app.authenticate] }, async (request: any, reply) => {
    const pSchema = z.object({ id: z.coerce.number().int().positive() });
    const parsedParams = pSchema.safeParse(request.params);
    if (!parsedParams.success) return reply.code(400).send({ error: 'Parâmetros inválidos' });

    const bodySchema = z
      .object({
        status: z.enum(['RASCUNHO', 'EM_EDICAO', 'FINALIZADO', 'SEM_EFEITO']).optional(),
        dados: z.record(z.any()),
        dispositivo: z.string().optional(),
      })
      .passthrough();
    const parsedBody = bodySchema.safeParse(request.body);
    if (!parsedBody.success) return reply.code(400).send({ error: 'Payload inválido' });

    const id = parsedParams.data.id;
    const userId = getUserId(request);
    const dispositivo = parsedBody.data.dispositivo ?? request.headers['user-agent'] ?? null;

    const existing = await app.prisma.autoImposicaoPenalidadeDocumento.findUnique({ where: { id } });
    if (!existing) return reply.code(404).send({ error: 'Auto de Imposição de Penalidade não encontrado.' });
    if (existing.status === 'FINALIZADO' || existing.status === 'SEM_EFEITO') {
      return reply.code(409).send({ error: 'Documento bloqueado para edição.' });
    }

    const before = flatten(existing.dados);
    const after = flatten(parsedBody.data.dados);

    const changes: Array<{ campo: string; de: string; para: string }> = [];
    for (const [k, v] of Object.entries(after)) {
      const old = before[k] ?? '';
      if (old !== v) changes.push({ campo: k, de: old, para: v });
    }

    const ip = (parsedBody.data.dados?.imposicao_penalidade ?? {}) as Record<string, unknown>;
    const pasNumero = normalizeString(ip['pas_numero']);

    if (!pasNumero) {
      return reply.code(400).send({ error: 'PAS é obrigatório.' });
    }
    if (!/^\d{4}\/\d{4}$/.test(pasNumero)) {
      return reply.code(400).send({ error: 'PAS inválido. Use o formato 0001/2026.' });
    }

    const updated = await app.prisma.$transaction(async (tx: any) => {
      const doc = await tx.autoImposicaoPenalidadeDocumento.update({
        where: { id },
        data: {
          status: (parsedBody.data.status ?? 'EM_EDICAO') as any,
          dados: parsedBody.data.dados,
          dataLavratura: normalizeString(ip['data_lavratura']) || null,
          pasNumero: pasNumero,
          updatedByUsuarioId: userId,
        },
      });

      for (const c of changes.slice(0, 500)) {
        await tx.autoImposicaoPenalidadeLog.create({
          data: {
            autoId: id,
            usuarioId: userId,
            campo: c.campo,
            valorAnterior: c.de,
            valorNovo: c.para,
            acao: 'ALTERAR',
            dispositivo,
          },
        });
      }

      if (parsedBody.data.status === 'FINALIZADO') {
        await tx.autoImposicaoPenalidadeLog.create({
          data: {
            autoId: id,
            usuarioId: userId,
            campo: 'status',
            valorAnterior: String(existing.status ?? ''),
            valorNovo: 'FINALIZADO',
            acao: 'FINALIZAR',
            dispositivo,
          },
        });
      }

      return doc;
    });

    const usuario = userId ? await app.prisma.usuario.findUnique({ where: { id: userId } }) : null
    await syncAutoTermoToSaude({
      chave_origem: `vs:imposicao_penalidade:${updated.id}`,
      tipo_documento: 'AUTO_DE_IMPOSICAO_DE_PENALIDADE',
      numero: updated.numeroAuto,
      ano: updated.ano,
      situacao: String(updated.status || '').replace(/_/g, ' '),
      estabelecimento_nome: updated.estabelecimentoNome || '',
      estabelecimento_cnpj_cpf: updated.estabelecimentoCnpj || '',
      fiscal_nome: usuario?.nome || usuario?.cpf || '',
      conteudo: updated.dados ?? {},
      dispositivo: dispositivo ?? null,
      data_lavratura: updated.dataLavratura || null,
    })

    return reply.send({ id: updated.id, numero: updated.numeroAuto, status: updated.status });
  });

  app.get('/api/imposicao-penalidade/:id/logs', { preValidation: [app.authenticate] }, async (request, reply) => {
    const paramsSchema = z.object({ id: z.coerce.number().int().positive() });
    const p = paramsSchema.safeParse(request.params);
    if (!p.success) return reply.code(400).send({ error: 'Parâmetros inválidos' });

    const logs = await app.prisma.autoImposicaoPenalidadeLog.findMany({
      where: { autoId: p.data.id },
      orderBy: { dataHora: 'desc' },
      include: { usuario: { select: { id: true, nome: true, cpf: true } } },
    });
    return reply.send(logs);
  });

  app.get('/api/imposicao-penalidade/:id/pdf', { preValidation: [app.authenticate] }, async (request: any, reply) => {
    const pSchema = z.object({ id: z.coerce.number().int().positive() });
    const parsedParams = pSchema.safeParse(request.params);
    if (!parsedParams.success) return reply.code(400).send({ error: 'Parâmetros inválidos' });
    const id = parsedParams.data.id;

    const doc = await app.prisma.autoImposicaoPenalidadeDocumento.findUnique({ where: { id } });
    if (!doc) return reply.code(404).send({ error: 'Documento não encontrado.' });

    const dados = (doc.dados ?? {}) as any;
    const est = (dados.dados_estabelecimento ?? {}) as any;
    const ip = (dados.imposicao_penalidade ?? {}) as any;
    const autuado = (ip.autuado ?? {}) as any;
    const base = (ip.base_legal ?? {}) as any;
    const rec = (ip.recebimento ?? {}) as any;
    const recusa = (ip.recusa ?? {}) as any;
    const autoridade = (ip.autoridade_saude ?? {}) as any;
    const autosInt = Array.isArray(ip.autos_intimacao_relacionados) ? ip.autos_intimacao_relacionados : [];
    const autosInf = Array.isArray(ip.autos_infracao_relacionados) ? ip.autos_infracao_relacionados : [];
    const autoInf = (ip.auto_infracao_relacionado ?? {}) as any;
    const penalidade = (ip.penalidade ?? {}) as any;

    const pdf = new PDFDocument({ size: 'A4', margin: 40 });
    reply.header('Content-Type', 'application/pdf');
    reply.header('Content-Disposition', `inline; filename="${doc.numeroAuto}.pdf"`);
    reply.send(pdf);

    const line = (label: string, value: string) => {
      pdf.font('Helvetica-Bold').fontSize(9).text(label, { continued: true });
      pdf.font('Helvetica').fontSize(9).text(` ${value || ''}`);
    };

    pdf.font('Helvetica-Bold').fontSize(10).text('ESTADO DE SANTA CATARINA', { align: 'center' });
    pdf.text('PREFEITURA DE BALNEÁRIO CAMBORIÚ', { align: 'center' });
    pdf.text('SECRETARIA MUNICIPAL DE SAÚDE', { align: 'center' });
    pdf.text('DIVISÃO DE VIGILÂNCIA SANITÁRIA', { align: 'center' });
    pdf.moveDown(0.2);
    pdf.font('Helvetica').fontSize(9).text(
      'Avenida Palestina, nº 150,\nesquina com Rua Suíça –\nBairro das Nações –\nBalneário Camboriú/SC',
      { align: 'center' },
    );
    pdf.moveDown(0.6);
    pdf.font('Helvetica-Bold').fontSize(12).text('AUTO DE IMPOSIÇÃO DE PENALIDADE', { align: 'left' });
    pdf.font('Helvetica-Bold').fontSize(11).text(doc.numeroAuto, { align: 'right' });
    pdf.moveDown(0.8);

    line('LAVRADO EM:', normalizeString(ip.data_lavratura));
    line('NOME DO SETOR DA VIGILÂNCIA SANITÁRIA:', normalizeString(ip.setor_vigilancia));
    line('TELEFONE DA VISA:', normalizeString(ip.telefone_visa));
    line('E-MAIL DA VISA:', normalizeString(ip.email_visa));
    line('NÚMERO DO PROCESSO ADMINISTRATIVO SANITÁRIO (PAS) / ANO:', normalizeString(ip.pas_numero));
    pdf.moveDown(0.4);

    pdf.font('Helvetica-Bold').fontSize(10).text('AUTUADO');
    pdf.moveDown(0.2);
    line('Nome da Pessoa Física/Jurídica:', normalizeString(autuado.nome || est.nome_fantasia));
    line('CNPJ/CPF:', normalizeString(autuado.cnpj_cpf_formatado || autuado.cnpj_cpf || est.cnpj));
    line('Denominação Comercial / Nome Fantasia:', normalizeString(autuado.nome_fantasia || est.nome_fantasia));
    line('Endereço Completo:', normalizeString(autuado.endereco_completo || est.endereco));
    line('Número:', normalizeString(autuado.numero));
    line('Bairro:', normalizeString(autuado.bairro));
    line('Município:', normalizeString(autuado.municipio));
    line('UF:', normalizeString(autuado.uf));
    line('Proprietário e/ou Responsável:', normalizeString(autuado.proprietario_responsavel));
    line('Tipo de Estabelecimento / Negócio / Atividade:', normalizeString(autuado.tipo_atividade));
    line('Pasta VISA:', normalizeString(autuado.alvara_pasta_visa));
    pdf.moveDown(0.4);

    if (autosInt.length) {
      pdf.font('Helvetica-Bold').fontSize(9).text('AUTO(S) DE INTIMAÇÃO:', { continued: true });
      pdf.font('Helvetica').text(
        ` ${autosInt.map((a: any) => `${normalizeString(a.numero_ano)} (${normalizeString(a.data_recebimento)})`).join(' | ')}`,
      );
      pdf.moveDown(0.3);
    }

    if (autosInf.length) {
      pdf.font('Helvetica-Bold').fontSize(9).text('AUTO(S) DE INFRAÇÃO:', { continued: true });
      pdf.font('Helvetica').text(
        ` ${autosInf.map((a: any) => `${normalizeString(a.numero_ano)} (${normalizeString(a.data_recebimento)})`).join(' | ')}`,
      );
      pdf.moveDown(0.3);
    } else if (normalizeString(autoInf.numero_ano) || normalizeString(autoInf.data_recebimento)) {
      pdf.font('Helvetica-Bold').fontSize(9).text('AUTO DE INFRAÇÃO:', { continued: true });
      pdf.font('Helvetica').text(` ${normalizeString(autoInf.numero_ano)} (${normalizeString(autoInf.data_recebimento)})`);
      pdf.moveDown(0.3);
    }

    pdf.font('Helvetica-Bold').fontSize(9).text('Enquadramento Legal (Legislação sanitária infringida que autoriza a medida):');
    pdf.font('Helvetica').fontSize(9).text(normalizeString(base.enquadramento_legal || base.base_legal));
    pdf.moveDown(0.4);

    pdf.font('Helvetica-Bold').fontSize(9).text('Ato ou Fato Constitutivo da Infração Cometida:');
    pdf.font('Helvetica').fontSize(9).text(normalizeString(ip.ato_ou_fato));
    pdf.moveDown(0.4);

    pdf.font('Helvetica-Bold').fontSize(9).text('Especificação Detalhada da Penalidade Imposta:');
    pdf.font('Helvetica').fontSize(9).text(normalizeString(penalidade.texto));
    if (normalizeString(penalidade.tipo) || normalizeString(penalidade.ufm) || normalizeString(penalidade.valor) || normalizeString(penalidade.valor_extenso)) {
      pdf.moveDown(0.2);
      line('Tipo de penalidade:', normalizeString(penalidade.tipo));
      line('Quantidade de UFM:', normalizeString(penalidade.ufm));
      line('Valor da multa:', normalizeString(penalidade.valor));
      line('Valor por extenso:', normalizeString(penalidade.valor_extenso));
    }
    pdf.moveDown(0.4);

    pdf.font('Helvetica-Bold').fontSize(9).text('Comentário sobre a Fiscalização:');
    pdf.font('Helvetica').fontSize(9).text(normalizeString(ip.comentario_fiscalizacao));
    pdf.moveDown(0.6);

    const boxW = pdf.page.width - pdf.page.margins.left - pdf.page.margins.right;
    const boxX = pdf.x;
    const boxY = pdf.y;
    const boxH = 150;
    pdf.rect(boxX, boxY, boxW, boxH).fillOpacity(0.08).fillAndStroke('#f1c40f', '#f1c40f');
    pdf.fillOpacity(1);
    pdf.fillColor('#000000');
    pdf.x = boxX + 10;
    pdf.y = boxY + 10;
    pdf.font('Helvetica-Bold').fontSize(10).text('CIÊNCIA');
    pdf.moveDown(0.3);
    pdf.font('Helvetica').fontSize(9).text(cienciaTexto, { width: boxW - 20, align: 'justify' });
    pdf.x = boxX;
    pdf.y = boxY + boxH + 14;

    const obsY = pdf.y;
    const obsH = 160;
    pdf.rect(boxX, obsY, boxW, obsH).fillOpacity(0.04).fillAndStroke('#0d6efd', '#0d6efd');
    pdf.fillOpacity(1);
    pdf.fillColor('#000000');
    pdf.x = boxX + 10;
    pdf.y = obsY + 10;
    pdf.font('Helvetica-Bold').fontSize(10).text('OBSERVAÇÃO:');
    pdf.moveDown(0.3);
    pdf.font('Helvetica').fontSize(9).text(observacaoTexto, { width: boxW - 20, align: 'justify' });
    pdf.x = boxX;
    pdf.y = obsY + obsH + 14;

    pdf.font('Helvetica-Bold').fontSize(10).text('RECEBIMENTO');
    pdf.moveDown(0.3);
    line('Recebido em:', normalizeString(rec.data));
    line('Horário:', normalizeString(rec.hora));
    line('Responsável:', normalizeString(rec.responsavel));
    pdf.moveDown(0.2);
    line('Assinatura:', '');
    pdf.moveDown(0.5);

    pdf.font('Helvetica-Bold').fontSize(9).text('Responsável recusou assinar:', { continued: true });
    pdf.font('Helvetica').fontSize(9).text(` ${recusa.responsavel_recusou_assinatura ? 'Sim' : 'Não'}`);
    if (recusa.responsavel_recusou_assinatura) {
      pdf.moveDown(0.2);
      line('1ª testemunha:', normalizeString(recusa.testemunha_1));
      line('Assinatura (1ª testemunha):', '');
      pdf.moveDown(0.2);
      line('2ª testemunha:', normalizeString(recusa.testemunha_2));
      line('Assinatura (2ª testemunha):', '');
    }
    pdf.moveDown(0.6);
    pdf.font('Helvetica-Bold').fontSize(10).text('AUTORIDADE DE SAÚDE');
    pdf.moveDown(0.2);
    line('Autoridade de Saúde:', normalizeString(autoridade.nome));
    line('Função:', normalizeString(autoridade.funcao));
    line('Assinatura:', '');

    pdf.end();
    return reply;
  });
}

