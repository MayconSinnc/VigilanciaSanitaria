import { Pool } from 'pg';

type SInnCDbConfig = {
  url?: string;
  host?: string;
  port?: number;
  user?: string;
  password?: string;
  database?: string;
  ssl?: boolean;
};

type BaseLegalGrupoRow = { id: string; descricao: string };
type BaseLegalSubgrupoRow = { id: string; grupo_id: string; descricao: string };

export type BaseLegalEntry = {
  id: string;
  normaId: string;
  grupoId: string | null;
  grupoDescricao: string | null;
  subgrupoId: string | null;
  subgrupoDescricao: string | null;
  tipoNorma: string | null;
  esfera: string | null;
  numeroNorma: string | null;
  anoNorma: number | null;
  situacao: string | null;
  ementa: string | null;
  observacoes: string | null;
  baseLegalHtml: string | null;
  artigo: string | null;
  complemento: string | null;
  inciso: string | null;
  paragrafo: string | null;
  descricao: string | null;
  score?: number;
};

let _pool: Pool | null = null;

function readConfig(): SInnCDbConfig {
  const url = process.env.SINNC_SAUDE_DB_URL?.trim();
  if (url) return { url };

  const port = process.env.SINNC_SAUDE_DB_PORT ? Number(process.env.SINNC_SAUDE_DB_PORT) : undefined;
  const ssl = process.env.SINNC_SAUDE_DB_SSL ? process.env.SINNC_SAUDE_DB_SSL === 'true' : undefined;
  return {
    host: process.env.SINNC_SAUDE_DB_HOST?.trim(),
    port,
    user: process.env.SINNC_SAUDE_DB_USER?.trim(),
    password: process.env.SINNC_SAUDE_DB_PASSWORD,
    database: process.env.SINNC_SAUDE_DB_NAME?.trim(),
    ssl,
  };
}

function ensurePool(): Pool {
  if (_pool) return _pool;

  const cfg = readConfig();
  if (cfg.url) {
    _pool = new Pool({ connectionString: cfg.url });
    return _pool;
  }

  if (!cfg.host || !cfg.user || !cfg.database) {
    throw new Error(
      'Banco do SINNC Saúde não configurado. Defina SINNC_SAUDE_DB_URL (recomendado) ou SINNC_SAUDE_DB_HOST/SINNC_SAUDE_DB_USER/SINNC_SAUDE_DB_PASSWORD/SINNC_SAUDE_DB_NAME/SINNC_SAUDE_DB_PORT.',
    );
  }

  _pool = new Pool({
    host: cfg.host,
    port: cfg.port ?? 5432,
    user: cfg.user,
    password: cfg.password,
    database: cfg.database,
    ssl: cfg.ssl ? { rejectUnauthorized: false } : undefined,
  });
  return _pool;
}

function normalizeText(input: string): string {
  return input
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[^\p{L}\p{N}\s]+/gu, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

const SYNONYMS: Record<string, string[]> = {
  'cozinha suja': ['higiene', 'limpeza', 'sujidade', 'sanitizacao', 'ambiente', 'manipulacao', 'boas praticas', 'alimentos', 'contaminacao'],
  'alimento vencido': ['validade', 'prazo de validade', 'produto vencido', 'produto improprio', 'consumo', 'rotulagem'],
  'geladeira quente': ['temperatura', 'refrigeracao', 'conservacao', 'armazenamento', 'cadeia fria'],
  praga: ['insetos', 'roedores', 'controle de pragas', 'vetores'],
  'sem touca': ['manipulador', 'uniforme', 'epi', 'higiene pessoal'],
};

function expandTerms(raw: string): { terms: string[]; synonyms: string[] } {
  const normalized = normalizeText(raw);
  const tokens = normalized.split(' ').filter((t) => t.length >= 2);
  const syn: string[] = [];
  for (const [key, values] of Object.entries(SYNONYMS)) {
    if (normalized.includes(normalizeText(key))) {
      syn.push(...values.map(normalizeText));
    }
  }
  return { terms: tokens, synonyms: Array.from(new Set(syn)) };
}

function calcScore(query: string, entry: BaseLegalEntry): number {
  const q = normalizeText(query);
  if (!q) return 0;
  const { terms, synonyms } = expandTerms(q);

  const group = normalizeText(entry.grupoDescricao ?? '');
  const subgroup = normalizeText(entry.subgrupoDescricao ?? '');
  const ementa = normalizeText(entry.ementa ?? '');
  const obs = normalizeText(entry.observacoes ?? '');
  const html = normalizeText(entry.baseLegalHtml ?? '');
  const artigo = normalizeText(entry.artigo ?? '');
  const artDesc = normalizeText(entry.descricao ?? '');
  const norma = normalizeText(`${entry.tipoNorma ?? ''} ${entry.numeroNorma ?? ''} ${entry.anoNorma ?? ''} ${entry.esfera ?? ''}`);

  const hay = `${group} ${subgroup} ${norma} ${ementa} ${obs} ${html} ${artigo} ${artDesc}`.trim();
  if (!hay) return 0;

  let score = 0;

  if (hay.includes(q)) score += 100;

  for (const t of terms) {
    if (ementa.includes(t) || artDesc.includes(t) || html.includes(t) || obs.includes(t)) score += 30;
    if (group.includes(t) || subgroup.includes(t)) score += 20;
    if (norma.includes(t)) score += 50;
    if (artigo.includes(t)) score += 40;
  }

  for (const s of synonyms) {
    if (hay.includes(s)) score += 15;
  }

  return score;
}

export async function listarGrupos(): Promise<BaseLegalGrupoRow[]> {
  const pool = ensurePool();
  const res = await pool.query<BaseLegalGrupoRow>(
    `select id, descricao
     from vigilancia_legislacao_grupo
     where ativo = true
     order by descricao asc`,
  );
  return res.rows;
}

export async function listarSubgrupos(grupoId: string): Promise<BaseLegalSubgrupoRow[]> {
  const pool = ensurePool();
  const res = await pool.query<BaseLegalSubgrupoRow>(
    `select id, grupo_id, descricao
     from vigilancia_legislacao_subgrupo
     where ativo = true and grupo_id = $1
     order by descricao asc`,
    [grupoId],
  );
  return res.rows;
}

export async function buscarEntries(params: {
  query: string;
  grupoId?: string;
  subgrupoId?: string;
  limit?: number;
}): Promise<BaseLegalEntry[]> {
  const pool = ensurePool();
  const q = normalizeText(params.query ?? '');
  const { terms, synonyms } = expandTerms(q);
  const tokens = Array.from(new Set([...terms, ...synonyms])).filter((t) => t.length >= 2);
  if (tokens.length === 0) return [];

  const where: string[] = [];
  const values: any[] = [];

  if (params.grupoId) {
    values.push(params.grupoId);
    where.push(`l.grupo_id = $${values.length}`);
  }
  if (params.subgrupoId) {
    values.push(params.subgrupoId);
    where.push(`l.subgrupo_id = $${values.length}`);
  }

  const likeClauses: string[] = [];
  for (const t of tokens.slice(0, 8)) {
    values.push(`%${t}%`);
    const idx = values.length;
    likeClauses.push(`lower(coalesce(l.ementa,'')) like $${idx}`);
    likeClauses.push(`lower(coalesce(l.observacoes,'')) like $${idx}`);
    likeClauses.push(`lower(coalesce(l.base_legal_html,'')) like $${idx}`);
    likeClauses.push(`lower(coalesce(a.descricao,'')) like $${idx}`);
    likeClauses.push(`lower(coalesce(g.descricao,'')) like $${idx}`);
    likeClauses.push(`lower(coalesce(sg.descricao,'')) like $${idx}`);
    likeClauses.push(`lower(coalesce(l.numero,'')) like $${idx}`);
    likeClauses.push(`lower(coalesce(l.tipo,'')) like $${idx}`);
  }
  if (likeClauses.length > 0) where.push(`(${likeClauses.join(' or ')})`);

  const limit = Math.max(10, Math.min(params.limit ?? 120, 300));
  values.push(limit);

  const sql = `
    select
      coalesce(a.id, l.id) as id,
      l.id as norma_id,
      l.tipo,
      l.esfera,
      l.numero,
      l.ano,
      l.situacao,
      l.ementa,
      l.observacoes,
      l.base_legal_html,
      l.grupo_id,
      g.descricao as grupo_descricao,
      l.subgrupo_id,
      sg.descricao as subgrupo_descricao,
      a.numero as artigo_numero,
      a.complemento as artigo_complemento,
      a.inciso as artigo_inciso,
      a.paragrafo as artigo_paragrafo,
      a.descricao as artigo_descricao
    from vigilancia_legislacao l
    left join vigilancia_legislacao_grupo g on g.id = l.grupo_id
    left join vigilancia_legislacao_subgrupo sg on sg.id = l.subgrupo_id
    left join vigilancia_legislacao_artigo a on a.legislacao_id = l.id and (a.ativo = true or a.ativo is null)
    where ${(where.length ? where.join(' and ') : 'true')}
    order by l.data_alteracao desc nulls last, l.data_criacao desc nulls last
    limit $${values.length}
  `;

  const res = await pool.query(sql, values);
  const items: BaseLegalEntry[] = res.rows.map((r: any) => ({
    id: String(r.id),
    normaId: String(r.norma_id),
    grupoId: r.grupo_id ? String(r.grupo_id) : null,
    grupoDescricao: r.grupo_descricao ? String(r.grupo_descricao) : null,
    subgrupoId: r.subgrupo_id ? String(r.subgrupo_id) : null,
    subgrupoDescricao: r.subgrupo_descricao ? String(r.subgrupo_descricao) : null,
    tipoNorma: r.tipo ? String(r.tipo) : null,
    esfera: r.esfera ? String(r.esfera) : null,
    numeroNorma: r.numero ? String(r.numero) : null,
    anoNorma: typeof r.ano === 'number' ? r.ano : r.ano ? Number(r.ano) : null,
    situacao: r.situacao ? String(r.situacao) : null,
    ementa: r.ementa ? String(r.ementa) : null,
    observacoes: r.observacoes ? String(r.observacoes) : null,
    baseLegalHtml: r.base_legal_html ? String(r.base_legal_html) : null,
    artigo: r.artigo_numero ? String(r.artigo_numero) : null,
    complemento: r.artigo_complemento ? String(r.artigo_complemento) : null,
    inciso: r.artigo_inciso ? String(r.artigo_inciso) : null,
    paragrafo: r.artigo_paragrafo ? String(r.artigo_paragrafo) : null,
    descricao: r.artigo_descricao ? String(r.artigo_descricao) : null,
  }));

  const scored = items
    .map((it) => ({ ...it, score: calcScore(params.query, it) }))
    .filter((it) => (it.score ?? 0) > 0)
    .sort((a, b) => (b.score ?? 0) - (a.score ?? 0));

  return scored.slice(0, limit);
}

export async function listarEntriesPorSubgrupo(params: {
  subgrupoId: string;
  search?: string;
  limit?: number;
}): Promise<BaseLegalEntry[]> {
  const pool = ensurePool();
  const where: string[] = ['l.subgrupo_id = $1'];
  const values: any[] = [params.subgrupoId];

  const search = normalizeText(params.search ?? '');
  if (search) {
    values.push(`%${search}%`);
    const idx = values.length;
    where.push(
      `(
        lower(coalesce(l.numero,'')) like $${idx}
        or lower(coalesce(l.tipo,'')) like $${idx}
        or lower(coalesce(l.ementa,'')) like $${idx}
        or lower(coalesce(a.numero,'')) like $${idx}
        or lower(coalesce(a.descricao,'')) like $${idx}
      )`,
    );
  }

  const limit = Math.max(10, Math.min(params.limit ?? 80, 200));
  values.push(limit);

  const sql = `
    select
      coalesce(a.id, l.id) as id,
      l.id as norma_id,
      l.tipo,
      l.esfera,
      l.numero,
      l.ano,
      l.situacao,
      l.ementa,
      l.observacoes,
      l.base_legal_html,
      l.grupo_id,
      g.descricao as grupo_descricao,
      l.subgrupo_id,
      sg.descricao as subgrupo_descricao,
      a.numero as artigo_numero,
      a.complemento as artigo_complemento,
      a.inciso as artigo_inciso,
      a.paragrafo as artigo_paragrafo,
      a.descricao as artigo_descricao
    from vigilancia_legislacao l
    left join vigilancia_legislacao_grupo g on g.id = l.grupo_id
    left join vigilancia_legislacao_subgrupo sg on sg.id = l.subgrupo_id
    left join vigilancia_legislacao_artigo a on a.legislacao_id = l.id and (a.ativo = true or a.ativo is null)
    where ${where.join(' and ')}
    order by l.numero asc nulls last, l.ano desc nulls last, a.ordem asc nulls last
    limit $${values.length}
  `;
  const res = await pool.query(sql, values);
  return res.rows.map((r: any) => ({
    id: String(r.id),
    normaId: String(r.norma_id),
    grupoId: r.grupo_id ? String(r.grupo_id) : null,
    grupoDescricao: r.grupo_descricao ? String(r.grupo_descricao) : null,
    subgrupoId: r.subgrupo_id ? String(r.subgrupo_id) : null,
    subgrupoDescricao: r.subgrupo_descricao ? String(r.subgrupo_descricao) : null,
    tipoNorma: r.tipo ? String(r.tipo) : null,
    esfera: r.esfera ? String(r.esfera) : null,
    numeroNorma: r.numero ? String(r.numero) : null,
    anoNorma: typeof r.ano === 'number' ? r.ano : r.ano ? Number(r.ano) : null,
    situacao: r.situacao ? String(r.situacao) : null,
    ementa: r.ementa ? String(r.ementa) : null,
    observacoes: r.observacoes ? String(r.observacoes) : null,
    baseLegalHtml: r.base_legal_html ? String(r.base_legal_html) : null,
    artigo: r.artigo_numero ? String(r.artigo_numero) : null,
    complemento: r.artigo_complemento ? String(r.artigo_complemento) : null,
    inciso: r.artigo_inciso ? String(r.artigo_inciso) : null,
    paragrafo: r.artigo_paragrafo ? String(r.artigo_paragrafo) : null,
    descricao: r.artigo_descricao ? String(r.artigo_descricao) : null,
  }));
}

export async function buscarEntryPorId(id: string): Promise<BaseLegalEntry | null> {
  const pool = ensurePool();
  const sql = `
    select
      coalesce(a.id, l.id) as id,
      l.id as norma_id,
      l.tipo,
      l.esfera,
      l.numero,
      l.ano,
      l.situacao,
      l.ementa,
      l.observacoes,
      l.base_legal_html,
      l.grupo_id,
      g.descricao as grupo_descricao,
      l.subgrupo_id,
      sg.descricao as subgrupo_descricao,
      a.numero as artigo_numero,
      a.complemento as artigo_complemento,
      a.inciso as artigo_inciso,
      a.paragrafo as artigo_paragrafo,
      a.descricao as artigo_descricao
    from vigilancia_legislacao l
    left join vigilancia_legislacao_grupo g on g.id = l.grupo_id
    left join vigilancia_legislacao_subgrupo sg on sg.id = l.subgrupo_id
    left join vigilancia_legislacao_artigo a on a.legislacao_id = l.id and (a.ativo = true or a.ativo is null)
    where a.id = $1 or l.id = $1
    limit 1
  `;
  const res = await pool.query(sql, [id]);
  if (res.rows.length === 0) return null;
  const r: any = res.rows[0];
  return {
    id: String(r.id),
    normaId: String(r.norma_id),
    grupoId: r.grupo_id ? String(r.grupo_id) : null,
    grupoDescricao: r.grupo_descricao ? String(r.grupo_descricao) : null,
    subgrupoId: r.subgrupo_id ? String(r.subgrupo_id) : null,
    subgrupoDescricao: r.subgrupo_descricao ? String(r.subgrupo_descricao) : null,
    tipoNorma: r.tipo ? String(r.tipo) : null,
    esfera: r.esfera ? String(r.esfera) : null,
    numeroNorma: r.numero ? String(r.numero) : null,
    anoNorma: typeof r.ano === 'number' ? r.ano : r.ano ? Number(r.ano) : null,
    situacao: r.situacao ? String(r.situacao) : null,
    ementa: r.ementa ? String(r.ementa) : null,
    observacoes: r.observacoes ? String(r.observacoes) : null,
    baseLegalHtml: r.base_legal_html ? String(r.base_legal_html) : null,
    artigo: r.artigo_numero ? String(r.artigo_numero) : null,
    complemento: r.artigo_complemento ? String(r.artigo_complemento) : null,
    inciso: r.artigo_inciso ? String(r.artigo_inciso) : null,
    paragrafo: r.artigo_paragrafo ? String(r.artigo_paragrafo) : null,
    descricao: r.artigo_descricao ? String(r.artigo_descricao) : null,
  };
}

export async function buscarEntriesPorIds(ids: string[]): Promise<BaseLegalEntry[]> {
  const unique = Array.from(new Set(ids.map((e) => String(e).trim()).filter((e) => e.length > 0)));
  if (unique.length === 0) return [];

  const pool = ensurePool();
  const sql = `
    select
      coalesce(a.id, l.id) as id,
      l.id as norma_id,
      l.tipo,
      l.esfera,
      l.numero,
      l.ano,
      l.situacao,
      l.ementa,
      l.observacoes,
      l.base_legal_html,
      l.grupo_id,
      g.descricao as grupo_descricao,
      l.subgrupo_id,
      sg.descricao as subgrupo_descricao,
      a.numero as artigo_numero,
      a.complemento as artigo_complemento,
      a.inciso as artigo_inciso,
      a.paragrafo as artigo_paragrafo,
      a.descricao as artigo_descricao
    from vigilancia_legislacao l
    left join vigilancia_legislacao_grupo g on g.id = l.grupo_id
    left join vigilancia_legislacao_subgrupo sg on sg.id = l.subgrupo_id
    left join vigilancia_legislacao_artigo a on a.legislacao_id = l.id and (a.ativo = true or a.ativo is null)
    where (a.id = any($1::text[]) or l.id = any($1::text[]))
  `;
  const res = await pool.query(sql, [unique]);
  return res.rows.map((r: any) => ({
    id: String(r.id),
    normaId: String(r.norma_id),
    grupoId: r.grupo_id ? String(r.grupo_id) : null,
    grupoDescricao: r.grupo_descricao ? String(r.grupo_descricao) : null,
    subgrupoId: r.subgrupo_id ? String(r.subgrupo_id) : null,
    subgrupoDescricao: r.subgrupo_descricao ? String(r.subgrupo_descricao) : null,
    tipoNorma: r.tipo ? String(r.tipo) : null,
    esfera: r.esfera ? String(r.esfera) : null,
    numeroNorma: r.numero ? String(r.numero) : null,
    anoNorma: typeof r.ano === 'number' ? r.ano : r.ano ? Number(r.ano) : null,
    situacao: r.situacao ? String(r.situacao) : null,
    ementa: r.ementa ? String(r.ementa) : null,
    observacoes: r.observacoes ? String(r.observacoes) : null,
    baseLegalHtml: r.base_legal_html ? String(r.base_legal_html) : null,
    artigo: r.artigo_numero ? String(r.artigo_numero) : null,
    complemento: r.artigo_complemento ? String(r.artigo_complemento) : null,
    inciso: r.artigo_inciso ? String(r.artigo_inciso) : null,
    paragrafo: r.artigo_paragrafo ? String(r.artigo_paragrafo) : null,
    descricao: r.artigo_descricao ? String(r.artigo_descricao) : null,
  }));
}
