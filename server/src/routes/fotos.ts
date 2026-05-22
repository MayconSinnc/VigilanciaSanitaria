import type { FastifyInstance } from 'fastify';
import { z } from 'zod';

export function registerFotosRoutes(app: FastifyInstance) {
  app.get('/inspecoes/:id/fotos', { preValidation: [app.authenticate] }, async (request, reply) => {
    const { id } = request.params as { id: string };
    const list = await app.prisma.foto.findMany({ where: { inspecaoId: Number(id) } });
    return reply.send(list);
  });

  app.post('/inspecoes/:id/fotos', { preValidation: [app.authenticate] }, async (request, reply) => {
    const { id } = request.params as { id: string };
    const body = z.object({
      url: z.string(),
      data: z.string(),
      gpsLatitude: z.number().optional(),
      gpsLongitude: z.number().optional(),
      dispositivo: z.string().optional(),
      resolucao: z.string().optional()
    }).parse(request.body);
    const foto = await app.prisma.foto.create({
      data: {
        inspecaoId: Number(id),
        url: body.url,
        data: new Date(body.data),
        gpsLatitude: body.gpsLatitude,
        gpsLongitude: body.gpsLongitude,
        dispositivo: body.dispositivo,
        resolucao: body.resolucao
      }
    });
    return reply.code(201).send(foto);
  });

  app.delete('/fotos/:fotoId', { preValidation: [app.authenticate] }, async (request, reply) => {
    const { fotoId } = request.params as { fotoId: string };
    await app.prisma.foto.delete({ where: { id: Number(fotoId) } });
    return reply.code(204).send();
  });
}
