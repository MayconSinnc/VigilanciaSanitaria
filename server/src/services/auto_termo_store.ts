import fs from 'fs';
import path from 'path';
import { randomUUID } from 'crypto';

export type AutoTermoRecord = Record<string, unknown> & {
  id: string;
  createdAt: string;
};

const DATA_DIR = path.join(process.cwd(), 'data');
const DATA_FILE = path.join(DATA_DIR, 'auto_termo.json');

let cache: AutoTermoRecord[] | null = null;

function ensureDir() {
  if (!fs.existsSync(DATA_DIR)) {
    fs.mkdirSync(DATA_DIR, { recursive: true });
  }
}

export function loadAutoTermo(): AutoTermoRecord[] {
  if (cache) return cache;
  ensureDir();
  if (!fs.existsSync(DATA_FILE)) {
    cache = [];
    return cache;
  }
  try {
    const raw = JSON.parse(fs.readFileSync(DATA_FILE, 'utf8'));
    cache = Array.isArray(raw) ? (raw as AutoTermoRecord[]) : [];
    return cache;
  } catch {
    cache = [];
    return cache;
  }
}

function persist(list: AutoTermoRecord[]) {
  ensureDir();
  cache = list;
  fs.writeFileSync(DATA_FILE, JSON.stringify(list, null, 2), 'utf8');
}

export function addAutoTermo(payload: Record<string, unknown>): AutoTermoRecord {
  const list = loadAutoTermo();
  const record: AutoTermoRecord = {
    ...payload,
    id: randomUUID(),
    createdAt: new Date().toISOString(),
  };
  list.unshift(record);
  persist(list);
  return record;
}

export function toAutoTermoListItem(record: AutoTermoRecord): Record<string, unknown> {
  const dados = (record.dados_estabelecimento ?? {}) as Record<string, unknown>;
  const numeroAno = String(record.numero_ano ?? record.numeroAno ?? record.numero ?? '');
  const tipo = String(record.tipo_documento ?? record.tipoDocumento ?? '');
  const estab = String(dados.nome_fantasia ?? record.estabelecimento_nome ?? record.estabelecimento ?? '');
  const cnpj = String(dados.cnpj ?? record.estabelecimento_cnpj ?? record.cnpj ?? '');
  const fiscal = String(record.profissional_id ?? record.profissional ?? record.fiscal ?? '');
  const status = String(record.status ?? '');
  const dataHora = String(record.data_hora ?? record.dataHora ?? record.data ?? '');

  return {
    id: record.id,
    numero_ano: numeroAno,
    tipo_documento: tipo,
    estabelecimento: estab,
    cnpj,
    data_hora: dataHora,
    profissional: fiscal,
    status,
    payload: record,
  };
}

