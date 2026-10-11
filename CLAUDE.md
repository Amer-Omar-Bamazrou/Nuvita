# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Run mobile app (Android)
flutter run
# Run doctor web portal in Chrome
flutter run -d chrome

# Builds used by the release checks
flutter build apk --debug
flutter build web

# Release builds
flutter build apk --release
flutter build web --release

# Analyse (lint)
flutter analyze

# Get dependencies (don't upgrade as part of a task)
flutter pub get

# Run all tests
flutter test

# Run one test file
flutter test test/path/to/file_test.dart
```

### Tests

Unit tests live under `test/`, mirroring the `lib/` layout (for example `test/core/...` for code in `lib/core/`). They are plain Dart tests run with `flutter test` and do not need a device, emulator or Firebase connection, so keep tested logic free of Firebase and plugin calls.

What is covered:
- `test/core/health/health_metrics_test.dart` — every status band boundary (each blood sugar context too), input ranges, legacy keys, labels
- `test/core/health/conditions_test.dart` — reading conditions (and old `diseaseType`), defaults per condition
- `test/core/services/reminder_time_test.dart` — next reminder time across UK clock changes
- `test/core/services/care_services_test.dart` — service selection fallback
- `test/features/health/health_reading_test.dart` — `HealthReading.fromMap` legacy key/status mapping, round-trip, BP pairing
- `test/features/medication/adherence_test.dart` — `calculateAdherence`
- `test/features/medication/medication_model_test.dart`, `test/features/appointments/appointment_model_test.dart` — JSON round-trips
- `test/features/profile/data_export_test.dart` — CSV export
- `test/features/charts/chart_data_point_test.dart` — tooltip detail

CI (`.github/workflows/ci.yml`) runs `flutter pub get`, `flutter analyze` and `flutter test` on every push and pull request. Both analyze and test must pass.

## Architecture

### Two apps in one codebase

`main.dart` uses `kIsWeb` to split at startup:
- **Web** → always lands on `DoctorLoginScreen` (doctor portal)
- **Mobile** → patient app; routing depends on onboarding flag + Firebase Auth state + Firestore `active` field. There is no guest mode: signed out means Login (or onboarding → Register), and `MainShell` sends anyone who reaches it signed out to `RegisterScreen`.

### Health metrics — one module

`lib/core/health/health_metrics.dart` (`HealthMetrics`) is the **only** place that defines a metric's stored key, label, unit, input range (min/max/step) and status bands. Entry screens, History (labels, edit ranges, edit statuses), charts (zones, insights), the PDF report, the doctor portal and the BP trend warning all read from it. Never hard-code a threshold, unit or label elsewhere; a threshold change is a clinical decision and has to update `health_metrics_test.dart`.

Status bands (`StatusBands`): below `low` → criticalLow ('Low'), up to `normalMax` → normal, up to `warningMax` → warning, above → criticalHigh ('High'). Weight and walking have no status ('Logged'). Blood sugar bands depend on the reading's context: fasting and before-meal 70/99/125, after-meal 70/140/199, random or no context 70/180/300.

`lib/core/health/conditions.dart` (`PatientConditions`) reads the patient's conditions and decides the metric order offered on Home and the default chart.

### Stored metric keys

| Metric | Key written | Legacy keys still read |
|---|---|---|
| Blood sugar | `bloodSugar` + `context` (`fasting`, `beforeMeal`, `afterMeal`, `random`) | `bloodSugarBefore` (→ beforeMeal), `bloodSugarAfter` (→ afterMeal) |
| Systolic / diastolic | `systolic`, `diastolic` (two documents, same timestamp) | — |
| Heart rate | `heartRate` | — |
| Weight | `weight` | — |
| Walking | `walkingMinutes` (minutes) | `steps` |
| Temperature | `temperature` | — |

`HealthReading.fromMap` maps legacy keys to the current key and context, and old enum status names (`criticalHigh`…) to display strings. Queries for one metric use `HealthMetrics.storedKeysFor(metric)` with `whereIn`. A reading's `note` holds the context chip the user picked (e.g. "After exercise"); it is shown in History rows, chart tooltips, the PDF and the doctor's readings table.

### Saving readings

Reading screens hand a list of `ReadingEntry` to `HomeScreen._saveReadings`, which refuses future times and signed-out users (`ReadingSaveException`, message shown on the screen) and writes all entries in one Firestore batch (`HealthReadingService.saveReadings`). The BP screen saves systolic + diastolic, plus heart rate only when the optional pulse is filled; systolic must be above diastolic.

### State management

| Provider | Scope | Purpose |
|---|---|---|
| `HealthHistoryProvider` | App root (`main.dart`) | Live Firestore query of the newest readings (`watch(uid)`); "Load older readings" widens it a page at a time. New, edited and deleted readings arrive through the query — never patch or reload the list by hand. Deleted readings are hidden while their Undo snackbar is up. `reset()` on sign-out. |
| `HealthProvider` | Scoped to `HomeScreen` only | Latest value (and blood sugar context) per metric for the header warning dot; backdated saves don't replace a newer value |

The doctor's patient detail listens to the patient's latest readings the same way (`DoctorService.watchPatientReadings`).

### Medications: doses and adherence

- **Recording a dose:** `DoseService.markTaken` / `DoseService.undo` (`lib/features/medication/services/dose_service.dart`) are the only code paths. Home, the Medication screen, the detail screen's Take Now and the notification Taken/Undo actions all use them. Each sets/clears the day's taken flag (`taken_{medId}_{HH:mm}_{yyyy-MM-dd}`), writes/deletes the adherence document (`{yyyy-MM-dd}_{medId}_{HH:mm}`), changes the pill count and handles the low-supply alert. `markTaken` is a no-op for a slot already taken.
- **Adherence:** `calculateAdherence` (`lib/features/medication/services/adherence.dart`) is the only calculation. It returns expected / taken / missed / pending per day and in total; inactive and "As needed" medications are excluded, weekly ones count on their start weekday, doses later today are pending (not missed). Used by the PDF report, the Home streak and task list (`isScheduledOn`), Tracking and the doctor's adherence bars.
- Editing a medication keeps `isActive`, `reminderEnabled` and `pillsPerDose` and reschedules all of its reminders.

### Reminders

- Scheduled in the device's local time zone: `NotificationService` resolves it with `flutter_timezone` at start-up and in the background action handler; times are built with `reminder_time.dart` so they keep their wall-clock time across daylight-saving changes. If the zone can't be resolved it falls back to a fixed offset sent as UTC.
- Gated by the chosen services (see below) inside each `schedule…` call. `NotificationService.rescheduleAll()` rebuilds every reminder from stored medications and appointments; it runs after sign-in and when services change.
- Notification taps that launch the app from closed are routed by `handleLaunchFromNotification()`. The appointment Reschedule action opens the edit form; saving an appointment cancels its old reminders and schedules new ones.

### Services and conditions

- **Services** (`CareServices`, `lib/core/services/care_services.dart`): medications, measurements, activities, appointments, chosen in onboarding and in Profile → My Services. Stored on `profile.services` and cached in SharedPreferences; nothing selected means all. They decide Home sections (summary items, streak + medication tasks, add-sheet options), Tracking cards, and which reminders are scheduled (Activities = daily wellness nudge; weekly summary needs Measurements or Medications).
- **Conditions** (`profile.conditions`: `diabetes_type1`, `diabetes_type2`, `hypertension`, `heart_disease`, `other`): picked in onboarding and in Profile → My Conditions (`DiseaseSelectionScreen`). `diseaseType` is still written (derived) for older readers and still read from older profiles. They order the measurements offered on Home, pick the default chart (patient and doctor), and show on the doctor's patient cards (with a filter) and detail.

### Sign-out and account deletion

`AccountService` (`lib/features/profile/services/account_service.dart`):
- `signOut` cancels every notification, stops the doctor listeners, removes the user's SharedPreferences data (medications, appointments, emergency contacts, taken flags, BP trend flag, onboarding name/gender/DOB/services/conditions) but keeps `onboarding_complete`, resets `HealthHistoryProvider`, then signs out. Used by Profile and the deactivated-account checks. Login's "Create account" goes through onboarding again when no onboarding answers are stored, so a new person never registers with the previous user's details.
- `deleteAccount` re-authenticates with the password, deletes the user's sub-collections and user document, deletes the auth account, clears all local data and returns to onboarding.

### Navigation (mobile)

`MainShell` uses `IndexedStack` with 4 tabs (Home, Tracking, History, Profile). Push-routes (charts, appointments, report, suggestions panel, profile screens) sit on top via `Navigator.push`. Charts open from Home ("View trends"), Tracking (Health Trends card) and the History app bar. The history icon on the reading screens opens History filtered to that metric.

Notification taps are routed via a global `navigatorKey` wired in `main.dart`. The appointment tap/reschedule and medication handlers are set there (not in `NotificationService`) to avoid a circular import.

### Home screen task refresh

The home screen task list (today's scheduled doses, Medications service only) refreshes via:
- **initState** — loads tasks when the screen first mounts
- **Pull-to-refresh** — `RefreshIndicator` reloads tasks and med summary
- **Tab switch** — `MainShell` fires `HomeScreen.refreshNotifier` when switching to the Home tab
- **Firestore listener** — `_listenForMedicationChanges()` streams `/users/{uid}/medications` so doctor-assigned medications appear in real time
- **Add medication callback** — returning from `AddMedicationScreen` reloads tasks and the med summary
- **Services / conditions changes** — `CareServices.changes` and `ConditionsService.changes`

### History screen — Blood Pressure merging

Systolic and diastolic readings are stored as separate Firestore documents but displayed as a single "Blood Pressure" card (e.g. "125/82 mmHg"). `_mergeReadingsInGroup` pairs them by matching minute-level timestamps (`pairBloodPressure` does the same for the PDF). Edit and delete actions on a merged card apply to both documents.

### Chart rendering

`HealthChartWidget` uses `fl_chart` with `isCurved` enabled only when there are more than 3 data points. Zone bands come from `HealthMetrics.bandsFor`; the glucose chart mixes contexts and uses the random bands. The Charts screen also shows the 7-day average and the comparison with the previous 7 days (`ChartDataService.getWeeklyAverage` / `getComparisonInsight`).

### Firestore conventions

- Patient data lives under `/users/{uid}/` with sub-collections: `readings`, `medications`, `alerts`, `suggestions`, `messages`, `appointments`, `emergency_contacts`, `adherence`
- Doctors are identified by a document existing at `/doctors/{uid}`
- `collectionGroup` queries are used by the doctor portal for cross-patient reads (`readings`, `alerts`, `messages`, `suggestions`)
- Compound Firestore queries on `collectionGroup` require composite indexes — prefer single-field filtering in Firestore and filter additional conditions client-side to avoid index errors

### Local persistence

`SharedPreferences` stores: `onboarding_complete`; onboarding answers (`onboarding_first_name`, `_last_name`, `_gender`, `_dob`, `_services`, `_conditions`); `medications_list`; `appointments_list`; `emergency_contacts`; per-day taken flags `taken_{medId}_{HH:mm}_{yyyy-MM-dd}`; `bp_trend_warning_shown_date`; `history_hint_shown` (device-level). Firestore is the source of truth for everything else.

### Doctor portal specifics

- `DoctorService` is the sole data layer for the web portal — all patient reads go through it
- Selecting a patient (Patients grid, a critical alert, a message) calls `onSelectPatient`; `DoctorDashboardScreen` shows `DoctorPatientDetailScreen` in its content area with the sidebar visible. Alerts and messages load the full record with `DoctorService.getPatient`.
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
- Flutter Local Notifications (reminders) + timezone + flutter_timezone (pinned to 5.1.0; 5.1.1 would upgrade equatable)
- pdf: ^3.10.8 + printing: ^5.14.3 (PDF generation and sharing)
- share_plus: ^13.1.0 (report and CSV export sharing)
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
- /users/{uid} — patientId, name, email, createdAt, registered, active
- /users/{uid}.profile — name, gender, dob, conditions (list), diseaseType (derived from conditions, kept for older readers), services (list)
- /users/{uid}/readings/{readingId} — metricType, value, unit, status, timestamp, note, context (blood sugar)
- /users/{uid}/medications/{medicationId} — id, name, dosage, frequency, times, startDate, isActive, notes, reminderEnabled, pillsRemaining, pillsPerDose, lowSupplyNotified
- /users/{uid}/suggestions/{suggestionId} — text, doctorName, timestamp, read (bool)
- /users/{uid}/messages/{msgId} — text, timestamp, readByDoctor, patientName, patientId
- /users/{uid}/alerts/{alertId} — timestamp, triggerType, cancelled, patientName, patientId, diseaseType, conditions
- /users/{uid}/adherence/{date_medId_time} — medicationId, medicationName, dosage, timeSlot, date, taken, timestamp
- /users/{uid}/appointments/, /users/{uid}/emergency_contacts/
- /doctors/{doctorId} — doctor account marker
- /bugReports/{reportId} — text, timestamp, userId, platform
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
- 1,600,000–1,699,999: follow-up confirmations (the "marked as taken" one carries an Undo action)
- 1,700,000–1,799,999: critical reading alerts
- 1,800,000–1,899,999: doctor-assigned medication notifications
- 1,900,000–1,999,999: doctor suggestion notifications
- 2,000,000–2,099,999: snoozed medication reminders
- 2,100,000–2,199,999: appointment reminders

## Folder Structure
lib/core/health/ — health_metric (enums), health_metrics (definitions, bands, keys), conditions
lib/core/theme/ — app_colors, app_text_styles, app_theme
lib/core/services/ — preferences_service, notification_service, reminder_time, care_services
lib/features/auth/ — login_screen, register_screen, change_password_screen, forgot_password_sent_screen, auth_service
lib/features/onboarding/ — onboarding_screen, widgets/service_option_card
lib/features/disease/ — disease_selection_screen (conditions), services/conditions_service
lib/features/home/ — home_screen, main_shell
lib/features/medication/ — medication_screen, add_medication, medication_detail_screen, medication_history_screen, model, medication_service, dose_service, adherence
lib/features/tracking/ — tracking_screen
lib/features/history/ — history_screen
lib/features/profile/ — profile_screen, edit_profile_screen, my_services_screen, services/account_service, services/data_export
lib/features/dashboard/ — health_provider, health_history_provider
lib/features/health/models/ — health_reading, reading_entry, blood_pressure_pair
lib/features/health/screens/ — add_reading_input_screen, blood_pressure_input_screen
lib/features/health/services/ — health_reading_service
lib/features/health/widgets/ — status_display, value_entry_dialog
lib/features/notifications/screens/ — suggestions_panel_screen
lib/features/emergency/ — emergency_service, trend_warning_service, models/emergency_contact
lib/features/emergency/screens/ — emergency_contacts_screen
lib/features/appointments/ — appointments_screen, add_appointment_screen, appointment_detail_screen, model, appointment_service
lib/features/charts/models/ — chart_data_point
lib/features/charts/services/ — chart_data_service
lib/features/charts/widgets/ — health_chart_widget
lib/features/charts/screens/ — charts_screen
lib/features/report/ — report_service, report_screen
lib/features/doctor/data/ — medicine_library
lib/features/doctor/screens/ — doctor_login_screen, doctor_dashboard_screen, doctor_overview_screen, doctor_patients_screen, doctor_patient_detail_screen, doctor_settings_screen, doctor_messages_screen, doctor_suggestions_history_screen, critical_alerts_screen, deleted_patients_screen
lib/features/doctor/services/ — doctor_service, patient_suggestion_service
lib/features/doctor/widgets/ — status_badge (shared status pill)
lib/shared/widgets/ — nuvita_text_field, nuvita_button, nuvita_time_picker

## Rebuild status
- **Batch A — foundations and correct core: done** on `rebuild/batch-a` (PR into main, awaiting the owner's approval). CI, naming, dead code, the single metric module, blood sugar contexts, BP fixes, walking/temperature consistency, save flow, local-time reminders, sign-out cleanup, single dose and adherence paths, honest SOS wording, error handling, tests, services, conditions, profile editing/export/deletion, appointment reschedule, live readings, charts, doctor patient selection, guest mode removal.
- **Next — Batch B: replace the data layer.** Medications, appointments and emergency contacts are still kept in SharedPreferences and synced to Firestore by hand (Firestore write errors are only logged). Batch B replaces that with one data layer. Open items to carry into it: clinician review of the status thresholds and blood-sugar context mapping; inactive medications keep their daily reminders; the legacy one-time notification IDs overlap the active-reminder range.

## Coding Rules — ALWAYS FOLLOW
- Work in batches on a feature branch; never commit directly to main.
- Change only what the task lists. If something listed is wrong or risky, stop and report.
- UI changes are allowed only where the task says so.
- Every batch ends with `flutter analyze` and `flutter test` passing.
- Natural developer-style comments only.

## Branch and release workflow
Follow this for every task.

1. Never commit directly to main. Start every task by creating a new branch from the latest main, named `rebuild/<short-task-name>`.
2. Commit in small steps with clear messages as the work progresses.
3. Before anything reaches main, run all of these and confirm every one passes with no errors:
   - flutter pub get
   - flutter analyze
   - flutter test
   - flutter build apk --debug
   - flutter build web
4. If any check fails, fix the cause and run all checks again. Never skip, delete or weaken a test, and never suppress an analyzer error, to make a check pass. If it cannot be fixed, stop and report; do not merge.
5. When all checks pass, push the branch and open a pull request into main with a summary of what changed and the check results.
6. Merge into main only after the checks pass and the owner has approved the pull request. After merging, confirm main still passes the checks, then delete the branch.
7. Update CLAUDE.md at the end of every task so it describes the code as it now stands.
