import type { FastifyInstance } from 'fastify';
import { z } from 'zod';

export function registerEstabelecimentosRoutes(app: FastifyInstance) {
  app.get('/estabelecimentos', { preValidation: [app.authenticate] }, async (request, reply) => {
    const querySchema = z.object({
      q: z.string().optional(),
      cnpj: z.string().optional(),
      inscricao: z.string().optional(),
      limit: z.string().optional(),
      offset: z.string().optional()
    });
    const parsed = querySchema.safeParse(request.query);
    if (!parsed.success) {
      return reply.code(400).send({ error: 'Parâmetros inválidos' });
    }
    const { q, cnpj, inscricao, limit, offset } = parsed.data;
    const take = limit ? Number(limit) : 20;
    const skip = offset ? Number(offset) : 0;
    const where: any = {};
    if (cnpj) {
      const digits = cnpj.replace(/\D/g, '');
      where.OR = [
        { cnpj: { equals: digits } },
        { cnpj: { equals: cnpj } }
      ];
    }
    if (inscricao) where.inscricaoMunicipal = inscricao;
    if (q) {
      const norm = q.replace(/\D/g, '');
      where.OR = [
        { nomeFantasia: { contains: q } },
        { razaoSocial: { contains: q } },
        { cnpj: { equals: norm } },
        { cnpj: { equals: q } },
        { cnpj: { contains: norm } },
        { cnpj: { contains: q } }
      ];
    }
    const list = await app.prisma.estabelecimento.findMany({ where, take, skip });
    return reply.send(list);
  });

  app.post('/estabelecimentos', { preValidation: [app.authenticate] }, async (request, reply) => {
    const bodySchema = z.object({
      cnpj: z.string(),
      razaoSocial: z.string(),
      nomeFantasia: z.string(),
      endereco: z.string(),
      cidade: z.string(),
      estado: z.string(),
      bairro: z.string().optional(),
      inscricaoMunicipal: z.string().optional(),
      latitude: z.number().optional(),
      longitude: z.number().optional(),
      telefone: z.string().optional(),
      responsavel: z.string().optional()
    });
    const parsed = bodySchema.safeParse(request.body);
    if (!parsed.success) return reply.code(400).send({ error: 'Dados inválidos' });
    const est = await app.prisma.estabelecimento.create({ data: parsed.data });
    return reply.code(201).send(est);
  });
}
