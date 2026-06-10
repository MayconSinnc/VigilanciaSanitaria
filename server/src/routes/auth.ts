import type { FastifyInstance } from 'fastify';
import { z } from 'zod';

//#region debug-point login-500-error-reporter
import fs from 'node:fs/promises';
import path from 'node:path';

let __dbgUrl: string | null = null;
let __dbgSession: string | null = null;

async function __dbg(event: Record<string, unknown>) {
  try {
    if (__dbgUrl == null) {
      const envPath = path.resolve(process.cwd(), '..', '.dbg', 'login-500-error.env');
      const raw = await fs.readFile(envPath, 'utf8');
      const url = raw
          .split('\n')
          .map((l) => l.trim())
          .filter((l) => l && !l.startsWith('#'))
          .find((l) => l.startsWith('DEBUG_SERVER_URL='))
          ?.split('=')
          .slice(1)
          .join('=')
          .trim() ??
        '';
      const sid = raw
          .split('\n')
          .map((l) => l.trim())
          .filter((l) => l && !l.startsWith('#'))
          .find((l) => l.startsWith('DEBUG_SESSION_ID='))
          ?.split('=')
          .slice(1)
          .join('=')
          .trim() ??
        '';
      __dbgUrl = url.length == 0 ? null : url;
      __dbgSession = sid.length == 0 ? null : sid;
    }
    if (__dbgUrl == null) return;
    const controller = new AbortController();
    const t = setTimeout(() => controller.abort(), 1200);
    await fetch(__dbgUrl, {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({
        sessionId: __dbgSession ?? 'login-500-error',
        ts: Date.now(),
        ...event,
      }),
      signal: controller.signal,
    });
    clearTimeout(t);
  } catch (_) {}
}
//#endregion debug-point login-500-error-reporter

export function registerAuthRoutes(app: FastifyInstance) {
  app.post('/auth/login', async (request, reply) => {
    const dbgReqId = `login-${Date.now()}-${Math.random().toString(16).slice(2)}`;
    try {
      const bodySchema = z.object({
        cpf: z.string(),
        senha: z.string()
      });
      const parsed = bodySchema.safeParse(request.body);
      void __dbg({
        runId: 'pre',
        hypothesisId: 'B',
        msg: 'login:payload-parse',
        reqId: dbgReqId,
        ok: parsed.success
      });
      if (!parsed.success) {
        return reply.code(400).send({ error: 'Dados inválidos' });
      }
      const { cpf, senha } = parsed.data;
      void __dbg({
        runId: 'pre',
        hypothesisId: 'A',
        msg: 'login:start',
        reqId: dbgReqId,
        cpfLast3: cpf.slice(-3),
        cpfLen: cpf.length
      });

      const user = await app.prisma.usuario.findUnique({ where: { cpf } });
      void __dbg({
        runId: 'pre',
        hypothesisId: 'A',
        msg: 'login:user-lookup',
        reqId: dbgReqId,
        found: Boolean(user)
      });
      if (!user) {
        return reply.code(401).send({ error: 'CPF ou senha inválidos' });
      }

      void __dbg({
        runId: 'pre',
        hypothesisId: 'C',
        msg: 'login:password-check',
        reqId: dbgReqId,
        hashLen: (user.senhaHash ?? '').length,
        providedLen: senha.length
      });
      if (user.senhaHash !== senha) {
        return reply.code(401).send({ error: 'CPF ou senha inválidos' });
      }

      const token = await reply.jwtSign({ userId: user.id, cpf: user.cpf });
      void __dbg({
        runId: 'pre',
        hypothesisId: 'D',
        msg: 'login:jwt-sign',
        reqId: dbgReqId,
        tokenLen: token.length
      });

      await app.prisma.auditoria.create({
        data: {
          usuarioId: user.id,
          acao: 'login',
          hora: new Date().toLocaleTimeString(),
          ip: request.ip
        }
      });
      void __dbg({
        runId: 'pre',
        hypothesisId: 'A',
        msg: 'login:audit-create',
        reqId: dbgReqId,
        ok: true
      });

      return reply.send({ token, user });
    } catch (e) {
      const err = e as Error;
      void __dbg({
        runId: 'pre',
        hypothesisId: 'E',
        msg: 'login:exception',
        reqId: dbgReqId,
        err: { message: err.message, stack: err.stack }
      });
      request.log.error({ err }, 'auth/login failed');
      const detail = process.env.NODE_ENV === 'production' ? undefined : err.message;
      return reply.code(500).send({ error: 'Erro interno ao autenticar', detail });
    }
  });
}
