import type { FastifyInstance } from 'fastify';

export function registerSinncSaudeSyncRoutes(app: FastifyInstance) {
  app.post('/api/sinnc-saude/view-vs-auto-termo/sync', { preValidation: [app.authenticate] }, async (_request, reply) => {
    return reply.code(410).send({
      error:
          'Rota descontinuada. A sincronização do Auto/Termo deve chamar POST http://127.0.0.1:8080/api/auto-termo/sincronizar (SINNC Saúde). Reinicie o Flutter Web e recarregue o navegador.',
    });
  });
}

