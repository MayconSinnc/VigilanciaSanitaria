import 'dotenv/config';
import Fastify from 'fastify';
import cors from '@fastify/cors';
import jwt from '@fastify/jwt';
import { routes } from './routes/index.js';
import { prisma } from './plugins/prisma.js';
import { registerSwagger } from './plugins/swagger.js';

const server = Fastify({
  logger: true,
  bodyLimit: 25 * 1024 * 1024
});

server.register(cors, {
  origin: true,
  allowedHeaders: ['Authorization', 'Content-Type', 'x-sinnc-token']
});

server.register(jwt, {
  secret: process.env.JWT_SECRET || 'dev-secret'
});

server.decorate('authenticate', async (request: any, reply: any) => {
  try {
    await request.jwtVerify();
  } catch (err) {
    reply.code(401).send({ error: 'Unauthorized' });
  }
});

server.decorate('prisma', prisma);

registerSwagger(server);

routes(server);

const start = async () => {
  try {
    await server.listen({ port: Number(process.env.PORT) || 3000, host: '0.0.0.0' });
    server.log.info('Server running');
  } catch (err) {
    server.log.error(err);
    process.exit(1);
  }
};

start();
