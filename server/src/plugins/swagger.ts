import swagger from '@fastify/swagger';
import type { FastifyInstance } from 'fastify';

export async function registerSwagger(app: FastifyInstance) {
  await app.register(swagger, {
    openapi: {
      info: {
        title: 'Vigilância Sanitária API',
        description: 'API para inspeções sanitárias municipais',
        version: '0.1.0'
      },
      servers: [{ url: 'http://localhost:3000' }]
    }
  });
}
