:: proton-qbt-sync - Synchronize Proton VPN forwarded ports with qBittorrent on Windows.
:: Copyright (C) 2026 Matisse-Krn
:: SPDX-License-Identifier: GPL-3.0-or-later





@echo off
setlocal EnableExtensions

set "SCRIPT=%~dp0Setup-qbt-proton.ps1"

if not exist "%SCRIPT%" (
	echo Setup-qbt-proton.ps1 was not found next to this launcher.
	echo Expected path:
	echo   %SCRIPT%
	echo.
	pause
	exit /b 1
)

echo Starting setup...
echo If administrator privileges are required, accept the UAC prompt.
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" -PauseOnExit

if errorlevel 1 (
	echo.
	echo Setup failed.
	pause
	exit /b 1
)

endlocal
