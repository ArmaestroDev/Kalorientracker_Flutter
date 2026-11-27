# Kalorientracker

Persönlicher Kalorien- und Makro-Tracker mit KI-Coach. Läuft komplett lokal auf dem Gerät, für einen Nutzer, ohne Konto und ohne Backend.

## Funktionen

- **Coach** — Chat mit dem KI-Coach. Er sieht Profil, Ziele, heutiges Log, Woche, Gewicht und Pläne und trägt per Function-Calling Mahlzeiten, Aktivitäten und Gewicht direkt ein.
- **Heute** — Tageslog mit Kalorien- und Makro-Übersicht, Aktivitäten und Gewichtseintrag. Neue Einträge per Text (die KI entscheidet zwischen Mahlzeit und Aktivität), Foto, Barcode oder Sprache.
- **Verlauf** — Kalorien-, Makro- und Gewichtsdiagramme für 14 Tage, 12 Wochen und 12 Monate.
- **Profil** — Körperdaten, Ziel, KI-Anbieter, API-Schlüssel, Modellwahl und Theme.
- **Barcode-Scanner** über OpenFoodFacts und **Foto-Erkennung** für Mahlzeiten.
- **Ernährungs- und Trainingspläne** — als PDF importieren (lokale Textextraktion, KI als Fallback) oder als Text anlegen.
- **Android-Widget** — Kalorien, Fortschritt und Makros auf dem Home-Screen, mit Schnellaktionen für Text, Sprache und Foto.

## KI-Anbieter

| Anbieter | Schlüssel |
|----------|-----------|
| Gemini | kostenlos, Schlüssel von [aistudio.google.com](https://aistudio.google.com) |
| Claude | kostenpflichtiger API-Schlüssel von Anthropic |
| OpenAI | kostenpflichtiger API-Schlüssel |
| Grok (xAI) | kostenpflichtiger API-Schlüssel |

Der Schlüssel wird im Profil eingetragen und bleibt auf dem Gerät. Die Liste der verfügbaren Modelle wird bei jedem App-Start live beim Anbieter abgefragt; ohne gültigen Schlüssel greift eine eingebaute Standardliste.

## Themes

Fünf Paletten: **Amethyst**, **Saphir**, **Smaragd**, **Schwarz & Weiß**, **Pink** — jede in Hell, Dunkel oder nach Systemeinstellung.

## Starten

```sh
flutter pub get
flutter run
```

## Tests

```sh
flutter test
```

## Projekt

ArmaestroDev — [github.com/ArmaestroDev/Kalorientracker](https://github.com/ArmaestroDev/Kalorientracker)
