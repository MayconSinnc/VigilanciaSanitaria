import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { buscarAlvarasPorCnpj } from '../services/epublica.js';

function normalizeTipo(value: unknown): string {
  const t = String(value ?? 'Alvará').trim();
  if (!t) return 'Alvará';
  const upper = t.toUpperCase();
  if (upper.includes('RAI')) return 'RAI';
  if (upper.includes('RIS')) return 'RIS';
  if (upper.includes('ALVAR')) return 'Alvará';
  return t;
}

function normalizeAlvara(raw: Record<string, unknown>, est?: {
  cnpj: string;
  nomeFantasia: string;
  razaoSocial: string;
  inscricaoMunicipal: string | null;
  statusAlvara: string | null;
}): Record<string, unknown> {
  const cnpj = String(raw.cnpj ?? est?.cnpj ?? '');
  const nome =
    raw.nomeFantasia ??
    raw.nome_fantasia ??
    raw.estabelecimento ??
    est?.nomeFantasia ??
    est?.razaoSocial ??
    '';

  return {
    tipo: normalizeTipo(raw.tipo ?? raw.tipoDocumento ?? raw.tipo_documento ?? 'Alvará'),
    estabelecimento: nome,
    nome_fantasia: nome,
    nomeFantasia: nome,
    cnpj,
    numero: String(
      raw.numero ??
        raw.numeroAlvara ??
        raw.numero_alvara ??
        raw.numeroDocumento ??
        est?.inscricaoMunicipal ??
        '',
    ),
    data_emissao: raw.dataEmissao ?? raw.data_emissao ?? raw.emissao ?? null,
    data_vencimento: raw.dataVencimento ?? raw.data_vencimento ?? raw.vencimento ?? null,
    status: String(
      raw.status ?? raw.situacao ?? raw.situacaoAlvara ?? est?.statusAlvara ?? 'Pendente',
    ),
    origem: String(raw.origem ?? 'E-Pública'),
  };
}

function alvaraFromEstabelecimento(est: {
  id: number;
  cnpj: string;
  nomeFantasia: string;
  razaoSocial: string;
  inscricaoMunicipal: string | null;
  statusAlvara: string | null;
  dataCadastro: Date | null;
}): Record<string, unknown> {
  return {
    tipo: 'Alvará',
    estabelecimento: est.nomeFantasia || est.razaoSocial,
    nome_fantasia: est.nomeFantasia,
    nomeFantasia: est.nomeFantasia,
    cnpj: est.cnpj,
    numero: est.inscricaoMunicipal || `ALV-${est.id}`,
    data_emissao: est.dataCadastro?.toISOString().slice(0, 10) ?? null,
    data_vencimento: null,
    status: est.statusAlvara || 'Pendente',
    origem: 'Cadastro local',
  };
}

export function registerAlvarasRoutes(app: FastifyInstance) {
  app.get('/api/alvaras', { preValidation: [app.authenticate] }, async (request, reply) => {
    const parsed = z
      .object({
        cnpj: z.string().optional(),
        search: z.string().optional(),
        tipo: z.string().optional(),
      })
      .safeParse(request.query);

    if (!parsed.success) {
      return reply.code(400).send({ error: 'Parâmetros inválidos' });
    }

    const { cnpj, search, tipo } = parsed.data;
    const digits = cnpj?.replace(/\D/g, '') ?? '';

    if (digits.length >= 11) {
      try {
        const est = await app.prisma.estabelecimento.findFirst({
          where: {
            OR: [{ cnpj: digits }, { cnpj: { contains: digits } }],
          },
        });

        const remote = await buscarAlvarasPorCnpj(digits);
        const list = Array.isArray(remote)
          ? remote
          : (remote?.data ?? remote?.items ?? remote?.results ?? []);

        if (Array.isArray(list) && list.length > 0) {
          const mapped = list.map((item: Record<string, unknown>) =>
            normalizeAlvara(item, est ?? undefined),
          );
          const filtered = tipo
            ? mapped.filter((m) => normalizeTipo(m.tipo) === normalizeTipo(tipo))
            : mapped;
          return reply.send(filtered);
        }

        if (est) {
          const doc = alvaraFromEstabelecimento(est);
          if (!tipo || normalizeTipo(doc.tipo) === normalizeTipo(tipo)) {
            return reply.send([doc]);
          }
          return reply.send([]);
        }

        return reply.send([]);
      } catch (err: any) {
        if (err?.code === 'EPUBLICA_NOT_CONFIGURED') {
          return reply.code(503).send({
            error: 'E-Pública não configurada no servidor.',
          });
        }
        app.log.error(err);
        return reply.code(502).send({ error: 'Erro ao consultar alvarás na E-Pública' });
      }
    }

    const where: Record<string, unknown> = {};
    if (search && search.trim()) {
      const term = search.trim();
      const norm = term.replace(/\D/g, '');
      where.OR = [
        { nomeFantasia: { contains: term, mode: 'insensitive' } },
        { razaoSocial: { contains: term, mode: 'insensitive' } },
        ...(norm ? [{ cnpj: { contains: norm } }] : []),
      ];
    }

    const estabelecimentos = await app.prisma.estabelecimento.findMany({
      where,
      orderBy: { nomeFantasia: 'asc' },
      take: 200,
    });

    let result = estabelecimentos.map(alvaraFromEstabelecimento);
    if (tipo) {
      const wanted = normalizeTipo(tipo);
      result = result.filter((r) => normalizeTipo(r.tipo) === wanted);
    }

    return reply.send(result);
  });
}
