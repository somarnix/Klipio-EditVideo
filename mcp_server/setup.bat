@echo off
REM ============================================================================
REM Klipio MCP Server - Setup Script
REM ============================================================================

echo.
echo ╔══════════════════════════════════════════════════════════════════════════╗
echo ║                                                                          ║
echo ║              🤖 KLIPIO MCP SERVER - SETUP 🤖                             ║
echo ║                                                                          ║
echo ╚══════════════════════════════════════════════════════════════════════════╝
echo.

cd /d "G:\Klipio EditVideo\Klipio\mcp_server"

echo [1/5] Checking Python installation...
python --version
if errorlevel 1 (
    echo.
    echo ❌ ERROR: Python not found!
    echo Please install Python 3.7+ from https://www.python.org/downloads/
    pause
    exit /b 1
)

echo.
echo [2/5] Creating virtual environment...
if exist venv (
    echo Virtual environment already exists, skipping...
) else (
    python -m venv venv
    echo ✅ Virtual environment created
)

echo.
echo [3/5] Activating virtual environment...
call venv\Scripts\activate.bat

echo.
echo [4/5] Installing dependencies...
pip install -r requirements.txt

if errorlevel 1 (
    echo.
    echo ❌ ERROR: Failed to install dependencies
    echo Please check your internet connection and try again
    pause
    exit /b 1
)

echo.
echo [5/5] Setting up Claude Desktop config...
set CLAUDE_CONFIG=%APPDATA%\Claude\claude_desktop_config.json

if not exist "%APPDATA%\Claude" (
    echo Creating Claude config directory...
    mkdir "%APPDATA%\Claude"
)

if exist "%CLAUDE_CONFIG%" (
    echo.
    echo ⚠️  Claude Desktop config already exists
    echo Please manually add the Klipio MCP server to:
    echo %CLAUDE_CONFIG%
    echo.
    echo Add this section:
    type claude_desktop_config.json
    echo.
) else (
    echo Creating new Claude Desktop config...
    copy claude_desktop_config.json "%CLAUDE_CONFIG%"
    echo ✅ Claude Desktop config created
)

echo.
echo ╔══════════════════════════════════════════════════════════════════════════╗
echo ║                                                                          ║
echo ║                        ✅ SETUP COMPLETE! ✅                              ║
echo ║                                                                          ║
echo ╚══════════════════════════════════════════════════════════════════════════╝
echo.
echo 🎉 Klipio MCP Server is ready!
echo.
echo NEXT STEPS:
echo.
echo 1. Launch Klipio video editor
echo 2. Go to Settings
echo 3. Enable "AI Control (MCP)"
echo 4. Restart Claude Desktop
echo 5. Ask Claude: "What Klipio tools do you have?"
echo.
echo MANUAL TEST:
echo    python klipio_mcp_server.py
echo.
echo For help, see: README.md
echo.
pause
