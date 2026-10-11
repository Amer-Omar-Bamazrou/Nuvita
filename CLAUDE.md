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

# Run all tests
flutter test

# Run one test file
flutter test test/path/to/file_test.dart
```

### Tests

Unit tests live under `test/`, mirroring the `lib/` layout (for example `test/core/...` for code in `lib/core/`). They are plain Dart tests run with `flutter test` and do not need a device, emulator or Firebase connection, so keep tested logic free of Firebase and plugin calls.

CI (`.github/workflows/ci.yml`) runs `flutter pub get`, `flutter analyze` and `flutter test` on every push and pull request. Both analyze and test must pass.

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

### Home screen task refresh

The home screen task list refreshes via four mechanisms:
- **initState** — loads tasks when the screen first mounts
- **Pull-to-refresh** — `RefreshIndicator` reloads tasks and med summary
- **Tab switch** — `MainShell` fires `HomeScreen.refreshNotifier` when switching to the Home tab, so tasks added from other tabs (e.g. Tracking) appear immediately
- **Firestore listener** — `_listenForMedicationChanges()` streams `/users/{uid}/medications` so doctor-assigned medications appear in real-time without manual refresh
- **Add medication callback** — returning from `AddMedicationScreen` calls both `_loadMedSummary()` and `_loadTasks()`

Medication tasks always show regardless of onboarding service selection — the service filter was removed from `_loadTasks()`.

### History screen — Blood Pressure merging

Systolic and diastolic readings are stored as separate Firestore documents but displayed as a single "Blood Pressure" card (e.g. "125/82 mmHg") in the history list. `_mergeReadingsInGroup` pairs them by matching minute-level timestamps. Edit and delete actions on a merged card apply to both documents. The summary card's "Last entry" label shows date context ("Yest 8:41 PM", "May 19") when the most recent reading is not from today.

### Chart rendering

`HealthChartWidget` uses `fl_chart` with `isCurved` enabled only when there are more than 3 data points. With fewer points, straight lines are used to avoid curve-smoothing distortion.

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
- `firebase.json` points at `firestore.rules` and `firestore.indexes.json` (currently empty), so `firebase deploy --only firestore` publishes both; copying the rules into Firebase Console → Firestore Database → Rules also works
- Coverage: /users/{userId} (owner + isDoctor()), all sub-collections, /doctors (read own), /bugReports (anyone write, doctor read), collectionGroup (readings, suggestions, alerts, messages — doctor read)

## Notification ID Ranges
Source of truth: the ID helpers at the bottom of `lib/core/services/notification_service.dart`. Most IDs are `base + (id.hashCode.abs() % 99990)`, plus the time-slot index for per-dose reminders.
- 0–99,999: isActive medication reminders (`scheduleMedicationReminder`)
- 0–999,989: legacy one-time notifications (`scheduleNotification`) — overlaps the range above
- 999,991–1,099,980: low supply alerts
- 1,100,000–1,199,999: daily medication reminders (reminderEnabled)
- 1,200,001: daily wellness reminder
- 1,300,000–1,399,999: missed dose alerts
- 1,400,000–1,499,999: appointment tomorrow reminders
- 1,500,001: weekly health summary
- 1,600,000–1,699,999: follow-up confirmations
- 1,700,000–1,799,999: critical reading alerts
- 1,800,000–1,899,999: doctor-assigned medication notifications
- 1,900,000–1,999,999: doctor suggestion notifications
- 2,000,000–2,099,999: snoozed medication reminders
- 2,100,000–2,199,999: appointment reminders

## Folder Structure
lib/core/theme/ — app_colors, app_text_styles, app_theme
lib/core/services/ — preferences_service, notification_service
lib/features/auth/ — login_screen, register_screen, change_password_screen, forgot_password_sent_screen, auth_service
lib/features/onboarding/ — onboarding_screen
lib/features/disease/ — disease_selection_screen, patient_service, patient_model
lib/features/home/ — home_screen, main_shell
lib/features/medication/ — medication_screen, add_medication, medication_detail_screen, medication_history_screen, model, service
lib/features/tracking/ — tracking_screen
lib/features/history/ — history_screen
lib/features/profile/ — profile_screen
lib/features/dashboard/ — health_provider, health_history_provider
lib/features/health/models/ — health_reading, metric_config
lib/features/health/screens/ — add_reading_input_screen, blood_pressure_input_screen
lib/features/health/services/ — health_reading_service
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
lib/features/doctor/widgets/ — status_badge (shared status pill)
lib/shared/widgets/ — nuvita_text_field, nuvita_button, nuvita_time_picker

## Coding Rules — ALWAYS FOLLOW
- Work in batches on a feature branch; never commit directly to main.
- Change only what the task lists. If something listed is wrong or risky, stop and report.
- UI changes are allowed only where the task says so.
- Every batch ends with `flutter analyze` and `flutter test` passing.
- Natural developer-style comments only.

## Git Strategy
- main: stable code only
- feature/xxx: one branch per feature
- Always commit before switching branches