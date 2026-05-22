import type { FastifyInstance } from 'fastify';
import { registerAuthRoutes } from './auth.js';
import { registerEstabelecimentosRoutes } from './estabelecimentos.js';
import { registerInspecoesRoutes } from './inspecoes.js';
import { registerFotosRoutes } from './fotos.js';
import { registerPenalidadesRoutes } from './penalidades.js';
import { registerSyncRoutes } from './sync.js';
import { registerPdfRoutes } from './pdf.js';
import { registerEpublicaRoutes } from './epublica.js';
import { registerCnpjRoutes } from './cnpj.js';
import { registerEstabelecimentosApi } from './estabelecimentos_api.js';
import { registerIntegracoesRoutes } from './integracoes.js';
import { registerAlvarasRoutes } from './alvaras.js';
import { registerHabiteSeRoutes } from './habite_se.js';
import { registerProfissionaisRoutes } from './profissionais.js';
import { registerDashboardRoutes } from './dashboard.js';
import { registerAutoTermoRoutes } from './auto_termo.js';

export function routes(app: FastifyInstance) {
  app.get('/health', async () => ({ status: 'ok' }));
  registerAuthRoutes(app);
  app.addHook('onRoute', (route) => {
    // placeholder for audit logging hook
  });
  registerEstabelecimentosRoutes(app);
  registerInspecoesRoutes(app);
  registerFotosRoutes(app);
  registerPenalidadesRoutes(app);
  registerSyncRoutes(app);
  registerPdfRoutes(app);
  registerEpublicaRoutes(app);
  registerCnpjRoutes(app);
  registerEstabelecimentosApi(app);
  registerIntegracoesRoutes(app);
  registerAlvarasRoutes(app);
  registerHabiteSeRoutes(app);
  registerProfissionaisRoutes(app);
  registerAutoTermoRoutes(app);
  registerDashboardRoutes(app);
}
