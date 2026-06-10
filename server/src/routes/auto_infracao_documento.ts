import type { FastifyInstance } from 'fastify';
import PDFDocument from 'pdfkit';
import { z } from 'zod';
import { buscarEntryPorId } from '../services/sinnc_base_legal.js';
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
 
export function registerAutoInfracaoDocumentoRoutes(app: FastifyInstance) {
  app.get('/api/auto-infracao', { preValidation: [app.authenticate] }, async (request, reply) => {
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

    const docs = await app.prisma.autoInfracaoDocumento.findMany({
      orderBy: { createdAt: 'desc' },
    });

    const items = docs
      .map((d: any) => {
        const dados = (d.dados ?? {}) as any;
        const dadosEstab = (dados.dados_estabelecimento ?? {}) as any;
        const dataHora = normalizeString(dados.data_hora);
        return {
          id: d.id,
          tipo_auto: 'AUTO_DE_INFRACAO',
          tipo_documento: 'AUTO_DE_INFRACAO',
          numero_ano: d.numeroAuto,
          numero_auto: d.numeroAuto,
          estabelecimento: normalizeString(dadosEstab.nome_fantasia),
          estabelecimento_nome: normalizeString(dadosEstab.nome_fantasia),
          estabelecimento_cnpj: normalizeString(dadosEstab.cnpj),
          cnpj: normalizeString(dadosEstab.cnpj),
          data_hora: dataHora,
          status: String(d.status ?? ''),
          payload: dados,
          pdf_url: `/api/auto-infracao/${d.id}/pdf`,
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

  app.get('/api/auto-infracao/next-numero', { preValidation: [app.authenticate] }, async (request, reply) => {
    const qSchema = z.object({ ano: z.coerce.number().min(2000).max(2100) });
    const parsed = qSchema.safeParse(request.query);
    if (!parsed.success) return reply.code(400).send({ error: 'Parâmetros inválidos' });
 
    const ano = parsed.data.ano;
    const rec = await app.prisma.autoInfracaoSequence.upsert({
      where: { ano },
      create: { ano, lastSeq: 1 },
      update: { lastSeq: { increment: 1 } },
    });
    const numero = `INF-${ano}-${pad6(rec.lastSeq)}`;
    return reply.send({ numero });
  });
 
  app.post('/api/auto-infracao', { preValidation: [app.authenticate] }, async (request: any, reply) => {
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
 
    const autoInfracao = (parsed.data.dados?.auto_infracao ?? {}) as Record<string, unknown>;
    const est = (parsed.data.dados?.dados_estabelecimento ?? {}) as Record<string, unknown>;
 
    if (status === 'SEM_EFEITO' && !normalizeString(autoInfracao['sem_efeito_motivo'])) {
      return reply.code(400).send({ error: 'Justificativa é obrigatória para Sem Efeito.' });
    }
 
    const created = await app.prisma.$transaction(async (tx: any) => {
      const seqRec = await tx.autoInfracaoSequence.upsert({
        where: { ano },
        create: { ano, lastSeq: 1 },
        update: { lastSeq: { increment: 1 } },
      });
      const numeroAuto = `INF-${ano}-${pad6(seqRec.lastSeq)}`;
 
      const doc = await tx.autoInfracaoDocumento.create({
        data: {
          ano,
          sequencia: seqRec.lastSeq,
          numeroAuto,
          status,
          dados: parsed.data.dados,
          estabelecimentoNome: normalizeString(est['nome_fantasia']),
          estabelecimentoCnpj: normalizeString(est['cnpj']),
          dataLavratura: normalizeString(autoInfracao['data_lavratura']),
          semEfeitoMotivo: normalizeString(autoInfracao['sem_efeito_motivo']) || null,
          semEfeitoUsuarioId: status === 'SEM_EFEITO' ? userId : null,
          semEfeitoDataHora: status === 'SEM_EFEITO' ? new Date() : null,
          createdByUsuarioId: userId,
          updatedByUsuarioId: userId,
        },
      });
 
      await tx.autoInfracaoLog.create({
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
        await tx.autoInfracaoLog.create({
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
        await tx.autoInfracaoLog.create({
          data: {
            autoId: doc.id,
            usuarioId: userId,
            campo: 'sem_efeito_motivo',
            valorAnterior: null,
            valorNovo: normalizeString(autoInfracao['sem_efeito_motivo']),
            acao: 'SEM_EFEITO',
            dispositivo,
          },
        });
      }
 
      return doc;
    });

    const usuario = userId ? await app.prisma.usuario.findUnique({ where: { id: userId } }) : null
    await syncAutoTermoToSaude({
      chave_origem: `vs:auto_infracao:${created.id}`,
      tipo_documento: 'AUTO_DE_INFRACAO',
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
 
  app.put('/api/auto-infracao/:id', { preValidation: [app.authenticate] }, async (request: any, reply) => {
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
 
    const existing = await app.prisma.autoInfracaoDocumento.findUnique({ where: { id } });
    if (!existing) return reply.code(404).send({ error: 'Auto de Infração não encontrado.' });
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
 
    const updated = await app.prisma.$transaction(async (tx: any) => {
      const doc = await tx.autoInfracaoDocumento.update({
        where: { id },
        data: {
          status: (parsedBody.data.status ?? 'EM_EDICAO') as any,
          dados: parsedBody.data.dados,
          updatedByUsuarioId: userId,
        },
      });
 
      for (const c of changes.slice(0, 500)) {
        await tx.autoInfracaoLog.create({
          data: {
            autoId: id,
            usuarioId: userId,
            campo: c.campo,
            valorAnterior: c.de.slice(0, 2000),
            valorNovo: c.para.slice(0, 2000),
            acao: 'EDITAR',
            dispositivo,
          },
        });
      }
 
      return doc;
    });

    const usuario = userId ? await app.prisma.usuario.findUnique({ where: { id: userId } }) : null
    await syncAutoTermoToSaude({
      chave_origem: `vs:auto_infracao:${updated.id}`,
      tipo_documento: 'AUTO_DE_INFRACAO',
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
 
  app.post('/api/auto-infracao/:id/finalizar', { preValidation: [app.authenticate] }, async (request: any, reply) => {
    const pSchema = z.object({ id: z.coerce.number().int().positive() });
    const parsedParams = pSchema.safeParse(request.params);
    if (!parsedParams.success) return reply.code(400).send({ error: 'Parâmetros inválidos' });
    const id = parsedParams.data.id;
 
    const userId = getUserId(request);
    const dispositivo = request.headers['user-agent'] ?? null;
 
    const existing = await app.prisma.autoInfracaoDocumento.findUnique({ where: { id } });
    if (!existing) return reply.code(404).send({ error: 'Auto de Infração não encontrado.' });
    if (existing.status === 'SEM_EFEITO') return reply.code(409).send({ error: 'Documento marcado como Sem Efeito.' });
 
    const updated = await app.prisma.$transaction(async (tx: any) => {
      const doc = await tx.autoInfracaoDocumento.update({
        where: { id },
        data: { status: 'FINALIZADO', updatedByUsuarioId: userId },
      });
      await tx.autoInfracaoLog.create({
        data: {
          autoId: id,
          usuarioId: userId,
          campo: 'status',
          valorAnterior: String(existing.status),
          valorNovo: 'FINALIZADO',
          acao: 'FINALIZAR',
          dispositivo,
        },
      });
      return doc;
    });

    const usuario = userId ? await app.prisma.usuario.findUnique({ where: { id: userId } }) : null
    await syncAutoTermoToSaude({
      chave_origem: `vs:auto_infracao:${updated.id}`,
      tipo_documento: 'AUTO_DE_INFRACAO',
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
 
  app.post('/api/auto-infracao/:id/sem-efeito', { preValidation: [app.authenticate] }, async (request: any, reply) => {
    const pSchema = z.object({ id: z.coerce.number().int().positive() });
    const parsedParams = pSchema.safeParse(request.params);
    if (!parsedParams.success) return reply.code(400).send({ error: 'Parâmetros inválidos' });
    const id = parsedParams.data.id;
 
    const bodySchema = z.object({ motivo: z.string().min(3), dispositivo: z.string().optional() });
    const parsedBody = bodySchema.safeParse(request.body);
    if (!parsedBody.success) return reply.code(400).send({ error: 'Justificativa inválida.' });
 
    const userId = getUserId(request);
    const dispositivo = parsedBody.data.dispositivo ?? request.headers['user-agent'] ?? null;
 
    const existing = await app.prisma.autoInfracaoDocumento.findUnique({ where: { id } });
    if (!existing) return reply.code(404).send({ error: 'Auto de Infração não encontrado.' });
 
    const updated = await app.prisma.$transaction(async (tx: any) => {
      const doc = await tx.autoInfracaoDocumento.update({
        where: { id },
        data: {
          status: 'SEM_EFEITO',
          semEfeitoMotivo: parsedBody.data.motivo,
          semEfeitoUsuarioId: userId,
          semEfeitoDataHora: new Date(),
          updatedByUsuarioId: userId,
        },
      });
      await tx.autoInfracaoLog.create({
        data: {
          autoId: id,
          usuarioId: userId,
          campo: 'sem_efeito_motivo',
          valorAnterior: existing.semEfeitoMotivo ?? null,
          valorNovo: parsedBody.data.motivo,
          acao: 'SEM_EFEITO',
          dispositivo,
        },
      });
      return doc;
    });

    const usuario = userId ? await app.prisma.usuario.findUnique({ where: { id: userId } }) : null
    await syncAutoTermoToSaude({
      chave_origem: `vs:auto_infracao:${updated.id}`,
      tipo_documento: 'AUTO_DE_INFRACAO',
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
 
  app.get('/api/auto-infracao/:id/logs', { preValidation: [app.authenticate] }, async (request, reply) => {
    const pSchema = z.object({ id: z.coerce.number().int().positive() });
    const parsedParams = pSchema.safeParse(request.params);
    if (!parsedParams.success) return reply.code(400).send({ error: 'Parâmetros inválidos' });
    const id = parsedParams.data.id;
 
    const logs = await app.prisma.autoInfracaoLog.findMany({
      where: { autoId: id },
      orderBy: { dataHora: 'desc' },
      include: { usuario: { select: { id: true, nome: true, cpf: true } } },
    });
    return reply.send(logs);
  });
 
  app.get('/api/auto-infracao/:id/auditoria', { preValidation: [app.authenticate] }, async (request, reply) => {
    const pSchema = z.object({ id: z.coerce.number().int().positive() });
    const parsedParams = pSchema.safeParse(request.params);
    if (!parsedParams.success) return reply.code(400).send({ error: 'Parâmetros inválidos' });
    const id = parsedParams.data.id;
 
    const doc = await app.prisma.autoInfracaoDocumento.findUnique({
      where: { id },
      include: {
        createdBy: { select: { id: true, nome: true, cpf: true } },
        updatedBy: { select: { id: true, nome: true, cpf: true } },
      },
    });
    if (!doc) return reply.code(404).send({ error: 'Auto de Infração não encontrado.' });
 
    const logs = await app.prisma.autoInfracaoLog.findMany({
      where: { autoId: id },
      orderBy: { dataHora: 'desc' },
      include: { usuario: { select: { id: true, nome: true, cpf: true } } },
    });
 
    return reply.send({
      documento: {
        id: doc.id,
        numero: doc.numeroAuto,
        status: doc.status,
        createdAt: doc.createdAt,
        updatedAt: doc.updatedAt,
        createdBy: doc.createdBy,
        updatedBy: doc.updatedBy,
        semEfeitoMotivo: doc.semEfeitoMotivo,
        semEfeitoDataHora: doc.semEfeitoDataHora,
      },
      logs,
    });
  });
 
  app.get('/api/auto-infracao/:id/pdf', { preValidation: [app.authenticate] }, async (request: any, reply) => {
    const pSchema = z.object({ id: z.coerce.number().int().positive() });
    const parsedParams = pSchema.safeParse(request.params);
    if (!parsedParams.success) return reply.code(400).send({ error: 'Parâmetros inválidos' });
    const id = parsedParams.data.id;
 
    const doc = await app.prisma.autoInfracaoDocumento.findUnique({ where: { id } });
    if (!doc) return reply.code(404).send({ error: 'Auto de Infração não encontrado.' });
 
    const dados = (doc.dados ?? {}) as any;
    const est = (dados.dados_estabelecimento ?? {}) as any;
    const infr = (dados.auto_infracao ?? {}) as any;
    const base = (infr.base_legal ?? {}) as any;
 
    const pdf = new PDFDocument({ size: 'A4', margin: 40 });
    const chunks: Buffer[] = [];
    pdf.on('data', (c) => chunks.push(c as Buffer));
    pdf.on('end', () => {
      const buffer = Buffer.concat(chunks);
      reply.header('Content-Type', 'application/pdf');
      reply.header('Content-Disposition', `inline; filename="${doc.numeroAuto}.pdf"`);
      reply.send(buffer);
    });
 
    const line = (label: string, value: string) => {
      pdf.font('Helvetica-Bold').fontSize(9).text(label, { continued: true });
      pdf.font('Helvetica').fontSize(9).text(` ${value || ''}`);
    };
 
    function formatDateBr(value: unknown) {
      const s = normalizeString(value);
      const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(s);
      if (m) return `${m[3]}/${m[2]}/${m[1]}`;
      return s;
    }

    pdf.font('Helvetica-Bold').fontSize(10).text('ESTADO DE SANTA CATARINA', { align: 'center' });
    pdf.text('PREFEITURA DE BALNEÁRIO CAMBORIÚ', { align: 'center' });
    pdf.text('SECRETARIA DE SAÚDE E SANEAMENTO', { align: 'center' });
    pdf.text('DIVISÃO DE VIGILÂNCIA SANITÁRIA', { align: 'center' });
    pdf.moveDown(0.2);
    pdf.font('Helvetica').fontSize(9).text(`ENDEREÇO: Rua 1500, nº 1100, Centro – Balneário Camboriú / SC`, { align: 'center' });
    pdf.moveDown(0.5);
    pdf.font('Helvetica-Bold').fontSize(12).text('AUTO DE INFRAÇÃO', { align: 'left' });
    pdf.font('Helvetica-Bold').fontSize(11).text(doc.numeroAuto, { align: 'right' });
    pdf.moveDown(0.8);
 
    line('LAVRADO EM:', normalizeString(infr.data_lavratura));
    pdf.moveDown(0.2);
    pdf.font('Helvetica-Bold').fontSize(10).text('AUTUADO');
    pdf.moveDown(0.2);
    line('NOME DA PESSOA FÍSICA / JURÍDICA:', normalizeString(est.nome_fantasia));
    line('CNPJ / CPF:', normalizeString(est.cnpj));
    line('DENOMINAÇÃO COMERCIAL / NOME FANTASIA:', normalizeString(est.nome_fantasia));
    line('ENDEREÇO COMPLETO:', normalizeString(est.endereco));
    const possuiPastaVisa = infr.possui_pasta_visa === true || est.possui_pasta_visa === true;
    const numeroPastaVisa = normalizeString(
      infr.numero_pasta_visa ||
        est.numero_pasta_visa ||
        est.alvara_pasta_visa ||
        est.alvara_sanitario ||
        est.pasta_visa ||
        '',
    );
    if (possuiPastaVisa && numeroPastaVisa) line('NÚMERO DA PASTA VISA:', numeroPastaVisa);
    pdf.moveDown(0.3);
 
    const intimacoes = Array.isArray(infr.intimacoes_relacionadas)
      ? infr.intimacoes_relacionadas
      : Array.isArray(infr.autos_intimacao_relacionados)
        ? infr.autos_intimacao_relacionados
        : [];
    const intimacaoNumeroPorId = new Map<string, string>();
    for (const it of intimacoes) {
      const idStr = normalizeString(it?.auto_intimacao_id);
      const num = normalizeString(it?.numero_ano);
      if (idStr && num) intimacaoNumeroPorId.set(idStr, num);
    }
    if (intimacoes.length) {
      pdf.font('Helvetica-Bold').fontSize(9).text('AUTO(S) DE INTIMAÇÃO:', { continued: true });
      pdf
        .font('Helvetica')
        .text(
          ` ${intimacoes
            .map((a: any) => `${normalizeString(a.numero_ano)} (${formatDateBr(a.data_recebimento)})`)
            .filter(Boolean)
            .join(' | ')}`,
        );
      pdf.moveDown(0.3);
    }
 
    pdf.font('Helvetica-Bold').fontSize(9).text(
      'ENQUADRAMENTO LEGAL (Dispositivo legal ou regulamentar infringido que autoriza a medida):',
    );
    const bases = Array.isArray(infr.bases_legais) ? infr.bases_legais : [];
    if (bases.length) {
      const ids = Array.from(
        new Set<string>(
          bases
            .map((b: any) => normalizeString(b.base_legal_id || b.id))
            .filter((s: string) => s.length > 0),
        ),
      );
      const detalhesEntries = await Promise.all(
        ids.map(async (id) => {
          try {
            const det = await buscarEntryPorId(id);
            return [id, det] as const;
          } catch {
            return [id, null] as const;
          }
        }),
      );
      const detalhesPorId = new Map<string, any>(detalhesEntries as any);

      pdf.font('Helvetica').fontSize(9);
      for (const b of bases) {
        const id = normalizeString(b.base_legal_id || b.id);
        const det = detalhesPorId.get(id);
        const grupo = normalizeString(det?.grupoDescricao);
        const subgrupo = normalizeString(det?.subgrupoDescricao);
        const groupPart = [grupo, subgrupo].filter(Boolean).join(' > ');
        const tipo = normalizeString(det?.tipoNorma);
        const numero = normalizeString(det?.numeroNorma);
        const ano = det?.anoNorma == null ? '' : String(det?.anoNorma);
        const esfera = normalizeString(det?.esfera);
        const normaPart = [tipo, [numero, ano].filter(Boolean).join('/'), esfera ? `(${esfera})` : ''].filter(Boolean).join(' ');
        const artigo = normalizeString(det?.artigo);
        const artigoPart = artigo ? `Art. ${artigo}` : '';
        const desc = normalizeString(det?.descricao || det?.ementa);

        const origem = normalizeString(b.origem).toUpperCase();
        let origemLabel = '';
        if (origem === 'PADRAO') origemLabel = 'Base legal padrão';
        else if (origem === 'AUTO_INTIMACAO') {
          const autoId = normalizeString(b.auto_intimacao_id);
          const numeroAno = (autoId && intimacaoNumeroPorId.get(autoId)) || '';
          origemLabel = `Auto de Intimação ${numeroAno ? `nº ${numeroAno}` : ''}`.trim();
        } else if (origem === 'MANUAL') origemLabel = 'Manual';

        const parts = [groupPart, normaPart, artigoPart, desc].filter(Boolean);
        const text = parts.length ? parts.join(' • ') : (id ? `Base legal: ${id}` : '');
        const textFinal = origemLabel ? `${text} • Origem: ${origemLabel}` : text;
        if (textFinal) pdf.text(textFinal);
      }
    } else {
      pdf.font('Helvetica').fontSize(9).text(normalizeString(base.base_legal));
    }
    pdf.moveDown(0.4);
 
    pdf.font('Helvetica-Bold').fontSize(9).text('ESPECIFICAÇÃO DETALHADA DO ATO OU FATO (Constitutivo da infração cometida):');
    pdf
      .font('Helvetica')
      .fontSize(9)
      .text(normalizeString(infr.especificacao_detalhada || infr.especificacao_detalhada_ato_ou_fato));
    pdf.moveDown(0.6);
 
    const ciencia =
      'ESTOU CIENTE DE QUE, EM VIRTUDE DA INFRAÇÃO CARACTERIZADA NESTE AUTO, RESPONDEREI A PROCESSO ADMINISTRATIVO, FICANDO SUJEITO ÀS PENALIDADES PREVISTAS NOS INCISOS DO ART. 158 DA LEI COMPLEMENTAR Nº 40/19. ESTOU CIENTE, AINDA, QUE PODEREI APRESENTAR DEFESA POR ESCRITO, NO PRAZO DE 15 (QUINZE) DIAS A CONTAR DESTA NOTIFICAÇÃO, AO DIRETOR-GERAL DA DIVISÃO DE VIGILÂNCIA SANITÁRIA DO MUNICÍPIO DE BALNEÁRIO CAMBORIÚ.';
 
    const boxX = pdf.x;
    const boxY = pdf.y;
    const boxW = pdf.page.width - pdf.page.margins.left - pdf.page.margins.right;
    const boxH = 120;
    pdf.rect(boxX, boxY, boxW, boxH).fillOpacity(0.06).fillAndStroke('#f1c40f', '#f1c40f');
    pdf.fillOpacity(1);
    pdf.fillColor('#000000');
    pdf.y = boxY + 10;
    pdf.x = boxX + 10;
    pdf.font('Helvetica-Bold').fontSize(10).text('CIÊNCIA:');
    pdf.moveDown(0.3);
    pdf.font('Helvetica').fontSize(9).text(ciencia, { width: boxW - 20, align: 'justify' });
    pdf.x = boxX;
    pdf.y = boxY + boxH + 14;
 
    pdf.font('Helvetica-Bold').fontSize(9).text('RECEBIDO EM: _____/____/_____. HORÁRIO: ___ : ___.');
    pdf.moveDown(0.8);
    line('RESPONSÁVEL (Nome legível):', '');
    line('ASSINATURA:', '');
    pdf.moveDown(0.6);
    pdf.font('Helvetica-Bold').fontSize(9).text('EM CASO DE RECUSA DO RESPONSÁVEL:');
    pdf.moveDown(0.5);
    line('1ª TESTEMUNHA:', '');
    line('ASSINATURA:', '');
    pdf.moveDown(0.5);
    line('2ª TESTEMUNHA:', '');
    line('ASSINATURA:', '');
    pdf.moveDown(0.8);
    pdf.font('Helvetica-Bold').fontSize(9).text('AUTORIDADE DE SAÚDE: _____________________   FUNÇÃO: _____________________   ASSINATURA: _____________________');
 
    pdf.end();
  });
}
