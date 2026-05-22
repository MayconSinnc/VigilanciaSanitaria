import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { buscarAlvarasPorCnpj, buscarDebitosPorCnpj, buscarEconomicosPorBusca, buscarEconomicosPorCnpj } from '../services/epublica.js';
import { getEstabelecimentoComplemento, saveEstabelecimentoComplemento } from '../services/estabelecimento_complemento_store.js';

export function registerEstabelecimentosApi(app: FastifyInstance) {
  const formatCnpj = (digits: string) => {
    const d = digits.replace(/\D/g, '').slice(0, 14);
    if (d.length !== 14) return digits;
    return `${d.slice(0, 2)}.${d.slice(2, 5)}.${d.slice(5, 8)}/${d.slice(8, 12)}-${d.slice(12, 14)}`;
  };

  app.get('/api/estabelecimentos', { preValidation: [app.authenticate] }, async (request, reply) => {
    const qSchema = z.object({ search: z.string().optional(), limit: z.string().optional(), offset: z.string().optional() });
    const parsed = qSchema.safeParse(request.query);
    if (!parsed.success) return reply.code(400).send({ error: 'Parâmetros inválidos' });
    const { search, limit, offset } = parsed.data;
    const take = limit ? Number(limit) : 20;
    const skip = offset ? Number(offset) : 0;
    const where: any = {};
    if (search && search.trim().length > 0) {
      const norm = search.replace(/\D/g, '');
      where.OR = [
        { nomeFantasia: { contains: search } },
        { razaoSocial: { contains: search } },
        { cnpj: { equals: norm } },
        { cnpj: { contains: norm } },
        { cnpj: { equals: search } },
        { cnpj: { contains: search } },
      ];
    }
    const result = await app.prisma.estabelecimento.findMany({
      where,
      select: { id: true, cnpj: true, razaoSocial: true, nomeFantasia: true, cidade: true },
      take,
      skip,
    });
    return reply.send(result);
  });

  app.get('/api/estabelecimentos/epublica', { preValidation: [app.authenticate] }, async (request, reply) => {
    const qSchema = z.object({ search: z.string().optional(), limit: z.string().optional(), offset: z.string().optional() });
    const parsed = qSchema.safeParse(request.query);
    if (!parsed.success) return reply.code(400).send({ error: 'Parâmetros inválidos' });
    const { search, limit, offset } = parsed.data;
    const q = (search ?? '').trim();
    if (!q) return reply.send([]);
    const take = limit ? Number(limit) : 20;
    const skip = offset ? Number(offset) : 0;
    const raw = await buscarEconomicosPorBusca(q);
    const list = Array.isArray(raw) ? raw : (raw?.data ?? raw?.items ?? raw?.results ?? []);
    const sliced = Array.isArray(list) ? list.slice(skip, skip + take) : [];
    const mapped = sliced.map((empresa: any) => {
      const contribuinte = empresa.contribuinte ?? {};
      const razaoSocial =
        contribuinte.nomeRazaoSocial ??
        contribuinte.nome_razao_social ??
        contribuinte.razaoSocial ??
        contribuinte.razao_social ??
        empresa.nomeRazaoSocial ??
        empresa.nome_razao_social ??
        empresa.razaoSocial ??
        empresa.razao_social ??
        empresa.razao ??
        empresa['razao_social'] ??
        empresa['razaoSocial'] ??
        '';
      const nomeFantasia =
        empresa.nomeFantasia ??
        empresa.nome_fantasia ??
        empresa.nome ??
        empresa['nome_fantasia'] ??
        empresa['nomeFantasia'] ??
        '';
      const cnpj = empresa.cnpj ?? empresa['cnpj'] ?? '';
      const inscricaoMunicipal = empresa.inscricaoMunicipal ?? empresa.inscricao_municipal ?? '';
      return {
        cnpj: String(cnpj).replace(/\D/g, ''),
        razaoSocial: String(razaoSocial ?? ''),
        razao_social: String(razaoSocial ?? ''),
        nomeFantasia: String(nomeFantasia ?? ''),
        nome_fantasia: String(nomeFantasia ?? ''),
        inscricaoMunicipal: String(inscricaoMunicipal ?? ''),
        inscricao_municipal: String(inscricaoMunicipal ?? ''),
      };
    });
    return reply.send(mapped);
  });

  app.get('/api/estabelecimentos/list', { preValidation: [app.authenticate] }, async (_request, reply) => {
    const list = await app.prisma.estabelecimento.findMany({
      select: { id: true, nomeFantasia: true, cnpj: true },
      orderBy: { nomeFantasia: 'asc' },
      take: 100,
    });
    return reply.send(list);
  });

  app.get('/api/estabelecimentos/cnpj/:cnpj', { preValidation: [app.authenticate] }, async (request, reply) => {
    const params = request.params as any;
    const cnpjParam = String(params.cnpj ?? '');
    const digits = cnpjParam.replace(/\D/g, '');
    if (digits.length < 11) return reply.code(400).send({ error: 'CNPJ inválido' });
    const cnpj = formatCnpj(digits);

    try {
      const economicos = await buscarEconomicosPorCnpj(digits);
      const list = Array.isArray(economicos)
        ? economicos
        : (economicos?.data ?? economicos?.items ?? economicos?.results ?? []);
      if (!Array.isArray(list) || list.length === 0) return reply.code(404).send({ error: 'Empresa não encontrada' });
      const empresa = list[0] as any;

      const contribuinte = empresa.contribuinte ?? {};
      const razaoSocial =
        contribuinte.nomeRazaoSocial ??
        contribuinte.nome_razao_social ??
        contribuinte.razaoSocial ??
        contribuinte.razao_social ??
        empresa.nomeRazaoSocial ??
        empresa.nome_razao_social ??
        empresa.razaoSocial ??
        empresa.razao_social ??
        empresa.razao ??
        empresa['razao_social'] ??
        empresa['razaoSocial'] ??
        '';
      const nomeFantasia =
        empresa.nomeFantasia ??
        empresa.nome_fantasia ??
        empresa.nome ??
        empresa['nome_fantasia'] ??
        empresa['nomeFantasia'] ??
        '';
      const enderecos = Array.isArray(empresa.enderecos) ? empresa.enderecos : [];
      const enderecoPrincipal = enderecos.find((e: any) => e?.principal) ?? enderecos[0] ?? {};
      const logradouroObj = enderecoPrincipal.logradouro ?? {};
      const bairroObj = enderecoPrincipal.bairro ?? {};
      const endereco =
        enderecoPrincipal.endereco ??
        logradouroObj.denominacao ??
        logradouroObj.nome ??
        logradouroObj.descricao ??
        enderecoPrincipal.logradouroDenominacao ??
        empresa.endereco ??
        empresa.logradouro ??
        empresa['logradouro'] ??
        empresa['endereco'] ??
        '';
      const numero = enderecoPrincipal.numero ?? empresa.numero ?? empresa['numero'] ?? '';
      const bairro =
        bairroObj.denominacao ??
        bairroObj.nome ??
        enderecoPrincipal.bairro ??
        empresa.bairro ??
        empresa['bairro'] ??
        '';
      const cidade =
        enderecoPrincipal.cidadeNome ??
        enderecoPrincipal.cidade ??
        empresa.cidade ??
        empresa.municipio ??
        empresa['municipio'] ??
        empresa['cidade'] ??
        '';
      const estado =
        enderecoPrincipal.estadoSigla ??
        enderecoPrincipal.uf ??
        empresa.estado ??
        empresa.uf ??
        empresa['uf'] ??
        empresa['estado'] ??
        '';
      const cep = enderecoPrincipal.cep ?? empresa.cep ?? empresa['cep'] ?? '';
      const inscricaoMunicipal = empresa.inscricaoMunicipal ?? empresa.inscricao_municipal ?? '';
      const cnaes = Array.isArray(empresa.cnaes) ? empresa.cnaes : [];
      const cnaePrincipal = cnaes.find((c: any) => c?.principal) ?? cnaes.find((c: any) => c?.dtFim == null) ?? cnaes[0] ?? {};
      const cnae = cnaePrincipal.codigo ?? empresa.cnae ?? empresa.cnaePrincipal ?? empresa['cnae'] ?? empresa['cnae_principal'] ?? '';
      const cnaeDescricao = cnaePrincipal.denominacao ?? '';

      let alvara: any = null;
      let alvarasHistorico: any[] = [];
      let debitosHistorico: any[] = [];
      let possuiDebito: boolean | null = null;
      try {
        const alvaras = await buscarAlvarasPorCnpj(digits);
        const aList = Array.isArray(alvaras) ? alvaras : (alvaras?.data ?? alvaras?.items ?? []);
        if (Array.isArray(aList)) {
          alvarasHistorico = aList;
          if (aList.length > 0) alvara = aList[0];
        }
      } catch {
        alvara = null;
        alvarasHistorico = [];
      }
      try {
        const debitos = await buscarDebitosPorCnpj(digits);
        const dList = Array.isArray(debitos) ? debitos : (debitos?.data ?? debitos?.items ?? []);
        if (Array.isArray(dList)) {
          debitosHistorico = dList;
          possuiDebito = dList.length > 0;
        }
      } catch {
        possuiDebito = null;
        debitosHistorico = [];
      }

      const saved = await app.prisma.estabelecimento.upsert({
        where: { cnpj },
        update: {
          razaoSocial: String(razaoSocial ?? ''),
          nomeFantasia: String(nomeFantasia ?? ''),
          endereco: String(endereco ?? ''),
          numero: String(numero ?? ''),
          bairro: String(bairro ?? ''),
          cidade: String(cidade ?? ''),
          estado: String(estado ?? ''),
          uf: String(estado ?? ''),
          cep: String(cep ?? ''),
          inscricaoMunicipal: String(inscricaoMunicipal ?? ''),
        },
        create: {
          cnpj,
          razaoSocial: String(razaoSocial ?? ''),
          nomeFantasia: String(nomeFantasia ?? ''),
          endereco: String(endereco ?? ''),
          numero: String(numero ?? ''),
          bairro: String(bairro ?? ''),
          cidade: String(cidade ?? ''),
          estado: String(estado ?? ''),
          uf: String(estado ?? ''),
          cep: String(cep ?? ''),
          inscricaoMunicipal: String(inscricaoMunicipal ?? ''),
        },
      });

      const complemento = getEstabelecimentoComplemento(saved.id);

      return reply.send({
        ...saved,
        telefone: complemento?.telefone ?? saved.telefone,
        email: complemento?.email ?? saved.email,
        responsavel_local: complemento?.responsavel_local ?? null,
        observacoes: complemento?.observacoes ?? null,
        latitude: complemento?.latitude ?? saved.latitude ?? null,
        longitude: complemento?.longitude ?? saved.longitude ?? null,
        classificacao_sanitaria_local: complemento?.classificacao_sanitaria_local ?? null,
        cnae,
        cnaeDescricao,
        economico: empresa,
        alvara,
        alvaras: alvarasHistorico,
        debitos: debitosHistorico,
        possuiDebito,
        origem_dados: 'e-Pública',
        ultima_sincronizacao: new Date().toISOString(),
        complemento,
      });
    } catch (err: any) {
      const code = err?.code;
      const upstreamStatus = err?.statusCode;
      const upstreamBody = err?.body;
      if (code === 'EPUBLICA_NOT_CONFIGURED') {
        return reply.code(503).send({ error: 'E-Pública não configurada. Defina EPUBLICA_X_API_KEY/EPUBLICA_X_ALIAS/EPUBLICA_X_NOME_CHAVE (ou EPUBLICA_TOKEN) no backend.' });
      }
      if (upstreamStatus === 401) {
        return reply.code(502).send({ error: 'E-Pública respondeu Unauthorized. Verifique as credenciais configuradas no backend.' });
      }
      app.log.error(err);
      if (process.env.NODE_ENV !== 'production') {
        return reply.code(500).send({ error: 'Erro ao buscar estabelecimento no E-Pública', upstreamStatus, upstreamBody });
      }
      return reply.code(500).send({ error: 'Erro ao buscar estabelecimento no E-Pública' });
    }
  });

  app.get('/api/estabelecimentos/:id', { preValidation: [app.authenticate] }, async (request, reply) => {
    const params = request.params as any;
    const id = Number(params.id);
    if (!id) return reply.code(400).send({ error: 'ID inválido' });
    const est = await app.prisma.estabelecimento.findUnique({ where: { id } });
    if (!est) return reply.code(404).send({ error: 'Não encontrado' });
    return reply.send(est);
  });

  app.post('/api/estabelecimentos', { preValidation: [app.authenticate] }, async (request, reply) => {
    const bodySchema = z.object({
      cnpj: z.string(),
      razao_social: z.string().optional().nullable(),
      razaoSocial: z.string().optional().nullable(),
      nome_fantasia: z.string().optional().nullable(),
      nomeFantasia: z.string().optional().nullable(),
      logradouro: z.string().optional().nullable(),
      endereco: z.string().optional().nullable(),
      numero: z.string().optional().nullable(),
      bairro: z.string().optional().nullable(),
      cidade: z.string().optional().nullable(),
      uf: z.string().optional().nullable(),
      estado: z.string().optional().nullable(),
      cep: z.string().optional().nullable(),
      telefone: z.string().optional().nullable(),
      email: z.string().optional().nullable(),
      responsavel: z.string().optional().nullable(),
      cpfResponsavel: z.string().optional().nullable(),
      cpf_responsavel: z.string().optional().nullable(),
      inscricaoMunicipal: z.string().optional().nullable(),
      risco: z.string().optional().nullable(),
      statusAlvara: z.string().optional().nullable(),
      status_alvara: z.string().optional().nullable(),
      statusSanitario: z.string().optional().nullable(),
      status_sanitario: z.string().optional().nullable(),
      grauRisco: z.string().optional().nullable(),
      grau_risco: z.string().optional().nullable(),
      latitude: z.number().optional().nullable(),
      longitude: z.number().optional().nullable(),
      lat: z.number().optional().nullable(),
      lng: z.number().optional().nullable(),
    });

    const parsed = bodySchema.safeParse(request.body);
    if (!parsed.success) {
      app.log.error(parsed.error);
      return reply.code(400).send({ error: 'Dados inválidos', details: parsed.error.format() });
    }

    const b = parsed.data;
    const data: any = {
      cnpj: b.cnpj,
      razaoSocial: b.razaoSocial ?? b.razao_social ?? '',
      nomeFantasia: b.nomeFantasia ?? b.nome_fantasia ?? '',
      endereco: b.endereco ?? b.logradouro ?? '',
      numero: b.numero ?? '',
      bairro: b.bairro ?? '',
      cidade: b.cidade ?? '',
      estado: b.estado ?? b.uf ?? '',
      uf: b.uf ?? b.estado ?? '',
      cep: b.cep ?? '',
      telefone: b.telefone ?? '',
      email: b.email ?? '',
      responsavel: b.responsavel ?? '',
      cpfResponsavel: b.cpfResponsavel ?? b.cpf_responsavel ?? '',
      inscricaoMunicipal: b.inscricaoMunicipal ?? '',
      risco: b.risco ?? '',
      statusAlvara: b.statusAlvara ?? b.status_alvara ?? '',
      statusSanitario: b.statusSanitario ?? b.status_sanitario ?? '',
      grauRisco: b.grauRisco ?? b.grau_risco ?? '',
      latitude: b.latitude ?? b.lat ?? null,
      longitude: b.longitude ?? b.lng ?? null,
    };

    try {
      const saved = await app.prisma.estabelecimento.upsert({
        where: { cnpj: data.cnpj },
        update: data,
        create: data,
      });
      return reply.code(201).send(saved);
    } catch (error: any) {
      app.log.error(error);
      return reply.code(500).send({ error: 'Erro ao criar estabelecimento', message: error.message });
    }
  });

  app.put('/api/estabelecimentos/:id', { preValidation: [app.authenticate] }, async (request, reply) => {
    const params = request.params as any;
    const id = Number(params.id);
    if (!id) return reply.code(400).send({ error: 'ID inválido' });
    const bodySchema = z.object({
      telefone: z.string().optional().nullable(),
      email: z.string().optional().nullable(),
      responsavel: z.string().optional().nullable(),
      responsavel_local: z.string().optional().nullable(),
      observacoes: z.string().optional().nullable(),
      latitude: z.number().optional().nullable(),
      longitude: z.number().optional().nullable(),
      classificacao_sanitaria_local: z.string().optional().nullable(),
    });
    const parsed = bodySchema.safeParse(request.body);
    if (!parsed.success) return reply.code(400).send({ error: 'Dados inválidos', details: parsed.error.format() });

    const body = parsed.data;
    const updated = await app.prisma.estabelecimento.update({
      where: { id },
      data: {
        telefone: body.telefone ?? undefined,
        email: body.email ?? undefined,
        responsavel: body.responsavel ?? body.responsavel_local ?? undefined,
        latitude: body.latitude ?? undefined,
        longitude: body.longitude ?? undefined,
      },
    });

    const complemento = saveEstabelecimentoComplemento(id, {
      telefone: body.telefone ?? updated.telefone ?? null,
      email: body.email ?? updated.email ?? null,
      responsavel_local: body.responsavel_local ?? body.responsavel ?? updated.responsavel ?? null,
      observacoes: body.observacoes ?? null,
      latitude: body.latitude ?? updated.latitude ?? null,
      longitude: body.longitude ?? updated.longitude ?? null,
      classificacao_sanitaria_local: body.classificacao_sanitaria_local ?? null,
    });

    return reply.send({
      ...updated,
      responsavel_local: complemento.responsavel_local,
      observacoes: complemento.observacoes,
      classificacao_sanitaria_local: complemento.classificacao_sanitaria_local,
      complemento,
    });
  });

  app.delete('/api/estabelecimentos/:id', { preValidation: [app.authenticate] }, async (request, reply) => {
    const params = request.params as any;
    const id = Number(params.id);
    if (!id) return reply.code(400).send({ error: 'ID inválido' });
    await app.prisma.estabelecimento.delete({ where: { id } });
    return reply.code(204).send();
  });


}
