import 'fastify';
import { PrismaClient } from '@prisma/client';

declare module 'fastify' {
  interface FastifyInstance {
    authenticate: (request: any, reply: any) => Promise<void>;
    prisma: PrismaClient;
  }
}
