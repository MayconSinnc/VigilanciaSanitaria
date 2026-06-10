export type PenalidadeRemota = {
  codigoLegal: string;
  descricao: string;
  valorMinimo?: number;
  valorMaximo?: number;
};

export type AutoEpublica = {
  numero: string;
  cnpj: string;
  tipo: 'INTIMACAO' | 'INFRACAO' | 'COLETA';
  data: string;
  fiscal: string;
  situacao: string;
  penalidade?: string;
};

export type EmpresaRemota = {
  cnpj: string;
  razao_social: string;
  nome_fantasia?: string;
  logradouro?: string;
  endereco?: string;
  numero?: string;
  bairro?: string;
  cidade?: string;
  uf?: string;
  cep?: string;
  inscricao_municipal?: string;
  cnae?: string;
  cnae_descricao?: string;
};

const EPUBLICA_BASE_URL = process.env.EPUBLICA_BASE_URL || 'https://sc.e-publica.net/epublica/api/v1';

function getEpublicaAuthHeaders() {
  const token = process.env.EPUBLICA_TOKEN;
  const xApiKey = process.env.EPUBLICA_X_API_KEY;
  const xAlias = process.env.EPUBLICA_X_ALIAS;
  const xNomeChave = process.env.EPUBLICA_X_NOME_CHAVE;

  const baseHeaders = {
    accept: 'application/json',
    'user-agent':
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36',
  } as const;

  if (xApiKey && xAlias && xNomeChave) {
    return {
      ...baseHeaders,
      'x-api-key': xApiKey,
      'x-alias': xAlias,
      'x-nome-chave': xNomeChave,
    } as const;
  }

  if (token) {
    return {
      ...baseHeaders,
      authorization: `Bearer ${token}`,
    } as const;
  }

  return null;
}

export async function epublicaGet(path: string, params?: Record<string, string | number | undefined>) {
  const headers = getEpublicaAuthHeaders();
  if (!headers) {
    const err = new Error('E-Pública não configurada (credenciais ausentes).');
    (err as any).code = 'EPUBLICA_NOT_CONFIGURED';
    throw err;
  }

  const url = new URL(`${EPUBLICA_BASE_URL}${path}`);
  if (params) {
    for (const [k, v] of Object.entries(params)) {
      if (v === undefined) continue;
      url.searchParams.set(k, String(v));
    }
  }

  const res = await fetch(url.toString(), { headers });
  const contentType = res.headers.get('content-type') ?? '';
  const body = contentType.includes('application/json') ? await res.json() : await res.text();
  if (!res.ok) {
    const err = new Error(`E-Pública HTTP ${res.status}`);
    (err as any).statusCode = res.status;
    (err as any).body = body;
    throw err;
  }
  return body;
}

export function extractCollection(raw: any): any[] {
  if (Array.isArray(raw)) return raw;
  const candidates = [
    raw?.data,
    raw?.items,
    raw?.results,
    raw?.content,
    raw?.records,
    raw?.rows,
    raw?.lista,
    raw?.economicos,
    raw?.data?.items,
    raw?.data?.results,
    raw?.data?.content,
    raw?.result,
  ];

  for (const candidate of candidates) {
    if (Array.isArray(candidate)) return candidate;
  }

  return [];
}

function extractPaginationMeta(raw: any): Record<string, any> {
  if (!raw || typeof raw !== 'object') return {};
  return {
    ...((raw.meta && typeof raw.meta === 'object') ? raw.meta : {}),
    ...((raw.pagination && typeof raw.pagination === 'object') ? raw.pagination : {}),
    ...((raw.page && typeof raw.page === 'object') ? raw.page : {}),
    page: raw.page,
    pagina: raw.pagina,
    total: raw.total,
    totalPages: raw.totalPages,
    total_paginas: raw.total_paginas,
    totalItems: raw.totalItems,
    total_items: raw.total_items,
    pageSize: raw.pageSize,
    page_size: raw.page_size,
    perPage: raw.perPage,
    per_page: raw.per_page,
  };
}

function firstNonEmpty(values: any[]): string {
  for (const value of values) {
    if (value === null || value === undefined) continue;
    const text = String(value).trim();
    if (text && text.toLowerCase() !== 'null') return text;
  }
  return '';
}

export function normalizeEconomicoToEmpresa(empresa: any): EmpresaRemota {
  const contribuinte = empresa?.contribuinte ?? {};
  const enderecos = Array.isArray(empresa?.enderecos) ? empresa.enderecos : [];
  const enderecoPrincipal = enderecos.find((e: any) => e?.principal) ?? enderecos[0] ?? {};
  const logradouroObj = enderecoPrincipal?.logradouro ?? {};
  const bairroObj = enderecoPrincipal?.bairro ?? {};
  const cnaes = Array.isArray(empresa?.cnaes) ? empresa.cnaes : [];
  const cnaePrincipal = cnaes.find((c: any) => c?.principal) ?? cnaes.find((c: any) => c?.dtFim == null) ?? cnaes[0] ?? {};

  const cnpj = firstNonEmpty([
    empresa?.cnpj,
    contribuinte?.cnpj,
  ]).replace(/\D/g, '');

  return {
    cnpj,
    razao_social: firstNonEmpty([
      contribuinte?.nomeRazaoSocial,
      contribuinte?.nome_razao_social,
      contribuinte?.razaoSocial,
      contribuinte?.razao_social,
      empresa?.nomeRazaoSocial,
      empresa?.nome_razao_social,
      empresa?.razaoSocial,
      empresa?.razao_social,
      empresa?.razao,
      empresa?.['razao_social'],
      empresa?.['razaoSocial'],
    ]),
    nome_fantasia: firstNonEmpty([
      empresa?.nomeFantasia,
      empresa?.nome_fantasia,
      empresa?.nome,
      empresa?.['nome_fantasia'],
      empresa?.['nomeFantasia'],
    ]),
    logradouro: firstNonEmpty([
      enderecoPrincipal?.endereco,
      logradouroObj?.denominacao,
      logradouroObj?.nome,
      logradouroObj?.descricao,
      enderecoPrincipal?.logradouroDenominacao,
      empresa?.endereco,
      empresa?.logradouro,
      empresa?.['logradouro'],
      empresa?.['endereco'],
    ]),
    endereco: firstNonEmpty([
      enderecoPrincipal?.endereco,
      empresa?.endereco,
      empresa?.logradouro,
      empresa?.['endereco'],
    ]),
    numero: firstNonEmpty([enderecoPrincipal?.numero, empresa?.numero, empresa?.['numero']]),
    bairro: firstNonEmpty([
      bairroObj?.denominacao,
      bairroObj?.nome,
      enderecoPrincipal?.bairro,
      empresa?.bairro,
      empresa?.['bairro'],
    ]),
    cidade: firstNonEmpty([
      enderecoPrincipal?.cidadeNome,
      enderecoPrincipal?.cidade,
      empresa?.cidade,
      empresa?.municipio,
      empresa?.['municipio'],
      empresa?.['cidade'],
    ]),
    uf: firstNonEmpty([
      enderecoPrincipal?.estadoSigla,
      enderecoPrincipal?.uf,
      empresa?.estado,
      empresa?.uf,
      empresa?.['uf'],
      empresa?.['estado'],
    ]),
    cep: firstNonEmpty([enderecoPrincipal?.cep, empresa?.cep, empresa?.['cep']]),
    inscricao_municipal: firstNonEmpty([
      empresa?.inscricaoMunicipal,
      empresa?.inscricao_municipal,
    ]),
    cnae: firstNonEmpty([
      cnaePrincipal?.codigo,
      empresa?.cnae,
      empresa?.cnaePrincipal,
      empresa?.['cnae'],
      empresa?.['cnae_principal'],
    ]),
    cnae_descricao: firstNonEmpty([
      cnaePrincipal?.denominacao,
      empresa?.cnaeDescricao,
      empresa?.cnae_fiscal_descricao,
    ]),
  };
}

export async function listarEconomicosParaImportacao(pageSize = 100, maxPages = 30): Promise<any[]> {
  const all: any[] = [];
  const seenKeys = new Set<string>();

  for (let page = 1; page <= maxPages; page += 1) {
    let raw: any = null;
    let list: any[] = [];
    let lastError: any = null;

    const attempts: Array<Record<string, string | number | undefined> | undefined> = page === 1
        ? [
            { page, limit: pageSize },
            { pagina: page, tamanho: pageSize },
            { limit: pageSize, offset: 0 },
            undefined,
          ]
        : [
            { page, limit: pageSize },
            { pagina: page, tamanho: pageSize },
            { limit: pageSize, offset: (page - 1) * pageSize },
          ];

    for (const params of attempts) {
      try {
        raw = await epublicaGet('/economicos', params);
        list = extractCollection(raw);
        break;
      } catch (err: any) {
        lastError = err;
        const status = Number(err?.statusCode ?? 0);
        if (status === 400 || status === 404) continue;
        throw err;
      }
    }

    if (raw == null) {
      if (lastError) throw lastError;
      break;
    }

    if (list.length === 0) break;

    let newItems = 0;
    for (const item of list) {
      const normalized = normalizeEconomicoToEmpresa(item);
      const key = normalized.cnpj || JSON.stringify(item).slice(0, 240);
      if (seenKeys.has(key)) continue;
      seenKeys.add(key);
      all.push(item);
      newItems += 1;
    }

    const meta = extractPaginationMeta(raw);
    const totalPages = Number(meta.totalPages ?? meta.total_paginas ?? meta.lastPage ?? meta.last_page ?? 0);
    const currentPage = Number(meta.page ?? meta.pagina ?? meta.currentPage ?? meta.current_page ?? page);
    const totalItems = Number(meta.total ?? meta.totalItems ?? meta.total_items ?? 0);
    const detectedPageSize = Number(meta.pageSize ?? meta.page_size ?? meta.perPage ?? meta.per_page ?? pageSize);

    if (totalPages && currentPage >= totalPages) break;
    if (totalItems && all.length >= totalItems) break;
    if (newItems === 0) break;
    if (list.length < detectedPageSize) break;
  }

  return all;
}

export async function importPenalidades(): Promise<PenalidadeRemota[]> {
  return [];
}

export async function importAutos(_page = 1, _pageSize = 20): Promise<AutoEpublica[]> {
  return [];
}

export async function syncInspecao(inspecao: any): Promise<{ success: boolean; numeroAuto?: string; error?: string }> {
  // Stub: Simula envio de inspeção para o sistema externo
  // Em produção, aqui seria feita uma chamada POST para a API da E-Pública
  console.log('Sincronizando inspeção com E-Pública:', inspecao.id);
  
  // Simula um sucesso com retorno de número de auto gerado
  const year = new Date().getFullYear();
  const random = Math.floor(Math.random() * 9999).toString().padStart(4, '0');
  
  return {
    success: true,
    numeroAuto: `${inspecao.tipoAuto}-${year}-${random}`
  };
}

export async function importEmpresas(): Promise<EmpresaRemota[]> {
  const economicos = await listarEconomicosParaImportacao();
  return economicos
    .map((item) => normalizeEconomicoToEmpresa(item))
    .filter((item) => item.cnpj.length === 14);
}

export async function buscarEconomicosPorCnpj(cnpj: string): Promise<any> {
  const raw = String(cnpj ?? '');
  const digits = raw.replace(/\D/g, '');
  const formatted =
    digits.length === 14 ? `${digits.slice(0, 2)}.${digits.slice(2, 5)}.${digits.slice(5, 8)}/${digits.slice(8, 12)}-${digits.slice(12, 14)}` : raw;

  const attempts: Array<Record<string, string>> = [
    { cnpj: digits },
    { cnpj: formatted },
    { cnpjCpf: digits },
    { cnpjCpf: formatted },
    { cpfCnpj: digits },
    { cpfCnpj: formatted },
    { documento: digits },
    { documento: formatted },
  ];

  let lastErr: any = null;
  for (const params of attempts) {
    try {
      return await epublicaGet('/economicos', params);
    } catch (err: any) {
      lastErr = err;
      const status = err?.statusCode ?? 0;
      if (status >= 400 && status < 500) continue;
      throw err;
    }
  }
  if (lastErr) throw lastErr;
  return [];
}

export async function buscarEconomicosPorBusca(search: string): Promise<any> {
  const q = String(search ?? '').trim();
  if (!q) return [];
  const attempts: Array<Record<string, string>> = [
    { search: q },
    { q },
    { termo: q },
    { nome: q },
    { nomeFantasia: q },
    { razaoSocial: q },
  ];
  let lastErr: any = null;
  for (const params of attempts) {
    try {
      return await epublicaGet('/economicos', params);
    } catch (err: any) {
      lastErr = err;
      const status = err?.statusCode ?? 0;
      if (status >= 400 && status < 500) continue;
      throw err;
    }
  }
  if (lastErr) throw lastErr;
  return [];
}

export async function buscarAlvarasPorCnpj(cnpj: string): Promise<any> {
  return epublicaGet('/alvaras', { cnpj });
}

export async function buscarDebitosPorCnpj(cnpj: string): Promise<any> {
  return epublicaGet('/debitos', { cnpj });
}
