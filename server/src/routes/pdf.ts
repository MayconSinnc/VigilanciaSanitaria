import type { FastifyInstance } from 'fastify';
import PDFDocument from 'pdfkit';

export function registerPdfRoutes(app: FastifyInstance) {
  app.get('/inspecoes/:id/pdf', { preValidation: [app.authenticate] }, async (request, reply) => {
    const { id } = request.params as { id: string };
    const inspecao = await app.prisma.inspecao.findUnique({
      where: { id: Number(id) },
      include: { estabelecimento: true, fiscal: true, Intimacao: true, Infracao: true, Coleta: true, Assinatura: true, Fotos: true }
    });
    if (!inspecao) return reply.code(404).send({ error: 'Inspeção não encontrada' });

    const doc = new PDFDocument({ size: 'A4', margin: 50 });
    reply.header('Content-Type', 'application/pdf');
    reply.header('Content-Disposition', `inline; filename="auto_${inspecao.id}.pdf"`);
    const stream = reply.raw;
    doc.pipe(stream);

    doc.fontSize(18).text('Prefeitura Municipal', { align: 'center' });
    doc.moveDown();
    doc.fontSize(16).text('Vigilância Sanitária — Auto', { align: 'center' });
    doc.moveDown();

    doc.fontSize(12).text(`Número do Auto: ${inspecao.id}`);
    doc.text(`Tipo: ${inspecao.tipoAuto}`);
    doc.text(`Data: ${new Date(inspecao.data).toLocaleDateString()} ${inspecao.hora}`);
    doc.text(`Fiscal: ${inspecao.fiscal?.nome} — CPF ${inspecao.fiscal?.cpf}`);
    doc.moveDown();
    doc.text(`Estabelecimento: ${inspecao.estabelecimento?.nomeFantasia}`);
    doc.text(`CNPJ: ${inspecao.estabelecimento?.cnpj}`);
    doc.text(`Endereço: ${inspecao.estabelecimento?.endereco} — ${inspecao.estabelecimento?.cidade}/${inspecao.estabelecimento?.estado}`);
    doc.moveDown();

    if (inspecao.tipoAuto === 'INTIMACAO' && inspecao.Intimacao) {
      doc.text('Intimação', { underline: true });
      doc.text(`Irregularidade: ${inspecao.Intimacao.descricaoIrregularidade}`);
      doc.text(`Base Legal: ${inspecao.Intimacao.baseLegal}`);
      doc.text(`Prazo: ${new Date(inspecao.Intimacao.prazoRegularizacao).toLocaleDateString()}`);
      doc.text(`Penalidade Prevista: ${inspecao.Intimacao.penalidadePrevista}`);
      doc.moveDown();
    }
    if (inspecao.tipoAuto === 'INFRACAO' && inspecao.Infracao) {
      doc.text('Infração', { underline: true });
      doc.text(`Descrição: ${inspecao.Infracao.descricao}`);
      doc.text(`Base Legal: ${inspecao.Infracao.baseLegal}`);
      doc.text(`Gravidade: ${inspecao.Infracao.gravidade}`);
      if (inspecao.Infracao.valorMulta) doc.text(`Valor da Multa: R$ ${inspecao.Infracao.valorMulta.toFixed(2)}`);
      doc.moveDown();
    }
    if (inspecao.tipoAuto === 'COLETA' && inspecao.Coleta) {
      doc.text('Coleta de Amostra', { underline: true });
      doc.text(`Produto: ${inspecao.Coleta.produtoNome}`);
      if (inspecao.Coleta.marca) doc.text(`Marca: ${inspecao.Coleta.marca}`);
      if (inspecao.Coleta.lote) doc.text(`Lote: ${inspecao.Coleta.lote}`);
      if (inspecao.Coleta.quantidade) doc.text(`Quantidade: ${inspecao.Coleta.quantidade}`);
      doc.moveDown();
    }

    doc.text('Assinaturas', { underline: true });
    doc.text(`Fiscal: ${inspecao.Assinatura?.assinaturaFiscal ? 'Disponível' : 'Não registrada'}`);
    doc.text(`Responsável: ${inspecao.Assinatura?.assinaturaResponsavel ? 'Disponível' : 'Não registrada'}`);

    doc.end();
    return reply;
  });
}
