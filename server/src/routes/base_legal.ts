import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import {
  buscarEntries,
  buscarEntriesPorIds,
  buscarEntryPorId,
  listarEntriesPorSubgrupo,
  listarGrupos,
  listarSubgrupos,
} from '../services/sinnc_base_legal.js';

export function registerBaseLegalRoutes(app: FastifyInstance) {
  const prisma = app.prisma as any;

  function normalizeText(input: string): string {
    return (input ?? '')
      .toLowerCase()
      .normalize('NFD')
      .replace(/[\u0300-\u036f]/g, '')
      .replace(/[^\p{L}\p{N}\s]+/gu, ' ')
      .replace(/\s+/g, ' ')
      .trim();
  }

  function jsonToText(v: any): string {
    if (v == null) return '';
    if (typeof v === 'string') return v;
    if (Array.isArray(v)) return v.map((e) => String(e ?? '')).join(' ');
    if (typeof v === 'object') return Object.values(v).map((e) => String(e ?? '')).join(' ');
    return String(v);
  }

  function configScore(query: string, cfg: any): number {
    const q = normalizeText(query);
    if (!q) return 0;
    const tokens = q.split(' ').filter((t) => t.length >= 2);
    const hay = normalizeText(
      [
        cfg?.descricaoItem,
        cfg?.descricaoIrregularidade,
        cfg?.descricaoProvidencia,
        jsonToText(cfg?.palavrasChave),
        jsonToText(cfg?.sinonimos),
      ].join(' '),
    );
    if (!hay) return 0;
    let score = 0;
    if (hay.includes(q)) score += 120;
    for (const t of tokens) {
      if (hay.includes(t)) score += 25;
    }
    return score;
  }

  async function carregarConfigs(ids: string[]) {
    const unique = Array.from(new Set(ids.map((e) => String(e).trim()).filter((e) => e.length > 0)));
    if (unique.length === 0) return new Map<string, any>();
    const cfgs = await prisma.baseLegalItemConfig.findMany({
      where: { baseLegalId: { in: unique } },
    });
    return new Map(cfgs.map((c: any) => [c.baseLegalId, c]));
  }

  function mergeConfig(entry: any, cfg: any) {
    return {
      ...entry,
      descricao_item: cfg?.descricaoItem ?? null,
      palavras_chave: cfg?.palavrasChave ?? null,
      sinonimos: cfg?.sinonimos ?? null,
      prazo_padrao_dias: cfg?.prazoPadraoDias ?? null,
      aplica_auto_intimacao: cfg?.aplicaAutoIntimacao ?? null,
      descricao_irregularidade: cfg?.descricaoIrregularidade ?? null,
      descricao_providencia: cfg?.descricaoProvidencia ?? null,
    };
  }

  app.get('/api/base-legal/grupos', { preValidation: [app.authenticate] }, async (_request, reply) => {
    try {
      const grupos = await listarGrupos();
      return reply.send(grupos);
    } catch (e: any) {
      const msg = e?.message ?? 'Falha ao consultar base legal.';
      const code = msg.toLowerCase().includes('não configurado') ? 503 : 500;
      return reply.code(code).send({ error: msg });
    }
  });

  app.get('/api/base-legal/subgrupos', { preValidation: [app.authenticate] }, async (request, reply) => {
    const qSchema = z.object({ grupoId: z.string().min(1) });
    const parsed = qSchema.safeParse(request.query);
    if (!parsed.success) return reply.code(400).send({ error: 'Parâmetros inválidos' });
    try {
      const subgrupos = await listarSubgrupos(parsed.data.grupoId);
      return reply.send(subgrupos);
    } catch (e: any) {
      const msg = e?.message ?? 'Falha ao consultar base legal.';
      const code = msg.toLowerCase().includes('não configurado') ? 503 : 500;
      return reply.code(code).send({ error: msg });
    }
  });

  app.get('/api/base-legal/entries', { preValidation: [app.authenticate] }, async (request, reply) => {
    const qSchema = z.object({
      subgrupoId: z.string().min(1),
      search: z.string().optional(),
      limit: z.coerce.number().optional(),
    });
    const parsed = qSchema.safeParse(request.query);
    if (!parsed.success) return reply.code(400).send({ error: 'Parâmetros inválidos' });
    try {
      const items = await listarEntriesPorSubgrupo({
        subgrupoId: parsed.data.subgrupoId,
        search: parsed.data.search,
        limit: parsed.data.limit,
      });
      const cfgMap = await carregarConfigs(items.map((e) => e.id));
      return reply.send(items.map((e) => mergeConfig(e, cfgMap.get(e.id))));
    } catch (e: any) {
      const msg = e?.message ?? 'Falha ao consultar base legal.';
      const code = msg.toLowerCase().includes('não configurado') ? 503 : 500;
      return reply.code(code).send({ error: msg });
    }
  });

  app.get('/api/base-legal/search', { preValidation: [app.authenticate] }, async (request, reply) => {
    const qSchema = z.object({
      query: z.string().min(3),
      grupoId: z.string().optional(),
      subgrupoId: z.string().optional(),
      limit: z.coerce.number().optional(),
    });
    const parsed = qSchema.safeParse(request.query);
    if (!parsed.success) return reply.code(400).send({ error: 'Parâmetros inválidos' });
    try {
      const items = await buscarEntries({
        query: parsed.data.query,
        grupoId: parsed.data.grupoId,
        subgrupoId: parsed.data.subgrupoId,
        limit: parsed.data.limit,
      });
      const initialCfgMap = await carregarConfigs(items.map((e) => e.id));
      const enriched = items.map((e) => {
        const cfg = initialCfgMap.get(e.id);
        const baseScore = typeof e.score === 'number' ? e.score : 0;
        return { ...mergeConfig(e, cfg), score: baseScore + configScore(parsed.data.query, cfg) };
      });

      const cfgCandidates = await prisma.baseLegalItemConfig.findMany({ take: 500 });
      const cfgMatches = cfgCandidates
        .map((c: any) => ({ c, score: configScore(parsed.data.query, c) }))
        .filter((x: any) => x.score > 0)
        .sort((a: any, b: any) => b.score - a.score)
        .slice(0, 50)
        .map((x: any) => x.c);

      const existingIds = new Set(enriched.map((e) => String(e.id)));
      const extraIds = cfgMatches.map((c: any) => c.baseLegalId).filter((id: string) => !existingIds.has(String(id)));
      if (extraIds.length > 0) {
        const extraEntries = await buscarEntriesPorIds(extraIds);
        const extraCfgMap = await carregarConfigs(extraEntries.map((e) => e.id));
        for (const e of extraEntries) {
          const cfg = extraCfgMap.get(e.id);
          const score = configScore(parsed.data.query, cfg);
          enriched.push({ ...mergeConfig(e, cfg), score });
        }
      }

      const limit = Math.max(10, Math.min(parsed.data.limit ?? 120, 300));
      const out = enriched
        .filter((e) => (typeof e.score === 'number' ? e.score : 0) > 0)
        .sort((a, b) => (b.score ?? 0) - (a.score ?? 0))
        .slice(0, limit);
      return reply.send(out);
    } catch (e: any) {
      const msg = e?.message ?? 'Falha ao consultar base legal.';
      const code = msg.toLowerCase().includes('não configurado') ? 503 : 500;
      return reply.code(code).send({ error: msg });
    }
  });

  app.get('/api/base-legal/:id', { preValidation: [app.authenticate] }, async (request, reply) => {
    const pSchema = z.object({ id: z.string().min(1) });
    const parsed = pSchema.safeParse(request.params);
    if (!parsed.success) return reply.code(400).send({ error: 'Parâmetros inválidos' });
    try {
      const item = await buscarEntryPorId(parsed.data.id);
      if (!item) return reply.code(404).send({ error: 'Base legal não encontrada.' });
      const cfgMap = await carregarConfigs([item.id]);
      return reply.send(mergeConfig(item, cfgMap.get(item.id)));
    } catch (e: any) {
      const msg = e?.message ?? 'Falha ao consultar base legal.';
      const code = msg.toLowerCase().includes('não configurado') ? 503 : 500;
      return reply.code(code).send({ error: msg });
    }
  });

  app.get('/api/base-legal/item-config/:baseLegalId', { preValidation: [app.authenticate] }, async (request, reply) => {
    const pSchema = z.object({ baseLegalId: z.string().min(1) });
    const parsed = pSchema.safeParse(request.params);
    if (!parsed.success) return reply.code(400).send({ error: 'Parâmetros inválidos' });
    const cfg = await prisma.baseLegalItemConfig.findUnique({ where: { baseLegalId: parsed.data.baseLegalId } });
    if (!cfg) return reply.code(404).send({ error: 'Configuração não encontrada.' });
    return reply.send({
      base_legal_id: cfg.baseLegalId,
      descricao_item: cfg.descricaoItem,
      palavras_chave: cfg.palavrasChave,
      sinonimos: cfg.sinonimos,
      prazo_padrao_dias: cfg.prazoPadraoDias,
      aplica_auto_intimacao: cfg.aplicaAutoIntimacao,
      descricao_irregularidade: cfg.descricaoIrregularidade,
      descricao_providencia: cfg.descricaoProvidencia,
    });
  });

  app.put('/api/base-legal/item-config/:baseLegalId', { preValidation: [app.authenticate] }, async (request, reply) => {
    const pSchema = z.object({ baseLegalId: z.string().min(1) });
    const bSchema = z.object({
      descricao_item: z.string().optional().nullable(),
      palavras_chave: z.array(z.string()).optional().nullable(),
      sinonimos: z.array(z.string()).optional().nullable(),
      prazo_padrao_dias: z.number().int().positive().optional().nullable(),
      aplica_auto_intimacao: z.boolean().optional(),
      descricao_irregularidade: z.string().optional().nullable(),
      descricao_providencia: z.string().optional().nullable(),
    });
    const parsedParams = pSchema.safeParse(request.params);
    const parsedBody = bSchema.safeParse(request.body);
    if (!parsedParams.success || !parsedBody.success) return reply.code(400).send({ error: 'Parâmetros inválidos' });

    const data: any = {};
    if ('descricao_item' in parsedBody.data) data.descricaoItem = parsedBody.data.descricao_item;
    if ('palavras_chave' in parsedBody.data) data.palavrasChave = parsedBody.data.palavras_chave;
    if ('sinonimos' in parsedBody.data) data.sinonimos = parsedBody.data.sinonimos;
    if ('prazo_padrao_dias' in parsedBody.data) data.prazoPadraoDias = parsedBody.data.prazo_padrao_dias;
    if ('aplica_auto_intimacao' in parsedBody.data) data.aplicaAutoIntimacao = parsedBody.data.aplica_auto_intimacao;
    if ('descricao_irregularidade' in parsedBody.data) data.descricaoIrregularidade = parsedBody.data.descricao_irregularidade;
    if ('descricao_providencia' in parsedBody.data) data.descricaoProvidencia = parsedBody.data.descricao_providencia;

    const cfg = await prisma.baseLegalItemConfig.upsert({
      where: { baseLegalId: parsedParams.data.baseLegalId },
      create: { baseLegalId: parsedParams.data.baseLegalId, ...data },
      update: data,
    });
    return reply.send({
      base_legal_id: cfg.baseLegalId,
      descricao_item: cfg.descricaoItem,
      palavras_chave: cfg.palavrasChave,
      sinonimos: cfg.sinonimos,
      prazo_padrao_dias: cfg.prazoPadraoDias,
      aplica_auto_intimacao: cfg.aplicaAutoIntimacao,
      descricao_irregularidade: cfg.descricaoIrregularidade,
      descricao_providencia: cfg.descricaoProvidencia,
    });
  });
}
