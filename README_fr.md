<!--
proton-qbt-sync — Synchronize Proton VPN forwarded ports with qBittorrent on Windows.
Copyright (C) 2026 <Matisse-Krn>
SPDX-License-Identifier: GPL-3.0-or-later
-->





# proton-qbt-sync

<p align="center">
  <a href="README.md"><img alt="README: English" src="https://img.shields.io/badge/README-English-blue"></a>
  <a href="README_fr.md"><img alt="README : Français" src="https://img.shields.io/badge/README-Français-blue"></a>
  <a href="LICENSE"><img alt="Licence : GPL-3.0-or-later" src="https://img.shields.io/badge/licence-GPL--3.0--or--later-blue"></a>
  <a href="#compatibilité"><img alt="Plateforme : Windows" src="https://img.shields.io/badge/plateforme-Windows%2010%2F11-0078D4?logo=windows&logoColor=white"></a>
  <a href="#compatibilité"><img alt="PowerShell : 5.1" src="https://img.shields.io/badge/PowerShell-5.1-5391FE?logo=powershell&logoColor=white"></a>
</p>


Synchronise automatiquement le port forwarded actif de Proton VPN vers le port d’écoute entrant de qBittorrent sous Windows.

L’outil lit le fichier local `client-logs.txt` de Proton VPN, extrait le port forwarded actuellement actif, puis met à jour qBittorrent via son API WebUI locale. Il peut être lancé manuellement ou via une tâche planifiée Windows cachée.

---

## Lecture rapide

| Élément | Résumé |
|---|---|
| But | Synchroniser automatiquement le port forwarding actif Proton VPN vers le port d’écoute entrant qBittorrent |
| Plateforme | Windows 10/11, Windows PowerShell 5.1 |
| Installation recommandée | Double-clic sur `Run-Setup.cmd` |
| Tâche planifiée | Créée automatiquement par le setup |
| Fenêtre visible en arrière-plan | Non, exécution cachée via VBS généré |
| Secret qBittorrent | Stocké localement via Windows DPAPI |
| Rotation des logs | Oui, par taille, sans dépendance externe |
| Fichier Proton lu | `%LOCALAPPDATA%\Proton\Proton VPN\Logs\client-logs.txt` |
| API qBittorrent utilisée | WebUI API locale sur `127.0.0.1` |

---

## Périmètre

Ce projet automatise une seule opération :

```text
Port forwarding actif Proton VPN
→ qBittorrent "Port used for incoming connections"
```

Il ne configure pas Proton VPN, ne crée pas de tunnel VPN, ne remplace pas la configuration réseau de qBittorrent et ne garantit pas l’anonymat.

> [!IMPORTANT]
> Proton VPN et qBittorrent doivent être correctement configurés avant de lancer l’installation de ce projet.

---

## Installation rapide

### 1. Configurer Proton VPN

Dans Proton VPN :

```text
Connect to a P2P-compatible server
Enable Port forwarding
Apply / reconnect if required
```

Vérification utile :

```powershell
Select-String `
	-Path "$env:LOCALAPPDATA\Proton\Proton VPN\Logs\client-logs.txt" `
	-Pattern "Port forwarding port changed", "Port pair", "PortForwarding Status"
```

Une ligne exploitable ressemble à :

```text
Port pair 55371->55371
```

ou :

```text
Port forwarding port changed from '' to '55371'
```

### 2. Configurer qBittorrent

Dans qBittorrent :

```text
Tools → Options → Advanced
```

Paramètres recommandés :

```text
Network interface: ProtonVPN
Optional IP address to bind to: All addresses
```

Puis :

```text
Tools → Options → Connection
```

Paramètres recommandés :

```text
Use UPnP / NAT-PMP port forwarding from my router: Disabled
Use different port on each startup: Disabled
```

Puis :

```text
Tools → Options → Web UI
```

Paramètres recommandés :

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

Vérification WebUI :

```text
http://127.0.0.1:8080
```

### 3. Installer ce projet

Depuis le dossier du dépôt :

```text
Run-Setup.cmd
```

Flux attendu :

```text
Double-clic sur Run-Setup.cmd
→ choisir le dossier d’installation ou appuyer sur Entrée pour le dossier par défaut
→ accepter l’UAC si demandé
→ entrer le mot de passe WebUI qBittorrent
→ le setup copie les scripts runtime
→ le setup crée config.json, qbt-webui-password.sec, automation.log, Run-Hidden-qbt-proton.vbs et la tâche planifiée
→ la fenêtre reste ouverte jusqu’à une validation finale
```

Dossier d’installation par défaut :

```text
%LOCALAPPDATA%\Scripts\qbt-proton
```

---

## Pourquoi ce projet existe

Lorsque le port forwarding est activé, Proton VPN peut attribuer dynamiquement un port forwarded actif. Ce port peut changer après une reconnexion VPN, un changement de serveur, un redémarrage de l’application ou un rafraîchissement de session.

qBittorrent doit utiliser le port Proton actuellement actif s’il doit recevoir des connexions BitTorrent entrantes via le port forwarding Proton VPN.

Ce projet est utile uniquement lorsque le port forwarding Proton VPN est activé. Si le port forwarding est désactivé, il n’existe pas de port Proton à synchroniser.

Si qBittorrent utilise un port d’écoute différent du port forwarded Proton actuellement actif, qBittorrent n’est plus joignable pour les connexions entrantes à travers ce port forwarding. Les transferts peuvent encore fonctionner via des connexions sortantes, mais la connectivité peut être dégradée : moins de pairs joignables, seed moins efficace, performances d’upload plus faibles, et certains trackers privés peuvent signaler le client comme non-connectable.

---

## Installation via PowerShell

Depuis le dossier du dépôt :

```powershell
powershell.exe `
	-NoProfile `
	-ExecutionPolicy Bypass `
	-File .\Setup-qbt-proton.ps1
```

Avec paramètres personnalisés :

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
<summary>Paramètres disponibles</summary>

| Paramètre | Défaut | Rôle |
|---|---:|---|
| `InstallDir` | demandé pendant l’installation ; défaut `%LOCALAPPDATA%\Scripts\qbt-proton` | Dossier d’installation runtime |
| `QbtBaseUrl` | `http://127.0.0.1:8080` | URL locale de la WebUI qBittorrent |
| `QbtUsername` | `admin` | Nom d’utilisateur WebUI qBittorrent |
| `ProtonLogPath` | `%LOCALAPPDATA%\Proton\Proton VPN\Logs\client-logs.txt` | Chemin du log Proton VPN |
| `TaskName` | `Update qBittorrent Proton forwarded port` | Nom de la tâche planifiée |
| `IntervalMinutes` | `2` | Intervalle d’exécution périodique |
| `MaxLogSizeKB` | `1024` | Taille maximale de `automation.log` avant rotation |
| `MaxLogBackups` | `3` | Nombre maximal de fichiers de backup |
| `StartImmediately` | `true` | Lance la tâche une fois après installation |
| `PauseOnExit` | désactivé sauf via `.cmd` | Garde la fenêtre ouverte à la fin du setup |

</details>

---

## Fonctionnement après installation

```text
Windows Task Scheduler
→ Run-Hidden-qbt-proton.vbs
→ Wait-And-Update-qBittorrent-Proton-Port.ps1
→ Update-qBittorrent-Proton-Port.ps1
→ qBittorrent WebUI API
```

<details>
<summary>Rôle des fichiers</summary>

```text
Setup-qbt-proton.ps1
→ installe les scripts runtime dans un dossier choisi, crée la configuration locale, crée le secret DPAPI, crée le log, génère le lanceur VBS et enregistre la tâche planifiée.

Run-Setup.cmd
→ lance le setup depuis l’interface graphique, déclenche l’élévation UAC si nécessaire et garde la fenêtre ouverte jusqu’à une validation finale.

Run-Hidden-qbt-proton.vbs
→ généré pendant l’installation ; lance le wrapper PowerShell sans fenêtre visible.

Wait-And-Update-qBittorrent-Proton-Port.ps1
→ attend et réessaie si Proton VPN ou qBittorrent ne sont pas encore prêts.

Update-qBittorrent-Proton-Port.ps1
→ extrait le port Proton VPN et met à jour qBittorrent.
```

`Wait-And-Update-qBittorrent-Proton-Port.ps1` reste utile même avec le VBS et la tâche planifiée. Le VBS masque seulement la fenêtre PowerShell ; il ne gère pas l’ordre de démarrage de Proton VPN, qBittorrent et Windows.

Le wrapper évite les échecs au démarrage quand le port forwarding Proton VPN n’a pas encore été écrit dans les logs ou quand la WebUI qBittorrent n’est pas encore joignable.

</details>

<details>
<summary>Fichiers du dépôt et fichiers générés</summary>

Fichiers inclus dans le dépôt :

```text
Run-Setup.cmd
Setup-qbt-proton.ps1
Update-qBittorrent-Proton-Port.ps1
Wait-And-Update-qBittorrent-Proton-Port.ps1
README.md
README_fr.md
LICENSE
```

Fichiers locaux générés pendant l’installation :

```text
config.json
qbt-webui-password.sec
Run-Hidden-qbt-proton.vbs
automation.log
```

`qbt-webui-password.sec` contient le secret WebUI qBittorrent chiffré via Windows DPAPI pour le compte Windows courant. Il ne doit pas être partagé ni versionné.

</details>

---

## Rotation du log

Les scripts limitent automatiquement la taille de `automation.log`.

Comportement par défaut :

```text
automation.log atteint environ 1 Mo
→ automation.log.3 est supprimé si nécessaire
→ automation.log.2 devient automation.log.3
→ automation.log.1 devient automation.log.2
→ automation.log devient automation.log.1
→ un nouveau automation.log est créé automatiquement
```

Avec les valeurs par défaut :

```text
MaxLogSizeKB = 1024
MaxLogBackups = 3
```

Taille disque maximale approximative :

```text
automation.log + automation.log.1 + automation.log.2 + automation.log.3
≈ 4 Mo
```

La rotation est implémentée dans les deux fichiers qui écrivent réellement dans le log :

```text
Update-qBittorrent-Proton-Port.ps1
Wait-And-Update-qBittorrent-Proton-Port.ps1
```

Aucune dépendance externe n’est requise.

---

## Test manuel

Si le dossier d’installation par défaut a été utilisé :

```powershell
$InstallDir = "$env:LOCALAPPDATA\Scripts\qbt-proton"
```

Sinon, adapter `$InstallDir` au dossier choisi pendant l’installation.

Exécuter :

```powershell
powershell.exe `
	-NoProfile `
	-NonInteractive `
	-ExecutionPolicy Bypass `
	-File "$InstallDir\Update-qBittorrent-Proton-Port.ps1"
```

Sortie attendue :

```text
Starting qBittorrent port update
Extracted Proton VPN forwarded port: XXXXX
qBittorrent already uses the expected port: XXXXX
```

ou :

```text
qBittorrent port updated: OLD_PORT -> NEW_PORT
```

Lire le log :

```powershell
Get-Content "$InstallDir\automation.log" -Tail 80
```

---

## Compatibilité

| Composant | Version validée |
|---|---:|
| Proton VPN for Windows | 4.4.1 |
| qBittorrent | 5.2.1 |
| Windows | Windows 11 25H2 |
| PowerShell | Windows PowerShell 5.1 |

<details>
<summary>Détails de compatibilité</summary>

Devrait fonctionner avec :

- Windows 10/11 avec Windows PowerShell 5.1.
- Les versions de qBittorrent exposant les endpoints WebUI API utilisés par ce projet :
  - `/api/v2/auth/login`
  - `/api/v2/auth/logout`
  - `/api/v2/app/preferences`
  - `/api/v2/app/setPreferences`
- Les versions Windows de Proton VPN qui continuent d’écrire le port forwarded actif dans :

```text
%LOCALAPPDATA%\Proton\Proton VPN\Logs\client-logs.txt
```

avec des lignes compatibles avec les motifs suivants :

```text
Port forwarding port changed from '...' to 'XXXXX'
Port pair XXXXX->XXXXX
Received PortForwarding Status 'Stopped'
```

Le projet peut cesser de fonctionner si Proton VPN change le chemin du fichier de log, la syntaxe des logs, ou si qBittorrent modifie son API WebUI.

</details>

---

## Commandes de maintenance

Dans les exemples ci-dessous, définir d’abord :

```powershell
$InstallDir = "$env:LOCALAPPDATA\Scripts\qbt-proton"
```

Adapter ce chemin si un dossier d’installation personnalisé a été choisi.

<details>
<summary>Vérifier les fichiers</summary>

```powershell
Get-ChildItem $InstallDir |
	Select-Object Name, Length, LastWriteTime
```

</details>

<details>
<summary>Lire la configuration</summary>

```powershell
Get-Content "$InstallDir\config.json" |
	ConvertFrom-Json |
	Format-List
```

</details>

<details>
<summary>Suivre le log en temps réel</summary>

```powershell
Get-Content "$InstallDir\automation.log" -Wait -Tail 30
```

</details>

<details>
<summary>Vider le log</summary>

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
<summary>Vérifier la taille des logs</summary>

```powershell
Get-ChildItem "$InstallDir\automation.log*" |
	Select-Object Name, Length, LastWriteTime
```

</details>

<details>
<summary>Vérifier la tâche planifiée</summary>

```powershell
Get-ScheduledTask -TaskName "Update qBittorrent Proton forwarded port" |
	Select-Object TaskName, State, TaskPath

Get-ScheduledTaskInfo -TaskName "Update qBittorrent Proton forwarded port"
```

</details>

<details>
<summary>Inspecter l’action de la tâche planifiée</summary>

```powershell
(Get-ScheduledTask -TaskName "Update qBittorrent Proton forwarded port").Actions
```

Action attendue :

```text
wscript.exe "...\Run-Hidden-qbt-proton.vbs"
```

Si l’action lance directement `powershell.exe`, une fenêtre PowerShell visible peut apparaître.

</details>

<details>
<summary>Désactiver, réactiver ou supprimer la tâche</summary>

Désactiver :

```powershell
Disable-ScheduledTask -TaskName "Update qBittorrent Proton forwarded port"
```

Réactiver :

```powershell
Enable-ScheduledTask -TaskName "Update qBittorrent Proton forwarded port"
```

Supprimer :

```powershell
Unregister-ScheduledTask `
	-TaskName "Update qBittorrent Proton forwarded port" `
	-Confirm:$false
```

</details>

<details>
<summary>Modifier l’intervalle d’exécution</summary>

Exemple : toutes les 5 minutes.

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
<summary>Recréer le secret du mot de passe WebUI qBittorrent</summary>

À exécuter depuis une session PowerShell normale, avec le même compte Windows que celui qui lance la tâche planifiée.

```powershell
$SecretPath = "$InstallDir\qbt-webui-password.sec"

Read-Host "qBittorrent WebUI password" -AsSecureString |
	ConvertFrom-SecureString |
	Set-Content $SecretPath -Encoding UTF8
```

</details>

<details>
<summary>Modifier l’URL WebUI qBittorrent</summary>

Exemple : WebUI qBittorrent déplacée de `8080` vers `8081`.

```powershell
$ConfigPath = "$InstallDir\config.json"
$config = Get-Content $ConfigPath -Encoding UTF8 | ConvertFrom-Json
$config.QbtBaseUrl = "http://127.0.0.1:8081"
$config | ConvertTo-Json -Depth 4 | Set-Content $ConfigPath -Encoding UTF8
```

</details>

<details>
<summary>Modifier le chemin du log Proton VPN</summary>

```powershell
$ConfigPath = "$InstallDir\config.json"
$config = Get-Content $ConfigPath -Encoding UTF8 | ConvertFrom-Json
$config.ProtonLogPath = "$env:LOCALAPPDATA\Proton\Proton VPN\Logs\client-logs.txt"
$config | ConvertTo-Json -Depth 4 | Set-Content $ConfigPath -Encoding UTF8
```

</details>

---

## Dépannage

<details>
<summary>Le setup se ferme immédiatement après l’UAC</summary>

Utiliser `Run-Setup.cmd` depuis le dossier du dépôt. Le fichier `.cmd` lance `Setup-qbt-proton.ps1` avec `-PauseOnExit`, et le setup relance une fenêtre élevée persistante si nécessaire.

Si le problème persiste, lancer depuis une console déjà ouverte pour lire l’erreur :

```powershell
powershell.exe `
	-NoProfile `
	-ExecutionPolicy Bypass `
	-File .\Setup-qbt-proton.ps1
```

</details>

<details>
<summary>Le setup échoue avant de demander le mot de passe WebUI</summary>

Causes probables :

```text
- Proton VPN n’est pas lancé ;
- le fichier client-logs.txt n’existe pas encore ;
- qBittorrent n’est pas lancé ;
- la WebUI qBittorrent n’est pas activée ;
- l’URL WebUI configurée n’est pas correcte.
```

Vérifier Proton VPN :

```powershell
Test-Path "$env:LOCALAPPDATA\Proton\Proton VPN\Logs\client-logs.txt"
```

Vérifier qBittorrent WebUI :

```text
http://127.0.0.1:8080
```

</details>

<details>
<summary><code>Access is denied</code> lors de la création de la tâche planifiée</summary>

L’enregistrement de la tâche nécessite une élévation. Utiliser `Run-Setup.cmd` et accepter l’UAC, ou lancer PowerShell en administrateur.

</details>

<details>
<summary>Une fenêtre PowerShell apparaît toutes les quelques minutes</summary>

La tâche planifiée lance probablement PowerShell directement au lieu du VBS généré.

Vérifier :

```powershell
(Get-ScheduledTask -TaskName "Update qBittorrent Proton forwarded port").Actions
```

Résultat attendu :

```text
wscript.exe "...\Run-Hidden-qbt-proton.vbs"
```

Relancer le setup pour recréer la tâche correctement.

</details>

<details>
<summary><code>Secret file not found</code></summary>

Le fichier secret DPAPI est manquant ou la configuration pointe vers le mauvais chemin.

Vérifier :

```powershell
Get-Content "$InstallDir\config.json" |
	ConvertFrom-Json |
	Format-List
```

Recréer le secret :

```powershell
$SecretPath = "$InstallDir\qbt-webui-password.sec"

Read-Host "qBittorrent WebUI password" -AsSecureString |
	ConvertFrom-SecureString |
	Set-Content $SecretPath -Encoding UTF8
```

</details>

<details>
<summary><code>qBittorrent login failed: 403 Forbidden</code></summary>

Causes probables :

- Mot de passe WebUI qBittorrent incorrect.
- Bannissement temporaire par qBittorrent après des tentatives de connexion échouées.
- Incohérence avec la validation du header `Host`.
- `Server domains` ne contient pas l’hôte utilisé par le script.

Valeurs WebUI qBittorrent recommandées :

```text
IP address: 127.0.0.1
Port: 8080
Host header validation: Enabled
Server domains: 127.0.0.1, localhost
```

Si un bannissement temporaire est suspecté, fermer qBittorrent, attendre quelques minutes, relancer qBittorrent, puis recréer le secret avec le bon mot de passe.

</details>

<details>
<summary><code>No active forwarded port found</code></summary>

Causes probables :

- Proton VPN n’est pas connecté.
- Le port forwarding Proton VPN est désactivé.
- Le serveur actuel ne supporte pas le P2P ou le port forwarding.
- Proton VPN n’a pas encore écrit le port forwarded actif dans le log.
- Proton VPN a changé le chemin du log ou sa syntaxe.

Vérifier :

```powershell
Select-String `
	-Path "$env:LOCALAPPDATA\Proton\Proton VPN\Logs\client-logs.txt" `
	-Pattern "Port forwarding port changed", "Port pair", "PortForwarding Status"
```

</details>

<details>
<summary>La WebUI qBittorrent est visible dans le navigateur, mais le script échoue</summary>

Le navigateur peut avoir un cookie d’authentification valide, alors que le script doit se connecter via l’API.

Tester l’endpoint WebUI :

```powershell
Invoke-WebRequest `
	-UseBasicParsing `
	-Uri "http://127.0.0.1:8080" `
	-Headers @{
		Referer = "http://127.0.0.1:8080/"
		Origin = "http://127.0.0.1:8080"
	}
```

Recréer ensuite le secret local si nécessaire.

</details>

<details>
<summary>Le log ne se met pas à jour</summary>

Tester chaque couche manuellement :

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

Après chaque commande :

```powershell
Get-Content "$InstallDir\automation.log" -Tail 80
```

</details>

<details>
<summary>Le port qBittorrent ne change pas</summary>

Lancer le script principal manuellement et vérifier le log :

```powershell
powershell.exe `
	-NoProfile `
	-NonInteractive `
	-ExecutionPolicy Bypass `
	-File "$InstallDir\Update-qBittorrent-Proton-Port.ps1"

Get-Content "$InstallDir\automation.log" -Tail 80
```

Vérifier ensuite dans qBittorrent :

```text
Tools → Options → Connection → Port used for incoming connections
```

</details>

---

## Désinstallation

Si le dossier d’installation par défaut a été utilisé :

```powershell
$InstallDir = "$env:LOCALAPPDATA\Scripts\qbt-proton"
```

Sinon, adapter `$InstallDir` au dossier choisi pendant l’installation.

Supprimer la tâche planifiée et les fichiers locaux :

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

## Notes de sécurité et légalité

> [!WARNING]
> Ce projet ne rend pas BitTorrent anonyme. Il synchronise uniquement un port d’écoute.

Une configuration correcte dépend toujours de l’usage adéquat du VPN, du binding de qBittorrent sur la bonne interface réseau, du durcissement de la WebUI qBittorrent, et d’un usage légal du protocole BitTorrent.

La WebUI qBittorrent ne doit pas être exposée à Internet. Ce projet suppose un endpoint WebUI local sur `127.0.0.1`.

Ne pas utiliser ce projet pour violer le droit d’auteur, contourner la loi, distribuer des malwares ou effectuer des activités non autorisées.

Utilisation à vos propres risques. Relire les scripts avant exécution.

---

## Licence

`proton-qbt-sync` est distribué sous **GNU General Public License version 3 ou ultérieure** (`GPL-3.0-or-later`).

Cela signifie que les versions modifiées redistribuées doivent rester sous des conditions compatibles GPL et conserver le code source correspondant disponible sous GPL. Voir [`LICENSE`](LICENSE) pour le texte complet de la licence.

---

## Références

- Documentation Proton VPN port forwarding : <https://protonvpn.com/support/port-forwarding>
- Documentation Proton VPN BitTorrent/qBittorrent : <https://protonvpn.com/support/bittorrent-vpn>
- Documentation qBittorrent WebUI API : <https://github.com/qbittorrent/qBittorrent/wiki/WebUI-API>
- Documentation qBittorrent VPN binding : <https://github.com/qbittorrent/qBittorrent/wiki/How-to-bind-your-vpn-to-prevent-ip-leaks>