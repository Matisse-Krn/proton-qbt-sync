<!--
proton-qbt-sync — Synchronize Proton VPN forwarded ports with qBittorrent on Windows.
Copyright (C) 2026 Matisse-Krn
SPDX-License-Identifier: GPL-3.0-or-later
-->





# proton-qbt-sync

<p align="center">
  <a href="README.md"><img alt="README: English" src="https://img.shields.io/badge/README-English-blue"></a>
  <a href="README_fr.md"><img alt="README: Français" src="https://img.shields.io/badge/README-Français-blue"></a>
  <a href="LICENSE"><img alt="License: GPL-3.0-or-later" src="https://img.shields.io/badge/license-GPL--3.0--or--later-blue"></a>
  <a href="#compatibility"><img alt="Platform: Windows" src="https://img.shields.io/badge/platform-Windows%2010%2F11-0078D4?logo=windows&logoColor=white"></a>
  <a href="#compatibility"><img alt="PowerShell: 5.1" src="https://img.shields.io/badge/PowerShell-5.1-5391FE?logo=powershell&logoColor=white"></a>
</p>

Automatically keeps qBittorrent's incoming listening port synchronized with the active forwarded port assigned by Proton VPN on Windows.

The tool reads Proton VPN's local `client-logs.txt`, extracts the currently active forwarded port, then updates qBittorrent through its local WebUI API. It can be run manually or silently through a Windows scheduled task.

---

## Quick overview

| Item | Summary |
|---|---|
| Purpose | Automatically sync Proton VPN's active forwarded port to qBittorrent's incoming listening port |
| Platform | Windows 10/11, Windows PowerShell 5.1 |
| Recommended install | Double-click `Run-Setup.cmd` |
| Scheduled task | Created automatically by the setup |
| Visible background window | No, hidden execution through a generated VBS launcher |
| qBittorrent secret | Stored locally with Windows DPAPI |
| Log rotation | Yes, size-based, no external dependency |
| Proton file read | `%LOCALAPPDATA%\Proton\Proton VPN\Logs\client-logs.txt` |
| qBittorrent API used | Local WebUI API on `127.0.0.1` |

---

## Scope

This project automates one operation only:

```text
Active Proton VPN forwarded port
→ qBittorrent "Port used for incoming connections"
```

It does not configure Proton VPN, create a VPN tunnel, replace qBittorrent's network configuration, or guarantee anonymity.

> [!IMPORTANT]
> Proton VPN and qBittorrent must already be correctly configured before running this project's setup.

---

## Quick install

### 1. Configure Proton VPN

In Proton VPN:

```text
Connect to a P2P-compatible server
Enable Port forwarding
Apply / reconnect if required
```

Useful check:

```powershell
Select-String `
	-Path "$env:LOCALAPPDATA\Proton\Proton VPN\Logs\client-logs.txt" `
	-Pattern "Port forwarding port changed", "Port pair", "PortForwarding Status"
```

A usable line looks like:

```text
Port pair 55371->55371
```

or:

```text
Port forwarding port changed from '' to '55371'
```

### 2. Configure qBittorrent

In qBittorrent:

```text
Tools → Options → Advanced
```

Recommended settings:

```text
Network interface: ProtonVPN
Optional IP address to bind to: All addresses
```

Then:

```text
Tools → Options → Connection
```

Recommended settings:

```text
Use UPnP / NAT-PMP port forwarding from my router: Disabled
Use different port on each startup: Disabled
```

Then:

```text
Tools → Options → Web UI
```

Recommended settings:

```text
Web User Interface: Enabled
IP address: 127.0.0.1
Port: 8080
Use HTTPS instead of HTTP: Disabled
Username: admin
Password: strong local password
Bypass authentication for clients on localhost: Disabled
Bypass authentication for clients in whitelisted IP subnets: Disabled
CSRF protection: Enabled
Clickjacking protection: Enabled
Host header validation: Enabled
Server domains: 127.0.0.1, localhost
Use UPnP / NAT-PMP to forward the WebUI port: Disabled
```

WebUI check:

```text
http://127.0.0.1:8080
```

### 3. Install this project

From the repository directory:

```text
Run-Setup.cmd
```

Expected flow:

```text
Double-click Run-Setup.cmd
→ choose the installation directory or press Enter for the default directory
→ accept the UAC prompt if requested
→ enter the qBittorrent WebUI password
→ setup copies the runtime scripts
→ setup creates config.json, qbt-webui-password.sec, automation.log, Run-Hidden-qbt-proton.vbs and the scheduled task
→ the window remains open until one final confirmation
```

Default installation directory:

```text
%LOCALAPPDATA%\Scripts\qbt-proton
```

---

## Why this project exists

When port forwarding is enabled, Proton VPN can dynamically assign an active forwarded port. This port can change after a VPN reconnect, a server change, an application restart, or a session refresh.

qBittorrent must use the currently active Proton port if it needs to receive incoming BitTorrent connections through Proton VPN port forwarding.

This project is useful only when Proton VPN port forwarding is enabled. If port forwarding is disabled, there is no Proton port to synchronize.

If qBittorrent uses a listening port different from the currently active Proton forwarded port, qBittorrent is no longer reachable for incoming connections through that forwarded port. Transfers may still work through outgoing connections, but connectivity can be degraded: fewer reachable peers, less efficient seeding, weaker upload performance, and some private trackers may report the client as not connectable.

---

## PowerShell installation

From the repository directory:

```powershell
powershell.exe `
	-NoProfile `
	-ExecutionPolicy Bypass `
	-File .\Setup-qbt-proton.ps1
```

With custom parameters:

```powershell
powershell.exe `
	-NoProfile `
	-ExecutionPolicy Bypass `
	-File .\Setup-qbt-proton.ps1 `
	-InstallDir "$env:LOCALAPPDATA\Scripts\qbt-proton" `
	-QbtBaseUrl "http://127.0.0.1:8080" `
	-QbtUsername "admin" `
	-ProtonLogPath "$env:LOCALAPPDATA\Proton\Proton VPN\Logs\client-logs.txt" `
	-TaskName "Update qBittorrent Proton forwarded port" `
	-IntervalMinutes 2 `
	-MaxLogSizeKB 1024 `
	-MaxLogBackups 3 `
	-StartImmediately true
```

<details>
<summary>Available parameters</summary>

| Parameter | Default | Purpose |
|---|---:|---|
| `InstallDir` | asked during installation; default `%LOCALAPPDATA%\Scripts\qbt-proton` | Runtime installation directory |
| `QbtBaseUrl` | `http://127.0.0.1:8080` | Local qBittorrent WebUI URL |
| `QbtUsername` | `admin` | qBittorrent WebUI username |
| `ProtonLogPath` | `%LOCALAPPDATA%\Proton\Proton VPN\Logs\client-logs.txt` | Proton VPN log path |
| `TaskName` | `Update qBittorrent Proton forwarded port` | Scheduled task name |
| `IntervalMinutes` | `2` | Periodic execution interval |
| `MaxLogSizeKB` | `1024` | Maximum size of `automation.log` before rotation |
| `MaxLogBackups` | `3` | Maximum number of backup log files |
| `StartImmediately` | `true` | Runs the task once after installation |
| `PauseOnExit` | disabled except through `.cmd` | Keeps the setup window open at the end |

</details>

---

## Runtime flow

```text
Windows Task Scheduler
→ Run-Hidden-qbt-proton.vbs
→ Wait-And-Update-qBittorrent-Proton-Port.ps1
→ Update-qBittorrent-Proton-Port.ps1
→ qBittorrent WebUI API
```

<details>
<summary>File roles</summary>

```text
Setup-qbt-proton.ps1
→ installs runtime scripts into the selected directory, creates the local configuration, creates the DPAPI secret, creates the log, generates the VBS launcher and registers the scheduled task.

Run-Setup.cmd
→ starts the setup from the graphical interface, triggers UAC elevation if needed and keeps the window open until one final confirmation.

Run-Hidden-qbt-proton.vbs
→ generated during installation; starts the PowerShell wrapper without a visible window.

Wait-And-Update-qBittorrent-Proton-Port.ps1
→ waits and retries if Proton VPN or qBittorrent are not ready yet.

Update-qBittorrent-Proton-Port.ps1
→ extracts the Proton VPN port and updates qBittorrent.
```

`Wait-And-Update-qBittorrent-Proton-Port.ps1` remains useful even with the VBS launcher and the scheduled task. The VBS only hides the PowerShell window; it does not manage the startup order of Proton VPN, qBittorrent and Windows.

The wrapper avoids startup failures when Proton VPN has not written the forwarded port to its logs yet, or when the qBittorrent WebUI is not reachable yet.

</details>

<details>
<summary>Repository files and generated files</summary>

Files included in the repository:

```text
Run-Setup.cmd
Setup-qbt-proton.ps1
Update-qBittorrent-Proton-Port.ps1
Wait-And-Update-qBittorrent-Proton-Port.ps1
README.md
README_fr.md
LICENSE
README_fr.md
LICENSE
```

Local files generated during installation:

```text
config.json
qbt-webui-password.sec
Run-Hidden-qbt-proton.vbs
automation.log
```

`qbt-webui-password.sec` contains the qBittorrent WebUI secret encrypted through Windows DPAPI for the current Windows account. It must not be shared or committed.

</details>

---

## Log rotation

The scripts automatically limit the size of `automation.log`.

Default behavior:

```text
automation.log reaches about 1 MB
→ automation.log.3 is deleted if needed
→ automation.log.2 becomes automation.log.3
→ automation.log.1 becomes automation.log.2
→ automation.log becomes automation.log.1
→ a new automation.log is created automatically
```

With default values:

```text
MaxLogSizeKB = 1024
MaxLogBackups = 3
```

Approximate maximum disk usage:

```text
automation.log + automation.log.1 + automation.log.2 + automation.log.3
≈ 4 MB
```

Rotation is implemented in the two files that actually write to the log:

```text
Update-qBittorrent-Proton-Port.ps1
Wait-And-Update-qBittorrent-Proton-Port.ps1
```

No external dependency is required.

---

## Manual test

If the default installation directory was used:

```powershell
$InstallDir = "$env:LOCALAPPDATA\Scripts\qbt-proton"
```

Otherwise, adapt `$InstallDir` to the directory selected during installation.

Run:

```powershell
powershell.exe `
	-NoProfile `
	-NonInteractive `
	-ExecutionPolicy Bypass `
	-File "$InstallDir\Update-qBittorrent-Proton-Port.ps1"
```

Expected output:

```text
Starting qBittorrent port update
Extracted Proton VPN forwarded port: XXXXX
qBittorrent already uses the expected port: XXXXX
```

or:

```text
qBittorrent port updated: OLD_PORT -> NEW_PORT
```

Read the log:

```powershell
Get-Content "$InstallDir\automation.log" -Tail 80
```

---

## Compatibility

| Component | Validated version |
|---|---:|
| Proton VPN for Windows | 4.4.1 |
| qBittorrent | 5.2.1 |
| Windows | Windows 11 25H2 |
| PowerShell | Windows PowerShell 5.1 |

<details>
<summary>Compatibility details</summary>

Expected to work with:

- Windows 10/11 with Windows PowerShell 5.1.
- qBittorrent versions exposing the WebUI API endpoints used by this project:
  - `/api/v2/auth/login`
  - `/api/v2/auth/logout`
  - `/api/v2/app/preferences`
  - `/api/v2/app/setPreferences`
- Windows versions of Proton VPN that continue to write the active forwarded port to:

```text
%LOCALAPPDATA%\Proton\Proton VPN\Logs\client-logs.txt
```

with lines compatible with these patterns:

```text
Port forwarding port changed from '...' to 'XXXXX'
Port pair XXXXX->XXXXX
Received PortForwarding Status 'Stopped'
```

The project may stop working if Proton VPN changes the log path, the log syntax, or if qBittorrent changes its WebUI API.

</details>

---

## Maintenance commands

In the examples below, first define:

```powershell
$InstallDir = "$env:LOCALAPPDATA\Scripts\qbt-proton"
```

Adapt this path if a custom installation directory was selected.

<details>
<summary>Check files</summary>

```powershell
Get-ChildItem $InstallDir |
	Select-Object Name, Length, LastWriteTime
```

</details>

<details>
<summary>Read the configuration</summary>

```powershell
Get-Content "$InstallDir\config.json" |
	ConvertFrom-Json |
	Format-List
```

</details>

<details>
<summary>Follow the log in real time</summary>

```powershell
Get-Content "$InstallDir\automation.log" -Wait -Tail 30
```

</details>

<details>
<summary>Clear the log</summary>

```powershell
$LogPath = "$InstallDir\automation.log"

Clear-Content $LogPath
Add-Content `
	-Path $LogPath `
	-Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | automation.log reset" `
	-Encoding UTF8
```

</details>

<details>
<summary>Check log sizes</summary>

```powershell
Get-ChildItem "$InstallDir\automation.log*" |
	Select-Object Name, Length, LastWriteTime
```

</details>

<details>
<summary>Check the scheduled task</summary>

```powershell
Get-ScheduledTask -TaskName "Update qBittorrent Proton forwarded port" |
	Select-Object TaskName, State, TaskPath

Get-ScheduledTaskInfo -TaskName "Update qBittorrent Proton forwarded port"
```

</details>

<details>
<summary>Inspect the scheduled task action</summary>

```powershell
(Get-ScheduledTask -TaskName "Update qBittorrent Proton forwarded port").Actions
```

Expected action:

```text
wscript.exe "···\Run-Hidden-qbt-proton.vbs"
```

If the action directly starts `powershell.exe`, a visible PowerShell window may appear.

</details>

<details>
<summary>Disable, re-enable or remove the task</summary>

Disable:

```powershell
Disable-ScheduledTask -TaskName "Update qBittorrent Proton forwarded port"
```

Re-enable:

```powershell
Enable-ScheduledTask -TaskName "Update qBittorrent Proton forwarded port"
```

Remove:

```powershell
Unregister-ScheduledTask `
	-TaskName "Update qBittorrent Proton forwarded port" `
	-Confirm:$false
```

</details>

<details>
<summary>Change the execution interval</summary>

Example: every 5 minutes.

```powershell
$TaskName = "Update qBittorrent Proton forwarded port"
$TriggerLogon = New-ScheduledTaskTrigger -AtLogOn
$TriggerPeriodic = New-ScheduledTaskTrigger `
	-Once `
	-At (Get-Date).AddMinutes(1) `
	-RepetitionInterval (New-TimeSpan -Minutes 5) `
	-RepetitionDuration (New-TimeSpan -Days 3650)

Set-ScheduledTask `
	-TaskName $TaskName `
	-Trigger @($TriggerLogon, $TriggerPeriodic)
```

</details>

<details>
<summary>Recreate the qBittorrent WebUI password secret</summary>

Run this from a normal PowerShell session, using the same Windows account as the one running the scheduled task.

```powershell
$SecretPath = "$InstallDir\qbt-webui-password.sec"

Read-Host "qBittorrent WebUI password" -AsSecureString |
	ConvertFrom-SecureString |
	Set-Content $SecretPath -Encoding UTF8
```

</details>

<details>
<summary>Change the qBittorrent WebUI URL</summary>

Example: qBittorrent WebUI moved from `8080` to `8081`.

```powershell
$ConfigPath = "$InstallDir\config.json"
$config = Get-Content $ConfigPath -Encoding UTF8 | ConvertFrom-Json
$config.QbtBaseUrl = "http://127.0.0.1:8081"
$config | ConvertTo-Json -Depth 4 | Set-Content $ConfigPath -Encoding UTF8
```

</details>

<details>
<summary>Change the Proton VPN log path</summary>

```powershell
$ConfigPath = "$InstallDir\config.json"
$config = Get-Content $ConfigPath -Encoding UTF8 | ConvertFrom-Json
$config.ProtonLogPath = "$env:LOCALAPPDATA\Proton\Proton VPN\Logs\client-logs.txt"
$config | ConvertTo-Json -Depth 4 | Set-Content $ConfigPath -Encoding UTF8
```

</details>

---

## Troubleshooting

<details>
<summary>Setup closes immediately after UAC</summary>

Use `Run-Setup.cmd` from the repository directory. The `.cmd` file starts `Setup-qbt-proton.ps1` with `-PauseOnExit`, and the setup relaunches a persistent elevated window if needed.

If the issue persists, run from an already open console to read the error:

```powershell
powershell.exe `
	-NoProfile `
	-ExecutionPolicy Bypass `
	-File .\Setup-qbt-proton.ps1
```

</details>

<details>
<summary>Setup fails before asking for the WebUI password</summary>

Likely causes:

```text
- Proton VPN is not running;
- client-logs.txt does not exist yet;
- qBittorrent is not running;
- qBittorrent WebUI is not enabled;
- the configured WebUI URL is incorrect.
```

Check Proton VPN:

```powershell
Test-Path "$env:LOCALAPPDATA\Proton\Proton VPN\Logs\client-logs.txt"
```

Check qBittorrent WebUI:

```text
http://127.0.0.1:8080
```

</details>

<details>
<summary><code>Access is denied</code> while creating the scheduled task</summary>

Registering the scheduled task requires elevation. Use `Run-Setup.cmd` and accept the UAC prompt, or start PowerShell as administrator.

</details>

<details>
<summary>A PowerShell window appears every few minutes</summary>

The scheduled task probably starts PowerShell directly instead of the generated VBS.

Check:

```powershell
(Get-ScheduledTask -TaskName "Update qBittorrent Proton forwarded port").Actions
```

Expected result:

```text
wscript.exe "···\Run-Hidden-qbt-proton.vbs"
```

Run the setup again to recreate the task correctly.

</details>

<details>
<summary><code>Secret file not found</code></summary>

The DPAPI secret file is missing or the configuration points to the wrong path.

Check:

```powershell
Get-Content "$InstallDir\config.json" |
	ConvertFrom-Json |
	Format-List
```

Recreate the secret:

```powershell
$SecretPath = "$InstallDir\qbt-webui-password.sec"

Read-Host "qBittorrent WebUI password" -AsSecureString |
	ConvertFrom-SecureString |
	Set-Content $SecretPath -Encoding UTF8
```

</details>

<details>
<summary><code>qBittorrent login failed: 403 Forbidden</code></summary>

Likely causes:

- Incorrect qBittorrent WebUI password.
- Temporary qBittorrent ban after failed login attempts.
- Inconsistency with `Host` header validation.
- `Server domains` does not include the host used by the script.

Recommended qBittorrent WebUI values:

```text
IP address: 127.0.0.1
Port: 8080
Host header validation: Enabled
Server domains: 127.0.0.1, localhost
```

If a temporary ban is suspected, close qBittorrent, wait a few minutes, start qBittorrent again, then recreate the secret with the correct password.

</details>

<details>
<summary><code>No active forwarded port found</code></summary>

Likely causes:

- Proton VPN is not connected.
- Proton VPN port forwarding is disabled.
- The current server does not support P2P or port forwarding.
- Proton VPN has not written the active forwarded port to the log yet.
- Proton VPN changed its log path or syntax.

Check:

```powershell
Select-String `
	-Path "$env:LOCALAPPDATA\Proton\Proton VPN\Logs\client-logs.txt" `
	-Pattern "Port forwarding port changed", "Port pair", "PortForwarding Status"
```

</details>

<details>
<summary>qBittorrent WebUI is visible in the browser, but the script fails</summary>

The browser may have a valid authentication cookie, while the script must log in through the API.

Test the WebUI endpoint:

```powershell
Invoke-WebRequest `
	-UseBasicParsing `
	-Uri "http://127.0.0.1:8080" `
	-Headers @{
		Referer = "http://127.0.0.1:8080/"
		Origin = "http://127.0.0.1:8080"
	}
```

Then recreate the local secret if needed.

</details>

<details>
<summary>The log is not updated</summary>

Test each layer manually:

```powershell
powershell.exe `
	-NoProfile `
	-NonInteractive `
	-ExecutionPolicy Bypass `
	-File "$InstallDir\Update-qBittorrent-Proton-Port.ps1"

powershell.exe `
	-NoProfile `
	-NonInteractive `
	-ExecutionPolicy Bypass `
	-File "$InstallDir\Wait-And-Update-qBittorrent-Proton-Port.ps1"

wscript.exe "$InstallDir\Run-Hidden-qbt-proton.vbs"

Start-ScheduledTask -TaskName "Update qBittorrent Proton forwarded port"
```

After each command:

```powershell
Get-Content "$InstallDir\automation.log" -Tail 80
```

</details>

<details>
<summary>qBittorrent port does not change</summary>

Run the main script manually and check the log:

```powershell
powershell.exe `
	-NoProfile `
	-NonInteractive `
	-ExecutionPolicy Bypass `
	-File "$InstallDir\Update-qBittorrent-Proton-Port.ps1"

Get-Content "$InstallDir\automation.log" -Tail 80
```

Then check in qBittorrent:

```text
Tools → Options → Connection → Port used for incoming connections
```

</details>

---

## Uninstall

If the default installation directory was used:

```powershell
$InstallDir = "$env:LOCALAPPDATA\Scripts\qbt-proton"
```

Otherwise, adapt `$InstallDir` to the directory selected during installation.

Remove the scheduled task and local files:

```powershell
Unregister-ScheduledTask `
	-TaskName "Update qBittorrent Proton forwarded port" `
	-Confirm:$false `
	-ErrorAction SilentlyContinue

Remove-Item `
	-Path $InstallDir `
	-Recurse `
	-Force
```

---

## Security and legal notes

> [!WARNING]
> This project does not make BitTorrent anonymous. It only synchronizes a listening port.

Correct setup still depends on proper VPN usage, qBittorrent binding to the correct network interface, qBittorrent WebUI hardening, and legal use of the BitTorrent protocol.

The qBittorrent WebUI must not be exposed to the Internet. This project assumes a local WebUI endpoint on `127.0.0.1`.

Do not use this project to violate copyright, bypass the law, distribute malware, or perform unauthorized activities.

Use at your own risk. Review the scripts before execution.

---

## License

`proton-qbt-sync` is licensed under the **GNU General Public License version 3 or later** (`GPL-3.0-or-later`).

This means redistributed modified versions must remain under GPL-compatible terms and keep the corresponding source code available under the GPL. See [`LICENSE`](LICENSE) for the full license text.

---

## References

- Proton VPN port forwarding documentation: <https://protonvpn.com/support/port-forwarding>
- Proton VPN BitTorrent/qBittorrent documentation: <https://protonvpn.com/support/bittorrent-vpn>
- qBittorrent WebUI API documentation: <https://github.com/qbittorrent/qBittorrent/wiki/WebUI-API>
- qBittorrent VPN binding documentation: <https://github.com/qbittorrent/qBittorrent/wiki/How-to-bind-your-vpn-to-prevent-ip-leaks>
