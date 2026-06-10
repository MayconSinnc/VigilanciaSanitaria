import type { FastifyInstance } from 'fastify';
import fetch from 'node-fetch';
import { AutoDocumentoStatus } from '@prisma/client';
import { z } from 'zod';

function getUserId(request: any): number | null {
  const id = request?.user?.userId;
  return typeof id === 'number' ? id : id ? Number(id) : null;
}

function getSinncToken(request: any): string | null {
  const raw = request.headers?.['x-sinnc-token'];
  if (typeof raw !== 'string') return null;
  const token = raw.trim();
  return token.length === 0 ? null : token;
}

async function readJsonOrText(res: any): Promise<{ contentType: string; payload: any }> {
  const contentType = res.headers.get('content-type') ?? '';
  if (contentType.includes('application/json')) {
    const data = await res.json().catch(() => ({}));
    return { contentType, payload: data };
  }
  const text = await res.text().catch(() => '');
  return { contentType, payload: text ? { message: text } : {} };
}

function isLoopbackRequest(request: any) {
  const ip = String(request?.ip ?? '');
  return (
    ip === '127.0.0.1' ||
    ip === '::1' ||
    ip === '::ffff:127.0.0.1' ||
    ip.endsWith('127.0.0.1')
  );
}

async function buildSinncAutoTermoItems(app: FastifyInstance, fiscalNome: string) {
  const emitidos = [AutoDocumentoStatus.FINALIZADO, AutoDocumentoStatus.SEM_EFEITO];

  const [ai, inf, ip, col, ris] = await Promise.all([
    app.prisma.autoIntimacaoDocumento.findMany({ where: { status: { in: emitidos } } }),
    app.prisma.autoInfracaoDocumento.findMany({ where: { status: { in: emitidos } } }),
    app.prisma.autoImposicaoPenalidadeDocumento.findMany({ where: { status: { in: emitidos } } }),
    app.prisma.autoColetaAmostraDocumento.findMany({ where: { status: { in: emitidos } } }),
    app.prisma.relatorioInspecaoSanitariaDocumento.findMany({ where: { status: { in: emitidos } } }),
  ]);

  const itens: Array<{
    chave_origem: string;
    documento: Record<string, unknown>;
  }> = [];

  for (const d of ai) {
    itens.push({
      chave_origem: `app:auto_intimacao:${d.id}`,
      documento: {
        tipo_documento: 'AUTO_DE_INTIMACAO',
        numero: d.numeroAuto,
        ano: d.ano,
        situacao: d.status,
        status_sincronizacao: 'SINCRONIZADO',
        origem: 'WEB',
        dispositivo: 'server-proxy',
        estabelecimento_nome: d.estabelecimentoNome ?? '',
        estabelecimento_cnpj_cpf: d.estabelecimentoCnpj ?? '',
        fiscal_nome: fiscalNome,
        data_lavratura: d.dataLavratura ?? null,
        conteudo: d.dados ?? {},
      },
    });
  }

  for (const d of inf) {
    itens.push({
      chave_origem: `app:auto_infracao:${d.id}`,
      documento: {
        tipo_documento: 'AUTO_DE_INFRACAO',
        numero: d.numeroAuto,
        ano: d.ano,
        situacao: d.status,
        status_sincronizacao: 'SINCRONIZADO',
        origem: 'WEB',
        dispositivo: 'server-proxy',
        estabelecimento_nome: d.estabelecimentoNome ?? '',
        estabelecimento_cnpj_cpf: d.estabelecimentoCnpj ?? '',
        fiscal_nome: fiscalNome,
        data_lavratura: d.dataLavratura ?? null,
        conteudo: d.dados ?? {},
      },
    });
  }

  for (const d of ip) {
    itens.push({
      chave_origem: `app:imposicao_penalidade:${d.id}`,
      documento: {
        tipo_documento: 'AUTO_DE_IMPOSICAO_DE_PENALIDADE',
        numero: d.numeroAuto,
        ano: d.ano,
        situacao: d.status,
        status_sincronizacao: 'SINCRONIZADO',
        origem: 'WEB',
        dispositivo: 'server-proxy',
        estabelecimento_nome: d.estabelecimentoNome ?? '',
        estabelecimento_cnpj_cpf: d.estabelecimentoCnpj ?? '',
        fiscal_nome: fiscalNome,
        data_lavratura: d.dataLavratura ?? null,
        conteudo: d.dados ?? {},
      },
    });
  }

  for (const d of col) {
    itens.push({
      chave_origem: `app:auto_coleta_amostra:${d.id}`,
      documento: {
        tipo_documento: 'AUTO_DE_COLETA_DE_AMOSTRA',
        numero: d.numeroAuto,
        ano: d.ano,
        situacao: d.status,
        status_sincronizacao: 'SINCRONIZADO',
        origem: 'WEB',
        dispositivo: 'server-proxy',
        estabelecimento_nome: d.estabelecimentoNome ?? '',
        estabelecimento_cnpj_cpf: d.estabelecimentoCnpj ?? '',
        fiscal_nome: fiscalNome,
        data_lavratura: d.dataLavratura ?? null,
        conteudo: d.dados ?? {},
      },
    });
  }

  for (const d of ris) {
    itens.push({
      chave_origem: `app:relatorio_inspecao:${d.id}`,
      documento: {
        tipo_documento: 'RELATORIO_DE_INSPECAO_SANITARIA',
        numero: d.numeroRelatorio,
        ano: d.ano,
        situacao: d.status,
        status_sincronizacao: 'SINCRONIZADO',
        origem: 'WEB',
        dispositivo: 'server-proxy',
        estabelecimento_nome: d.estabelecimentoNome ?? '',
        estabelecimento_cnpj_cpf: d.estabelecimentoCnpj ?? '',
        fiscal_nome: fiscalNome,
        data_lavratura: d.dataLavratura ?? null,
        conteudo: d.dados ?? {},
      },
    });
  }

  return itens;
}

export function registerSinncProxyRoutes(app: FastifyInstance) {
  app.post('/api/sinnc/login', { preValidation: [app.authenticate] }, async (request, reply) => {
    const bodySchema = z.object({
      cpf: z.string(),
      senha: z.string()
    });
    const parsed = bodySchema.safeParse(request.body);
    if (!parsed.success) {
      return reply.code(400).send({ error: 'Dados inválidos' });
    }
    try {
      const res = await fetch('http://127.0.0.1:8080/auth/login', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify(parsed.data)
      });
      const { payload } = await readJsonOrText(res);
      return reply.code(res.status).send(payload);
    } catch (_) {
      return reply.code(502).send({ error: 'Falha ao conectar no SINNC (127.0.0.1:8080).' });
    }
  });

  app.post('/api/sinnc/auto-termo/sincronizar', { preValidation: [app.authenticate] }, async (request, reply) => {
    const sinncToken = getSinncToken(request);
    if (!sinncToken) {
      return reply.code(400).send({ error: 'Token do SINNC não configurado' });
    }
    try {
      const res = await fetch('http://127.0.0.1:8080/api/auto-termo/sincronizar', {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          authorization: `Bearer ${sinncToken}`
        },
        body: JSON.stringify(request.body ?? {}),
      });
      const { payload } = await readJsonOrText(res);
      return reply.code(res.status).send(payload);
    } catch (_) {
      return reply.code(502).send({ error: 'Falha ao conectar no SINNC (127.0.0.1:8080).' });
    }
  });

  app.post('/api/sinnc/sincronizar-emitidos', { preValidation: [app.authenticate] }, async (request, reply) => {
    const sinncToken = getSinncToken(request);
    if (!sinncToken) {
      return reply.code(400).send({ error: 'Token do SINNC não configurado' });
    }
    const userId = getUserId(request);
    const usuario = userId ? await app.prisma.usuario.findUnique({ where: { id: userId } }) : null;
    const fiscalNome = usuario?.nome ?? usuario?.cpf ?? '';

    const itens = await buildSinncAutoTermoItems(app, fiscalNome);

    if (itens.length === 0) {
      return reply.send({ ok: 0, erro: 0, total: 0 });
    }

    let ok = 0;
    let erro = 0;
    let firstError: string | null = null;

    for (const item of itens) {
      try {
        const res = await fetch('http://127.0.0.1:8080/api/auto-termo/sincronizar', {
          method: 'POST',
          headers: {
            'content-type': 'application/json',
            authorization: `Bearer ${sinncToken}`
          },
          body: JSON.stringify(item),
        });

        if (res.ok) {
          ok += 1;
          continue;
        }
        erro += 1;
        if (!firstError) {
          const { payload } = await readJsonOrText(res);
          const msg =
            typeof payload === 'string'
              ? payload
              : ((payload as any)?.error ?? (payload as any)?.message ?? JSON.stringify(payload ?? {}));
          firstError = `HTTP ${res.status}${msg ? ` — ${msg}` : ''}`;
        }
      } catch (e) {
        erro += 1;
        if (!firstError) firstError = (e as any)?.message ?? 'Falha';
      }
    }

    return reply.send({ ok, erro, total: itens.length, firstError });
  });

  app.get('/api/sinnc/auto-termo/emitidos', async (request, reply) => {
    if (!isLoopbackRequest(request)) {
      return reply.code(403).send({ error: 'Acesso permitido apenas localmente.' });
    }

    const itens = await buildSinncAutoTermoItems(app, '');
    return reply.send({ status: true, total: itens.length, documentos: itens });
  });
}
