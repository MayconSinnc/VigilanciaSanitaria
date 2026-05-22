import fs from 'fs';
import path from 'path';
import { randomUUID } from 'crypto';

export type HabiteSeRecord = Record<string, unknown> & {
  id: string;
  protocolo: string;
  createdAt: string;
};

const DATA_DIR = path.join(process.cwd(), 'data');
const DATA_FILE = path.join(DATA_DIR, 'habite_se.json');

let cache: HabiteSeRecord[] | null = null;

function ensureDir() {
  if (!fs.existsSync(DATA_DIR)) {
    fs.mkdirSync(DATA_DIR, { recursive: true });
  }
}

export function loadHabiteSe(): HabiteSeRecord[] {
  if (cache) return cache;
  ensureDir();
  if (!fs.existsSync(DATA_FILE)) {
    cache = [];
    return cache;
  }
  try {
    const raw = JSON.parse(fs.readFileSync(DATA_FILE, 'utf8'));
    cache = Array.isArray(raw) ? (raw as HabiteSeRecord[]) : [];
    return cache;
  } catch {
    cache = [];
    return cache;
  }
}

function persist(list: HabiteSeRecord[]) {
  ensureDir();
  cache = list;
  fs.writeFileSync(DATA_FILE, JSON.stringify(list, null, 2), 'utf8');
}

export function addHabiteSe(payload: Record<string, unknown>): HabiteSeRecord {
  const list = loadHabiteSe();
  const year = new Date().getFullYear();
  const protocolo =
    String(payload.protocolo ?? '').trim() ||
    `HBS-${year}-${String(list.length + 1).padStart(4, '0')}`;

  const record: HabiteSeRecord = {
    ...payload,
    id: randomUUID(),
    protocolo,
    createdAt: new Date().toISOString(),
    data_solicitacao:
      payload.data_solicitacao ?? new Date().toISOString().slice(0, 10),
    status: payload.status ?? 'EM_ANALISE',
  };

  list.unshift(record);
  persist(list);
  return record;
}

export function toListItem(record: HabiteSeRecord): Record<string, unknown> {
  const emp = (record.empreendimento ?? {}) as Record<string, unknown>;
  const end = (record.endereco ?? {}) as Record<string, unknown>;
  const enderecoParts = [
    end.logradouro,
    end.numero,
    end.bairro,
    end.cidade,
    end.estado ?? end.uf,
  ]
    .map((p) => (p == null ? '' : String(p).trim()))
    .filter((p) => p.length > 0);

  const nome = String(
    emp.nome ?? record.nome_empreendimento ?? record.requerente ?? '',
  );

  return {
    ...record,
    protocolo: record.protocolo,
    requerente: nome,
    empreendimento: nome,
    nome_empreendimento: nome,
    endereco: enderecoParts.length > 0 ? enderecoParts.join(', ') : record.endereco,
    data: record.data_solicitacao,
    data_solicitacao: record.data_solicitacao,
    status: record.status,
    cnpj: emp.cnpj ?? record.cnpj,
    tipo: record.tipo,
  };
}
