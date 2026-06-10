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

const TEXTO_CIENCIA_INTIMACAO =
  'ESTOU CIENTE DE QUE O DESCUMPRIMENTO DAS EXIGÊNCIAS CONTIDAS NESTE AUTO PERMITIRÁ A APLICAÇÃO DAS SANÇÕES PREVISTAS PELO ART. 4º DA LEI COMPLEMENTAR Nº 40/19, SEM PREJUÍZO DE OUTRAS MEDIDAS LEGAIS E REGULAMENTARES. ESTOU CIENTE, AINDA, DE QUE PODEREI SOLICITAR PRORROGAÇÃO DO PRAZO AQUI ESTABELECIDO, UMA ÚNICA VEZ, JUSTIFICADAMENTE, À DIRETORIA DE VIGILÂNCIA SANITÁRIA DO MUNICÍPIO DE BALNEÁRIO CAMBORIÚ, NOS TERMOS DO §3º DO ART. 125 DA REFERIDA LEI.';

export function registerAutoIntimacaoDocumentoRoutes(app: FastifyInstance) {
  app.get('/api/auto-intimacao', { preValidation: [app.authenticate] }, async (request, reply) => {
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

    const docs = await app.prisma.autoIntimacaoDocumento.findMany({
      orderBy: { createdAt: 'desc' },
    });

    const items = docs
      .map((d: any) => {
        const dados = (d.dados ?? {}) as any;
        const dadosEstab = (dados.dados_estabelecimento ?? {}) as any;
        const dataHora = normalizeString(dados.data_hora);
        return {
          id: d.id,
          tipo_auto: 'AUTO_DE_INTIMACAO',
          tipo_documento: 'AUTO_DE_INTIMACAO',
          numero_ano: d.numeroAuto,
          numero_auto: d.numeroAuto,
          estabelecimento: normalizeString(dadosEstab.nome_fantasia),
          estabelecimento_nome: normalizeString(dadosEstab.nome_fantasia),
          estabelecimento_cnpj: normalizeString(dadosEstab.cnpj),
          cnpj: normalizeString(dadosEstab.cnpj),
          data_hora: dataHora,
          status: String(d.status ?? ''),
          payload: dados,
          pdf_url: `/api/auto-intimacao/${d.id}/pdf`,
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

  app.get('/api/auto-intimacao/next-numero', { preValidation: [app.authenticate] }, async (request, reply) => {
    const qSchema = z.object({ ano: z.coerce.number().min(2000).max(2100) });
    const parsed = qSchema.safeParse(request.query);
    if (!parsed.success) return reply.code(400).send({ error: 'Parâmetros inválidos' });

    const ano = parsed.data.ano;
    const rec = await app.prisma.autoIntimacaoSequence.upsert({
      where: { ano },
      create: { ano, lastSeq: 1 },
      update: { lastSeq: { increment: 1 } },
    });
    const numero = `INT-${ano}-${pad6(rec.lastSeq)}`;
    return reply.send({ numero });
  });

  app.post('/api/auto-intimacao', { preValidation: [app.authenticate] }, async (request: any, reply) => {
    const bodySchema = z
      .object({
        ano: z.coerce.number().min(2000).max(2100),
        status: z.enum(['RASCUNHO', 'EM_EDICAO', 'FINALIZADO', 'SEM_EFEITO']).optional(),
        dados: z.record(z.any()),
        dispositivo: z.string().optional(),
        logs: z
          .array(
            z
              .object({
                campo: z.string(),
                valorAnterior: z.string().optional().nullable(),
                valorNovo: z.string().optional().nullable(),
                acao: z.string().optional(),
                dataHora: z.string().optional(),
              })
              .strict(),
          )
          .optional(),
      })
      .strict();
    const parsed = bodySchema.safeParse(request.body);
    if (!parsed.success) return reply.code(400).send({ error: 'Body inválido' });

    const ano = parsed.data.ano;
    const status = (parsed.data.status ?? 'RASCUNHO').toString().toUpperCase();
    const usuarioId = getUserId(request);
    const dispositivo = parsed.data.dispositivo;
    const logs = parsed.data.logs ?? [];

    const created = await app.prisma.$transaction(async (tx) => {
      const seqRec = await tx.autoIntimacaoSequence.upsert({
        where: { ano },
        create: { ano, lastSeq: 1 },
        update: { lastSeq: { increment: 1 } },
      });
      const sequencia = seqRec.lastSeq;
      const numeroAuto = `INT-${ano}-${pad6(sequencia)}`;

      const dados = { ...(parsed.data.dados ?? {}) } as any;
      const ai = dados.auto_intimacao;
      if (ai && typeof ai === 'object') {
        dados.auto_intimacao = { ...(ai as any), numero_auto: numeroAuto };
      }

      const estab = (dados.dados_estabelecimento ?? {}) as any;
      const dataLavratura = normalizeString(dados?.auto_intimacao?.data_lavratura ?? dados?.auto_intimacao?.dataLavratura);

      const doc = await tx.autoIntimacaoDocumento.create({
        data: {
          ano,
          sequencia,
          numeroAuto,
          status: status as any,
          dados,
          estabelecimentoNome: normalizeString(estab.nome_fantasia),
          estabelecimentoCnpj: normalizeString(estab.cnpj),
          dataLavratura: dataLavratura || null,
          createdByUsuarioId: usuarioId ?? undefined,
          updatedByUsuarioId: usuarioId ?? undefined,
          Logs: {
            create: [
              {
                usuarioId: usuarioId ?? undefined,
                campo: 'documento',
                valorAnterior: null,
                valorNovo: JSON.stringify({ status }),
                acao: 'CRIAR',
                dispositivo: dispositivo ?? null,
              },
              ...logs.map((l) => ({
                usuarioId: usuarioId ?? undefined,
                campo: l.campo,
                valorAnterior: l.valorAnterior ?? null,
                valorNovo: l.valorNovo ?? null,
                acao: (l.acao ?? 'ALTERAR').toString(),
                dispositivo: dispositivo ?? null,
              })),
            ],
          },
        },
      });

      return doc;
    });

    const usuario = usuarioId ? await app.prisma.usuario.findUnique({ where: { id: usuarioId } }) : null
    await syncAutoTermoToSaude({
      chave_origem: `vs:auto_intimacao:${created.id}`,
      tipo_documento: 'AUTO_DE_INTIMACAO',
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

    return reply.send({ id: created.id, numero: created.numeroAuto, status: created.status });
  });

  app.put('/api/auto-intimacao/:id', { preValidation: [app.authenticate] }, async (request: any, reply) => {
    const paramsSchema = z.object({ id: z.coerce.number().int().positive() });
    const bodySchema = z
      .object({
        status: z.enum(['RASCUNHO', 'EM_EDICAO', 'FINALIZADO', 'SEM_EFEITO']).optional(),
        dados: z.record(z.any()),
        dispositivo: z.string().optional(),
        logs: z
          .array(
            z
              .object({
                campo: z.string(),
                valorAnterior: z.string().optional().nullable(),
                valorNovo: z.string().optional().nullable(),
                acao: z.string().optional(),
                dataHora: z.string().optional(),
              })
              .strict(),
          )
          .optional(),
      })
      .strict();

    const p = paramsSchema.safeParse(request.params);
    const b = bodySchema.safeParse(request.body);
    if (!p.success || !b.success) return reply.code(400).send({ error: 'Parâmetros inválidos' });

    const usuarioId = getUserId(request);
    const dispositivo = b.data.dispositivo;
    const logs = b.data.logs ?? [];

    const existing = await app.prisma.autoIntimacaoDocumento.findUnique({ where: { id: p.data.id } });
    if (!existing) return reply.code(404).send({ error: 'Documento não encontrado' });

    const oldFlat = flatten(existing.dados ?? {});
    const newDados = { ...(b.data.dados ?? {}) };
    const newFlat = flatten(newDados);

    const changes: Array<{ campo: string; valorAnterior: string | null; valorNovo: string | null }> = [];
    const keys = new Set([...Object.keys(oldFlat), ...Object.keys(newFlat)]);
    for (const k of keys) {
      const a = oldFlat[k] ?? '';
      const n = newFlat[k] ?? '';
      if (a !== n) changes.push({ campo: k, valorAnterior: a || null, valorNovo: n || null });
    }

    const dataLavratura = normalizeString((newDados as any)?.auto_intimacao?.data_lavratura ?? (newDados as any)?.auto_intimacao?.dataLavratura);
    const estab = ((newDados as any).dados_estabelecimento ?? {}) as any;

    const updated = await app.prisma.autoIntimacaoDocumento.update({
      where: { id: p.data.id },
      data: {
        status: (b.data.status ?? existing.status) as any,
        dados: newDados,
        dataLavratura: dataLavratura || null,
        estabelecimentoNome: normalizeString(estab.nome_fantasia),
        estabelecimentoCnpj: normalizeString(estab.cnpj),
        updatedByUsuarioId: usuarioId ?? undefined,
        Logs: {
          create: [
            ...changes.map((c) => ({
              usuarioId: usuarioId ?? undefined,
              campo: c.campo,
              valorAnterior: c.valorAnterior,
              valorNovo: c.valorNovo,
              acao: 'ALTERAR',
              dispositivo: dispositivo ?? null,
            })),
            ...logs.map((l) => ({
              usuarioId: usuarioId ?? undefined,
              campo: l.campo,
              valorAnterior: l.valorAnterior ?? null,
              valorNovo: l.valorNovo ?? null,
              acao: (l.acao ?? 'ALTERAR').toString(),
              dispositivo: dispositivo ?? null,
            })),
            {
              usuarioId: usuarioId ?? undefined,
              campo: 'status',
              valorAnterior: String(existing.status ?? ''),
              valorNovo: String(b.data.status ?? existing.status ?? ''),
              acao: 'SALVAR',
              dispositivo: dispositivo ?? null,
            },
          ],
        },
      },
    });

    const usuario = usuarioId ? await app.prisma.usuario.findUnique({ where: { id: usuarioId } }) : null
    await syncAutoTermoToSaude({
      chave_origem: `vs:auto_intimacao:${updated.id}`,
      tipo_documento: 'AUTO_DE_INTIMACAO',
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

  app.post('/api/auto-intimacao/:id/finalizar', { preValidation: [app.authenticate] }, async (request: any, reply) => {
    const paramsSchema = z.object({ id: z.coerce.number().int().positive() });
    const p = paramsSchema.safeParse(request.params);
    if (!p.success) return reply.code(400).send({ error: 'Parâmetros inválidos' });

    const usuarioId = getUserId(request);
    const updated = await app.prisma.autoIntimacaoDocumento.update({
      where: { id: p.data.id },
      data: {
        status: 'FINALIZADO' as any,
        updatedByUsuarioId: usuarioId ?? undefined,
        Logs: {
          create: [
            {
              usuarioId: usuarioId ?? undefined,
              campo: 'status',
              valorAnterior: null,
              valorNovo: 'FINALIZADO',
              acao: 'FINALIZAR',
            },
          ],
        },
      },
    });

    const usuario = usuarioId ? await app.prisma.usuario.findUnique({ where: { id: usuarioId } }) : null
    await syncAutoTermoToSaude({
      chave_origem: `vs:auto_intimacao:${updated.id}`,
      tipo_documento: 'AUTO_DE_INTIMACAO',
      numero: updated.numeroAuto,
      ano: updated.ano,
      situacao: String(updated.status || '').replace(/_/g, ' '),
      estabelecimento_nome: updated.estabelecimentoNome || '',
      estabelecimento_cnpj_cpf: updated.estabelecimentoCnpj || '',
      fiscal_nome: usuario?.nome || usuario?.cpf || '',
      conteudo: updated.dados ?? {},
      dispositivo: null,
      data_lavratura: updated.dataLavratura || null,
    })
    return reply.send({ id: updated.id, numero: updated.numeroAuto, status: updated.status });
  });

  app.post('/api/auto-intimacao/:id/sem-efeito', { preValidation: [app.authenticate] }, async (request: any, reply) => {
    const paramsSchema = z.object({ id: z.coerce.number().int().positive() });
    const bodySchema = z.object({ motivo: z.string().min(1), dispositivo: z.string().optional() }).strict();
    const p = paramsSchema.safeParse(request.params);
    const b = bodySchema.safeParse(request.body);
    if (!p.success || !b.success) return reply.code(400).send({ error: 'Parâmetros inválidos' });

    const usuarioId = getUserId(request);
    const updated = await app.prisma.autoIntimacaoDocumento.update({
      where: { id: p.data.id },
      data: {
        status: 'SEM_EFEITO' as any,
        semEfeitoMotivo: b.data.motivo,
        semEfeitoUsuarioId: usuarioId ?? undefined,
        semEfeitoDataHora: new Date(),
        updatedByUsuarioId: usuarioId ?? undefined,
        Logs: {
          create: [
            {
              usuarioId: usuarioId ?? undefined,
              campo: 'sem_efeito',
              valorAnterior: null,
              valorNovo: b.data.motivo,
              acao: 'SEM_EFEITO',
              dispositivo: b.data.dispositivo ?? null,
            },
          ],
        },
      },
    });

    const usuario = usuarioId ? await app.prisma.usuario.findUnique({ where: { id: usuarioId } }) : null
    await syncAutoTermoToSaude({
      chave_origem: `vs:auto_intimacao:${updated.id}`,
      tipo_documento: 'AUTO_DE_INTIMACAO',
      numero: updated.numeroAuto,
      ano: updated.ano,
      situacao: String(updated.status || '').replace(/_/g, ' '),
      estabelecimento_nome: updated.estabelecimentoNome || '',
      estabelecimento_cnpj_cpf: updated.estabelecimentoCnpj || '',
      fiscal_nome: usuario?.nome || usuario?.cpf || '',
      conteudo: updated.dados ?? {},
      dispositivo: b.data.dispositivo ?? null,
      data_lavratura: updated.dataLavratura || null,
    })
    return reply.send({ id: updated.id, numero: updated.numeroAuto, status: updated.status });
  });

  app.get('/api/auto-intimacao/:id/logs', { preValidation: [app.authenticate] }, async (request, reply) => {
    const paramsSchema = z.object({ id: z.coerce.number().int().positive() });
    const p = paramsSchema.safeParse(request.params);
    if (!p.success) return reply.code(400).send({ error: 'Parâmetros inválidos' });

    const logs = await app.prisma.autoIntimacaoLog.findMany({
      where: { autoId: p.data.id },
      orderBy: { dataHora: 'desc' },
      include: { usuario: true },
    });
    return reply.send(logs);
  });

  app.get('/api/auto-intimacao/:id/auditoria', { preValidation: [app.authenticate] }, async (request, reply) => {
    const paramsSchema = z.object({ id: z.coerce.number().int().positive() });
    const p = paramsSchema.safeParse(request.params);
    if (!p.success) return reply.code(400).send({ error: 'Parâmetros inválidos' });

    const doc = await app.prisma.autoIntimacaoDocumento.findUnique({
      where: { id: p.data.id },
      include: {
        createdBy: true,
        updatedBy: true,
        Logs: { orderBy: { dataHora: 'desc' }, include: { usuario: true } },
      },
    });
    if (!doc) return reply.code(404).send({ error: 'Documento não encontrado' });
    return reply.send(doc);
  });

  app.get('/api/auto-intimacao/:id/pdf', { preValidation: [app.authenticate] }, async (request, reply) => {
    const paramsSchema = z.object({ id: z.coerce.number().int().positive() });
    const p = paramsSchema.safeParse(request.params);
    if (!p.success) return reply.code(400).send({ error: 'Parâmetros inválidos' });

    const doc = await app.prisma.autoIntimacaoDocumento.findUnique({ where: { id: p.data.id } });
    if (!doc) return reply.code(404).send({ error: 'Documento não encontrado' });

    const dados = (doc.dados ?? {}) as any;
    const ai = (dados.auto_intimacao ?? {}) as any;
    const dadosEstab = (dados.dados_estabelecimento ?? {}) as any;

    reply.header('Content-Type', 'application/pdf');
    reply.header('Content-Disposition', `inline; filename="${doc.numeroAuto}.pdf"`);

    const pdf = new PDFDocument({ size: 'A4', margin: 36 });
    pdf.fontSize(11);

    function formatDateBr(value: unknown) {
      const s = normalizeString(value);
      const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(s);
      if (m) return `${m[3]}/${m[2]}/${m[1]}`;
      return s;
    }

    pdf.fontSize(11).font('Helvetica-Bold').text('ESTADO DE SANTA CATARINA', { align: 'center' });
    pdf.text('PREFEITURA DE BALNEÁRIO CAMBORIÚ', { align: 'center' });
    pdf.text('SECRETARIA MUNICIPAL DE SAÚDE', { align: 'center' });
    pdf.text('DIVISÃO DE VIGILÂNCIA SANITÁRIA', { align: 'center' });
    const dadosVisa = (ai.dados_visa ?? {}) as any;
    const setor = normalizeString(dadosVisa.setor || ai.departamento_vigilancia).toUpperCase();
    if (setor) pdf.text(setor, { align: 'center' });
    pdf.moveDown(0.4);
    pdf.font('Helvetica').text(
      'Avenida Palestina, nº 150,\nesquina com Rua Suíça –\nBairro das Nações –\nBalneário Camboriú/SC',
      { align: 'center' },
    );
    pdf.moveDown(0.8);

    pdf.font('Helvetica-Bold').text('AUTO DE INTIMAÇÃO', { continued: true });
    pdf.text(`  ${doc.numeroAuto}`, { align: 'right' });
    pdf.moveDown(0.8);

    pdf.font('Helvetica-Bold').text('AUTUADO', { underline: true });
    pdf.moveDown(0.3);
    const autuado = (ai.autuado ?? {}) as any;
    pdf.font('Helvetica').text(`Nome da Pessoa Física/Jurídica: ${normalizeString(autuado.nome || dadosEstab.razao_social || dadosEstab.nome_razao_social)}`);
    pdf.text(`CNPJ/CPF: ${normalizeString(autuado.cnpj_cpf_formatado || autuado.cnpj_cpf || dadosEstab.cnpj)}`);
    pdf.text(`Denominação Comercial / Nome Fantasia: ${normalizeString(autuado.nome_fantasia || dadosEstab.nome_fantasia)}`);
    pdf.text(`Endereço Completo: ${normalizeString(autuado.endereco_completo || dadosEstab.endereco || dadosEstab.rua)}`);
    pdf.text(`Número: ${normalizeString(autuado.numero || dadosEstab.numero)}`);
    pdf.text(`Bairro: ${normalizeString(autuado.bairro || dadosEstab.bairro)}`);
    pdf.text(`Município: ${normalizeString(autuado.municipio || dadosEstab.cidade)}`);
    pdf.text(`UF: ${normalizeString(autuado.uf || dadosEstab.uf || dadosEstab.estado)}`);
    pdf.text(`Proprietário e/ou Responsável: ${normalizeString(autuado.proprietario_responsavel || dadosEstab.responsavel_legal || dadosEstab.responsavel)}`);
    pdf.text(`Tipo de Estabelecimento / Negócio / Atividade: ${normalizeString(autuado.tipo_atividade || dadosEstab.atividade_principal || dadosEstab.atividade)}`);
    pdf.text(`Pasta VISA: ${normalizeString(autuado.alvara_pasta_visa || dadosEstab.alvara_sanitario || dadosEstab.pasta_visa)}`);
    pdf.moveDown(0.8);

    pdf.font('Helvetica-Bold').text('Enquadramento Legal (Legislação sanitária infringida que autoriza a medida):', { underline: true });
    const bases = Array.isArray(ai.bases_legais) ? ai.bases_legais : [];
    if (bases.length) {
      pdf.font('Helvetica');
      for (const b of bases) {
        const grupo = normalizeString(b.grupo || b.grupo_descricao || b.grupo_id);
        const subgrupo = normalizeString(b.subgrupo || b.subgrupo_descricao || b.subgrupo_id);
        const base = normalizeString(b.base_legal || b.base);
        const artigo = normalizeString(b.artigo);
        const desc = normalizeString(b.descricao);
        const line = [grupo && subgrupo ? `${grupo} > ${subgrupo}` : grupo || subgrupo, base, artigo ? `Art. ${artigo}` : '', desc]
          .filter(Boolean)
          .join(' • ');
        if (line) pdf.text(line);
      }
    } else {
      const baseLegal = (ai.base_legal ?? {}) as any;
      const enquadramento = normalizeString(baseLegal.enquadramento_legal || baseLegal.base_legal);
      if (enquadramento) pdf.font('Helvetica').text(enquadramento);
    }
    pdf.moveDown(0.6);

    pdf.font('Helvetica-Bold').text('Descrição das Irregularidades:', { underline: true });
    pdf.font('Helvetica').text(normalizeString(ai.descricao_irregularidades), { align: 'justify' });
    pdf.moveDown(0.6);

    pdf.font('Helvetica-Bold').text('Descrição das Providências / Exigências / Outras Informações:', { underline: true });
    pdf.font('Helvetica').text(normalizeString(ai.descricao_providencias), { align: 'justify' });
    pdf.moveDown(0.6);

    pdf.font('Helvetica-Bold').text('Prazo(s) para Cumprimento das Exigências:', { underline: true });
    const prazosItens = Array.isArray((ai as any).prazos_exigencias) ? ((ai as any).prazos_exigencias as any[]) : [];
    if (prazosItens.length) {
      pdf.font('Helvetica');
      for (const p of prazosItens) {
        const ref = normalizeString(p?.referencia);
        const dias = p?.prazo_dias != null ? String(p.prazo_dias) : '';
        const venc = formatDateBr(p?.data_vencimento);
        const line = [ref ? `Itens ${ref}` : '', dias ? `${dias} dias` : '', venc ? `vencimento ${venc}` : ''].filter(Boolean).join(' — ');
        if (line) pdf.text(line);
      }
    } else {
      const prazoDias = ai.prazo_dias != null ? String(ai.prazo_dias) : '';
      const prazoTxt = normalizeString(ai.prazo_cumprimento_texto);
      const prazoData = normalizeString(ai.prazo_cumprimento_data);
      pdf.font('Helvetica').text(prazoDias ? `${prazoDias} dias` : prazoTxt || prazoData);
      const venc = formatDateBr(ai.data_vencimento);
      if (venc) pdf.text(`Data de vencimento do prazo: ${venc}`);
    }
    pdf.moveDown(0.6);

    pdf
      .font('Helvetica-Bold')
      .text('CIÊNCIA', { underline: true });
    pdf.moveDown(0.3);
    pdf.font('Helvetica').text(TEXTO_CIENCIA_INTIMACAO, { align: 'justify' });
    pdf.moveDown(0.8);

    pdf.font('Helvetica').text(`Data da lavratura do Auto de Intimação: ${formatDateBr(ai.data_lavratura)}`);
    pdf.text(`Telefone da VISA: ${normalizeString(dadosVisa.telefone || ai.telefone_visa)}`);
    pdf.text(`E-mail da VISA: ${normalizeString(dadosVisa.email || ai.email_visa)}`);
    pdf.moveDown(0.8);

    const receb = (ai.recebimento ?? {}) as any;
    pdf.font('Helvetica-Bold').text('RECEBIMENTO', { underline: true });
    pdf.moveDown(0.3);
    pdf.font('Helvetica').text(`Recebido em: ${formatDateBr(receb.data)}`);
    pdf.text(`Horário: ${normalizeString(receb.hora)}`);
    pdf.text(`Responsável: ${normalizeString(receb.responsavel)}`);
    pdf.moveDown(0.8);

    const recusa = (ai.recusa ?? {}) as any;
    if (recusa.responsavel_recusou_assinatura === true) {
      pdf.font('Helvetica-Bold').text('EM CASO DE RECUSA DO RESPONSÁVEL', { underline: true });
      pdf.moveDown(0.3);
      pdf.font('Helvetica').text(`1ª testemunha: ${normalizeString(recusa.testemunha_1)}`);
      pdf.text(`2ª testemunha: ${normalizeString(recusa.testemunha_2)}`);
      pdf.moveDown(0.8);
    }

    const autoridades = Array.isArray(ai.autoridades_saude) ? ai.autoridades_saude : [];
    if (autoridades.length) {
      pdf.font('Helvetica-Bold').text('AUTORIDADE DE SAÚDE', { underline: true });
      pdf.moveDown(0.3);
      pdf.font('Helvetica');
      for (const a of autoridades) {
        pdf.text(`Autoridade de Saúde: ${normalizeString(a.nome)}`);
        pdf.text(`Função: ${normalizeString(a.funcao)}`);
        pdf.moveDown(0.4);
      }
    }

    pdf.end();
    return reply.send(pdf);
  });
}
