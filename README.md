# Water With Me

Eigenständige React-Web-App für GitHub Pages. Supabase speichert Profile, Getränke und Freundesverbindungen in einem separaten, privaten Datenbereich.

## Funktionen

- Wasser, Sprudel, Kaffee, Tee, Saft und Softdrink.
- Eigene Monster-Energy-Sektion mit 500-ml-Dose und frei wählbarer Menge.
- Push-Mitteilungen von verknüpften Freunden, pro Gerät aktivierbar, mit Test-Mitteilung.
- Ein-Tipp-Eintrag, eigene Mengen und Tagesziel.
- Tagesverlauf und sieben Tage Trinkmengen.
- Freunde per QR-Code oder Einladungscode, mit Bestätigung.
- Gegenseitiger Feed und Anstoßen.
- Anmeldung und Registrierung über Supabase. Bestehende RepPilot-Konten funktionieren ebenfalls.
- Kein persönlicher Name und keine E-Mail in den App- oder QR-Adressen. Freunde sehen ausschließlich den gewählten Profilnamen.

## Veröffentlichung

Repository: `basti92bot/water-with-me-`. Die mitgelieferte Workflow-Datei baut und veröffentlicht die App bei einem Push nach `main`. In GitHub Settings > Pages als Quelle GitHub Actions auswählen. Solange diese Quelle nicht aktiviert ist, kann der Workflow die Veröffentlichung nicht abschließen. Bei Bedarf danach unter Actions den Workflow erneut starten.

## Entwicklung

Node.js 22, pnpm 11.25.0.

```
pnpm install --frozen-lockfile
pnpm test
pnpm build
```

Alle Assets und Links funktionieren auch unter dem Repository-Unterpfad. Die Supabase-Konfiguration enthält ausschließlich den öffentlichen Publishable Key, keinen Server-Schlüssel.

## Datenbank

`backend/schema.sql` dokumentiert den bereits eingerichteten Datenbereich. Nicht erneut ungeprüft ausführen. Die privaten Tabellen haben RLS aktiviert und keine direkten Zugriffsrechte für Browser-Clients. Die API-Funktionen prüfen serverseitig die Benutzer-ID und bestehende Freundesverbindungen. `backend/test.sql` prüft die Funktionen mit Testdaten in einer zurückgerollten Transaktion.

Die Tests haben Speicherung, Einstellungen, Einladungsvorschau, gegenseitige Freundschaften, Eintragsbesitz, Reaktionen und Ablehnung nicht angemeldeter Aufrufe geprüft. QR-Codes wurden generiert und unabhängig wieder ausgelesen. Ein vollständiger Bedienungstest im Browser steht noch aus.

## E-Mail-Bestätigung

Neue Nutzer bestätigen ihre E-Mail und öffnen anschließend Water With Me erneut. Der bestehende Supabase-Projektstandard für Bestätigungslinks bleibt bestehen. Die Pages-Adresse kann als eigener erlaubter Rücksprungpfad eingerichtet werden.

## Push-Mitteilungen

Im Profil oder unter Freunde auf diesem Gerät aktivieren. Auf dem iPhone zuerst in Safari zum Home-Bildschirm hinzufügen und über das Icon öffnen. Die Browserberechtigung wird ausschließlich nach einem Tastendruck angefragt. Beim Abmelden wird dieses Gerät abgemeldet.

`backend/push/schema.sql` ist bereits angewendet. Private VAPID- und Dispatcher-Schlüssel befinden sich ausschließlich in Supabase Vault. Die Edge Function `wwm-push` prüft einen eigenen Dispatcher-Token; deshalb ist die Legacy-JWT-Prüfung für diese einzelne Function deaktiviert. Ihre Worker-RPCs sind ausschließlich für die Serverrolle freigegeben.

Neue Getränke erzeugen atomar Aufträge für aktivierte Freundesgeräte. Der Versand wird nach Transaktionsabschluss gestartet; ein Cron-Job versucht vorübergehende Fehler erneut. Abgelaufene Geräte werden entfernt, Wiederholungen sind begrenzt und Aufträge verfallen nach 15 Minuten. Entfernte Freundschaften, abgemeldete Geräte und gelöschte Einträge werden vor dem Versand berücksichtigt. Bereits empfangene Mitteilungen können nicht zurückgerufen werden. Apple, Google, Mozilla und Microsoft empfangen ausschließlich verschlüsselte Nachrichten. Zustellung hängt von Browserberechtigung, Netzwerk und Geräte-Einstellungen ab.

`backend/push/test.sql` läuft in einer zurückgerollten Transaktion und prüft Berechtigungen, Freunde, SSRF-Schutz, Duplikate, Leasing, Wiederholung, Abmeldung und Monster. `tests/push.test.mjs` prüft die tatsächliche Verschlüsselung/Entschlüsselung, Fehlerbehandlung und Service-Worker-Mitteilungen. Eine reale Mitteilung auf einem iPhone muss nach Aktivierung über „Test-Mitteilung senden“ bestätigt werden.

### Registrierung

Anmelden und Konto erstellen sind getrennte Schaltflächen. Fehlende Angaben und Passwörter unter 8 Zeichen werden sichtbar erklärt. Eine Anfrage kann die Oberfläche maximal 20 Sekunden sperren. Die E-Mail-Bestätigung bleibt aktiv; nach dem Bestätigen die Water-With-Me-App erneut öffnen. Fehler des E-Mail-Versanddiensts und Sendelimits werden konkret angezeigt. Eine Registrierung mit echter Bestätigungsmail wurde in diesem Update nicht durchgeführt.

## Version 1.2

Monster Energy mit 500 ml ist beim Öffnen vorausgewählt. Wasser wurde aus der Auswahl neuer Getränke entfernt. Die eigene Monster-Sektion bleibt erhalten. Bestehende Wasser-Einträge bleiben im Verlauf lesbar.
