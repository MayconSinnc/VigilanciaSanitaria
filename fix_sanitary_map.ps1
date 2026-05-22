# Fix specific dropdowns with exact spacing

$file = 'mobile/lib/pages/sanitary_map_page.dart'
$content = Get-Content $file -Raw

# Fix all dropdowns in this file
$content = $content -replace "items: const \['REGULAR', 'IRREGULAR', 'INTERDITADO'\],", "items: const ['REGULAR', 'IRREGULAR', 'INTERDITADO']`n                        .map((String e) => DropdownMenuItem<String>(value: e, child: Text(e)))`n                        .toList(),"

$content = $content -replace "items: const \['BAIXO', 'MÉDIO', 'ALTO'\],", "items: const ['BAIXO', 'MÉDIO', 'ALTO']`n                        .map((String e) => DropdownMenuItem<String>(value: e, child: Text(e)))`n                        .toList(),"

$content = $content -replace "items: const \['REGULAR', 'VENCIDO', 'PENDENTE'\],", "items: const ['REGULAR', 'VENCIDO', 'PENDENTE']`n                        .map((String e) => DropdownMenuItem<String>(value: e, child: Text(e)))`n                        .toList(),"

Set-Content $file -Value $content
Write-Host "Corrigido sanitary_map_page.dart"

# Also fix hintText -> placeholder
$content = Get-Content $file -Raw
$content = $content -replace "hintText:", "placeholder:"
Set-Content $file -Value $content
Write-Host "Corrigido hintText em sanitary_map_page.dart"
