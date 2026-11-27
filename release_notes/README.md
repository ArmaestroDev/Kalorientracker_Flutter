# Release-Notizen

Für jede Version eine Datei `release_notes/v<version>.md` anlegen, wobei `<version>` der Version in `pubspec.yaml` entspricht (z. B. `release_notes/v1.3.0.md`).

Ein Push auf `main` mit einer neuen Version baut die APKs und veröffentlicht das GitHub-Release mit diesen Notizen. Pusht man ohne Versionsänderung, entstehen nur Build-Artefakte und kein neues Release.
