import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { importAutos } from '../services/epublica.js';

export function registerEpublicaRoutes(app: FastifyInstance) {
  app.get('/epublica/autos', { preValidation: [app.authenticate] }, async (request, reply) => {
    const query = z.object({
      page: z.string().optional(),
      pageSize: z.string().optional()
    }).parse(request.query);
    const page = query.page ? Number(query.page) : 1;
    const pageSize = query.pageSize ? Number(query.pageSize) : 20;
    const autos = await importAutos(page, pageSize);
    return reply.send({ page, pageSize, total: autos.length, data: autos });
  });
}
