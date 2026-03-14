# SHIFT - Performance Tracking App

SHIFT is a Flutter mobile application for real-time physiological performance tracking. It connects to a BLE wearable sensor to monitor heart rate, blood oxygen, temperature, and signal quality during sessions, and includes an AI-powered coach chatbot for performance analysis.

---

## Features

- **Live Session Monitoring** — Real-time BPM, blood oxygen saturation, body temperature, signal quality, and alert tracking via BLE
- **BLE Device Connection** — Scan, discover, and connect to SHIFT wearable sensors
- **Session History** — View and review past session records and metrics
- **AI Coach Chatbot** — Powered by Google Gemini API; analyze your session data and ask performance questions
- **Dark UI** — Clean dark-themed interface

---

## Screens

| Screen | Description |
|---|---|
| Device Page | Scan and connect to BLE sensor |
| Live Session | Real-time metrics display with session timer |
| History | Past session logs and alert counts |
| AI Chatbot | Gemini-powered coaching assistant |

---

## Tech Stack

- **Framework**: Flutter (Dart)
- **BLE**: `flutter_reactive_ble` with custom Android GATT patch
- **AI**: `google_generative_ai` (Gemini API)
- **Sensors**: Heart rate (BPM), SpO2, temperature, signal quality

---

## Setup

### 1. Install dependencies

```bash
flutter pub get
```

### 2. Configure API key

Create a file `lib/config.dart` (this file is gitignored — never commit it):

```dart
const String geminiApiKey = 'YOUR_GOOGLE_AI_STUDIO_API_KEY';
```

Get a free API key at [aistudio.google.com](https://aistudio.google.com).

> **Important:** Never commit your API key to git. Each team member should create their own `lib/config.dart` locally.

### 3. Run the app

```bash
flutter run
```

---

## BLE Sensor UUIDs

| Type | UUID |
|---|---|
| Service | `0000b001-0000-1000-8000-00805f9b34fb` |
| Characteristic | `0000c001-0000-1000-8000-00805f9b34fb` |

---

## Project Structure

```
lib/
├── main.dart                 # App entry point and theme
├── navigationBar.dart        # Bottom navigation
├── device_page.dart          # BLE scan and connect
├── live_session_screen.dart  # Real-time session view
├── history_screen.dart       # Session history
├── ai_chatbot.dart           # Gemini AI coach
├── session_manager.dart      # Session data management
└── config.dart               # API key (gitignored, create locally)
```

---

## Team

Group project — SHIFT Performance Tracking.
