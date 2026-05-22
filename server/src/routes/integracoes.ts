import type { FastifyInstance } from 'fastify';
import {
  buscarAlvarasPorCnpj,
  buscarDebitosPorCnpj,
  extractCollection,
  importEmpresas,
} from '../services/epublica.js';

type ImportResponse = {
  success: boolean;
  importados: number;
  atualizados: number;
  ignorados: number;
  erros: Array<{ item?: string; mensagem: string }>;
  ultima_sincronizacao: string;
  message?: string;
};

function buildResponse(
  overrides: Partial<ImportResponse> & Pick<ImportResponse, 'success'>,
): ImportResponse {
  return {
    success: overrides.success,
    importados: overrides.importados ?? 0,
    atualizados: overrides.atualizados ?? 0,
    ignorados: overrides.ignorados ?? 0,
    erros: overrides.erros ?? [],
    ultima_sincronizacao: overrides.ultima_sincronizacao ?? new Date().toISOString(),
    message: overrides.message,
  };
}

function formatCnpj(digits: string) {
  const d = digits.replace(/\D/g, '').slice(0, 14);
  if (d.length !== 14) return digits;
  return `${d.slice(0, 2)}.${d.slice(2, 5)}.${d.slice(5, 8)}/${d.slice(8, 12)}-${d.slice(12, 14)}`;
}

function firstNonEmpty(values: any[]) {
  for (const value of values) {
    if (value === null || value === undefined) continue;
    const text = String(value).trim();
    if (text && text.toLowerCase() !== 'null') return text;
  }
  return '';
}

function extractAlvaraStatus(item: any) {
  return firstNonEmpty([
    item?.situacao,
    item?.status,
    item?.descricao,
    item?.nome,
  ]);
}

function mapImportError(err: any) {
  const code = err?.code;
  const statusCode = Number(err?.statusCode ?? 0);

  if (code === 'EPUBLICA_NOT_CONFIGURED') {
    return {
      statusCode: 503,
      message: 'Erro de autenticação com a e-Pública. Verifique a configuração do backend.',
    };
  }

  if (statusCode === 401 || statusCode === 403) {
    return {
      statusCode: 502,
      message: 'Erro de autenticação com a e-Pública.',
    };
  }

  if (statusCode === 404) {
    return {
      statusCode: 404,
      message: 'A API da e-Pública não possui este endpoint.',
    };
  }

  return {
    statusCode: 500,
    message: 'Não foi possível concluir a importação no backend.',
  };
}

export function registerIntegracoesRoutes(app: FastifyInstance) {
  const importarEstabelecimentos = async (_request: any, reply: any) => {
    try {
      const empresas = await importEmpresas();
      if (empresas.length === 0) {
        return reply.send(
          buildResponse({
            success: false,
            message: 'Nenhum dado encontrado para importação.',
          }),
        );
      }

      let importados = 0;
      let atualizados = 0;
      let ignorados = 0;
      const erros: Array<{ item?: string; mensagem: string }> = [];

      for (const empresa of empresas) {
        const digits = String(empresa.cnpj ?? '').replace(/\D/g, '');
        if (digits.length !== 14) {
          ignorados += 1;
          erros.push({
            item: empresa.cnpj,
            mensagem: 'CNPJ inválido recebido da e-Pública.',
          });
          continue;
        }

        const cnpj = formatCnpj(digits);

        try {
          const existente = await app.prisma.estabelecimento.findUnique({ where: { cnpj } });

          let statusAlvara = existente?.statusAlvara ?? null;
          try {
            const alvaras = extractCollection(await buscarAlvarasPorCnpj(digits));
            if (alvaras.length > 0) {
              statusAlvara = extractAlvaraStatus(alvaras[0]) || statusAlvara;
            }
          } catch (err) {
            app.log.warn({ err, cnpj }, 'Falha ao consultar alvarás na importação de estabelecimentos');
          }

          try {
            await buscarDebitosPorCnpj(digits);
          } catch (err) {
            app.log.warn({ err, cnpj }, 'Falha ao consultar débitos na importação de estabelecimentos');
          }

          const payload = {
            cnpj,
            razaoSocial: empresa.razao_social || empresa.nome_fantasia || '',
            nomeFantasia: empresa.nome_fantasia || empresa.razao_social || '',
            endereco: empresa.endereco || empresa.logradouro || '',
            numero: empresa.numero || '',
            bairro: empresa.bairro || '',
            cidade: empresa.cidade || '',
            estado: empresa.uf || '',
            uf: empresa.uf || '',
            cep: empresa.cep || '',
            inscricaoMunicipal: empresa.inscricao_municipal || '',
            statusAlvara: statusAlvara || '',
          };

          if (existente) {
            await app.prisma.estabelecimento.update({
              where: { cnpj },
              data: payload,
            });
            atualizados += 1;
          } else {
            await app.prisma.estabelecimento.create({
              data: payload,
            });
            importados += 1;
          }
        } catch (err: any) {
          app.log.error({ err, cnpj }, 'Erro ao importar estabelecimento');
          erros.push({
            item: cnpj,
            mensagem: err?.message || 'Falha ao salvar estabelecimento importado.',
          });
        }
      }

      const success = erros.length === 0 || importados > 0 || atualizados > 0;
      const message = success
        ? erros.length > 0
            ? 'Importação concluída com avisos.'
            : 'Importação concluída com sucesso.'
        : 'Nenhum estabelecimento foi importado.';

      return reply.send(
        buildResponse({
          success,
          importados,
          atualizados,
          ignorados,
          erros,
          message,
        }),
      );
    } catch (err: any) {
      app.log.error({ err }, 'Erro ao importar estabelecimentos da e-Pública');
      const mapped = mapImportError(err);
      return reply.code(mapped.statusCode).send(
        buildResponse({
          success: false,
          message: mapped.message,
          erros: [{ mensagem: mapped.message }],
        }),
      );
    }
  };

  const importarPenalidades = async (_request: any, reply: any) => {
    return reply.send(
      buildResponse({
        success: false,
        message:
          'A API de Gestão de Tributos da e-Pública não possui endpoint específico para penalidades sanitárias. Utilize a base local do módulo Auto/Termo.',
      }),
    );
  };

  const importarAutosExternos = async (_request: any, reply: any) => {
    return reply.send(
      buildResponse({
        success: false,
        message:
          'A API de Gestão de Tributos da e-Pública não possui endpoint específico para autos sanitários externos.',
      }),
    );
  };

  app.post('/api/integracoes/epublica/importar-estabelecimentos', { preValidation: [app.authenticate] }, importarEstabelecimentos);
  app.post('/api/integracoes/epublica/importar-penalidades', { preValidation: [app.authenticate] }, importarPenalidades);
  app.post('/api/integracoes/epublica/importar-autos-externos', { preValidation: [app.authenticate] }, importarAutosExternos);

  // Compatibilidade com chamadas anteriores do app.
  app.post('/api/integracoes/epublica/empresas', { preValidation: [app.authenticate] }, importarEstabelecimentos);
  app.post('/api/integracoes/epublica/penalidades', { preValidation: [app.authenticate] }, importarPenalidades);
  app.post('/api/integracoes/epublica/autos', { preValidation: [app.authenticate] }, importarAutosExternos);

  app.post('/api/integracoes/epublica/sync', { preValidation: [app.authenticate] }, async (_request, reply) => {
    return reply.send({ success: true, sincronizados: 0, erros: 0 });
  });
}
