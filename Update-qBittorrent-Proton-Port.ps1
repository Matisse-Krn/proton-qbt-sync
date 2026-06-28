# proton-qbt-sync — Synchronize Proton VPN forwarded ports with qBittorrent on Windows.
# Copyright (C) 2026 Matisse-Krn
# SPDX-License-Identifier: GPL-3.0-or-later





Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ConfigPath = Join-Path $PSScriptRoot "config.json"

if (-not (Test-Path $ConfigPath)) {
	throw "Configuration file not found: $ConfigPath"
}

$Config = Get-Content $ConfigPath -Encoding UTF8 | ConvertFrom-Json

function Get-ConfigValue {
	param(
		[object]$Object,
		[string]$Name,
		[object]$DefaultValue = $null
	)

	if ($Object.PSObject.Properties.Name -contains $Name) {
		return $Object.$Name
	}

	return $DefaultValue
}

$QbtBaseUrl = Get-ConfigValue -Object $Config -Name "QbtBaseUrl" -DefaultValue "http://127.0.0.1:8080"
$QbtUsername = Get-ConfigValue -Object $Config -Name "QbtUsername" -DefaultValue "admin"
$ProtonLogPath = Get-ConfigValue -Object $Config -Name "ProtonLogPath" -DefaultValue "$env:LOCALAPPDATA\Proton\Proton VPN\Logs\client-logs.txt"
$SecretPath = Get-ConfigValue -Object $Config -Name "SecretPath" -DefaultValue "$PSScriptRoot\qbt-webui-password.sec"
$AutomationLogPath = Get-ConfigValue -Object $Config -Name "LogPath" -DefaultValue "$PSScriptRoot\automation.log"
$MaxLogSizeKB = [int](Get-ConfigValue -Object $Config -Name "MaxLogSizeKB" -DefaultValue 1024)
$MaxLogBackups = [int](Get-ConfigValue -Object $Config -Name "MaxLogBackups" -DefaultValue 3)

function Rotate-LogFile {
	param(
		[string]$Path,
		[int]$MaxSizeKB,
		[int]$MaxBackups
	)

	if ([string]::IsNullOrWhiteSpace($Path)) {
		return
	}

	if ($MaxSizeKB -le 0) {
		return
	}

	if (-not (Test-Path $Path)) {
		return
	}

	$maxBytes = [int64]$MaxSizeKB * 1024
	$currentSize = (Get-Item $Path).Length

	if ($currentSize -lt $maxBytes) {
		return
	}

	if ($MaxBackups -le 0) {
		Remove-Item -Path $Path -Force -ErrorAction SilentlyContinue
		return
	}

	for ($i = $MaxBackups; $i -ge 1; $i--) {
		$destination = "$Path.$i"

		if ($i -eq 1) {
			$source = $Path
		}
		else {
			$source = "$Path.$($i - 1)"
		}

		if (Test-Path $destination) {
			Remove-Item -Path $destination -Force -ErrorAction SilentlyContinue
		}

		if (Test-Path $source) {
			Rename-Item -Path $source -NewName (Split-Path $destination -Leaf) -Force
		}
	}
}

function Write-AutomationLog {
	param(
		[string]$Message
	)

	$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
	$line = "$timestamp | $Message"

	Write-Output $line

	if ($AutomationLogPath) {
		Rotate-LogFile `
			-Path $AutomationLogPath `
			-MaxSizeKB $MaxLogSizeKB `
			-MaxBackups $MaxLogBackups

		Add-Content -Path $AutomationLogPath -Value $line -Encoding UTF8
	}
}

function Get-PlainTextSecret {
	param(
		[string]$SecretPath
	)

	if (-not (Test-Path $SecretPath)) {
		throw "Secret file not found: $SecretPath"
	}

	$secure = Get-Content $SecretPath -Encoding UTF8 | ConvertTo-SecureString
	$credential = [System.Management.Automation.PSCredential]::new("qbt", $secure)

	return $credential.GetNetworkCredential().Password
}

function Get-ProtonForwardedPort {
	param(
		[string]$LogPath
	)

	if (-not (Test-Path $LogPath)) {
		throw "Proton VPN log file not found: $LogPath"
	}

	$currentPort = $null
	$currentStatus = $null
	$lastRelevantLine = $null

	$fileStream = [System.IO.File]::Open(
		$LogPath,
		[System.IO.FileMode]::Open,
		[System.IO.FileAccess]::Read,
		[System.IO.FileShare]::ReadWrite
	)

	try {
		$reader = [System.IO.StreamReader]::new($fileStream, [System.Text.Encoding]::UTF8)

		try {
			while (($line = $reader.ReadLine()) -ne $null) {
				if ($line -match "Received PortForwarding Status '([^']+)'") {
					$currentStatus = $Matches[1]
					$lastRelevantLine = $line

					if ($currentStatus -eq "Stopped") {
						$currentPort = $null
					}
				}

				if ($line -match "Port forwarding port changed from '[^']*' to '(\d+)'") {
					$currentPort = [int]$Matches[1]
					$lastRelevantLine = $line
				}
				elseif ($line -match "Port pair (\d+)->\d+") {
					$currentPort = [int]$Matches[1]
					$lastRelevantLine = $line
				}
			}
		}
		finally {
			$reader.Dispose()
		}
	}
	finally {
		$fileStream.Dispose()
	}

	if (-not $currentPort) {
		throw "No active Proton VPN forwarded port found. Last status: $currentStatus. Last relevant line: $lastRelevantLine"
	}

	if ($currentPort -lt 1 -or $currentPort -gt 65535) {
		throw "Invalid Proton VPN forwarded port extracted from log: $currentPort"
	}

	return $currentPort
}

function Test-QBittorrentWebUi {
	param(
		[string]$BaseUrl
	)

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

function Start-QBittorrentIfNeeded {
	param(
		[string]$BaseUrl
	)

	if (Test-QBittorrentWebUi -BaseUrl $BaseUrl) {
		return
	}

	$running = Get-Process qbittorrent -ErrorAction SilentlyContinue

	if (-not $running) {
		$candidates = @(
			"$env:ProgramFiles\qBittorrent\qbittorrent.exe",
			"${env:ProgramFiles(x86)}\qBittorrent\qbittorrent.exe",
			"$env:LOCALAPPDATA\Programs\qBittorrent\qbittorrent.exe"
		)

		$exe = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1

		if ($exe) {
			Write-AutomationLog "qBittorrent is not running. Starting: $exe"
			Start-Process -FilePath $exe
			Start-Sleep -Seconds 8
		}
	}

	if (-not (Test-QBittorrentWebUi -BaseUrl $BaseUrl)) {
		throw "qBittorrent WebUI is unreachable: $BaseUrl"
	}
}

function Login-QBittorrent {
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

	return $session
}

function Logout-QBittorrent {
	param(
		[string]$BaseUrl,
		[Microsoft.PowerShell.Commands.WebRequestSession]$Session
	)

	try {
		Invoke-WebRequest `
			-UseBasicParsing `
			-Uri "$BaseUrl/api/v2/auth/logout" `
			-Method Post `
			-WebSession $Session `
			-Headers @{
				Referer = "$BaseUrl/"
				Origin = $BaseUrl
			} | Out-Null
	}
	catch {
	}
}

function Get-QBittorrentPreferences {
	param(
		[string]$BaseUrl,
		[Microsoft.PowerShell.Commands.WebRequestSession]$Session
	)

	$response = Invoke-WebRequest `
		-UseBasicParsing `
		-Uri "$BaseUrl/api/v2/app/preferences" `
		-Method Get `
		-WebSession $Session `
		-Headers @{
			Referer = "$BaseUrl/"
			Origin = $BaseUrl
		}

	return ($response.Content | ConvertFrom-Json)
}

function Set-QBittorrentListenPort {
	param(
		[string]$BaseUrl,
		[Microsoft.PowerShell.Commands.WebRequestSession]$Session,
		[int]$Port
	)

	$prefs = @{
		listen_port = $Port
		random_port = $false
		upnp = $false
	} | ConvertTo-Json -Compress

	Invoke-WebRequest `
		-UseBasicParsing `
		-Uri "$BaseUrl/api/v2/app/setPreferences" `
		-Method Post `
		-WebSession $Session `
		-Headers @{
			Referer = "$BaseUrl/"
			Origin = $BaseUrl
		} `
		-ContentType "application/x-www-form-urlencoded" `
		-Body @{
			json = $prefs
		} | Out-Null
}

Write-AutomationLog "Starting qBittorrent port update"

$port = Get-ProtonForwardedPort -LogPath $ProtonLogPath
Write-AutomationLog "Extracted Proton VPN forwarded port: $port"

Start-QBittorrentIfNeeded -BaseUrl $QbtBaseUrl

$password = Get-PlainTextSecret -SecretPath $SecretPath

$session = Login-QBittorrent `
	-BaseUrl $QbtBaseUrl `
	-Username $QbtUsername `
	-Password $password

try {
	$prefsBefore = Get-QBittorrentPreferences `
		-BaseUrl $QbtBaseUrl `
		-Session $session

	$currentPort = [int]$prefsBefore.listen_port

	if ($currentPort -eq $port) {
		Write-AutomationLog "qBittorrent already uses the expected port: $port"
		return
	}

	Set-QBittorrentListenPort `
		-BaseUrl $QbtBaseUrl `
		-Session $session `
		-Port $port

	Start-Sleep -Seconds 1

	$prefsAfter = Get-QBittorrentPreferences `
		-BaseUrl $QbtBaseUrl `
		-Session $session

	if ([int]$prefsAfter.listen_port -ne $port) {
		throw "qBittorrent port update failed. Expected port: $port. Current port: $($prefsAfter.listen_port)"
	}

	Write-AutomationLog "qBittorrent port updated: $currentPort -> $port"
}
finally {
	Logout-QBittorrent -BaseUrl $QbtBaseUrl -Session $session
}
