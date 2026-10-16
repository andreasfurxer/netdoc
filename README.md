# netDoc

Netzwerk-Dokumentation & VLAN-Tracker (PHP + SQLite + nmap) als Docker-Image.
Aktuelle Version: siehe `APP_VERSION` in `src/index.php`.

Ablauf: Code in GitHub → GitHub Actions baut das Image → `ghcr.io/andreasfurxer/netdoc` → Dockhand zieht es.

## Inhalt

| Datei | Zweck |
| --- | --- |
| `src/index.php` | die komplette App |
| `Dockerfile`, `docker-entrypoint.sh` | PHP 8.3 + Apache + nmap, Start-Skript mit Hintergrund-Scan |
| `apache-netdoc.conf`, `netdoc.ini` | Apache-/PHP-Einstellungen (`data/` ist gesperrt) |
| `.github/workflows/docker.yml` | baut und veröffentlicht das Image bei einem Tag `v*` |
| `docker-compose.example.yml` | Beispiel-Stack (Vorlage) für Dockhand |
| `build.sh` | optional: lokaler Test-Build |
| `branding/` | Logo, App-Icons, BookStack-Buchbild |

## 1. Repository anlegen (einmalig)

1. Auf github.com → **New repository**: Name `netdoc`, **Public**, ohne README/.gitignore/Lizenz.
2. ZIP entpacken, im Ordner `netdoc` ausführen:
   ```
   git init -b main
   git add .
   git commit -m "netDoc 2.0.1"
   git remote add origin https://github.com/andreasfurxer/netdoc.git
   git push -u origin main
   ```
   Beim Push fragt Git nach dem Benutzernamen und einem **Personal Access Token** als Passwort (GitHub → Settings → Developer settings → Personal access tokens, Recht `repo` und `workflow`). Mit der GitHub-CLI geht es einfacher: `gh auth login`.

## 2. Version veröffentlichen

Die Version steht in `src/index.php` (`APP_VERSION`). Der Tag muss dazu passen, sonst bricht der Workflow ab.

```
git tag v2.0.1
git push origin v2.0.1
```

Alternativ auf GitHub: **Releases → Draft a new release → Tag `v2.0.1` neu anlegen → Publish**.

Unter dem Reiter **Actions** läuft jetzt der Build (ca. 5–10 Minuten, Intel/AMD und ARM). Danach liegt das Image unter `ghcr.io/andreasfurxer/netdoc:2.0.1`.

## 3. Paket öffentlich machen (einmalig, wichtig)

GitHub legt neue Pakete zunächst als **privat** an. Damit der Docker-Host ohne Login ziehen kann:

GitHub → dein Profil → **Packages** → `netdoc` → **Package settings** → **Change visibility** → **Public**.

## 4. NFS-Freigabe auf der Synology

Systemsteuerung → Dateidienste → NFS aktivieren (maximal NFSv4.1). Dann den Freigabeordner, in dem der Datenordner liegt → Bearbeiten → NFS-Berechtigungen → Erstellen:

| Feld | Wert |
| --- | --- |
| Hostname oder IP | IP des Docker-Hosts (oder das gesamte Netz) |
| Berechtigung | Lesen/Schreiben |
| Squash | Kein Mapping (empfohlen) oder „Alle Benutzer auf admin abbilden“ |
| Asynchron | Nein |
| Nicht privilegierte Ports erlauben | Ja |

Der Datenordner (`device:` im Stack) muss auf dem NFS-Server existieren. Eine vorhandene `network.db` wird weiterverwendet.

Test auf dem Docker-Host: `sudo mount -t nfs -o nfsvers=4.1 <nfs-server-ip>:<datenordner> /mnt`. Geht NFSv4.1 nicht, im Stack `nfsvers=3` eintragen.

## 5. Stack in Dockhand

`docker-compose.example.yml` ist eine Vorlage. Den Inhalt kopieren, in Dockhand als neuen Stack einfügen und **dort** an das eigene Netz anpassen (macvlan-Netzwerk, freie IP, NFS-Server und -Pfad). Die angepasste Version bleibt nur in Dockhand und gehört nicht ins Repository, damit keine Netzwerkdaten öffentlich werden.

Dockhand zieht das Image selbst von ghcr.io. Aufgerufen wird netDoc unter der IP, die im Stack bei `ipv4_address` steht.

Voraussetzung: Das macvlan-Netzwerk existiert auf dem Docker-Host (`docker network ls`) und die gewählte IP ist frei.

## Update

1. Code ändern, `APP_VERSION` erhöhen (zum Beispiel `2.0.2`), committen und pushen:
   ```
   git add . && git commit -m "netDoc 2.0.2" && git push
   ```
2. Tag setzen: `git tag v2.0.2 && git push origin v2.0.2`
3. Warten, bis der Build unter **Actions** grün ist.
4. In Dockhand im Stack `image: ghcr.io/andreasfurxer/netdoc:2.0.2` eintragen und neu deployen.

Die Daten bleiben auf der Synology, die Datenbank wird automatisch erweitert.

## SQLite auf NFS

- NFSv4 verwenden, kein `nolock`, `hard` statt `soft`.
- Nur eine netDoc-Instanz auf die Datei zugreifen lassen.
- `network.db` regelmäßig sichern (zum Beispiel Hyper Backup oder Snapshot Replication).

## Einstellungen

| Was | Wo |
| --- | --- |
| Port der Weboberfläche | `NETDOC_PORT` im Stack (auf 80 gesetzt) |
| Zeitzone | `TZ` im Stack (Europe/Vienna) |
| Scan-Intervall, NEU-Markierung usw. | in der App unter „Einstellungen“ |

Der automatische Scan läuft im Container (Schleife im Entrypoint, jede Minute Prüfung). Ein Cronjob ist nicht nötig.

## Netzwerk-Hinweise

- Der Container hängt über ein externes macvlan-Netzwerk mit fester IP im Netz. Es gibt kein `ports:`, die Seite läuft auf Port 80 der Container-IP.
- Bei macvlan kann der Docker-Host den Container nicht direkt erreichen, andere Geräte schon.
- MAC und Hersteller gibt es nur für Geräte im selben Layer-2-Netz wie der Container. Andere VLANs werden über den Router gescannt, dort bleiben die MACs leer.
- Die Seite hat keinen Login. Nur intern erreichbar machen oder einen Reverse-Proxy mit Anmeldung davorsetzen.
- Das Repository ist öffentlich: Keine Zugangsdaten, Datenbanken oder eigenen Stacks einchecken (`data/` und `*.db` stehen in `.gitignore`).

## Fehlersuche

| Symptom | Abhilfe |
| --- | --- |
| Actions-Build bricht ab: „Tag passt nicht zu APP_VERSION“ | `APP_VERSION` in `src/index.php` an den Tag anpassen, committen, Tag neu setzen |
| Dockhand: „denied“ / „unauthorized“ beim Pull | Paket auf **Public** stellen (Schritt 3) |
| Dockhand: „manifest unknown“ | Tag im Stack stimmt nicht oder der Build lief noch nicht durch |
| Deploy-Fehler beim Volume (`mount`, `permission denied`) | NFS-Berechtigung für die IP des Docker-Hosts prüfen, Ordner `data` vorhanden? |
| Log: „nicht beschreibbar“ | Squash auf „Kein Mapping“ oder „Alle Benutzer auf admin abbilden“ |
| „database is locked“ / „readonly database“ | NFSv4, `hard`, nur eine Instanz, Schreibrechte prüfen |
| Scan meldet „fehlgeschlagen“ | `docker exec netdoc which nmap` |
| „davon 0 mit MAC“ | Gescanntes Netz ist nicht das macvlan-Netz: `docker exec netdoc ip neigh` |
| Seite nicht erreichbar | Ist die IP aus dem Stack frei und das macvlan-Netzwerk vorhanden? Nicht vom Docker-Host aus testen (macvlan) |
| Logs | `docker logs netdoc` |
