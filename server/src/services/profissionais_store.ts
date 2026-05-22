import fs from 'fs';
import path from 'path';
import { randomUUID } from 'crypto';

export type ProfissionalRecord = Record<string, unknown> & {
  id: string | number;
  nome: string;
  status: string;
};

const DATA_DIR = path.join(process.cwd(), 'data');
const DATA_FILE = path.join(DATA_DIR, 'profissionais.json');

let cache: ProfissionalRecord[] | null = null;

function ensureDir() {
  if (!fs.existsSync(DATA_DIR)) {
    fs.mkdirSync(DATA_DIR, { recursive: true });
  }
}

export function loadProfissionais(): ProfissionalRecord[] {
  if (cache) return cache;
  ensureDir();
  if (!fs.existsSync(DATA_FILE)) {
    cache = [];
    return cache;
  }
  try {
    const raw = JSON.parse(fs.readFileSync(DATA_FILE, 'utf8'));
    cache = Array.isArray(raw) ? (raw as ProfissionalRecord[]) : [];
    return cache;
  } catch {
    cache = [];
    return cache;
  }
}

function persist(list: ProfissionalRecord[]) {
  ensureDir();
  cache = list;
  fs.writeFileSync(DATA_FILE, JSON.stringify(list, null, 2), 'utf8');
}

export function addProfissional(payload: Record<string, unknown>): ProfissionalRecord {
  const list = loadProfissionais();
  const payloadId = payload.id;
  const id =
    typeof payloadId === 'string' || typeof payloadId === 'number'
      ? payloadId
      : randomUUID();
  const record: ProfissionalRecord = {
    ...payload,
    id,
    nome: String(payload.nome ?? 'Sem nome'),
    cargo: String(payload.cargo ?? payload.perfil_acesso ?? 'Fiscal'),
    matricula: String(payload.matricula ?? `MAT-${String(list.length + 1).padStart(4, '0')}`),
    email: payload.email ?? null,
    telefone: payload.telefone ?? null,
    perfil_acesso: payload.perfil_acesso ?? 'FISCAL',
    status: String(payload.status ?? 'ATIVO').toUpperCase(),
  };
  list.unshift(record);
  persist(list);
  return record;
}

export function updateProfissional(
  id: string,
  payload: Record<string, unknown>,
): ProfissionalRecord | null {
  const list = loadProfissionais();
  const idx = list.findIndex((p) => String(p.id) === id);
  if (idx < 0) return null;
  list[idx] = { ...list[idx], ...payload, id: list[idx].id };
  persist(list);
  return list[idx];
}

export function replaceAll(list: ProfissionalRecord[]) {
  persist(list);
}
