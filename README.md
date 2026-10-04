# Water With Me

Eigenständige React-Web-App für GitHub Pages. Supabase speichert Profile, Getränke und Freundesverbindungen in einem separaten, privaten Datenbereich.

## Funktionen

- Wasser, Sprudel, Kaffee, Tee, Saft und Softdrink.
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
