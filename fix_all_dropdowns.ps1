# Comprehensive dropdown fixer for all Flutter files

Get-ChildItem -Path "mobile/lib/pages/*.dart" -Recurse | ForEach-Object {
    $file = $_.FullName
    $content = Get-Content $file -Raw
    $changed = $false
    
    # List of all dropdown patterns to fix (String to DropdownMenuItem)
    $patterns = @(
        @{ old = "items: const \['REGULAR', 'IRREGULAR', 'INTERDITADO'\],"; new = "items: const ['REGULAR', 'IRREGULAR', 'INTERDITADO']`n                        .map((String e) => DropdownMenuItem<String>(value: e, child: Text(e)))`n                        .toList()," },
        @{ old = "items: const \['BAIXO', 'MÉDIO', 'ALTO'\],"; new = "items: const ['BAIXO', 'MÉDIO', 'ALTO']`n                        .map((String e) => DropdownMenuItem<String>(value: e, child: Text(e)))`n                        .toList()," },
        @{ old = "items: const \['REGULAR', 'VENCIDO', 'PENDENTE'\],"; new = "items: const ['REGULAR', 'VENCIDO', 'PENDENTE']`n                        .map((String e) => DropdownMenuItem<String>(value: e, child: Text(e)))`n                        .toList()," },
        @{ old = "items: const \['Vigente', 'Vencido', 'Pendente', 'Cancelado', 'Em análise'\],"; new = "items: const ['Vigente', 'Vencido', 'Pendente', 'Cancelado', 'Em análise']`n                            .map((String e) => DropdownMenuItem<String>(value: e, child: Text(e)))`n                            .toList()," }
    )
    
    foreach($pattern in $patterns) {
        if ($content -like $pattern.old) {
            $content = $content -replace [regex]::Escape($pattern.old), $pattern.new
            $changed = $true
        }
    }
    
    if ($changed) {
        Set-Content $file -Value $content
        Write-Host "Corrigido: $file"
    }
}

Write-Host "Correção de dropdowns completa!"
