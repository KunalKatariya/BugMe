# BugMe — Roadmap

## Legend
- ✅ Completed
- 🔄 In Progress
- 📋 Planned
- 💡 Future idea

---

## v1.0 — Foundation (Current)

### Architecture
- ✅ Flutter project scaffolded with proper folder structure
- ✅ Material 3 dark theme with custom violet brand palette
- ✅ Riverpod state management wired up
- ✅ Drift SQLite database with transactions & budget allocations tables
- ✅ Bottom navigation shell (5 tabs)

### Features
- ✅ **Voice entry** — speech-to-text via Android SpeechRecognizer
- ✅ **AI parsing** — Google Gemini 1.5 Flash extracts amount, category, description, date
- ✅ **Confirm card** — review and edit parsed entry before saving
- ✅ **Dashboard** — total spend card, donut chart by category, progress bars, recent transactions
- ✅ **Transaction log** — monthly list, category filter, swipe-to-delete
- ✅ **Budget setup** — per-category monthly allocations with over-budget warnings
- ✅ **Settings** — Gemini API key management
- ✅ **Month navigation** — arrow buttons to browse past/future months

### Infrastructure
- ✅ Android permissions (RECORD_AUDIO, INTERNET)
- ✅ README with setup instructions
- ✅ ROADMAP (this file)

---

## v1.1 — Polish & Reliability

- 📋 Run `build_runner` and commit generated Drift `*.g.dart` files
- 📋 Add app icon (replace default Flutter icon)
- 📋 Add splash screen with BugMe branding
- 📋 Haptic feedback on mic tap and save
- 📋 Empty-state illustrations on dashboard and transaction list
- 📋 Keyboard shortcut: type instead of speak (text fallback in voice screen)
- 📋 Input validation and better error messages in confirm card
- 📋 Unit tests for GeminiService JSON parsing
- 📋 Widget tests for dashboard spend calculations

---

## v1.2 — UX Improvements

- 📋 Onboarding flow (first launch: explain voice, prompt for API key)
- 📋 Long-press transaction to edit (not just delete)
- 📋 Search transactions by description
- 📋 Date range filter in transaction log
- 📋 Sort options (newest, oldest, largest amount)
- 📋 Copy previous month's budget allocations to current month
- 📋 Total monthly budget cap (in addition to per-category)

---

## v1.3 — Insights

- 📋 Monthly comparison chart (bar chart: last 3–6 months)
- 📋 Average daily spend card
- 📋 Biggest category this month callout
- 📋 "On track" indicator per category based on day-of-month
- 📋 Weekly spending breakdown

---

## v2.0 — Advanced Features

- 💡 Recurring expense detection (suggest tagging subscriptions)
- 💡 Export to CSV / share sheet
- 💡 Multiple currencies with live conversion
- 💡 Dark/light theme toggle
- 💡 Home screen widget (quick total + mic shortcut)
- 💡 Backup / restore (local file export)
- 💡 Optional cloud sync (Firebase or iCloud) — user opt-in only
- 💡 iOS support

---

## Known limitations (v1.0)

- Gemini API key must be obtained manually by the user
- Speech recognition requires internet connectivity on most Android devices
- No offline AI fallback (manual entry only if no API key)
- No data backup — uninstalling the app deletes all data
