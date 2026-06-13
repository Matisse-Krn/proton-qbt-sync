# proton-qbt-sync — Synchronize Proton VPN forwarded ports with qBittorrent on Windows.
# Copyright (C) 2026 <Matisse-Krn>
# SPDX-License-Identifier: GPL-3.0-or-later





Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Script = Join-Path $PSScriptRoot "Update-qBittorrent-Proton-Port.ps1"
$ConfigPath = Join-Path $PSScriptRoot "config.json"

if (-not (Test-Path $Script)) {
	throw "Main script not found: $Script"
}

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

$LogPath = Get-ConfigValue -Object $Config -Name "LogPath" -DefaultValue "$PSScriptRoot\automation.log"
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

	if ($LogPath) {
		Rotate-LogFile `
			-Path $LogPath `
			-MaxSizeKB $MaxLogSizeKB `
			-MaxBackups $MaxLogBackups

		Add-Content -Path $LogPath -Value $line -Encoding UTF8
	}
}

$MaxAttempts = 60
$DelaySeconds = 5
$attempt = 1

while ($attempt -le $MaxAttempts) {
	try {
		Write-AutomationLog "Wrapper attempt $attempt/$MaxAttempts"

		& $Script

		Write-AutomationLog "Update completed"
		return
	}
	catch {
		Write-AutomationLog "Wrapper attempt $attempt/$MaxAttempts failed: $($_.Exception.Message)"
		Start-Sleep -Seconds $DelaySeconds
		$attempt++
	}
}

throw "Unable to update qBittorrent after $MaxAttempts attempts."
