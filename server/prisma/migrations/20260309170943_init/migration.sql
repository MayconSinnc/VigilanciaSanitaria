-- CreateTable
CREATE TABLE "Usuario" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "nome" TEXT NOT NULL,
    "cpf" TEXT NOT NULL,
    "cargo" TEXT,
    "email" TEXT,
    "senhaHash" TEXT NOT NULL,
    "createdAt" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" DATETIME NOT NULL
);

-- CreateTable
CREATE TABLE "Estabelecimento" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "cnpj" TEXT NOT NULL,
    "razaoSocial" TEXT NOT NULL,
    "nomeFantasia" TEXT NOT NULL,
    "endereco" TEXT NOT NULL,
    "cidade" TEXT NOT NULL,
    "estado" TEXT NOT NULL,
    "bairro" TEXT,
    "inscricaoMunicipal" TEXT,
    "latitude" REAL,
    "longitude" REAL,
    "telefone" TEXT,
    "responsavel" TEXT,
    "createdAt" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" DATETIME NOT NULL
);

-- CreateTable
CREATE TABLE "Inspecao" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "tipoAuto" TEXT NOT NULL,
    "estabelecimentoId" INTEGER NOT NULL,
    "fiscalId" INTEGER NOT NULL,
    "data" DATETIME NOT NULL,
    "hora" TEXT NOT NULL,
    "descricao" TEXT,
    "situacao" TEXT,
    "gpsLatitude" REAL,
    "gpsLongitude" REAL,
    "status" TEXT,
    "createdAt" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" DATETIME NOT NULL,
    "penalidadeId" INTEGER,
    CONSTRAINT "Inspecao_estabelecimentoId_fkey" FOREIGN KEY ("estabelecimentoId") REFERENCES "Estabelecimento" ("id") ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT "Inspecao_fiscalId_fkey" FOREIGN KEY ("fiscalId") REFERENCES "Usuario" ("id") ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT "Inspecao_penalidadeId_fkey" FOREIGN KEY ("penalidadeId") REFERENCES "Penalidade" ("id") ON DELETE SET NULL ON UPDATE CASCADE
);

-- CreateTable
CREATE TABLE "Foto" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "inspecaoId" INTEGER NOT NULL,
    "url" TEXT NOT NULL,
    "data" DATETIME NOT NULL,
    "gpsLatitude" REAL,
    "gpsLongitude" REAL,
    "dispositivo" TEXT,
    "resolucao" TEXT,
    "createdAt" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "Foto_inspecaoId_fkey" FOREIGN KEY ("inspecaoId") REFERENCES "Inspecao" ("id") ON DELETE RESTRICT ON UPDATE CASCADE
);

-- CreateTable
CREATE TABLE "Penalidade" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "descricao" TEXT NOT NULL,
    "codigoLegal" TEXT NOT NULL,
    "valor" REAL,
    "valorMinimo" REAL,
    "valorMaximo" REAL,
    "createdAt" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- CreateTable
CREATE TABLE "Auditoria" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "usuarioId" INTEGER,
    "acao" TEXT NOT NULL,
    "data" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "hora" TEXT NOT NULL,
    "gps" TEXT,
    "dispositivo" TEXT,
    "ip" TEXT,
    "inspecaoId" INTEGER,
    CONSTRAINT "Auditoria_usuarioId_fkey" FOREIGN KEY ("usuarioId") REFERENCES "Usuario" ("id") ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT "Auditoria_inspecaoId_fkey" FOREIGN KEY ("inspecaoId") REFERENCES "Inspecao" ("id") ON DELETE SET NULL ON UPDATE CASCADE
);

-- CreateTable
CREATE TABLE "Intimacao" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "inspecaoId" INTEGER NOT NULL,
    "descricaoIrregularidade" TEXT NOT NULL,
    "baseLegal" TEXT NOT NULL,
    "prazoRegularizacao" DATETIME NOT NULL,
    "penalidadePrevista" TEXT NOT NULL,
    CONSTRAINT "Intimacao_inspecaoId_fkey" FOREIGN KEY ("inspecaoId") REFERENCES "Inspecao" ("id") ON DELETE RESTRICT ON UPDATE CASCADE
);

-- CreateTable
CREATE TABLE "Infracao" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "inspecaoId" INTEGER NOT NULL,
    "descricao" TEXT NOT NULL,
    "baseLegal" TEXT NOT NULL,
    "gravidade" TEXT NOT NULL,
    "penalidadeId" INTEGER,
    "valorMulta" REAL,
    CONSTRAINT "Infracao_inspecaoId_fkey" FOREIGN KEY ("inspecaoId") REFERENCES "Inspecao" ("id") ON DELETE RESTRICT ON UPDATE CASCADE
);

-- CreateTable
CREATE TABLE "ColetaAmostra" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "inspecaoId" INTEGER NOT NULL,
    "produtoNome" TEXT NOT NULL,
    "marca" TEXT,
    "lote" TEXT,
    "dataFabricacao" DATETIME,
    "dataValidade" DATETIME,
    "quantidade" REAL NOT NULL,
    "temperatura" REAL,
    "condicaoProduto" TEXT,
    "destinoLaboratorio" TEXT NOT NULL,
    CONSTRAINT "ColetaAmostra_inspecaoId_fkey" FOREIGN KEY ("inspecaoId") REFERENCES "Inspecao" ("id") ON DELETE RESTRICT ON UPDATE CASCADE
);

-- CreateTable
CREATE TABLE "Assinatura" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "inspecaoId" INTEGER NOT NULL,
    "assinaturaFiscal" TEXT NOT NULL,
    "assinaturaResponsavel" TEXT,
    "dataAssinatura" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "Assinatura_inspecaoId_fkey" FOREIGN KEY ("inspecaoId") REFERENCES "Inspecao" ("id") ON DELETE RESTRICT ON UPDATE CASCADE
);

-- CreateIndex
CREATE UNIQUE INDEX "Usuario_cpf_key" ON "Usuario"("cpf");

-- CreateIndex
CREATE UNIQUE INDEX "Usuario_email_key" ON "Usuario"("email");

-- CreateIndex
CREATE UNIQUE INDEX "Estabelecimento_cnpj_key" ON "Estabelecimento"("cnpj");

-- CreateIndex
CREATE UNIQUE INDEX "Intimacao_inspecaoId_key" ON "Intimacao"("inspecaoId");

-- CreateIndex
CREATE UNIQUE INDEX "Infracao_inspecaoId_key" ON "Infracao"("inspecaoId");

-- CreateIndex
CREATE UNIQUE INDEX "ColetaAmostra_inspecaoId_key" ON "ColetaAmostra"("inspecaoId");

-- CreateIndex
CREATE UNIQUE INDEX "Assinatura_inspecaoId_key" ON "Assinatura"("inspecaoId");
