import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

try {
  await prisma.baseLegalItemConfig.findFirst();
  console.log('ok');
} finally {
  await prisma.$disconnect();
}

