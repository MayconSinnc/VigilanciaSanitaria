import fs from 'fs';
import path from 'path';

export type EstabelecimentoComplemento = {
  estabelecimento_id: string;
  telefone?: string | null;
  email?: string | null;
  responsavel_local?: string | null;
  observacoes?: string | null;
  latitude?: number | null;
  longitude?: number | null;
  classificacao_sanitaria_local?: string | null;
  cnae?: string | null;
  cnaeDescricao?: string | null;
  updatedAt: string;
};

const DATA_DIR = path.join(process.cwd(), 'data');
const DATA_FILE = path.join(DATA_DIR, 'estabelecimentos_complemento.json');

let cache: Record<string, EstabelecimentoComplemento> | null = null;

function ensureDir() {
  if (!fs.existsSync(DATA_DIR)) {
    fs.mkdirSync(DATA_DIR, { recursive: true });
  }
}

function loadAll(): Record<string, EstabelecimentoComplemento> {
  if (cache) return cache;
  ensureDir();
  if (!fs.existsSync(DATA_FILE)) {
    cache = {};
    return cache;
  }
  try {
    const raw = JSON.parse(fs.readFileSync(DATA_FILE, 'utf8'));
    cache = raw && typeof raw === 'object' ? (raw as Record<string, EstabelecimentoComplemento>) : {};
    return cache;
  } catch {
    cache = {};
    return cache;
  }
}

function persist(data: Record<string, EstabelecimentoComplemento>) {
  ensureDir();
  cache = data;
  fs.writeFileSync(DATA_FILE, JSON.stringify(data, null, 2), 'utf8');
}

export function getEstabelecimentoComplemento(estabelecimentoId: string | number) {
  const all = loadAll();
  return all[String(estabelecimentoId)] ?? null;
}

export function saveEstabelecimentoComplemento(
  estabelecimentoId: string | number,
  payload: Omit<EstabelecimentoComplemento, 'estabelecimento_id' | 'updatedAt'>,
) {
  const all = loadAll();
  const current = all[String(estabelecimentoId)] ?? {
    estabelecimento_id: String(estabelecimentoId),
    updatedAt: new Date().toISOString(),
  };
  const next: EstabelecimentoComplemento = {
    ...current,
    ...payload,
    estabelecimento_id: String(estabelecimentoId),
    updatedAt: new Date().toISOString(),
  };
  all[String(estabelecimentoId)] = next;
  persist(all);
  return next;
}
