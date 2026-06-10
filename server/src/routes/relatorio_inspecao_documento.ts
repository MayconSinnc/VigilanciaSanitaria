import type { FastifyInstance } from 'fastify';
import PDFDocument from 'pdfkit';
import { z } from 'zod';
import { syncAutoTermoToSaude } from '../services/sinnc_saude_auto_termo_sync.js';

function pad6(n: number) {
  return String(n).padStart(6, '0');
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

function decodeB64(v: any): Buffer | null {
  if (!v) return null;
  const s = String(v).trim();
  if (!s) return null;
  try {
    return Buffer.from(s, 'base64');
  } catch (_) {
    return null;
  }
}

export function registerRelatorioInspecaoRoutes(app: FastifyInstance) {
  app.get('/api/relatorio-inspecao', { preValidation: [app.authenticate] }, async (request, reply) => {
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

    const docs = await app.prisma.relatorioInspecaoSanitariaDocumento.findMany({
      orderBy: { createdAt: 'desc' },
    });

    const items = docs
      .map((d: any) => {
        const dados = (d.dados ?? {}) as any;
        const ris = (dados.inspecao_sanitaria ?? {}) as any;
        const estab = (ris.estabelecimento ?? {}) as any;
        const dataHora = normalizeString(dados.data_hora);
        return {
          id: d.id,
          tipo_auto: 'INSPECAO_SANITARIA',
          tipo_documento: 'INSPECAO_SANITARIA',
          numero_ano: d.numeroRelatorio,
          numero_auto: d.numeroRelatorio,
          estabelecimento: normalizeString(estab.nome_fantasia),
          estabelecimento_nome: normalizeString(estab.nome_fantasia),
          estabelecimento_cnpj: normalizeString(estab.cnpj),
          cnpj: normalizeString(estab.cnpj),
          data_hora: dataHora,
          status: String(d.status ?? ''),
          payload: dados,
          pdf_url: `/api/relatorio-inspecao/${d.id}/pdf`,
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

  app.get('/api/relatorio-inspecao/next-numero', { preValidation: [app.authenticate] }, async (request, reply) => {
    const qSchema = z.object({ ano: z.coerce.number().min(2000).max(2100) });
    const parsed = qSchema.safeParse(request.query);
    if (!parsed.success) return reply.code(400).send({ error: 'Parâmetros inválidos' });

    const ano = parsed.data.ano;
    const rec = await app.prisma.relatorioInspecaoSanitariaSequence.upsert({
      where: { ano },
      create: { ano, lastSeq: 1 },
      update: { lastSeq: { increment: 1 } },
    });
    const numero = `RIS-${ano}-${pad6(rec.lastSeq)}`;
    return reply.send({ numero });
  });

  app.post('/api/relatorio-inspecao', { preValidation: [app.authenticate] }, async (request: any, reply) => {
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

    const ris = (parsed.data.dados?.inspecao_sanitaria ?? {}) as Record<string, unknown>;
    const estab = (ris['estabelecimento'] ?? {}) as Record<string, unknown>;

    if (status === 'SEM_EFEITO' && !normalizeString(ris['sem_efeito_motivo'])) {
      return reply.code(400).send({ error: 'Justificativa é obrigatória para Sem Efeito.' });
    }

    const created = await app.prisma.$transaction(async (tx: any) => {
      const seqRec = await tx.relatorioInspecaoSanitariaSequence.upsert({
        where: { ano },
        create: { ano, lastSeq: 1 },
        update: { lastSeq: { increment: 1 } },
      });
      const numeroRelatorio = `RIS-${ano}-${pad6(seqRec.lastSeq)}`;

      const doc = await tx.relatorioInspecaoSanitariaDocumento.create({
        data: {
          ano,
          sequencia: seqRec.lastSeq,
          numeroRelatorio,
          status,
          dados: parsed.data.dados,
          estabelecimentoNome: normalizeString(estab['nome_fantasia']),
          estabelecimentoCnpj: normalizeString(estab['cnpj']),
          dataLavratura: normalizeString(ris['data_lavratura']),
          semEfeitoMotivo: normalizeString(ris['sem_efeito_motivo']) || null,
          semEfeitoUsuarioId: status === 'SEM_EFEITO' ? userId : null,
          semEfeitoDataHora: status === 'SEM_EFEITO' ? new Date() : null,
          createdByUsuarioId: userId,
          updatedByUsuarioId: userId,
        },
      });

      await tx.relatorioInspecaoLog.create({
        data: {
          relatorioId: doc.id,
          usuarioId: userId,
          campo: 'DOCUMENTO',
          valorAnterior: null,
          valorNovo: numeroRelatorio,
          acao: 'CRIAR',
          dispositivo,
        },
      });

      if (status === 'FINALIZADO') {
        await tx.relatorioInspecaoLog.create({
          data: {
            relatorioId: doc.id,
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
        await tx.relatorioInspecaoLog.create({
          data: {
            relatorioId: doc.id,
            usuarioId: userId,
            campo: 'sem_efeito_motivo',
            valorAnterior: null,
            valorNovo: normalizeString(ris['sem_efeito_motivo']),
            acao: 'SEM_EFEITO',
            dispositivo,
          },
        });
      }

      return doc;
    });

    const usuario = userId ? await app.prisma.usuario.findUnique({ where: { id: userId } }) : null
    await syncAutoTermoToSaude({
      chave_origem: `vs:relatorio_inspecao:${created.id}`,
      tipo_documento: 'RELATORIO_DE_INSPECAO_SANITARIA',
      numero: created.numeroRelatorio,
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
      numero: created.numeroRelatorio,
      status: created.status,
    });
  });

  app.put('/api/relatorio-inspecao/:id', { preValidation: [app.authenticate] }, async (request: any, reply) => {
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

    const existing = await app.prisma.relatorioInspecaoSanitariaDocumento.findUnique({ where: { id } });
    if (!existing) return reply.code(404).send({ error: 'Relatório de Inspeção não encontrado.' });
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

    const ris = (parsedBody.data.dados?.inspecao_sanitaria ?? {}) as Record<string, unknown>;

    const updated = await app.prisma.$transaction(async (tx: any) => {
      const doc = await tx.relatorioInspecaoSanitariaDocumento.update({
        where: { id },
        data: {
          status: (parsedBody.data.status ?? 'EM_EDICAO') as any,
          dados: parsedBody.data.dados,
          dataLavratura: normalizeString(ris['data_lavratura']) || null,
          updatedByUsuarioId: userId,
        },
      });

      for (const c of changes.slice(0, 500)) {
        await tx.relatorioInspecaoLog.create({
          data: {
            relatorioId: id,
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
        await tx.relatorioInspecaoLog.create({
          data: {
            relatorioId: id,
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
      chave_origem: `vs:relatorio_inspecao:${updated.id}`,
      tipo_documento: 'RELATORIO_DE_INSPECAO_SANITARIA',
      numero: updated.numeroRelatorio,
      ano: updated.ano,
      situacao: String(updated.status || '').replace(/_/g, ' '),
      estabelecimento_nome: updated.estabelecimentoNome || '',
      estabelecimento_cnpj_cpf: updated.estabelecimentoCnpj || '',
      fiscal_nome: usuario?.nome || usuario?.cpf || '',
      conteudo: updated.dados ?? {},
      dispositivo: dispositivo ?? null,
      data_lavratura: updated.dataLavratura || null,
    })

    return reply.send({ id: updated.id, numero: updated.numeroRelatorio, status: updated.status });
  });

  app.get('/api/relatorio-inspecao/:id/logs', { preValidation: [app.authenticate] }, async (request, reply) => {
    const paramsSchema = z.object({ id: z.coerce.number().int().positive() });
    const p = paramsSchema.safeParse(request.params);
    if (!p.success) return reply.code(400).send({ error: 'Parâmetros inválidos' });

    const logs = await app.prisma.relatorioInspecaoLog.findMany({
      where: { relatorioId: p.data.id },
      orderBy: { dataHora: 'desc' },
      include: { usuario: { select: { id: true, nome: true, cpf: true } } },
    });
    return reply.send(logs);
  });

  app.get('/api/relatorio-inspecao/:id/pdf', { preValidation: [app.authenticate] }, async (request: any, reply) => {
    const paramsSchema = z.object({ id: z.coerce.number().int().positive() });
    const p = paramsSchema.safeParse(request.params);
    if (!p.success) return reply.code(400).send({ error: 'Parâmetros inválidos' });

    const docRow = await app.prisma.relatorioInspecaoSanitariaDocumento.findUnique({ where: { id: p.data.id } });
    if (!docRow) return reply.code(404).send({ error: 'Documento não encontrado.' });

    const dados = (docRow.dados ?? {}) as any;
    const ris = (dados.inspecao_sanitaria ?? {}) as any;
    const estab = (ris.estabelecimento ?? {}) as any;
    const equipe = Array.isArray(ris.equipe_fiscalizacao) ? ris.equipe_fiscalizacao : [];

    const pdf = new PDFDocument({ size: 'A4', margin: 40 });
    reply.header('Content-Type', 'application/pdf');
    reply.header('Content-Disposition', `inline; filename="${docRow.numeroRelatorio}.pdf"`);
    reply.send(pdf);

    const line = (label: string, value: string) => {
      pdf.font('Helvetica-Bold').fontSize(9).text(label, { continued: true });
      pdf.font('Helvetica').fontSize(9).text(` ${value || ''}`);
    };

    const assinaturaBox = (img: Buffer | null) => {
      const x = pdf.x;
      const y = pdf.y + 4;
      const w = 220;
      const h = 70;
      pdf.rect(x, y, w, h).stroke();
      if (img) {
        try {
          pdf.image(img, x + 6, y + 6, { fit: [w - 12, h - 12] });
        } catch (_) {}
      }
      pdf.y = y + h + 6;
    };

    pdf.font('Helvetica-Bold').fontSize(10).text('ESTADO DE SANTA CATARINA', { align: 'center' });
    pdf.text('PREFEITURA DE BALNEÁRIO CAMBORIÚ', { align: 'center' });
    pdf.text('SECRETARIA DE SAÚDE E SANEAMENTO', { align: 'center' });
    pdf.text('DIVISÃO DE VIGILÂNCIA SANITÁRIA', { align: 'center' });
    pdf.moveDown(0.2);
    pdf.font('Helvetica').fontSize(9).text(
      'Avenida Palestina, nº 150,\nesquina com Rua Suíça –\nBairro das Nações –\nBalneário Camboriú/SC',
      { align: 'center' },
    );
    pdf.moveDown(0.6);
    pdf.font('Helvetica-Bold').fontSize(12).text('RELATÓRIO DE INSPEÇÃO SANITÁRIA', { align: 'left' });
    pdf.font('Helvetica-Bold').fontSize(11).text(docRow.numeroRelatorio, { align: 'right' });
    pdf.moveDown(0.6);

    line('Data da lavratura do Relatório:', normalizeString(ris.data_lavratura));
    line('Nome do setor da Vigilância Sanitária:', normalizeString(ris.setor_vigilancia));
    line('Telefone da VISA:', normalizeString(ris.telefone_visa));
    line('E-Mail da VISA:', normalizeString(ris.email_visa));
    pdf.moveDown(0.4);

    pdf.font('Helvetica-Bold').fontSize(10).text('IDENTIFICAÇÃO DO ESTABELECIMENTO INSPECIONADO');
    pdf.moveDown(0.2);
    line('Data / Período da Inspeção:', normalizeString(estab.periodo_inspecao));
    line('Nome da Pessoa Física / Jurídica:', normalizeString(estab.nome_pessoa));
    line('Denominação Comercial / Nome Fantasia:', normalizeString(estab.nome_fantasia));
    line('Endereço:', normalizeString(estab.endereco));
    line('CNPJ:', normalizeString(estab.cnpj));
    line('Pasta VISA:', normalizeString(estab.alvara_pasta_visa));
    line('Telefone:', normalizeString(estab.telefone));
    line('E-Mail:', normalizeString(estab.email));
    line('Representante Legal:', normalizeString(estab.representante_legal));
    pdf.moveDown(0.2);
    pdf.font('Helvetica-Bold').fontSize(9).text('Pessoas Contatadas:');
    pdf.font('Helvetica').fontSize(9).text(normalizeString(estab.pessoas_contatadas));
    pdf.moveDown(0.2);
    pdf.font('Helvetica-Bold').fontSize(9).text('Outras Observações:');
    pdf.font('Helvetica').fontSize(9).text(normalizeString(estab.outras_observacoes));
    pdf.moveDown(0.4);

    pdf.font('Helvetica-Bold').fontSize(10).text('Motivo da Inspeção');
    pdf.moveDown(0.2);
    pdf.font('Helvetica').fontSize(9).text(normalizeString(ris.motivo_inspecao));
    pdf.moveDown(0.3);
    pdf.font('Helvetica-Bold').fontSize(10).text('Histórico do Estabelecimento');
    pdf.moveDown(0.2);
    pdf.font('Helvetica').fontSize(9).text(normalizeString(ris.historico_estabelecimento));
    pdf.moveDown(0.3);
    pdf.font('Helvetica-Bold').fontSize(10).text('Situação Encontrada');
    pdf.moveDown(0.2);
    pdf.font('Helvetica').fontSize(9).text(normalizeString(ris.situacao_encontrada));
    pdf.moveDown(0.3);
    pdf.font('Helvetica-Bold').fontSize(10).text('Medida Adotada');
    pdf.moveDown(0.2);
    pdf.font('Helvetica').fontSize(9).text(normalizeString(ris.medida_adotada));
    pdf.moveDown(0.4);

    pdf.font('Helvetica-Bold').fontSize(10).text('Equipe de Fiscalização');
    pdf.moveDown(0.2);
    for (const f of equipe) {
      const nome = normalizeString(f?.nome);
      const funcao = normalizeString(f?.funcao);
      const ass = decodeB64(f?.assinatura_base64);
      line('Nome:', nome);
      line('Função:', funcao);
      assinaturaBox(ass);
      pdf.moveDown(0.2);
    }

    pdf.end();
    return reply;
  });
}

