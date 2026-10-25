@echo off
title WordFS Backend (Spring Boot)

REM ============================================
REM  WordFS 后端一键启动（直接运行已打好的 jar）
REM  前置条件:
REM    1. MySQL 已启动（XAMPP Control Panel 里 Start MySQL）
REM    2. JDK 17+ 已安装（默认使用 D:\java）
REM ============================================

set JAVA_HOME=D:\java
set PATH=%JAVA_HOME%\bin;%PATH%
cd /d "%~dp0"

echo [1/3] 检查 MySQL (端口 3306) ...
netstat -ano | findstr ":3306 " | findstr "LISTENING" >nul
if errorlevel 1 (
  echo     [错误] MySQL 未启动。请先在 XAMPP Control Panel 点击 Start MySQL。
  pause
  exit /b 1
)
echo      MySQL OK

echo [2/3] 检查后端端口 8080 ...
for /f "tokens=5" %%a in ('netstat -ano ^| findstr ":8080 " ^| findstr "LISTENING"') do (
  echo      端口 8080 被 PID %%a 占用，正在结束该进程 ...
  taskkill /F /PID %%a >nul 2>&1
  timeout /t 2 /nobreak >nul
)
echo      端口 8080 OK

echo [3/3] 启动 Spring Boot 后端（看到 "Started" 即成功，请勿关闭本窗口）...
echo.

if not exist "target\demo_backend-0.0.1-SNAPSHOT.jar" (
  echo     [错误] 未找到 target\demo_backend-0.0.1-SNAPSHOT.jar，请先执行 mvn clean package -DskipTests
  pause
  exit /b 1
)

java -jar "target\demo_backend-0.0.1-SNAPSHOT.jar"

pause
