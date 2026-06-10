import type { FastifyInstance } from 'fastify';
import { AutoDocumentoStatus } from '@prisma/client';

const BC_LAT = -26.9905;
const BC_LNG = -48.6348;

function mapEstabelecimento(est: {
  id: number;
  cnpj: string;
  razaoSocial: string;
  nomeFantasia: string;
  endereco: string;
  numero: string | null;
  bairro: string | null;
  cidade: string;
  estado: string;
  uf: string | null;
  telefone: string | null;
  latitude: number | null;
  longitude: number | null;
  statusAlvara: string | null;
  statusSanitario: string | null;
  grauRisco: string | null;
  risco: string | null;
  responsavel: string | null;
}) {
  const lat =
    est.latitude ??
    BC_LAT + ((est.id % 20) - 10) * 0.002;
  const lng =
    est.longitude ??
    BC_LNG + ((est.id % 15) - 7) * 0.002;

  return {
    id: est.id,
    cnpj: est.cnpj,
    razaoSocial: est.razaoSocial,
    razao_social: est.razaoSocial,
    nomeFantasia: est.nomeFantasia,
    nome_fantasia: est.nomeFantasia,
    nome: est.nomeFantasia,
    endereco: est.endereco,
    numero: est.numero,
    bairro: est.bairro,
    cidade: est.cidade,
    municipio: est.cidade,
    estado: est.estado,
    uf: est.uf ?? est.estado,
    telefone: est.telefone,
    responsavel: est.responsavel,
    latitude: lat,
    longitude: lng,
    lat,
    lng,
    status_alvara: est.statusAlvara ?? 'Regular',
    statusAlvara: est.statusAlvara ?? 'Regular',
    status_sanitario: est.statusSanitario ?? 'REGULAR',
    statusSanitario: est.statusSanitario ?? 'REGULAR',
    grau_risco: est.grauRisco ?? est.risco ?? 'Médio',
    grauRisco: est.grauRisco ?? est.risco ?? 'Médio',
    risco: est.risco ?? est.grauRisco ?? 'Médio',
  };
}

export function registerDashboardRoutes(app: FastifyInstance) {
  app.get('/api/estatisticas', { preValidation: [app.authenticate] }, async (_request, reply) => {
    const [inspecoes, estabelecimentos, pendentes, autosInfracao, autosColeta] =
      await Promise.all([
        app.prisma.inspecao.count(),
        app.prisma.estabelecimento.count(),
        app.prisma.inspecao.count({ where: { status: 'Pendente' } }),
        app.prisma.inspecao.count({ where: { tipoAuto: 'INFRACAO' } }),
        app.prisma.inspecao.count({ where: { tipoAuto: 'COLETA' } }),
      ]);

    return reply.send({
      inspecoes,
      estabelecimentos,
      pendentes,
      autos: autosInfracao + autosColeta,
      autos_infracao: autosInfracao,
      autos_coleta: autosColeta,
    });
  });

  app.get('/api/dashboard/resumo', { preValidation: [app.authenticate] }, async (_request, reply) => {
    const now = new Date();
    const start = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 0, 0, 0, 0);
    const end = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1, 0, 0, 0, 0);

    const emitidosWhere = { status: { in: [AutoDocumentoStatus.FINALIZADO, AutoDocumentoStatus.SEM_EFEITO] } };

    const [
      aiTotal,
      infTotal,
      ipTotal,
      colTotal,
      risTotal,
      aiEmitidos,
      infEmitidos,
      ipEmitidos,
      colEmitidos,
      risEmitidos,
      aiHoje,
      infHoje,
      ipHoje,
      colHoje,
      risHoje,
      aiRecent,
      infRecent,
      ipRecent,
      colRecent,
      risRecent,
    ] = await Promise.all([
      app.prisma.autoIntimacaoDocumento.count(),
      app.prisma.autoInfracaoDocumento.count(),
      app.prisma.autoImposicaoPenalidadeDocumento.count(),
      app.prisma.autoColetaAmostraDocumento.count(),
      app.prisma.relatorioInspecaoSanitariaDocumento.count(),
      app.prisma.autoIntimacaoDocumento.count({ where: emitidosWhere }),
      app.prisma.autoInfracaoDocumento.count({ where: emitidosWhere }),
      app.prisma.autoImposicaoPenalidadeDocumento.count({ where: emitidosWhere }),
      app.prisma.autoColetaAmostraDocumento.count({ where: emitidosWhere }),
      app.prisma.relatorioInspecaoSanitariaDocumento.count({ where: emitidosWhere }),
      app.prisma.autoIntimacaoDocumento.count({ where: { createdAt: { gte: start, lt: end } } }),
      app.prisma.autoInfracaoDocumento.count({ where: { createdAt: { gte: start, lt: end } } }),
      app.prisma.autoImposicaoPenalidadeDocumento.count({ where: { createdAt: { gte: start, lt: end } } }),
      app.prisma.autoColetaAmostraDocumento.count({ where: { createdAt: { gte: start, lt: end } } }),
      app.prisma.relatorioInspecaoSanitariaDocumento.count({ where: { createdAt: { gte: start, lt: end } } }),
      app.prisma.autoIntimacaoDocumento.findMany({
        take: 10,
        orderBy: { updatedAt: 'desc' },
        select: { id: true, numeroAuto: true, status: true, estabelecimentoNome: true, updatedAt: true },
      }),
      app.prisma.autoInfracaoDocumento.findMany({
        take: 10,
        orderBy: { updatedAt: 'desc' },
        select: { id: true, numeroAuto: true, status: true, estabelecimentoNome: true, updatedAt: true },
      }),
      app.prisma.autoImposicaoPenalidadeDocumento.findMany({
        take: 10,
        orderBy: { updatedAt: 'desc' },
        select: { id: true, numeroAuto: true, status: true, estabelecimentoNome: true, updatedAt: true },
      }),
      app.prisma.autoColetaAmostraDocumento.findMany({
        take: 10,
        orderBy: { updatedAt: 'desc' },
        select: { id: true, numeroAuto: true, status: true, estabelecimentoNome: true, updatedAt: true },
      }),
      app.prisma.relatorioInspecaoSanitariaDocumento.findMany({
        take: 10,
        orderBy: { updatedAt: 'desc' },
        select: { id: true, numeroRelatorio: true, status: true, estabelecimentoNome: true, updatedAt: true },
      }),
    ]);

    const historico = [
      ...aiRecent.map((d) => ({
        tipo: 'AUTO_INTIMACAO',
        numero: d.numeroAuto,
        status: d.status,
        estabelecimento_nome: d.estabelecimentoNome ?? '',
        updated_at: d.updatedAt,
      })),
      ...infRecent.map((d) => ({
        tipo: 'AUTO_INFRACAO',
        numero: d.numeroAuto,
        status: d.status,
        estabelecimento_nome: d.estabelecimentoNome ?? '',
        updated_at: d.updatedAt,
      })),
      ...ipRecent.map((d) => ({
        tipo: 'IMPOSICAO_PENALIDADE',
        numero: d.numeroAuto,
        status: d.status,
        estabelecimento_nome: d.estabelecimentoNome ?? '',
        updated_at: d.updatedAt,
      })),
      ...colRecent.map((d) => ({
        tipo: 'AUTO_COLETA_AMOSTRA',
        numero: d.numeroAuto,
        status: d.status,
        estabelecimento_nome: d.estabelecimentoNome ?? '',
        updated_at: d.updatedAt,
      })),
      ...risRecent.map((d) => ({
        tipo: 'INSPECAO_SANITARIA',
        numero: d.numeroRelatorio,
        status: d.status,
        estabelecimento_nome: d.estabelecimentoNome ?? '',
        updated_at: d.updatedAt,
      })),
    ]
      .sort((a, b) => (b.updated_at as Date).getTime() - (a.updated_at as Date).getTime())
      .slice(0, 10)
      .map((i) => ({
        tipo: i.tipo,
        numero: i.numero,
        status: i.status,
        estabelecimento_nome: i.estabelecimento_nome,
        updated_at: (i.updated_at as Date).toISOString(),
      }));

    return reply.send({
      hoje: aiHoje + infHoje + ipHoje + colHoje + risHoje,
      autos_emitidos: aiEmitidos + infEmitidos + ipEmitidos + colEmitidos + risEmitidos,
      total_documentos: aiTotal + infTotal + ipTotal + colTotal + risTotal,
      por_tipo: {
        auto_intimacao: { total: aiTotal, emitidos: aiEmitidos, hoje: aiHoje },
        auto_infracao: { total: infTotal, emitidos: infEmitidos, hoje: infHoje },
        imposicao_penalidade: { total: ipTotal, emitidos: ipEmitidos, hoje: ipHoje },
        auto_coleta_amostra: { total: colTotal, emitidos: colEmitidos, hoje: colHoje },
        inspecao_sanitaria: { total: risTotal, emitidos: risEmitidos, hoje: risHoje },
      },
      historico,
    });
  });

  app.get('/api/mapa-sanitario', { preValidation: [app.authenticate] }, async (_request, reply) => {
    const ests = await app.prisma.estabelecimento.findMany({
      orderBy: { nomeFantasia: 'asc' },
      take: 300,
    });

    return reply.send({
      estabelecimentos: ests.map(mapEstabelecimento),
    });
  });

  app.get('/api/perfil-sanitario', { preValidation: [app.authenticate] }, async (request, reply) => {
    const q = request.query as { estabelecimentoId?: string; cnpj?: string };
    const estabelecimentoId = q.estabelecimentoId ? Number(q.estabelecimentoId) : undefined;
    const cnpjDigits = q.cnpj?.replace(/\D/g, '');

    let est = null;
    if (estabelecimentoId) {
      est = await app.prisma.estabelecimento.findUnique({ where: { id: estabelecimentoId } });
    } else if (cnpjDigits && cnpjDigits.length >= 11) {
      est = await app.prisma.estabelecimento.findFirst({
        where: { cnpj: { contains: cnpjDigits } },
      });
    } else {
      est = await app.prisma.estabelecimento.findFirst({ orderBy: { nomeFantasia: 'asc' } });
    }

    if (!est) {
      return reply.code(404).send({ error: 'Estabelecimento não encontrado' });
    }

    const inspecoes = await app.prisma.inspecao.findMany({
      where: { estabelecimentoId: est.id },
      orderBy: { data: 'desc' },
      take: 20,
      include: { fiscal: { select: { nome: true } } },
    });

    const historico = inspecoes.map((i) => ({
      id: i.id,
      data: i.data.toISOString().slice(0, 10),
      hora: i.hora,
      tipo: i.tipoAuto,
      situacao: i.situacao ?? i.status ?? 'REGULAR',
      status: i.status ?? 'CONCLUÍDO',
      fiscal: i.fiscal?.nome ?? '—',
      descricao: i.descricao ?? '',
    }));

    const infracoes = inspecoes.filter((i) => i.tipoAuto === 'INFRACAO').length;
    const coletas = inspecoes.filter((i) => i.tipoAuto === 'COLETA').length;
    const pendentes = inspecoes.filter((i) => (i.status ?? '').toUpperCase() === 'PENDENTE').length;

    const evolucao = historico.slice(0, 6).reverse().map((h, idx) => ({
      mes: `M${idx + 1}`,
      label: h.data,
      inspecoes: idx + 1,
      infracoes: h.tipo === 'INFRACAO' ? 1 : 0,
      score: Math.max(40, 100 - idx * 8),
    }));

    const mapped = mapEstabelecimento(est);

    return reply.send({
      estabelecimento: mapped,
      historico,
      evolucao,
      indicadores: {
        total_inspecoes: inspecoes.length,
        totalInspecoes: inspecoes.length,
        total_autos: infracoes + coletas,
        totalAutos: infracoes + coletas,
        reincidencias: Math.min(infracoes, 2),
        infracoes_graves: Math.min(infracoes, 1),
        infracoesGraves: Math.min(infracoes, 1),
        multas: infracoes,
        coletas,
        interdicoes: (mapped.status_sanitario as string)?.toUpperCase().includes('INTER') ? 1 : 0,
        pendencias: pendentes,
      },
    });
  });
}
