# Fix dropdowns in Flutter files

# Fix establishment_form_page.dart
$file = 'mobile/lib/pages/establishment_form_page.dart'
$content = Get-Content $file -Raw

# Replace all dropdown string lists with proper DropdownMenuItems
$replacements = @{
    "items: const ['Baixo', 'Médio', 'Alto']," = "items: const ['Baixo', 'Médio', 'Alto']`n                      .map((String e) => DropdownMenuItem<String>(value: e, child: Text(e)))`n                      .toList(),"
    "items: const ['Regular', 'Vencido', 'Suspenso']," = "items: const ['Regular', 'Vencido', 'Suspenso']`n                      .map((String e) => DropdownMenuItem<String>(value: e, child: Text(e)))`n                      .toList(),"
    "items: const ['Regular', 'Irregular']," = "items: const ['Regular', 'Irregular']`n                .map((String e) => DropdownMenuItem<String>(value: e, child: Text(e)))`n                .toList(),"
}

foreach($key in $replacements.Keys) {
    if ($content.Contains($key)) {
        $content = $content.Replace($key, $replacements[$key])
        Write-Host "Corrigido: $key"
    }
}

Set-Content $file -Value $content

# Fix reports_page.dart
$file = 'mobile/lib/pages/reports_page.dart'
$content = Get-Content $file -Raw

$replacements2 = @{
    "items: const ['INFRAÇÃO', 'INTIMAÇÃO', 'ADVERTÊNCIA', 'MULTA']," = "items: const ['INFRAÇÃO', 'INTIMAÇÃO', 'ADVERTÊNCIA', 'MULTA']`n                        .map((String e) => DropdownMenuItem<String>(value: e, child: Text(e)))`n                        .toList(),"
    "items: const ['CONCLUÍDO', 'PENDENTE', 'CANCELADO']," = "items: const ['CONCLUÍDO', 'PENDENTE', 'CANCELADO']`n                        .map((String e) => DropdownMenuItem<String>(value: e, child: Text(e)))`n                        .toList(),"
    "items: const ['ALTO', 'MÉDIO', 'BAIXO']," = "items: const ['ALTO', 'MÉDIO', 'BAIXO']`n                        .map((String e) => DropdownMenuItem<String>(value: e, child: Text(e)))`n                        .toList(),"
}

foreach($key in $replacements2.Keys) {
    if ($content.Contains($key)) {
        $content = $content.Replace($key, $replacements2[$key])
        Write-Host "Corrigido: $key"
    }
}

Set-Content $file -Value $content

Write-Host "Erros de dropdown corrigidos!"
