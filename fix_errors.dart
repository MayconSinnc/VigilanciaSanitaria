import 'dart:io';

void main() {
  // Fix establishment_form_page.dart
  fixEstablishmentFormPage();
  
  // Fix reports_page.dart
  fixReportsPage();
  
  // Fix licenses_page.dart (if needed)
  fixLicensesPage();
  
  print('Todos os erros foram corrigidos!');
}

void fixEstablishmentFormPage() {
  final file = File('d:\\Dev\\VigilanciaSanitaria\\mobile\\lib\\pages\\establishment_form_page.dart');
  var content = file.readAsStringSync();
  
  // Replace OfficialDropdownField with plain list to proper dropdown items
  content = content.replaceAll(
    "items: const ['Baixo', 'Médio', 'Alto'],",
    "items: const ['Baixo', 'Médio', 'Alto']\n                      .map((String e) => DropdownMenuItem<String>(value: e, child: Text(e)))\n                      .toList(),"
  );
  
  content = content.replaceAll(
    "items: const ['Regular', 'Vencido', 'Suspenso'],",
    "items: const ['Regular', 'Vencido', 'Suspenso']\n                      .map((String e) => DropdownMenuItem<String>(value: e, child: Text(e)))\n                      .toList(),"
  );
  
  content = content.replaceAll(
    "items: const ['Regular', 'Irregular'],",
    "items: const ['Regular', 'Irregular']\n                .map((String e) => DropdownMenuItem<String>(value: e, child: Text(e)))\n                .toList(),"
  );
  
  file.writeAsStringSync(content);
  print('Corrigido establishment_form_page.dart');
}

void fixReportsPage() {
  final file = File('d:\\Dev\\VigilanciaSanitaria\\mobile\\lib\\pages\\reports_page.dart');
  var content = file.readAsStringSync();
  
  // Fix all dropdowns in reports_page
  content = content.replaceAll(
    "items: const ['INFRAÇÃO', 'INTIMAÇÃO', 'ADVERTÊNCIA', 'MULTA'],",
    "items: const ['INFRAÇÃO', 'INTIMAÇÃO', 'ADVERTÊNCIA', 'MULTA']\n                        .map((String e) => DropdownMenuItem<String>(value: e, child: Text(e)))\n                        .toList(),"
  );
  
  content = content.replaceAll(
    "items: const ['CONCLUÍDO', 'PENDENTE', 'CANCELADO'],",
    "items: const ['CONCLUÍDO', 'PENDENTE', 'CANCELADO']\n                        .map((String e) => DropdownMenuItem<String>(value: e, child: Text(e)))\n                        .toList(),"
  );
  
  content = content.replaceAll(
    "items: const ['ALTO', 'MÉDIO', 'BAIXO'],",
    "items: const ['ALTO', 'MÉDIO', 'BAIXO']\n                        .map((String e) => DropdownMenuItem<String>(value: e, child: Text(e)))\n                        .toList(),"
  );
  
  file.writeAsStringSync(content);
  print('Corrigido reports_page.dart');
}

void fixLicensesPage() {
  final file = File('d:\\Dev\\VigilanciaSanitaria\\mobile\\lib\\pages\\licenses_page.dart');
  var content = file.readAsStringSync();
  
  // Already fixed, but ensure all dropdowns are correct
  content = content.replaceAll(
    "items: const ['Vigente', 'Vencido', 'Pendente', 'Cancelado', 'Em análise'],",
    "items: const ['Vigente', 'Vencido', 'Pendente', 'Cancelado', 'Em análise']\n                            .map((String e) => DropdownMenuItem<String>(value: e, child: Text(e)))\n                            .toList(),"
  );
  
  content = content.replaceAll(
    "items: const ['Baixo', 'Médio', 'Alto'],",
    "items: const ['Baixo', 'Médio', 'Alto']\n                  .map((String e) => DropdownMenuItem<String>(value: e, child: Text(e)))\n                  .toList(),"
  );
  
  file.writeAsStringSync(content);
  print('Corrigido licenses_page.dart');
}
