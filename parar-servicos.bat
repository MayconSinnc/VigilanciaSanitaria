@echo off
chcp 65001 >nul
setlocal EnableExtensions

echo.
echo  Parando servicos nas portas 3000 e 8080...
echo.

for %%P in (3000 8080) do (
  for /f "tokens=5" %%A in ('netstat -ano ^| findstr ":%%P " ^| findstr "LISTENING"') do (
    echo  Encerrando PID %%A na porta %%P
    taskkill /PID %%A /F >nul 2>&1
  )
)

echo.
echo  Concluido.
pause
