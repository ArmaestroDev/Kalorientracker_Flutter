# Kalorientracker (Flutter Edition)

Ein moderner, plattformübergreifender und einfach zu bedienender Kalorientracker. Diese App wurde entwickelt, um die tägliche Nahrungsaufnahme unkompliziert zu protokollieren und Fitnessziele zu unterstützen. Das Projekt ist ein Rewrite der ursprünglichen Android-App in **Flutter**.

## <img src="https://github.com/user-attachments/assets/1bdafe89-2089-475d-b62c-9eba9724e0ff" alt="App Screenshot" width="350"/>

## Inhaltsverzeichnis

- [Über das Projekt](#über-das-projekt)
  - [Funktionen](#funktionen)
  - [Technologie-Stack](#technologie-stack)
- [Erste Schritte](#erste-schritte)
  - [Voraussetzungen](#voraussetzungen)
  - [Installation & Ausführung](#installation--ausführung)
- [Verwendung](#verwendung)
- [Zukünftige Entwicklungen](#zukünftige-entwicklungen)
- [Mitwirkung](#mitwirkung)
- [Kontakt](#kontakt)

---

## Über das Projekt

Dieses Projekt ist eine Cross-Platform-Anwendung (Android, iOS, Windows), die es Benutzern ermöglicht, ihre tägliche Kalorien-, Protein-, Kohlenhydrat- und Fettaufnahme, sowie ihr Aktivitätslevel zu verfolgen. Ziel war es, eine minimalistische und performante Alternative zu überladenen Fitness-Apps zu schaffen.

### Funktionen

- ✔️ **Tagesprotokoll:** Erfasse Mahlzeiten und Snacks für den aktuellen Tag.
- ✔️ **KI-Unterstützung:** Automatische Nährwertschätzung durch Gemini 2.5 Flash oder Claude 3.5 Sonnet.
- ✔️ **Barcode-Scanner:** Scanne Produkte direkt über die OpenFoodFacts-API.
- ✔️ **Nährwertübersicht:** Automatische Berechnung der Gesamt-Makronährstoffe und Kalorien (BMR/TDEE).
- ✔️ **Persistente Datenspeicherung:** Einträge werden lokal auf dem Gerät gespeichert (SQLite).
- ✔️ **Theming:** 4 verschiedene Farbthemen (Default, Ocean, Dark Forest, Dark Purple).

### Technologie-Stack

Dieses Projekt wurde mit den folgenden Technologien umgesetzt:

- **Framework:** Flutter (Dart)
- **State Management:** Provider
- **Datenbank:** Sqflite (SQLite)
- **API Integration:**
  - Google Generative AI (Gemini)
  - Anthropic API (Claude)
  - OpenFoodFacts API
  - Mobile Scanner (Kamera-Integration)

---

## Erste Schritte

Folge diesen Schritten, um das Projekt lokal auf deinem Rechner einzurichten und auf einem Emulator oder einem physischen Gerät auszuführen.

### Voraussetzungen

Stelle sicher, dass die folgende Software auf deinem System installiert ist:

- **Flutter SDK:** [Installationsanleitung](https://docs.flutter.dev/get-started/install)
- **Visual Studio Code** oder **Android Studio** mit Flutter-Plugins.

### Installation & Ausführung

1.  **Klone das Repository:**
    ```sh
    git clone https://github.com/ArmaestroDev/Kalorientracker.git
    cd kalorientracker_flutter
    ```
2.  **Abhängigkeiten installieren:**
    ```sh
    flutter pub get
    ```
3.  **Die App ausführen:**
    Stelle sicher, dass ein Simulator/Emulator läuft oder ein Gerät angeschlossen ist.

    ```sh
    flutter run
    ```

    Für eine optimierte Release-Version:

    ```sh
    flutter build apk --release
    ```

---

## Verwendung

Nachdem die App gestartet ist, kannst du beginnen, deine Mahlzeiten hinzuzufügen. Zuvor musst du deine Profildaten eingeben, sowie auch deinen Gemini API Key (oder Claude Key), den sich jeder kostenlos besorgen kann: [https://ai.google.dev/gemini-api/docs/api-key](https://ai.google.dev/gemini-api/docs/api-key)

1.  **Mahlzeit hinzufügen:** Tippe auf den entsprechenden Button (`+`), um eine neue Mahlzeit einzugeben. Du kannst den Namen eingeben (z.B. "1 Apfel") und die KI schätzt die Kalorien, oder den Barcode scannen.
2.  **Aktivitäten hinzufügen:** Tippe auf den "Running"-Button, um eine neue Aktivität einzugeben (z.B. "30 min Joggen").
3.  **Werte anpassen:** Falls die KI-Schätzung nicht passt, kannst du die Werte jederzeit manuell korrigieren.
4.  **Speichern:** Bestätige die Eingabe. Die Hauptansicht aktualisiert sich automatisch und zeigt die neuen Gesamtwerte für den Tag an.

---

## Zukünftige Entwicklungen

Ideen für zukünftige Versionen und Verbesserungen:

- [ ] Grafische Darstellung des Verlaufs mit Diagrammen.
- [ ] Cloud-Sync für mehrere Geräte.
- [ ] Export der Daten als CSV/PDF.

---

## Mitwirkung

Beiträge sind das, was die Open-Source-Community zu einem so großartigen Ort zum Lernen, Inspirieren und Gestalten macht. Jeder Beitrag, den du leistest, wird **sehr geschätzt**.

1.  Forke das Projekt
2.  Erstelle deinen Feature-Branch (`git checkout -b feature/AmazingFeature`)
3.  Commite deine Änderungen (`git commit -m 'Add some AmazingFeature'`)
4.  Pushe zum Branch (`git push origin feature/AmazingFeature`)
5.  Öffne einen Pull Request

---

## Kontakt

ArmaestroDev - Finde mich auf GitHub

Projekt-Link: [https://github.com/ArmaestroDev/Kalorientracker](https://github.com/ArmaestroDev/Kalorientracker)
