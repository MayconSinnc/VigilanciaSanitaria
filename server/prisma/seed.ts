import { PrismaClient } from '@prisma/client';
const prisma = new PrismaClient();

async function main() {
  const user = await prisma.usuario.upsert({
    where: { cpf: '00000000000' },
    update: {},
    create: {
      nome: 'Fiscal Teste',
      cpf: '00000000000',
      cargo: 'Fiscal',
      email: 'fiscal@prefeitura.gov.br',
      senhaHash: 'senha123'
    }
  });

  await prisma.usuario.upsert({
    where: { cpf: '12345678909' },
    update: {},
    create: {
      nome: 'Administrador do Sistema',
      cpf: '12345678909',
      cargo: 'Administrador',
      email: 'admin@prefeitura.gov.br',
      senhaHash: 'senha123'
    }
  });

  await prisma.estabelecimento.upsert({
    where: { cnpj: '12.345.678/0001-99' },
    update: {},
    create: {
      cnpj: '12.345.678/0001-99',
      razaoSocial: 'Padaria Pão Quente LTDA',
      nomeFantasia: 'Padaria Pão Quente',
      endereco: 'Rua das Flores, 123',
      cidade: 'Cidade',
      estado: 'UF',
      bairro: 'Centro',
      telefone: '(11) 9999-9999',
      responsavel: 'João da Silva'
    }
  });

  console.log('Seed concluído. Usuários: 00000000000/senha123 e 12345678909/senha123');
}

main().finally(async () => {
  await prisma.$disconnect();
});
