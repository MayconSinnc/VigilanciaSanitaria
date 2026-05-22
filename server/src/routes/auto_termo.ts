import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { addAutoTermo, loadAutoTermo, toAutoTermoListItem } from '../services/auto_termo_store.js';

export function registerAutoTermoRoutes(app: FastifyInstance) {
  app.get('/api/auto-termo', { preValidation: [app.authenticate] }, async (request, reply) => {
    const qSchema = z.object({
      search: z.string().optional(),
      cnpj: z.string().optional(),
      tipo_documento: z.string().optional(),
      status: z.string().optional(),
      data_inicio: z.string().optional(),
      data_fim: z.string().optional(),
    });
    const parsed = qSchema.safeParse(request.query);
    if (!parsed.success) return reply.code(400).send({ error: 'Parâmetros inválidos' });
    const q = (parsed.data.search ?? '').trim().toLowerCase();
    const cnpj = (parsed.data.cnpj ?? '').replace(/\D/g, '');
    const tipoDocumento = (parsed.data.tipo_documento ?? '').trim().toUpperCase();
    const status = (parsed.data.status ?? '').trim().toUpperCase();
    const dataInicio = (parsed.data.data_inicio ?? '').trim();
    const dataFim = (parsed.data.data_fim ?? '').trim();
    const inicio = dataInicio ? new Date(`${dataInicio}T00:00:00`) : null;
    const fim = dataFim ? new Date(`${dataFim}T23:59:59`) : null;

    const list = loadAutoTermo().map((r) => toAutoTermoListItem(r));
    const filtered = list.filter((item) => {
      const raw = JSON.stringify(item).toLowerCase();
      const itemCnpj = String(item.cnpj ?? '').replace(/\D/g, '');
      const itemTipo = String(item.tipo_documento ?? '').toUpperCase();
      const itemStatus = String(item.status ?? '').toUpperCase();
      const dataBruta = String(item.data_hora ?? '').trim();
      const dataItem = dataBruta ? new Date(dataBruta.replace(' ', 'T')) : null;

      if (q && !raw.includes(q)) return false;
      if (cnpj && !itemCnpj.includes(cnpj)) return false;
      if (tipoDocumento && tipoDocumento != 'TODOS' && itemTipo != tipoDocumento) return false;
      if (status && status != 'TODOS' && itemStatus != status) return false;
      if (inicio != null && (dataItem == null || dataItem.getTime() < inicio.getTime())) return false;
      if (fim != null && (dataItem == null || dataItem.getTime() > fim.getTime())) return false;
      return true;
    });
    return reply.send(filtered);
  });

  app.post('/api/auto-termo', { preValidation: [app.authenticate] }, async (request, reply) => {
    const bodySchema = z.object({
      ano: z.string().min(4),
      data_hora: z.string().min(10),
      estabelecimento_id: z.string().optional(),
      tipo_documento: z.string().min(3),
      dados_estabelecimento: z.record(z.any()),
      profissional_id: z.string().optional().nullable(),
      testemunha_1: z.string().optional().nullable(),
      testemunha_2: z.string().optional().nullable(),
      responsavel_tecnico_id: z.string().optional().nullable(),
      status: z.string().optional(),
    }).passthrough();
    const parsed = bodySchema.safeParse(request.body);
    if (!parsed.success) return reply.code(400).send({ error: 'Payload inválido' });
    const record = addAutoTermo(parsed.data as Record<string, unknown>);
    return reply.code(201).send(toAutoTermoListItem(record));
  });
}
