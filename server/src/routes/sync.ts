import type { FastifyInstance } from 'fastify';
import { z } from 'zod';

export function registerSyncRoutes(app: FastifyInstance) {
  app.get('/sincronizacao', { preValidation: [app.authenticate] }, async (_req, reply) => {
    const list = await app.prisma.inspecao.findMany({
      select: { id: true, tipoAuto: true, data: true, status: true }
    });
    return reply.send(list);
  });

  app.post('/sincronizacao/:id', { preValidation: [app.authenticate] }, async (request, reply) => {
    const { id } = request.params as { id: string };
    const body = z.object({ status: z.enum(['Pendente', 'Enviado', 'Erro', 'Sincronizado']) }).parse(request.body);
    const updated = await app.prisma.inspecao.update({ where: { id: Number(id) }, data: { status: body.status } });
    return reply.send(updated);
  });
}
