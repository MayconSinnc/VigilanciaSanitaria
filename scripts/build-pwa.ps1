# Gera ícones PWA e build web release
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$flutter = Join-Path $root 'flutter\bin\flutter.bat'
$mobile = Join-Path $root 'mobile'

Push-Location $mobile
try {
  & $flutter pub get
  & (Join-Path (Split-Path -Parent $flutter) 'dart.bat') run flutter_launcher_icons
  & $flutter build web --release --no-wasm-dry-run
  Write-Host ''
  Write-Host 'PWA pronto em mobile\build\web' -ForegroundColor Green
  Write-Host 'Inicie: node serve-web.js (na raiz do projeto)' -ForegroundColor Cyan
  Write-Host 'Instalar: abra http://localhost:8080 no Chrome/Edge > Instalar aplicativo' -ForegroundColor Cyan
}
finally {
  Pop-Location
}
