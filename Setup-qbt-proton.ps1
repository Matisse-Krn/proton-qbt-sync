# proton-qbt-sync — Synchronize Proton VPN forwarded ports with qBittorrent on Windows.
# Copyright (C) 2026 <Matisse-Krn>
# SPDX-License-Identifier: GPL-3.0-or-later





param(
	[string]$InstallDir = "",
	[string]$QbtBaseUrl = "http://127.0.0.1:8080",
	[string]$QbtUsername = "admin",
	[string]$ProtonLogPath = "$env:LOCALAPPDATA\Proton\Proton VPN\Logs\client-logs.txt",
	[string]$TaskName = "Update qBittorrent Proton forwarded port",
	[int]$IntervalMinutes = 2,
	[int]$MaxLogSizeKB = 1024,
	[int]$MaxLogBackups = 3,
	[string]$StartImmediately = "true",
	[switch]$PauseOnExit
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$script:ShouldPauseOnExit = [bool]$PauseOnExit
$script:RepositoryDir = $PSScriptRoot

function Wait-BeforeExit {
	if ($script:ShouldPauseOnExit) {
		Write-Host ""
		Write-Host "Press any key to close this window."
		& $env:ComSpec /c "pause >nul"
	}
}

function ConvertTo-BooleanSetting {
	param([object]$Value)

	if ($null -eq $Value) {
		return $false
	}

	if ($Value -is [bool]) {
		return [bool]$Value
	}

	$text = ([string]$Value).Trim().ToLowerInvariant()

	if ($text -in @("1", "true", "$true", "yes", "y", "on")) {
		return $true
	}

	if ($text -in @("0", "false", "$false", "no", "n", "off")) {
		return $false
	}

	throw "Invalid boolean value for StartImmediately: $Value. Use true or false."
}

function Test-IsAdministrator {
	$currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
	$principal = [Security.Principal.WindowsPrincipal]::new($currentIdentity)
	return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function ConvertTo-CmdQuotedValue {
	param([string]$Value)

	if ($null -eq $Value) {
		return '""'
	}

	return '"' + ($Value -replace '"', '""') + '"'
}

function Resolve-InstallationDirectory {
	param([string]$RequestedPath)

	if (-not [string]::IsNullOrWhiteSpace($RequestedPath)) {
		$expandedPath = [Environment]::ExpandEnvironmentVariables($RequestedPath)
		return [System.IO.Path]::GetFullPath($expandedPath)
	}

	$defaultPath = Join-Path $env:LOCALAPPDATA "Scripts\qbt-proton"

	Write-Host ""
	Write-Host "Installation directory"
	Write-Host "Default: $defaultPath"
	$userPath = Read-Host "Press Enter to use the default path, or type a custom absolute path"

	if ([string]::IsNullOrWhiteSpace($userPath)) {
		return [System.IO.Path]::GetFullPath($defaultPath)
	}

	$expandedUserPath = [Environment]::ExpandEnvironmentVariables($userPath)
	return [System.IO.Path]::GetFullPath($expandedUserPath)
}

function Copy-FileIfNeeded {
	param(
		[string]$Source,
		[string]$Destination
	)

	$sourceFullPath = [System.IO.Path]::GetFullPath($Source)
	$destinationFullPath = [System.IO.Path]::GetFullPath($Destination)

	if (-not (Test-Path $sourceFullPath)) {
		throw "Missing required source file: $sourceFullPath"
	}

	if ($sourceFullPath.ToLowerInvariant() -eq $destinationFullPath.ToLowerInvariant()) {
		return
	}

	Copy-Item -Path $sourceFullPath -Destination $destinationFullPath -Force
}

function Restart-Elevated {
	$powerShellPath = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"
	$cmdPath = $env:ComSpec
	$scriptPath = $PSCommandPath

	if ([string]::IsNullOrWhiteSpace($scriptPath)) {
		throw "Unable to determine the setup script path."
	}

	$tempLauncher = Join-Path $env:TEMP ("qbt-proton-setup-elevated-{0}.cmd" -f ([guid]::NewGuid().ToString("N")))
	$startImmediatelyValue = if (ConvertTo-BooleanSetting -Value $StartImmediately) { "true" } else { "false" }

	$setupCommand = @(
		(ConvertTo-CmdQuotedValue $powerShellPath),
		"-NoProfile",
		"-ExecutionPolicy", "Bypass",
		"-File", (ConvertTo-CmdQuotedValue $scriptPath),
		"-InstallDir", (ConvertTo-CmdQuotedValue $InstallDir),
		"-QbtBaseUrl", (ConvertTo-CmdQuotedValue $QbtBaseUrl),
		"-QbtUsername", (ConvertTo-CmdQuotedValue $QbtUsername),
		"-ProtonLogPath", (ConvertTo-CmdQuotedValue $ProtonLogPath),
		"-TaskName", (ConvertTo-CmdQuotedValue $TaskName),
		"-IntervalMinutes", $IntervalMinutes,
		"-MaxLogSizeKB", $MaxLogSizeKB,
		"-MaxLogBackups", $MaxLogBackups,
		"-StartImmediately", $startImmediatelyValue
	) -join " "

	@"
@echo off
title qBittorrent Proton Port Sync Setup
cd /d $(ConvertTo-CmdQuotedValue $script:RepositoryDir)
$setupCommand
set "SETUP_EXIT_CODE=%ERRORLEVEL%"
echo.
if not "%SETUP_EXIT_CODE%"=="0" echo Setup failed with exit code %SETUP_EXIT_CODE%.
echo Press any key to close this window.
pause >nul
exit /b %SETUP_EXIT_CODE%
"@ | Set-Content -Path $tempLauncher -Encoding ASCII

	Start-Process `
		-FilePath $cmdPath `
		-Verb RunAs `
		-ArgumentList "/c `"$tempLauncher`""
}

function Write-Step {
	param([string]$Message)
	Write-Host "[setup] $Message"
}

function Test-WebEndpoint {
	param([string]$BaseUrl)

	try {
		Invoke-WebRequest `
			-UseBasicParsing `
			-Uri $BaseUrl `
			-Method Get `
			-Headers @{
				Referer = "$BaseUrl/"
				Origin = $BaseUrl
			} `
			-TimeoutSec 5 | Out-Null

		return $true
	}
	catch {
		$response = $_.Exception.Response

		if ($response -and (
			[int]$response.StatusCode -eq 401 -or
			[int]$response.StatusCode -eq 403
		)) {
			return $true
		}

		return $false
	}
}

function Test-QBittorrentLogin {
	param(
		[string]$BaseUrl,
		[string]$Username,
		[string]$Password
	)

	$session = New-Object Microsoft.PowerShell.Commands.WebRequestSession

	try {
		$response = Invoke-WebRequest `
			-UseBasicParsing `
			-Uri "$BaseUrl/api/v2/auth/login" `
			-Method Post `
			-WebSession $session `
			-Headers @{
				Referer = "$BaseUrl/"
				Origin = $BaseUrl
			} `
			-ContentType "application/x-www-form-urlencoded" `
			-Body @{
				username = $Username
				password = $Password
			}
	}
	catch {
		$response = $_.Exception.Response

		if ($response -and [int]$response.StatusCode -eq 403) {
			throw "qBittorrent WebUI login failed: 403 Forbidden. Check the WebUI password, temporary login bans, and host header validation."
		}

		throw
	}

	if ($response.Content -notmatch "Ok\.") {
		throw "qBittorrent WebUI login failed. Response: $($response.Content)"
	}

	try {
		Invoke-WebRequest `
			-UseBasicParsing `
			-Uri "$BaseUrl/api/v2/auth/logout" `
			-Method Post `
			-WebSession $session `
			-Headers @{
				Referer = "$BaseUrl/"
				Origin = $BaseUrl
			} | Out-Null
	}
	catch {
	}
}

function Protect-WebUiPassword {
	param([string]$SecretPath)

	$securePassword = Read-Host "qBittorrent WebUI password" -AsSecureString
	$credential = [System.Management.Automation.PSCredential]::new("qbt", $securePassword)
	$plainPassword = $credential.GetNetworkCredential().Password

	$securePassword |
		ConvertFrom-SecureString |
		Set-Content $SecretPath -Encoding UTF8

	return $plainPassword
}

try {
	$InstallDir = Resolve-InstallationDirectory -RequestedPath $InstallDir

	if (-not (Test-IsAdministrator)) {
		Write-Step "Administrator privileges are required to register the scheduled task."
		Write-Step "Requesting elevation through UAC."
		$script:ShouldPauseOnExit = $false
		Restart-Elevated
		return
	}

	if ([string]::IsNullOrWhiteSpace($InstallDir)) {
		throw "InstallDir is empty."
	}

	if ($IntervalMinutes -lt 1) {
		throw "IntervalMinutes must be greater than or equal to 1."
	}

	if ($MaxLogSizeKB -lt 1) {
		throw "MaxLogSizeKB must be greater than or equal to 1."
	}

	if ($MaxLogBackups -lt 0) {
		throw "MaxLogBackups must be greater than or equal to 0."
	}

	$InstallDir = [System.IO.Path]::GetFullPath($InstallDir)

	$SourceMainScriptPath = Join-Path $script:RepositoryDir "Update-qBittorrent-Proton-Port.ps1"
	$SourceWrapperPath = Join-Path $script:RepositoryDir "Wait-And-Update-qBittorrent-Proton-Port.ps1"

	$MainScriptPath = Join-Path $InstallDir "Update-qBittorrent-Proton-Port.ps1"
	$WrapperPath = Join-Path $InstallDir "Wait-And-Update-qBittorrent-Proton-Port.ps1"
	$VbsPath = Join-Path $InstallDir "Run-Hidden-qbt-proton.vbs"
	$ConfigPath = Join-Path $InstallDir "config.json"
	$SecretPath = Join-Path $InstallDir "qbt-webui-password.sec"
	$LogPath = Join-Path $InstallDir "automation.log"

	Write-Step "Repository directory: $script:RepositoryDir"
	Write-Step "Installation directory: $InstallDir"

	New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null

	Write-Step "Copying runtime PowerShell scripts."
	Copy-FileIfNeeded -Source $SourceMainScriptPath -Destination $MainScriptPath
	Copy-FileIfNeeded -Source $SourceWrapperPath -Destination $WrapperPath

	if (-not (Test-Path $ProtonLogPath)) {
		throw "Proton VPN log file not found: $ProtonLogPath"
	}

	if (-not (Test-WebEndpoint -BaseUrl $QbtBaseUrl)) {
		throw "qBittorrent WebUI is not reachable at: $QbtBaseUrl"
	}

	Write-Step "Creating local configuration file."

	@{
		QbtBaseUrl = $QbtBaseUrl
		QbtUsername = $QbtUsername
		ProtonLogPath = $ProtonLogPath
		SecretPath = $SecretPath
		LogPath = $LogPath
		MaxLogSizeKB = $MaxLogSizeKB
		MaxLogBackups = $MaxLogBackups
	} | ConvertTo-Json -Depth 4 | Set-Content $ConfigPath -Encoding UTF8

	Write-Step "Creating local DPAPI-protected qBittorrent WebUI secret."
	$plainPassword = Protect-WebUiPassword -SecretPath $SecretPath

	Write-Step "Testing qBittorrent WebUI login."
	Test-QBittorrentLogin `
		-BaseUrl $QbtBaseUrl `
		-Username $QbtUsername `
		-Password $plainPassword

	$plainPassword = $null

	Write-Step "Creating local automation log."

	if (-not (Test-Path $LogPath)) {
		New-Item -ItemType File -Path $LogPath -Force | Out-Null
	}

	Add-Content `
		-Path $LogPath `
		-Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | automation.log initialized" `
		-Encoding UTF8

	Write-Step "Creating hidden VBS launcher."

	@'
Option Explicit

Dim shell
Dim fso
Dim scriptDir
Dim psScript
Dim powershellPath
Dim command

Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

scriptDir = fso.GetParentFolderName(WScript.ScriptFullName)
psScript = scriptDir & "\Wait-And-Update-qBittorrent-Proton-Port.ps1"
powershellPath = shell.ExpandEnvironmentStrings("%SystemRoot%") & "\System32\WindowsPowerShell\v1.0\powershell.exe"

command = Chr(34) & powershellPath & Chr(34) & " -NoProfile -NonInteractive -ExecutionPolicy Bypass -File " & Chr(34) & psScript & Chr(34)

shell.Run command, 0, False
'@ | Set-Content $VbsPath -Encoding ASCII

	Write-Step "Registering hidden scheduled task."

	$action = New-ScheduledTaskAction `
		-Execute "$env:SystemRoot\System32\wscript.exe" `
		-Argument "`"$VbsPath`""

	$triggerLogon = New-ScheduledTaskTrigger -AtLogOn

	$triggerPeriodic = New-ScheduledTaskTrigger `
		-Once `
		-At (Get-Date).AddMinutes(1) `
		-RepetitionInterval (New-TimeSpan -Minutes $IntervalMinutes) `
		-RepetitionDuration (New-TimeSpan -Days 3650)

	$settings = New-ScheduledTaskSettingsSet `
		-AllowStartIfOnBatteries `
		-DontStopIfGoingOnBatteries `
		-StartWhenAvailable `
		-MultipleInstances IgnoreNew `
		-ExecutionTimeLimit (New-TimeSpan -Minutes 10)

	$currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name

	$principal = New-ScheduledTaskPrincipal `
		-UserId $currentUser `
		-LogonType Interactive `
		-RunLevel Limited

	Unregister-ScheduledTask `
		-TaskName $TaskName `
		-Confirm:$false `
		-ErrorAction SilentlyContinue

	Register-ScheduledTask `
		-TaskName $TaskName `
		-Action $action `
		-Trigger @($triggerLogon, $triggerPeriodic) `
		-Settings $settings `
		-Principal $principal `
		-Description "Synchronize qBittorrent listening port with Proton VPN active forwarded port." | Out-Null

	Write-Step "Scheduled task registered: $TaskName"

	if (ConvertTo-BooleanSetting -Value $StartImmediately) {
		Write-Step "Starting scheduled task once for validation."
		Start-ScheduledTask -TaskName $TaskName
		Start-Sleep -Seconds 10
	}

	Write-Step "Setup completed."

	Write-Output ""
	Write-Output "Files:"
	Write-Output "  Config: $ConfigPath"
	Write-Output "  Secret: $SecretPath"
	Write-Output "  Log:    $LogPath"
	Write-Output "  VBS:    $VbsPath"
	Write-Output ""
	Write-Output "Scheduled task:"
	Write-Output "  $TaskName"
	Write-Output ""
	Write-Output "Log rotation:"
	Write-Output "  MaxLogSizeKB:  $MaxLogSizeKB"
	Write-Output "  MaxLogBackups: $MaxLogBackups"
	Write-Output ""
	Write-Output "Useful check:"
	Write-Output "  Get-Content `"$LogPath`" -Tail 80"
}
catch {
	Write-Error $_.Exception.Message
	if ($script:ShouldPauseOnExit) {
		exit 1
	}
	throw
}
finally {
	Wait-BeforeExit
}
