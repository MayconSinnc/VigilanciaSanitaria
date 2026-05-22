@echo off
chcp 65001 >nul
setlocal EnableExtensions

cd /d "%~dp0"
set "ROOT=%cd%"

title Vigilancia Sanitaria - Iniciar servicos

echo.
echo  ============================================
echo   Vigilancia Sanitaria - Iniciando servicos
echo  ============================================
echo.

where node >nul 2>&1
if errorlevel 1 (
  echo [ERRO] Node.js nao encontrado. Instale: https://nodejs.org/
  pause
  exit /b 1
)

where npm >nul 2>&1
if errorlevel 1 (
  echo [ERRO] npm nao encontrado.
  pause
  exit /b 1
)

if not exist "%ROOT%\server\package.json" (
  echo [ERRO] Pasta server nao encontrada em %ROOT%
  pause
  exit /b 1
)

if not exist "%ROOT%\serve-web.js" (
  echo [ERRO] serve-web.js nao encontrado em %ROOT%
  pause
  exit /b 1
)

if not exist "%ROOT%\mobile\build\web\main.dart.js" (
  echo [AVISO] Build web ausente. Execute antes:
  echo   cd mobile
  echo   ..\flutter\bin\flutter.bat build web --release
  echo.
)

echo [1/2] Backend API  - porta 3000
start "Vigilancia - Backend :3000" cmd /k "cd /d "%ROOT%\server" && npm run dev"

echo [2/2] Frontend PWA - porta 8080 ^(proxy da API^)
timeout /t 3 /nobreak >nul
start "Vigilancia - Frontend :8080" cmd /k "cd /d "%ROOT%" && set HOST=0.0.0.0&& set PORT=8080&& set BACKEND_HOST=127.0.0.1&& set BACKEND_PORT=3000&& node serve-web.js"

echo.
echo  Servicos iniciados em janelas separadas.
echo.
echo  Acesso local:  http://localhost:8080
echo  API interna:   http://127.0.0.1:3000 ^(via proxy na 8080^)
echo.
echo  Login de teste:
echo    CPF:   00000000000
echo    Senha: senha123
echo.
echo  Na VPN use o IP que aparece na janela do Frontend ^(ex.: http://10.8.0.31:8080^)
echo  Campo Servidor no app: mesma URL do navegador ^(porta 8080^)
echo.
echo  Feche as janelas "Backend" e "Frontend" para parar os servicos.
echo.
pause
