# Expense OS Mobile 🚀📱

> **Futuristic Dark Glassmorphic Mobile Personal Finance Command Center**
> Built with **Flutter (Dart)** and **Supabase Backend** for **Android** (Google Play Store) and **iOS** (Apple App Store).

---

## 🌟 Key Features

* **⚡ Ultra-Smooth GPU Rendering (60/120 FPS):** Native performance powered by Flutter's Impeller graphics engine.
* **✨ Dark Glassmorphic UI:** Frosted glass cards (`BackdropFilter`), glowing borders, and modern typography (Poppins & IBM Plex Mono).
* **🔌 Live Multi-App Cloud Sync:** Seamless real-time bidirectional sync across **Web**, **Desktop**, **iOS**, and **Android** apps via Supabase.
* **📊 Income & Expense Tracking:** Track transactions, net balance, income vs. expense breakdown.
* **📱 Touch & Mobile Native:** Hardware back button handling, swipe-to-delete transactions, smooth bottom sheet modals, pull-to-refresh.
* **🔄 Dual-Write Sync Engine:** Every transaction writes to both relational tables and unified JSON state for 100% cross-platform compatibility.
* **⚡ 6-Channel Realtime Listeners:** Instant updates across `expenses`, `subscriptions`, `split_bills`, `budgets`, `profiles`, and `user_data` tables.
* **💰 Recurring Bills & Subscriptions:** Track recurring bills with automatic cycle rollover and due-date notifications.
* **👥 Split Bills & Group Expenses:** Split expenses with friends, track settlements, and sync across all platforms.
* **🎯 Savings Goals:** Set and track financial goals with progress visualization.
* **📸 Receipt OCR Scanner:** Scan receipts and auto-extract transaction details.
* **🌍 Multi-Currency Support:** Automatic currency detection with live exchange rates.
* **📤 Export & Reports:** Generate CSV and executive financial statements.

---

## 🔗 Multi-App Ecosystem

Expense OS syncs seamlessly across all platforms in real-time:

| Platform | Reads From | Writes To | Real-Time |
|----------|-----------|-----------|:---------:|
| **Web App** | `user_data` (JSON) | `user_data` | ✅ |
| **Desktop App** | Relational tables | Relational tables | ✅ |
| **iOS App** | All sources (merged) | Both relational + `user_data` | ✅ |
| **Android App** | All sources (merged) | Both relational + `user_data` | ✅ |

### Supabase Tables (9 Total)
`profiles` · `categories` · `expenses` · `subscriptions` · `budgets` · `split_bills` · `split_bill_members` · `export_templates` · `user_data`

---

## 📁 Architecture & Tech Stack

* **Framework:** [Flutter](https://flutter.dev) (Dart >= 3.0)
* **Backend:** [Supabase Flutter](https://pub.dev/packages/supabase_flutter) (Database, Auth & Realtime)
* **Sync Engine:** Dual-write to relational tables + unified JSON state document
* **Realtime:** 6-channel Postgres change listeners for instant cross-app updates
* **Styling:** Custom Glassmorphism Theme System
* **Icons & Fonts:** Font Awesome Flutter & Google Fonts

---

## 📦 How to Build for Google Play Store & Apple App Store

### 1. Install Dependencies
```bash
flutter pub get
```

### 2. Run Locally in Debug Mode
```bash
flutter run
```

### 🟢 Build for Google Play Store (Android `.aab`)
```bash
flutter build appbundle --release
```
*The generated Android App Bundle will be at:* `build/app/outputs/bundle/release/app-release.aab`

### 🍎 Build for Apple App Store (iOS `.ipa`)
```bash
flutter build ipa --release
```
*The generated iOS archive will be at:* `build/ios/ipa/ExpenseOSMobile.ipa`

---

## 🔗 GitHub Repository Setup

To publish this project to your new GitHub repository:

```bash
git remote add origin https://github.com/VaibhavJalota06/Expense-OS-Mobile.git
git branch -M main
git add .
git commit -m "Initial commit: Complete Expense OS Mobile Flutter App"
git push -u origin main
```
