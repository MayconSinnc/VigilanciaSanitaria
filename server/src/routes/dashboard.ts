import type { FastifyInstance } from 'fastify';

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
