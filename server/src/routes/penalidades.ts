import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { importPenalidades } from '../services/epublica.js';

export function registerPenalidadesRoutes(app: FastifyInstance) {
  app.get('/penalidades', { preValidation: [app.authenticate] }, async (_req, reply) => {
    const list = await app.prisma.penalidade.findMany();
    return reply.send(list);
  });

  app.post('/penalidades', { preValidation: [app.authenticate] }, async (request, reply) => {
    const body = z.object({
      descricao: z.string(),
      codigoLegal: z.string(),
      valor: z.number().optional(),
      valorMinimo: z.number().optional(),
      valorMaximo: z.number().optional()
    }).parse(request.body);
    const p = await app.prisma.penalidade.create({ data: body });
    return reply.code(201).send(p);
  });

  app.post('/penalidades/importar', { preValidation: [app.authenticate] }, async (_request, reply) => {
    const itens = await importPenalidades();
    for (const item of itens) {
      await app.prisma.penalidade.upsert({
        where: { codigoLegal: item.codigoLegal },
        update: { descricao: item.descricao, valorMinimo: item.valorMinimo, valorMaximo: item.valorMaximo },
        create: { descricao: item.descricao, codigoLegal: item.codigoLegal, valorMinimo: item.valorMinimo, valorMaximo: item.valorMaximo }
      });
    }
    return reply.send({ importados: itens.length });
  });
}
