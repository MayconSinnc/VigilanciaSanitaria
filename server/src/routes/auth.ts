import type { FastifyInstance } from 'fastify';
import { z } from 'zod';

export function registerAuthRoutes(app: FastifyInstance) {
  app.post('/auth/login', async (request, reply) => {
    const bodySchema = z.object({
      cpf: z.string(),
      senha: z.string()
    });
    const parsed = bodySchema.safeParse(request.body);
    if (!parsed.success) {
      return reply.code(400).send({ error: 'Dados inválidos' });
    }
    const { cpf, senha } = parsed.data;
    const user = await app.prisma.usuario.findUnique({ where: { cpf } });
    if (!user) {
      return reply.code(401).send({ error: 'CPF ou senha inválidos' });
    }
    // Placeholder password check (replace with hashing e.g., bcrypt)
    if (user.senhaHash !== senha) {
      return reply.code(401).send({ error: 'CPF ou senha inválidos' });
    }
    const token = await reply.jwtSign({ userId: user.id, cpf: user.cpf });
    await app.prisma.auditoria.create({
      data: {
        usuarioId: user.id,
        acao: 'login',
        hora: new Date().toLocaleTimeString(),
        ip: request.ip
      }
    });
    return reply.send({ token, user });
  });
}
