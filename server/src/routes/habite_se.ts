import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { addHabiteSe, loadHabiteSe, toListItem } from '../services/habite_se_store.js';

async function seedFromEstabelecimentos(app: FastifyInstance) {
  const existing = loadHabiteSe();
  if (existing.length > 0) return;

  const ests = await app.prisma.estabelecimento.findMany({
    orderBy: { nomeFantasia: 'asc' },
    take: 5,
  });

  for (const est of ests) {
    addHabiteSe({
      protocolo: `HBS-${new Date().getFullYear()}-${String(est.id).padStart(4, '0')}`,
      tipo: 'HABITESE_SANITARIO',
      status: 'EM_ANALISE',
      data_solicitacao: (est.dataCadastro ?? new Date()).toISOString().slice(0, 10),
      empreendimento: {
        nome: est.nomeFantasia || est.razaoSocial,
        cnpj: est.cnpj,
        inscricao_municipal: est.inscricaoMunicipal,
      },
      endereco: {
        logradouro: est.endereco,
        numero: est.numero,
        bairro: est.bairro,
        cidade: est.cidade,
        estado: est.uf ?? est.estado,
        cep: est.cep,
      },
      origem: 'Cadastro local',
    });
  }
}

export function registerHabiteSeRoutes(app: FastifyInstance) {
  app.get('/api/habite-se', { preValidation: [app.authenticate] }, async (request, reply) => {
    const parsed = z
      .object({
        protocolo: z.string().optional(),
        cnpj: z.string().optional(),
        search: z.string().optional(),
      })
      .safeParse(request.query);

    if (!parsed.success) {
      return reply.code(400).send({ error: 'Parâmetros inválidos' });
    }

    await seedFromEstabelecimentos(app);

    const { protocolo, cnpj, search } = parsed.data;
    let list = loadHabiteSe().map(toListItem);

    if (protocolo?.trim()) {
      const term = protocolo.trim().toLowerCase();
      list = list.filter((item) =>
        String(item.protocolo ?? '')
          .toLowerCase()
          .includes(term),
      );
    }

    if (cnpj?.trim()) {
      const digits = cnpj.replace(/\D/g, '');
      list = list.filter((item) =>
        String(item.cnpj ?? '')
          .replace(/\D/g, '')
          .includes(digits),
      );
    }

    if (search?.trim()) {
      const term = search.trim().toLowerCase();
      list = list.filter((item) => {
        const nome = String(
          item.requerente ?? item.empreendimento ?? item.nome_empreendimento ?? '',
        ).toLowerCase();
        return nome.includes(term);
      });
    }

    return reply.send(list);
  });

  app.post('/api/habite-se', { preValidation: [app.authenticate] }, async (request, reply) => {
    const body = (request.body ?? {}) as Record<string, unknown>;
    if (!body || typeof body !== 'object') {
      return reply.code(400).send({ error: 'Corpo da requisição inválido' });
    }

    const saved = addHabiteSe(body);
    return reply.code(201).send(toListItem(saved));
  });

  app.get('/api/habite-se/:protocolo', { preValidation: [app.authenticate] }, async (request, reply) => {
    const params = request.params as { protocolo?: string };
    const protocolo = decodeURIComponent(String(params.protocolo ?? '')).trim();
    if (!protocolo) return reply.code(400).send({ error: 'Protocolo inválido' });

    const found = loadHabiteSe().find(
      (r) => String(r.protocolo).toLowerCase() === protocolo.toLowerCase(),
    );
    if (!found) return reply.code(404).send({ error: 'Solicitação não encontrada' });
    return reply.send(toListItem(found));
  });
}
