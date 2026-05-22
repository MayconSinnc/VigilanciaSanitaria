import type { FastifyInstance } from 'fastify';

export function registerCnpjRoutes(app: FastifyInstance) {
  const fetchBrasilApi = async (digits: string) => {
    const url = `https://brasilapi.com.br/api/cnpj/v1/${digits}`;
    const res = await fetch(url, {
      headers: {
        accept: 'application/json',
        'user-agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36',
      },
    });
    return { res, url };
  };

  const readUpstreamBody = async (res: Response) => {
    const contentType = res.headers.get('content-type') ?? '';
    if (contentType.includes('application/json')) return await res.json();
    return await res.text();
  };

  app.get('/api/cnpj/:cnpj', async (request, reply) => {
    const cnpjParam = (request.params as any).cnpj as string;
    const digits = cnpjParam.replace(/\D/g, '');
    const { res } = await fetchBrasilApi(digits);
    if (!res.ok) {
      return reply.code(res.status).send(await readUpstreamBody(res));
    }
    const data = await res.json();
    const mapped = {
      cnpj: data.cnpj || digits,
      razaoSocial: data.razao_social || data['razao_social'] || '',
      nomeFantasia: data.nome_fantasia || data['nome_fantasia'] || '',
      endereco: data.logradouro || '',
      numero: data.numero || '',
      bairro: data.bairro || '',
      cidade: data.municipio || '',
      estado: data.uf || '',
      cep: data.cep || '',
      cnaeDescricao: data.cnae_fiscal_descricao || ''
    };
    return reply.send(mapped);
  });
  app.get('/cnpj/:cnpj', async (request, reply) => {
    const cnpjParam = (request.params as any).cnpj as string;
    const digits = cnpjParam.replace(/\D/g, '');
    const { res } = await fetchBrasilApi(digits);
    if (!res.ok) {
      return reply.code(res.status).send(await readUpstreamBody(res));
    }
    const data = await res.json();
    const mapped = {
      cnpj: data.cnpj || digits,
      razaoSocial: data.razao_social || data['razao_social'] || '',
      nomeFantasia: data.nome_fantasia || data['nome_fantasia'] || '',
      endereco: data.logradouro || '',
      numero: data.numero || '',
      bairro: data.bairro || '',
      cidade: data.municipio || '',
      estado: data.uf || '',
      cep: data.cep || '',
      cnaeDescricao: data.cnae_fiscal_descricao || ''
    };
    return reply.send(mapped);
  });
}
