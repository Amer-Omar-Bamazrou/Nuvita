# Nuvita

A smart health companion built for chronic care patients. Nuvita helps patients track vitals, manage medications, and stay connected with their doctors — all from one app.

Built as a dual-platform Flutter application: a mobile app for patients and a web portal for doctors.

---

## The Problem

Chronic care patients — those living with diabetes, hypertension, or heart conditions — face a daily burden of tracking medications, monitoring vitals, and communicating with doctors between appointments. Most forget doses, miss warning signs in their readings, or only discover problems at their next clinic visit when it's already too late to intervene early.

Doctors, on the other hand, have limited visibility into what happens between appointments. They rely on patients to self-report, which is often incomplete or inaccurate.

## How Nuvita Helps

- **Reduces missed medications** — scheduled reminders, visual dose tracking, and low pill supply alerts keep patients on top of their therapy
- **Catches health deterioration early** — trend arrows, warning prompts, and zone-based charts highlight when readings are moving in the wrong direction before they become critical
- **Bridges the gap between visits** — doctors can monitor patient vitals, adherence, and emergency alerts in real-time from their portal without waiting for the next appointment
- **Empowers elderly and non-technical users** — large touch targets, minimal navigation, and a clean interface designed for accessibility
- **Speeds up emergency response** — one-tap SOS with a 10-second countdown notifies emergency contacts and logs the event for the doctor

---

## What It Does

**Patient App (Android)**
- Log health readings (blood pressure, blood sugar, heart rate, weight, temperature, walking)
- Medication management with reminders, adherence tracking, and low pill supply alerts
- Visual health trends with charts and zone bands
- Emergency SOS alert with countdown and doctor notification
- Appointment scheduling with notification reminders
- PDF health reports with charts, ready to share with doctors
- Doctor suggestions delivered in real-time

**Doctor Portal (Web)**
- View all assigned patients and their health data
- Send suggestions and assign medications from a built-in medicine library
- Monitor medication adherence with 7-day progress bars
- Track critical emergency alerts
- Patient health trend charts per disease type
- Messaging system with unread badges
- Soft-delete and restore patients

---

## Tech Stack

| Layer | Technology |
|---|---|
| Framework | Flutter + Dart |
| Auth | Firebase Authentication |
| Database | Cloud Firestore |
| Storage | Firebase Storage |
| Messaging | Firebase Cloud Messaging |
| State | Provider |
| Local Storage | SharedPreferences |
| Notifications | Flutter Local Notifications |
| Charts | fl_chart |
| PDF | pdf + printing |
| Icons | Iconly |

---

## Screenshots

<!-- Add screenshots here -->
<!-- ![Home Screen](screenshots/home.png) -->
<!-- ![Doctor Dashboard](screenshots/doctor_dashboard.png) -->

---

## Getting Started

### Prerequisites

- Flutter SDK (3.x+)
- Android Studio or VS Code with Flutter extension
- Firebase project configured (Auth, Firestore, Storage, FCM)
- Chrome (for doctor web portal)

### Run the App

```bash
# Install dependencies
flutter pub get

# Run patient app on Android
flutter run

# Run doctor portal in Chrome
flutter run -d chrome
```

### Build

```bash
# Android release APK
flutter build apk --release

# Web release
flutter build web --release
```

---

## Project Structure

```
lib/
  core/
    theme/          — colours, typography, theme
    services/       — notifications, preferences
  features/
    auth/           — login, register, password management
    onboarding/     — 7-step onboarding flow
    home/           — home screen, bottom navigation shell
    medication/     — medication list, detail, reminders, adherence
    tracking/       — tracking overview (meds, appointments, reports)
    health/         — reading input screens, metric configs
    history/        — health readings history with edit/delete
    charts/         — health trend charts with zone bands
    report/         — PDF report generation
    profile/        — patient profile, messaging, settings
    appointments/   — appointment scheduling and reminders
    emergency/      — SOS alerts, emergency contacts
    lifestyle/      — lifestyle suggestion engine
    notifications/  — suggestions panel
    doctor/         — doctor portal (dashboard, patients, messaging)
  shared/
    widgets/        — reusable components (buttons, text fields, cards)
```

---

## Architecture

- `main.dart` splits at startup: web loads the doctor portal, mobile loads the patient app
- Two providers manage state: `HealthProvider` (current session) and `HealthHistoryProvider` (full history)
- Firestore is the source of truth; SharedPreferences handles offline-first medication tracking
- Doctor portal uses `DoctorService` as its sole data layer with collectionGroup queries for cross-patient reads

---

## Testing

This project was tested manually across real devices and emulators. No automated test suite is included.

**Approach:**
- Functional testing on Android physical devices and Android emulator
- Doctor portal tested on Chrome (desktop)
- Each feature tested in isolation after implementation, then regression tested as part of the full flow
- Firebase integration verified with real Firestore reads/writes, authentication flows, and notification delivery

**Key scenarios covered:**
- Patient registration, login (email and Patient ID), password reset
- Full medication lifecycle: add, edit, take dose, undo, delete, low supply alert, reminders
- Health reading input for all metric types, with validation and status calculation
- Appointment creation, reminders, notification tap confirmation
- Emergency SOS countdown, cancel, and alert logging
- Doctor login, patient list, sending suggestions, assigning medications
- PDF report generation with charts and sharing
- Offline-first behaviour: SharedPreferences persistence when Firestore is unavailable
- Edge cases: guest mode restrictions, deactivated patient sign-out, empty states, future date blocking

---

## Author

**Amer Bamazrua**
De Montfort University — CTEC3451 Final Year Project

---

## License

This project was developed as part of an academic submission. All rights reserved.
