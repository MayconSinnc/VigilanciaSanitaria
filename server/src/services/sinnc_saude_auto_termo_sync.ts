import fetch from 'node-fetch'

function normalizeStr(value: unknown) {
  if (value == null) return ''
  return String(value).trim()
}

function normalizeUpperSpaced(value: unknown) {
  const s = normalizeStr(value).toUpperCase()
  if (!s) return ''
  return s.replace(/_/g, ' ').replace(/\s+/g, ' ').trim()
}

function computeSyncStatus(situacao: unknown) {
  const s = normalizeUpperSpaced(situacao)
  if (!s) return 'PENDENTE'
  if (s === 'FINALIZADO' || s === 'SEM EFEITO') return 'SINCRONIZADO'
  return 'PENDENTE'
}

export async function syncAutoTermoToSaude(input: {
  chave_origem: string
  tipo_documento: string
  numero: string
  ano: number
  situacao: string
  estabelecimento_nome?: string
  estabelecimento_cnpj_cpf?: string
  fiscal_nome?: string
  conteudo?: unknown
  dispositivo?: string | null
  data_lavratura?: string | null
}) {
  const baseUrl = normalizeStr(process.env.SINNC_SAUDE_BASE_URL) || 'http://127.0.0.1:8080'
  const token = normalizeStr(process.env.SINNC_SAUDE_TOKEN)
  if (!token) return

  const url = `${baseUrl.replace(/\/$/, '')}/api/auto-termo/sincronizar`

  const documento = {
    tipo_documento: input.tipo_documento,
    numero: input.numero,
    ano: input.ano,
    situacao: input.situacao,
    status_sincronizacao: computeSyncStatus(input.situacao),
    origem: 'WEB',
    dispositivo: input.dispositivo ?? null,
    estabelecimento_nome: input.estabelecimento_nome || '',
    estabelecimento_cnpj_cpf: input.estabelecimento_cnpj_cpf || '',
    fiscal_nome: input.fiscal_nome || '',
    data_lavratura: input.data_lavratura || null,
    conteudo: input.conteudo ?? {},
  }

  const payload = {
    chave_origem: input.chave_origem,
    documento,
  }

  const resp = await fetch(url, {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      authorization: `Bearer ${token}`,
    },
    body: JSON.stringify(payload),
  })

  if (!resp.ok) {
    const txt = await resp.text().catch(() => '')
    throw new Error(`Falha ao sincronizar com SINNC Saúde (HTTP ${resp.status})${txt ? `: ${txt}` : ''}`)
  }
}
