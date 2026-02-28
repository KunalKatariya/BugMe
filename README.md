<div align="center">

<img src="assets/images/logo_transparent.png" width="110" alt="BugMe logo" />

# BugMe

### Voice-first. AI-powered. Zero friction.

**Just say it. BugMe logs it.**

*"Spent 150 on coffee and 800 on groceries"* → two categorised transactions, instantly.

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Platform](https://img.shields.io/badge/Platform-iOS%20%7C%20Android-lightgrey?logo=apple&logoColor=white)](https://flutter.dev)
[![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)
[![AI](https://img.shields.io/badge/AI-Gemini%201.5%20Flash-4285F4?logo=google&logoColor=white)](https://ai.google.dev)

</div>

---

## What is BugMe?

BugMe is a **personal finance app that gets out of your way**. No tedious form filling, no manual categorisation, no syncing woes. Hold the mic, say what you spent, and walk away. Google Gemini AI handles the rest — parsing amount, category, description, and date from plain natural language.

Everything lives on your device. Your money data never touches a server.

---

## ✨ Highlights

| | |
|---|---|
| 🎤 **Voice-first entry** | Speak naturally. One sentence, multiple expenses — Gemini parses them all at once. |
| 🤖 **Gemini AI parsing** | Extracts amount, category, merchant, and date. Falls back to today if no date is mentioned. |
| 📊 **Living dashboard** | Animated hero with daily spend chart, month navigation, and a real-time committed-spend preview. |
| 💰 **Zero-based budgeting** | Income-first. Allocate every rupee. Unallocated balance shown in real time. |
| 🎯 **Goals + auto-SIP** | Set savings targets. Configure monthly SIP deductions. BugMe auto-contributes on launch. |
| 🔄 **Recurring payments** | Add subscriptions and bills once. BugMe auto-creates transactions when they fall due. |
| 📅 **Month wrap-up** | Past months get a smart summary — savings %, top categories, and a personalised tip. |
| 🏦 **Multi-account** | Separate wallets, separate budgets, separate currencies. Switch in one tap. |
| 📤 **Excel + JSON export** | Monthly or yearly Excel reports. Full JSON backup and restore. |
| 🏠 **Home screen widget** | Glanceable spend summary right on your Android home screen. |
| 🌗 **Dark & light modes** | Fully themeable, persisted across restarts. |
| 📳 **Haptic feedback** | Every tap and long-press has the right weight. |

---

## 📱 App Walkthrough

### 🎙️ Voice Entry
Hold the mic on the nav bar (or long-press for instant-listen). Speak in plain language:

```
"800 on groceries, 150 chai, and Netflix subscription 499"
```

BugMe transcribes in real time, sends the text to Gemini, and returns 3 ready-to-confirm cards. Each card is editable before saving. Confirmation plays a haptic + sound cue.

### 🏠 Dashboard
The hero card shows your month at a glance:
- **Total spent** — animated counter that counts up on load
- **Daily bar chart** — lights up today in amber; past days in soft white
- **Budget / income badge** — shows remaining budget or how far over you are
- **Month navigation** — swipe between months with a slide animation
- Scrolling collapses the hero into a compact bar; expanding it brings it back

Below the hero, the current month shows a **live transaction feed**. Past months show a **full wrap-up report** instead of transactions — savings percentage, top 3 categories, budget performance, and a specific one-line tip.

### 💰 Budget Planning
Set your monthly income at the top. Allocate per category below. BugMe shows:
- How much of your income is committed (recurring + SIPs)
- How much is unallocated
- Which categories are close to or over limit (turns red at 80%+)
- One-tap copy of last month's allocations

### 🎯 Goals
Create a savings goal with a target amount and optional deadline. Enable **SIP** to auto-deduct a fixed amount every month on a chosen day — logged as an investment transaction so it doesn't eat into your category budgets.

### 🔄 Recurring Payments
Add your subscriptions, EMIs, and bills. Set frequency (daily / weekly / monthly / yearly). BugMe auto-creates transactions for any overdue ones every time the app launches — tagged as `recurring` so they appear in cash flow but not in discretionary category budgets.

---

## 🚀 Getting Started

### Prerequisites

| Requirement | Version |
|---|---|
| Flutter | 3.10 + |
| Dart | 3.0 + |
| Android | API 21+ (Android 5.0+) |
| iOS | iOS 13.0+ |
| Google Gemini API key | Free tier at [aistudio.google.com](https://aistudio.google.com/app/apikey) |

### Setup

```bash
# 1. Clone and install dependencies
git clone https://github.com/your-username/bugme.git
cd bugme
flutter pub get

# 2. Generate Drift database code (run once, and after any schema change)
dart run build_runner build --delete-conflicting-outputs

# 3. Run
flutter run
```

### Add your Gemini key

Open the app → **Settings** → **Gemini API Key** → paste your key.
It's stored locally in SharedPreferences and never leaves your device.

> Get a free key at [aistudio.google.com](https://aistudio.google.com/app/apikey) — the free tier is more than enough for personal use.

---

## 🏗️ Project Structure

```
lib/
├── core/
│   ├── constants/          # Categories, Gemini prompts, currency definitions
│   └── theme/              # Material 3 theme, category colours & emojis
│
├── data/
│   ├── database/           # Drift schema: Transactions, Goals, RecurringPayments,
│   │                       #   BudgetAllocations, Accounts, UserProfile
│   ├── models/             # ParsedEntry DTO (Gemini response)
│   ├── providers/          # All Riverpod providers
│   └── services/           # GeminiService (prompt building + response parsing)
│
└── features/
    ├── dashboard/          # Hero, daily chart, month wrap-up, transaction feed
    ├── voice/              # Mic orb, STT, confirm cards, manual entry sheet
    ├── transactions/       # Full transaction history with filters
    ├── budget/             # Income entry, category allocation, committed spend
    ├── goals/              # Goals list, SIP config, contribution flow
    └── settings/           # Theme, accounts, API key, backup/restore, export
```

---

## 🛠️ Tech Stack

| Layer | Technology |
|---|---|
| **Framework** | Flutter 3 · Material 3 |
| **Language** | Dart 3 |
| **State management** | Riverpod 2 |
| **Database** | Drift 2 (SQLite ORM) · sqlite3_flutter_libs |
| **AI** | Google Generative AI SDK · Gemini 1.5 Flash |
| **Voice** | speech_to_text 7 |
| **Charts** | fl_chart |
| **Animations** | flutter_animate · TweenAnimationBuilder · AnimatedScale |
| **Fonts** | Google Fonts |
| **Export** | excel · share_plus · file_picker |
| **Home widget** | home_widget (Android) |
| **Storage** | shared_preferences · path_provider |
| **Utilities** | intl · uuid · permission_handler |

---

## 🔒 Privacy

**All your data stays on your device.**

- The SQLite database is stored in your app's private directory — inaccessible to other apps.
- The only outbound network call is to the **Google Gemini API** when you submit a voice entry. The text transcript is sent; your stored transaction history never leaves your phone.
- Your Gemini API key is saved in SharedPreferences (app-private storage).
- No analytics, no telemetry, no third-party SDKs with data collection.

---

## 📋 Expense Categories

🛒 Groceries · 🍽️ Restaurants · ☕ Coffee & Drinks · 🚗 Transport · 🎬 Entertainment
🛍️ Shopping · ✈️ Travel · 💪 Health & Fitness · ⚡ Utilities & Bills · 📺 Subscriptions
📚 Education · 💅 Personal Care · 🏠 Rent & Housing · 📈 Investments · 💰 Other

---

## 📄 License

MIT — see [LICENSE](LICENSE).

---

<div align="center">
  <sub>Built with Flutter · Powered by Gemini AI · Your money, your device.</sub>
</div>
