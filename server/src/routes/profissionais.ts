import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import {
  addProfissional,
  loadProfissionais,
  replaceAll,
  updateProfissional,
  type ProfissionalRecord,
} from '../services/profissionais_store.js';

async function seedFromUsuarios(app: FastifyInstance) {
  const existing = loadProfissionais();
  if (existing.length > 0) return;

  const usuarios = await app.prisma.usuario.findMany({
    orderBy: { nome: 'asc' },
    take: 50,
  });

  const seeded: ProfissionalRecord[] = usuarios.map((u) => ({
    id: u.id,
    nome: u.nome,
    cargo: u.cargo ?? 'Fiscal de Vigilância Sanitária',
    matricula: `MAT-${String(u.id).padStart(4, '0')}`,
    email: u.email,
    telefone: null,
    perfil_acesso: u.cargo?.toUpperCase().includes('ADMIN') ? 'ADMINISTRADOR' : 'FISCAL',
    status: 'ATIVO',
  }));

  if (seeded.length === 0) {
    seeded.push(
      {
        id: 1,
        nome: 'Fiscal Teste',
        cargo: 'Fiscal de Vigilância Sanitária',
        matricula: 'MAT-0001',
        email: 'fiscal@prefeitura.gov.br',
        perfil_acesso: 'FISCAL',
        status: 'ATIVO',
      },
      {
        id: 2,
        nome: 'Supervisor Regional',
        cargo: 'Supervisor',
        matricula: 'MAT-0002',
        email: 'supervisor@prefeitura.gov.br',
        perfil_acesso: 'SUPERVISOR',
        status: 'ATIVO',
      },
    );
  }

  replaceAll(seeded);
}

export function registerProfissionaisRoutes(app: FastifyInstance) {
  app.get('/api/profissionais', { preValidation: [app.authenticate] }, async (request, reply) => {
    const parsed = z
      .object({ search: z.string().optional(), status: z.string().optional() })
      .safeParse(request.query);
    if (!parsed.success) return reply.code(400).send({ error: 'Parâmetros inválidos' });

    await seedFromUsuarios(app);

    let list = loadProfissionais();
    const { search, status } = parsed.data;

    if (search?.trim()) {
      const term = search.trim().toLowerCase();
      list = list.filter(
        (p) =>
          String(p.nome ?? '').toLowerCase().includes(term) ||
          String(p.cargo ?? '').toLowerCase().includes(term) ||
          String(p.matricula ?? '').toLowerCase().includes(term),
      );
    }

    if (status?.trim()) {
      const wanted = status.trim().toUpperCase();
      list = list.filter((p) => String(p.status ?? '').toUpperCase() === wanted);
    }

    return reply.send(list);
  });

  app.post('/api/profissionais', { preValidation: [app.authenticate] }, async (request, reply) => {
    const body = (request.body ?? {}) as Record<string, unknown>;
    const saved = addProfissional(body);
    return reply.code(201).send(saved);
  });

  app.put('/api/profissionais/:id', { preValidation: [app.authenticate] }, async (request, reply) => {
    const params = request.params as { id?: string };
    const id = String(params.id ?? '');
    const body = (request.body ?? {}) as Record<string, unknown>;
    const updated = updateProfissional(id, body);
    if (!updated) return reply.code(404).send({ error: 'Profissional não encontrado' });
    return reply.send(updated);
  });
}
