# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Run mobile app (Android)
flutter run
# Run doctor web portal in Chrome
flutter run -d chrome

# Build release APK
flutter build apk --release

# Build web
flutter build web --release

# Analyse (lint)
flutter analyze

# Get / update dependencies
flutter pub get
flutter pub upgrade
```

No test suite exists — `flutter test` will find nothing.

## Architecture

### Two apps in one codebase

`main.dart` uses `kIsWeb` to split at startup:
- **Web** → always lands on `DoctorLoginScreen` (doctor portal)
- **Mobile** → patient app; routing depends on onboarding flag + Firebase Auth state + Firestore `active` field

### State management

Two providers, intentionally scoped differently:

| Provider | Scope | Purpose |
|---|---|---|
| `HealthHistoryProvider` | App root (`main.dart`) | Full readings list, loaded once per session from Firestore; shared across History, Charts, PDF report |
| `HealthProvider` | Scoped to `HomeScreen` only | Current-session metric values, inline tip logic, Firestore save/load — **not accessible from sibling screens** |

### Navigation (mobile)

`MainShell` uses `IndexedStack` with 4 tabs (Home, Tracking, History, Profile). Push-routes (charts, appointments, report, suggestions panel) sit on top of the stack via `Navigator.push`.

Notification taps are routed via a global `navigatorKey` wired in `main.dart`. The appointment tap handler is set there (not in `NotificationService`) to avoid a circular import.

### Firestore conventions

- Patient data lives under `/users/{uid}/` with sub-collections: `readings`, `medications`, `alerts`, `suggestions`, `messages`, `appointments`, `emergency_contacts`, `adherence`
- Doctors are identified by a document existing at `/doctors/{uid}`
- `collectionGroup` queries are used by the doctor portal for cross-patient reads (`readings`, `alerts`, `messages`, `suggestions`)
- Compound Firestore queries on `collectionGroup` require composite indexes — prefer single-field filtering in Firestore and filter additional conditions client-side to avoid index errors

### Local persistence

`SharedPreferences` (via `PreferencesService`) stores onboarding state, user profile fields (name, gender, DOB), and per-day medication taken flags (`taken_{medId}_{time}_{yyyy-MM-dd}`). Firestore is the source of truth for everything else.

### Doctor portal specifics

- `DoctorService` is the sole data layer for the web portal — all patient reads go through it
- The `active` field on `/users/{uid}` is how doctors soft-delete patients; login and startup both check this and sign out if `false`
- `patientId` is a 6-char alphanumeric generated at registration, stored in the Firestore root user doc, and used as an alternative login credential

---

## Project Overview
- App Name: Nuvita
- Type: Flutter Android mobile application + Doctor web portal
- Purpose: Smart health companion for chronic patients
- Developer: Amer Omar Bamazrrou
- University: De Montfort University Leicester
- Module: CTEC3451 Final Year Project
- Deadline: 22 May 2026

## Tech Stack
- Flutter + Dart
- Firebase Auth, Firestore, Storage, FCM
- Provider (state management)
- SharedPreferences (local storage)
- Flutter Local Notifications (medication reminders)
- pdf: ^3.10.8 + printing: ^5.14.3 (PDF generation and sharing)
- share_plus: ^13.1.0
- fl_chart (health charts — trends, zone bands, insights)

## Design System
- Background: #F7F9FB
- Input Fill: #F0F4F6
- Divider: #E2EAED
- Primary: #004346
- Cards: #74B3CE
- Secondary: #508991
- Text: #172A3A
- White: #FFFFFF
- Card Radius: 16 (patient app), 12 (doctor portal)
- Button Height: 56, Radius: 14
- Style: Minimal, elderly friendly
- Shadow System: xs `0 2px 8px rgba(23,42,58,0.06)`, sm `0 3px 10px rgba(23,42,58,0.06)`, md `0 4px 12px rgba(23,42,58,0.08)`, brand `0 4px 14px rgba(0,67,70,0.25)`
- Status Badges: outlined pill style — 12% alpha fill + 40% alpha border + coloured text, borderRadius 20
- Doctor Portal Greys: border #EEEEEE, light text #9AA3AB, muted text #6E7A82
- Design reference: `C:\Users\lenovo\Downloads\Nuvita Design System` (CSS tokens, JSX component recreations, HTML previews)

## Firestore Structure
- /users/{uid}/profile — name, diseaseType
- /users/{uid}/readings/{readingId} — metricType, value, unit, status, timestamp, note
- /users/{uid}/medications/{medicationId} — id, name, dosage, frequency, times, startDate, isActive, notes, reminderEnabled, pillsRemaining, pillsPerDose
- /users/{uid}/suggestions/{suggestionId} — text, doctorName, timestamp, read (bool)
- /users/{uid}/messages/{msgId} — text, timestamp, readByDoctor, patientName, patientId
- /users/{uid}/alerts/{alertId} — timestamp, triggerType, cancelled, patientName, diseaseType
- /users/{uid}/adherence/{date_medId_time} — medicationId, medicationName, dosage, timeSlot, date, taken, timestamp
- /users/{uid}/appointments/, /users/{uid}/emergency_contacts/
- /doctors/{doctorId} — doctor account marker
- /bugReports/{reportId} — text, timestamp, patientId, patientName
- /share_tokens/ — public read, auth write

## Firestore Security Rules
- Rules file: `firestore.rules` in project root
- Must be manually copied into Firebase Console → Firestore Database → Rules tab and published
- Coverage: /users/{userId} (owner + isDoctor()), all sub-collections, /doctors (read own), /bugReports (anyone write, doctor read), collectionGroup (readings, suggestions, alerts, messages — doctor read)

## Notification ID Ranges
- 0–99,999: base notifications
- 100,000–199,999: missed dose alerts
- 200,000–299,999: low supply alerts
- 1,000,000–1,099,999: medication reminders
- 1,100,000–1,199,999: daily medication reminders
- 1,200,001: daily wellness reminder
- 1,200,002: weekly health summary
- 1,300,000–1,399,999: appointment tomorrow reminders
- 1,400,000–1,499,999: doctor-assigned med notifications
- 1,500,000–1,599,999: doctor suggestion notifications
- 1,600,000–1,699,999: follow-up notifications
- 2,000,000–2,099,999: snoozed medication reminders
- 2,100,000–2,199,999: appointment reminders

## Folder Structure
lib/core/theme/ — app_colors, app_text_styles, app_theme
lib/core/services/ — preferences_service, notification_service
lib/features/auth/ — login_screen, register_screen, change_password_screen, forgot_password_sent_screen, auth_service
lib/features/onboarding/ — onboarding_screen, welcome_splash (dormant)
lib/features/disease/ — disease_selection (dormant)
lib/features/home/ — home_screen, main_shell
lib/features/medication/ — medication_screen, add_medication, medication_detail_screen, medication_history_screen, model, service
lib/features/tracking/ — tracking_screen
lib/features/history/ — history_screen
lib/features/profile/ — profile_screen
lib/features/dashboard/ — health_provider, health_history_provider
lib/features/health/models/ — health_reading, metric_config
lib/features/health/screens/ — add_reading_list_screen (legacy), add_reading_input_screen, blood_pressure_input_screen
lib/features/health/services/ — health_reading_service, health_log_service (legacy)
lib/features/health/widgets/ — ruler_picker (legacy — replaced by stepper buttons)
lib/features/lifestyle/models/ — lifestyle_suggestion
lib/features/lifestyle/services/ — lifestyle_engine
lib/features/lifestyle/widgets/ — suggestion_card
lib/features/lifestyle/screens/ — lifestyle_screen (dormant — built, not wired to nav)
lib/features/notifications/screens/ — suggestions_panel_screen
lib/features/emergency/ — emergency_service, trend_warning_service, models/emergency_contact
lib/features/emergency/screens/ — emergency_contacts_screen
lib/features/charts/models/ — chart_data_point, metric_thresholds
lib/features/charts/services/ — chart_data_service
lib/features/charts/widgets/ — health_chart_widget
lib/features/charts/screens/ — charts_screen
lib/features/report/ — report_service, report_screen
lib/features/doctor/data/ — medicine_library
lib/features/doctor/screens/ — doctor_login_screen, doctor_dashboard_screen, doctor_overview_screen, doctor_patients_screen, doctor_patient_detail_screen, doctor_settings_screen, doctor_messages_screen, doctor_suggestions_history_screen, critical_alerts_screen, deleted_patients_screen
lib/features/doctor/services/ — doctor_service, patient_suggestion_service
lib/shared/widgets/ — nuvita_text_field, nuvita_button, health_metric_card

## Coding Rules — ALWAYS FOLLOW
- Natural developer style comments only
- Never AI style comments
- Clean modular code
- Follow existing folder structure
- Never change UI unless asked
- Scan for errors after every file
- Tell me each file created or updated
- Build one feature at a time
- Never regenerate existing working code
- Always ask about modifications after building

## Git Strategy
- main: stable code only
- feature/xxx: one branch per feature
- Always commit before switching branches