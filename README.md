# Expense OS Mobile 🚀📱

> **Futuristic Dark Glassmorphic Mobile Personal Finance Command Center**
> Built with **Flutter (Dart)** and **Supabase Backend** for **Android** (Google Play Store) and **iOS** (Apple App Store).

---

## 🌟 Key Features

* **⚡ Ultra-Smooth GPU Rendering (60/120 FPS):** Native performance powered by Flutter's Impeller graphics engine.
* **✨ Dark Glassmorphic UI:** Frosted glass cards (`BackdropFilter`), glowing borders, and modern typography (Poppins & IBM Plex Mono).
* **🔌 Live Cloud Sync:** Connected directly to the live Expense OS Supabase database backend.
* **📊 Income & Expense Tracking:** Track transactions, net balance, income vs. expense breakdown.
* **📱 Touch & Mobile Native:** Hardware back button handling, swipe-to-delete transactions, smooth bottom sheet modals, pull-to-refresh.

---

## 📁 Architecture & Tech Stack

* **Framework:** [Flutter](https://flutter.dev) (Dart >= 3.0)
* **Backend:** [Supabase Flutter](https://pub.dev/packages/supabase_flutter) (Database & Auth)
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
