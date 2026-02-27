# BugMe 🎙️

> **Voice-powered personal budget tracker for Android.**  
> Say "Spent $12 on coffee this morning" — BugMe logs it automatically.

---

## What it does

- **Voice entry** — hold the mic button and describe your spend in plain English
- **AI parsing** — Google Gemini extracts amount, category, description and date from your words
- **Confirm before saving** — review and edit the parsed entry before it hits the database
- **Monthly budget allocations** — set spending limits per category for any month
- **Visual dashboard** — donut chart, per-category progress bars, and a running total
- **Transaction log** — scrollable list with category filters and swipe-to-delete
- **100% local storage** — SQLite on device, no cloud, no sync, no accounts

---

## Screenshots

_Coming soon once first build is complete._

---

## Getting started

### Prerequisites

| Tool | Minimum version |
|---|---|
| Flutter | 3.10+ |
| Dart | 3.0+ |
| Android device or emulator | API 21+ (Android 5.0+) |

### Steps

1. **Install dependencies**
   ```bash
   flutter pub get
   ```

2. **Generate database code** (Drift ORM — run once, and after DB schema changes)
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```

3. **Run on Android**
   ```bash
   flutter run
   ```

4. **Add your Gemini API key**  
   Open the app → **Settings** → paste your free key from [aistudio.google.com](https://aistudio.google.com).  
   The key is stored locally on device only.

---

## Project structure

```
lib/
├── core/
│   ├── constants/      app_constants.dart  (Gemini prompt, categories)
│   └── theme/          app_theme.dart      (Material 3 dark theme)
├── data/
│   ├── database/       Drift schema & DAOs
│   ├── models/         ParsedEntry DTO
│   ├── providers/      Riverpod providers
│   └── services/       GeminiService
└── features/
    ├── dashboard/      Overview screen (charts, totals)
    ├── voice/          Voice entry + confirm card
    ├── transactions/   Transaction list
    ├── budget/         Monthly allocation setup
    └── settings/       API key management
```

---

## Tech stack

| Layer | Package |
|---|---|
| Framework | Flutter 3 + Material 3 |
| State management | flutter_riverpod |
| Database | Drift (SQLite) |
| Voice input | speech_to_text |
| AI parsing | google_generative_ai (Gemini 1.5 Flash) |
| Charts | fl_chart |
| Animations | flutter_animate |

---

## Privacy

All data stays on your device. The only network call made is to the Google Gemini API when you submit a voice entry for parsing. Your Gemini API key is stored in Android SharedPreferences (app-private storage).

---

## License

MIT
