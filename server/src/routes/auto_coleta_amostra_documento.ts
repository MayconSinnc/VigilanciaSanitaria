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

const cienciaTexto =
  'ESTOU CIENTE DE QUE A COLETA AQUI REGISTRADA FOI REALIZADA CONFORME OS PROCEDIMENTOS LEGAIS E REGULAMENTARES (ART. 67 DA LEI ESTADUAL Nº 6.320/83 E ART. 40 DO DECRETO ESTADUAL Nº 23.663/84), BEM COMO ATESTO QUE TODOS OS DADOS LANÇADOS NO PRESENTE SÃO VERDADEIROS. ADEMAIS, TAMBÉM ESTOU CIENTE DE QUE O EXTRAVIO, VIOLAÇÃO E/OU ALTERAÇÃO DAS AMOSTRAS EM MEU PODER ELIMINARÁ A POSSIBILIDADE DE REALIZAÇÃO DE PERÍCIA DE CONTRAPROVA, SUJEITANDO O DETENTOR (FIEL DEPOSITÁRIO) ÀS PENALIDADES PREVISTAS NA LEGISLAÇÃO SANITÁRIA.';

const laboratorioTexto =
  'LABORATÓRIO CENTRAL DE SAÚDE PÚBLICA (LACEN/SC)\nRua Felipe Schmidt, nº 788 – Centro – Florianópolis/SC\nFone: (48) 3664-7800\nE-Mail: lacen@saude.sc.gov.br';

export function registerAutoColetaAmostraDocumentoRoutes(app: FastifyInstance) {
  app.get('/api/auto-coleta', { preValidation: [app.authenticate] }, async (request, reply) => {
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

    const docs = await app.prisma.autoColetaAmostraDocumento.findMany({
      orderBy: { createdAt: 'desc' },
    });

    const items = docs
      .map((d: any) => {
        const dados = (d.dados ?? {}) as any;
        const dadosEstab = (dados.dados_estabelecimento ?? {}) as any;
        const col = (dados.auto_coleta_amostra ?? {}) as any;
        const dataHora = normalizeString(dados.data_hora);
        return {
          id: d.id,
          tipo_auto: 'AUTO_COLETA_AMOSTRA',
          tipo_documento: 'AUTO_COLETA_AMOSTRA',
          numero_ano: d.numeroAuto,
          numero_auto: d.numeroAuto,
          estabelecimento: normalizeString(dadosEstab.nome_fantasia),
          estabelecimento_nome: normalizeString(dadosEstab.nome_fantasia),
          estabelecimento_cnpj: normalizeString(dadosEstab.cnpj),
          cnpj: normalizeString(dadosEstab.cnpj),
          data_hora: dataHora,
          status: String(d.status ?? ''),
          payload: dados,
          pdf_url: `/api/auto-coleta/${d.id}/pdf?via=2`,
          via: 2,
          tipo_amostra: normalizeString(col.tipo_amostra),
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

  app.get('/api/auto-coleta/next-numero', { preValidation: [app.authenticate] }, async (request, reply) => {
    const qSchema = z.object({ ano: z.coerce.number().min(2000).max(2100) });
    const parsed = qSchema.safeParse(request.query);
    if (!parsed.success) return reply.code(400).send({ error: 'Parâmetros inválidos' });

    const ano = parsed.data.ano;
    const rec = await app.prisma.autoColetaAmostraSequence.upsert({
      where: { ano },
      create: { ano, lastSeq: 1 },
      update: { lastSeq: { increment: 1 } },
    });
    const numero = `COL-${ano}-${pad6(rec.lastSeq)}`;
    return reply.send({ numero });
  });

  app.post('/api/auto-coleta', { preValidation: [app.authenticate] }, async (request: any, reply) => {
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

    const col = (parsed.data.dados?.auto_coleta_amostra ?? {}) as Record<string, unknown>;
    const est = (parsed.data.dados?.dados_estabelecimento ?? {}) as Record<string, unknown>;

    if (status === 'SEM_EFEITO' && !normalizeString(col['sem_efeito_motivo'])) {
      return reply.code(400).send({ error: 'Justificativa é obrigatória para Sem Efeito.' });
    }

    const created = await app.prisma.$transaction(async (tx: any) => {
      const seqRec = await tx.autoColetaAmostraSequence.upsert({
        where: { ano },
        create: { ano, lastSeq: 1 },
        update: { lastSeq: { increment: 1 } },
      });
      const numeroAuto = `COL-${ano}-${pad6(seqRec.lastSeq)}`;

      const doc = await tx.autoColetaAmostraDocumento.create({
        data: {
          ano,
          sequencia: seqRec.lastSeq,
          numeroAuto,
          status,
          dados: parsed.data.dados,
          estabelecimentoNome: normalizeString(est['nome_fantasia']),
          estabelecimentoCnpj: normalizeString(est['cnpj']),
          dataLavratura: normalizeString(col['data_lavratura']),
          semEfeitoMotivo: normalizeString(col['sem_efeito_motivo']) || null,
          semEfeitoUsuarioId: status === 'SEM_EFEITO' ? userId : null,
          semEfeitoDataHora: status === 'SEM_EFEITO' ? new Date() : null,
          createdByUsuarioId: userId,
          updatedByUsuarioId: userId,
        },
      });

      await tx.autoColetaAmostraLog.create({
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
        await tx.autoColetaAmostraLog.create({
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
        await tx.autoColetaAmostraLog.create({
          data: {
            autoId: doc.id,
            usuarioId: userId,
            campo: 'sem_efeito_motivo',
            valorAnterior: null,
            valorNovo: normalizeString(col['sem_efeito_motivo']),
            acao: 'SEM_EFEITO',
            dispositivo,
          },
        });
      }

      return doc;
    });

    const usuario = userId ? await app.prisma.usuario.findUnique({ where: { id: userId } }) : null
    await syncAutoTermoToSaude({
      chave_origem: `vs:auto_coleta_amostra:${created.id}`,
      tipo_documento: 'AUTO_DE_COLETA_DE_AMOSTRA',
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

  app.put('/api/auto-coleta/:id', { preValidation: [app.authenticate] }, async (request: any, reply) => {
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

    const existing = await app.prisma.autoColetaAmostraDocumento.findUnique({ where: { id } });
    if (!existing) return reply.code(404).send({ error: 'Auto de Coleta não encontrado.' });
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

    const col = (parsedBody.data.dados?.auto_coleta_amostra ?? {}) as Record<string, unknown>;

    const updated = await app.prisma.$transaction(async (tx: any) => {
      const doc = await tx.autoColetaAmostraDocumento.update({
        where: { id },
        data: {
          status: (parsedBody.data.status ?? 'EM_EDICAO') as any,
          dados: parsedBody.data.dados,
          dataLavratura: normalizeString(col['data_lavratura']) || null,
          updatedByUsuarioId: userId,
        },
      });

      for (const c of changes.slice(0, 500)) {
        await tx.autoColetaAmostraLog.create({
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
        await tx.autoColetaAmostraLog.create({
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
      chave_origem: `vs:auto_coleta_amostra:${updated.id}`,
      tipo_documento: 'AUTO_DE_COLETA_DE_AMOSTRA',
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

  app.get('/api/auto-coleta/:id/logs', { preValidation: [app.authenticate] }, async (request, reply) => {
    const paramsSchema = z.object({ id: z.coerce.number().int().positive() });
    const p = paramsSchema.safeParse(request.params);
    if (!p.success) return reply.code(400).send({ error: 'Parâmetros inválidos' });

    const logs = await app.prisma.autoColetaAmostraLog.findMany({
      where: { autoId: p.data.id },
      orderBy: { dataHora: 'desc' },
      include: { usuario: { select: { id: true, nome: true, cpf: true } } },
    });
    return reply.send(logs);
  });

  app.get('/api/auto-coleta/:id/pdf', { preValidation: [app.authenticate] }, async (request: any, reply) => {
    const paramsSchema = z.object({ id: z.coerce.number().int().positive() });
    const querySchema = z.object({ via: z.coerce.number().int().min(1).max(2).optional() });
    const p = paramsSchema.safeParse(request.params);
    const q = querySchema.safeParse(request.query);
    if (!p.success || !q.success) return reply.code(400).send({ error: 'Parâmetros inválidos' });

    const via = q.data.via ?? 2;
    const doc = await app.prisma.autoColetaAmostraDocumento.findUnique({ where: { id: p.data.id } });
    if (!doc) return reply.code(404).send({ error: 'Documento não encontrado.' });

    const dados = (doc.dados ?? {}) as any;
    const col = (dados.auto_coleta_amostra ?? {}) as any;
    const det = (col.detentor ?? {}) as any;
    const prodListRaw = Array.isArray(col.produtos) ? col.produtos : [];
    const produtos = prodListRaw.length > 0 ? prodListRaw : [col.produto ?? {}];
    const receb = (col.recebimento ?? {}) as any;
    const recusa = (col.recusa ?? {}) as any;
    const autoridade = (col.autoridade_saude ?? {}) as any;

    const assinaturaReceb = decodeB64(receb.assinatura_base64);
    const assinaturaT1 = decodeB64(recusa.assinatura_testemunha_1_base64);
    const assinaturaT2 = decodeB64(recusa.assinatura_testemunha_2_base64);
    const assinaturaAutoridade = decodeB64(autoridade.assinatura_base64);

    const pdf = new PDFDocument({ size: 'A4', margin: 40 });
    reply.header('Content-Type', 'application/pdf');
    reply.header('Content-Disposition', `inline; filename="${doc.numeroAuto}-VIA-${via}.pdf"`);
    reply.send(pdf);

    const line = (label: string, value: string) => {
      pdf.font('Helvetica-Bold').fontSize(9).text(label, { continued: true });
      pdf.font('Helvetica').fontSize(9).text(` ${value || ''}`);
    };

    const assinaturaBox = (label: string, img: Buffer | null) => {
      pdf.font('Helvetica-Bold').fontSize(9).text(label);
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
    pdf.text('SECRETARIA MUNICIPAL DE SAÚDE', { align: 'center' });
    pdf.text('DIVISÃO DE VIGILÂNCIA SANITÁRIA', { align: 'center' });
    pdf.moveDown(0.2);
    pdf.font('Helvetica').fontSize(9).text(
      'Avenida Palestina, nº 150,\nesquina com Rua Suíça –\nBairro das Nações –\nBalneário Camboriú/SC',
      { align: 'center' },
    );
    pdf.moveDown(0.6);
    pdf.font('Helvetica-Bold').fontSize(12).text(
      `AUTO DE COLETA DE AMOSTRA PARA ANÁLISE — ${via}ª VIA`,
      { align: 'left' },
    );
    pdf.font('Helvetica-Bold').fontSize(11).text(doc.numeroAuto, { align: 'right' });
    pdf.moveDown(0.6);

    line('Tipo de Amostra:', normalizeString(col.tipo_amostra));
    line('Data da lavratura:', normalizeString(col.data_lavratura));
    line('Nome do setor da Vigilância Sanitária:', normalizeString(col.setor_vigilancia));
    line('Telefone da VISA:', normalizeString(col.telefone_visa));
    line('E-mail da VISA:', normalizeString(col.email_visa));
    pdf.moveDown(0.4);

    pdf.font('Helvetica-Bold').fontSize(10).text('LABORATÓRIO DE DESTINO');
    pdf.moveDown(0.2);
    pdf.font('Helvetica').fontSize(9).text(laboratorioTexto);
    pdf.moveDown(0.4);

    pdf.font('Helvetica-Bold').fontSize(10).text('DETENTOR');
    pdf.moveDown(0.2);
    line('Nome da Pessoa Física/Jurídica:', normalizeString(det.nome));
    line('CNPJ/CPF:', normalizeString(det.cnpj_cpf_formatado || det.cnpj_cpf));
    line('Denominação Comercial / Nome Fantasia:', normalizeString(det.nome_fantasia));
    line('Endereço Completo:', normalizeString(det.endereco_completo));
    line('Número:', normalizeString(det.numero));
    line('Bairro:', normalizeString(det.bairro));
    line('CEP:', normalizeString(det.cep));
    line('Proprietário / Responsável:', normalizeString(det.proprietario_responsavel));
    line('Município:', normalizeString(det.municipio));
    line('UF:', normalizeString(det.uf));
    line('Tipo de Estabelecimento / Negócio / Atividade:', normalizeString(det.tipo_atividade));
    line('Número Alvará Sanitário:', normalizeString(det.alvara_sanitario));
    pdf.moveDown(0.4);

    pdf.font('Helvetica-Bold').fontSize(10).text('PRODUTO COLETADO');
    pdf.moveDown(0.2);
    for (let i = 0; i < produtos.length; i++) {
      const prod = (produtos[i] ?? {}) as any;
      if (produtos.length > 1) {
        pdf.font('Helvetica-Bold').fontSize(9).text(`Item ${i + 1}/${produtos.length}`);
        pdf.moveDown(0.1);
      }
      line('Nome do Produto:', normalizeString(prod.nome_produto));
      line('Marca:', normalizeString(prod.marca));
      line('Quantidade:', normalizeString(prod.quantidade));
      line('Peso / Volume:', normalizeString(prod.peso_volume));
      line('Lote / Partida:', normalizeString(prod.lote));
      line('Número de Registro do Produto:', normalizeString(prod.registro_produto));
      line('Data de Fabricação:', normalizeString(prod.data_fabricacao));
      line('Data de Validade:', normalizeString(prod.data_validade));
      line('Indústria Produtora / Produtor / Importador:', normalizeString(prod.produtor_nome));
      line('CNPJ/CPF do Produtor:', normalizeString(prod.produtor_cnpj_cpf));
      line('Endereço Completo:', normalizeString(prod.produtor_endereco_completo || prod.produtor_endereco_cep));
      line('CEP:', normalizeString(prod.produtor_cep));
      line('Município:', normalizeString(prod.produtor_municipio || prod.produtor_municipio_estado));
      line('UF:', normalizeString(prod.produtor_uf));
      line('Informações adicionais:', normalizeString(prod.informacoes_adicionais));
      line('Motivo da Coleta:', normalizeString(prod.motivo_coleta));
      line('Temperatura / Conservação:', normalizeString(prod.temperatura_conservacao));
      line('Número dos Lacres (Detentor/Fiel Depositário):', normalizeString(prod.lacres_detentor));
      line('Número dos Lacres (Laboratório):', normalizeString(prod.lacres_laboratorio));
      if (i < produtos.length - 1) pdf.moveDown(0.3);
    }
    pdf.moveDown(0.5);

    const boxW = pdf.page.width - pdf.page.margins.left - pdf.page.margins.right;
    const boxX = pdf.x;
    const boxY = pdf.y;
    const boxH = 110;
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

    if (via === 2) {
      const comentario = normalizeString(col.comentario_fiscalizacao);
      if (comentario) {
        pdf.font('Helvetica-Bold').fontSize(10).text('Comentário sobre a Fiscalização');
        pdf.moveDown(0.2);
        pdf.font('Helvetica').fontSize(9).text(comentario);
        pdf.moveDown(0.5);
      }
    }

    pdf.font('Helvetica-Bold').fontSize(10).text('RECEBIMENTO');
    pdf.moveDown(0.2);
    line('Recebi a 1ª via deste em:', normalizeString(receb.data));
    line('Horário:', normalizeString(receb.hora));
    line('Responsável:', normalizeString(receb.responsavel));
    pdf.moveDown(0.2);
    assinaturaBox('Assinatura digital:', assinaturaReceb);
    pdf.moveDown(0.2);

    pdf.font('Helvetica-Bold').fontSize(9).text('Responsável recusou assinatura:', { continued: true });
    pdf.font('Helvetica').fontSize(9).text(` ${recusa.responsavel_recusou_assinatura ? 'Sim' : 'Não'}`);
    if (recusa.responsavel_recusou_assinatura) {
      pdf.moveDown(0.2);
      line('1ª testemunha:', normalizeString(recusa.testemunha_1));
      assinaturaBox('Assinatura (1ª testemunha):', assinaturaT1);
      line('2ª testemunha:', normalizeString(recusa.testemunha_2));
      assinaturaBox('Assinatura (2ª testemunha):', assinaturaT2);
    }

    pdf.font('Helvetica-Bold').fontSize(10).text('AUTORIDADE DE SAÚDE');
    pdf.moveDown(0.2);
    line('Nome:', normalizeString(autoridade.nome));
    line('Função:', normalizeString(autoridade.funcao));
    pdf.moveDown(0.2);
    assinaturaBox('Assinatura digital:', assinaturaAutoridade);

    pdf.end();
    return reply;
  });
}

