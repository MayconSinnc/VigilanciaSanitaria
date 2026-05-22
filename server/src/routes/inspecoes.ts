import type { FastifyInstance } from 'fastify';
import { z } from 'zod';

export function registerInspecoesRoutes(app: FastifyInstance) {
  app.get('/inspecoes', { preValidation: [app.authenticate] }, async (request, reply) => {
    const list = await app.prisma.inspecao.findMany({
      include: { estabelecimento: true, fiscal: true, Fotos: true, Intimacao: true, Infracao: true, Coleta: true, Assinatura: true }
    });
    return reply.send(list);
  });

  const createSchema = z.object({
    tipoAuto: z.enum(['INTIMACAO', 'INFRACAO', 'COLETA']),
    estabelecimentoId: z.number(),
    descricao: z.string().optional(),
    situacao: z.enum(['REGULAR', 'IRREGULAR', 'INTERDITADO', 'EM_ADEQUACAO']).optional(),
    gpsLatitude: z.number().optional(),
    gpsLongitude: z.number().optional()
  });

  app.post('/inspecoes', { preValidation: [app.authenticate] }, async (request, reply) => {
    const parsed = createSchema.safeParse(request.body);
    if (!parsed.success) return reply.code(400).send({ error: 'Dados inválidos' });
    const userId = (request as any).user?.userId;
    const now = new Date();
    const inspecao = await app.prisma.inspecao.create({
      data: {
        tipoAuto: parsed.data.tipoAuto,
        estabelecimentoId: parsed.data.estabelecimentoId,
        fiscalId: userId,
        data: now,
        hora: now.toLocaleTimeString(),
        descricao: parsed.data.descricao,
        situacao: parsed.data.situacao,
        gpsLatitude: parsed.data.gpsLatitude,
        gpsLongitude: parsed.data.gpsLongitude,
        status: 'Pendente'
      }
    });
    await app.prisma.auditoria.create({
      data: {
        usuarioId: userId,
        acao: 'nova_inspecao',
        hora: now.toLocaleTimeString(),
        inspecaoId: inspecao.id,
        ip: request.ip
      }
    });
    return reply.code(201).send(inspecao);
  });

  app.get('/inspecoes/:id', { preValidation: [app.authenticate] }, async (request, reply) => {
    const { id } = request.params as { id: string };
    const inspecao = await app.prisma.inspecao.findUnique({
      where: { id: Number(id) },
      include: { estabelecimento: true, fiscal: true, Fotos: true, Intimacao: true, Infracao: true, Coleta: true, Assinatura: true }
    });
    if (!inspecao) return reply.code(404).send({ error: 'Inspeção não encontrada' });
    return reply.send(inspecao);
  });

  app.patch('/inspecoes/:id/status', { preValidation: [app.authenticate] }, async (request, reply) => {
    const { id } = request.params as { id: string };
    const body = z.object({ status: z.string() }).parse(request.body);
    const updated = await app.prisma.inspecao.update({ where: { id: Number(id) }, data: { status: body.status } });
    return reply.send(updated);
  });

  // Detalhes de Intimação
  app.post('/inspecoes/:id/intimacao', { preValidation: [app.authenticate] }, async (request, reply) => {
    const { id } = request.params as { id: string };
    const body = z.object({
      descricaoIrregularidade: z.string(),
      baseLegal: z.string(),
      prazoRegularizacao: z.string(),
      penalidadePrevista: z.string()
    }).parse(request.body);
    const record = await app.prisma.intimacao.upsert({
      where: { inspecaoId: Number(id) },
      update: {
        descricaoIrregularidade: body.descricaoIrregularidade,
        baseLegal: body.baseLegal,
        prazoRegularizacao: new Date(body.prazoRegularizacao),
        penalidadePrevista: body.penalidadePrevista
      },
      create: {
        inspecaoId: Number(id),
        descricaoIrregularidade: body.descricaoIrregularidade,
        baseLegal: body.baseLegal,
        prazoRegularizacao: new Date(body.prazoRegularizacao),
        penalidadePrevista: body.penalidadePrevista
      }
    });
    return reply.code(201).send(record);
  });

  // Detalhes de Infração
  app.post('/inspecoes/:id/infracao', { preValidation: [app.authenticate] }, async (request, reply) => {
    const { id } = request.params as { id: string };
    const body = z.object({
      descricao: z.string(),
      baseLegal: z.string(),
      gravidade: z.enum(['Leve', 'Moderada', 'Grave', 'Gravíssima']),
      penalidadeId: z.number().optional(),
      valorMulta: z.number().optional()
    }).parse(request.body);
    const record = await app.prisma.infracao.create({
      data: {
        inspecaoId: Number(id),
        descricao: body.descricao,
        baseLegal: body.baseLegal,
        gravidade: body.gravidade,
        penalidadeId: body.penalidadeId,
        valorMulta: body.valorMulta
      }
    });
    return reply.code(201).send(record);
  });

  // Detalhes de Coleta de Amostra
  app.post('/inspecoes/:id/coleta', { preValidation: [app.authenticate] }, async (request, reply) => {
    const { id } = request.params as { id: string };
    const body = z.object({
      produtoNome: z.string(),
      marca: z.string().optional(),
      lote: z.string().optional(),
      dataFabricacao: z.string().optional(),
      dataValidade: z.string().optional(),
      quantidade: z.number(),
      temperatura: z.number().optional(),
      condicaoProduto: z.enum(['Refrigerado', 'Congelado', 'Ambiente']).optional(),
      destinoLaboratorio: z.string()
    }).parse(request.body);
    const record = await app.prisma.coletaAmostra.create({
      data: {
        inspecaoId: Number(id),
        produtoNome: body.produtoNome,
        marca: body.marca,
        lote: body.lote,
        dataFabricacao: body.dataFabricacao ? new Date(body.dataFabricacao) : null,
        dataValidade: body.dataValidade ? new Date(body.dataValidade) : null,
        quantidade: body.quantidade,
        temperatura: body.temperatura,
        condicaoProduto: body.condicaoProduto,
        destinoLaboratorio: body.destinoLaboratorio
      }
    });
    return reply.code(201).send(record);
  });

  // Assinaturas digitais
  app.post('/inspecoes/:id/assinatura', { preValidation: [app.authenticate] }, async (request, reply) => {
    const { id } = request.params as { id: string };
    const body = z.object({
      assinaturaFiscal: z.string(),
      assinaturaResponsavel: z.string().optional()
    }).parse(request.body);
    const record = await app.prisma.assinatura.upsert({
      where: { inspecaoId: Number(id) },
      update: {
        assinaturaFiscal: body.assinaturaFiscal,
        assinaturaResponsavel: body.assinaturaResponsavel ?? null
      },
      create: {
        inspecaoId: Number(id),
        assinaturaFiscal: body.assinaturaFiscal,
        assinaturaResponsavel: body.assinaturaResponsavel ?? null
      }
    });
    return reply.code(201).send(record);
  });

  // Finalizar auto (gera link para PDF e atualiza status)
  app.post('/inspecoes/:id/finalizar', { preValidation: [app.authenticate] }, async (request, reply) => {
    const { id } = request.params as { id: string };
    const updated = await app.prisma.inspecao.update({
      where: { id: Number(id) },
      data: { status: 'Enviado' }
    });
    return reply.send({ ...updated, pdfUrl: `/inspecoes/${id}/pdf` });
  });
}
