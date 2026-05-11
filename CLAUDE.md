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

`MainShell` uses `IndexedStack` with 4 tabs (Home, Medications, History, Profile). Push-routes (charts, appointments, report, suggestions panel) sit on top of the stack via `Navigator.push`.

Notification taps are routed via a global `navigatorKey` wired in `main.dart`. The appointment tap handler is set there (not in `NotificationService`) to avoid a circular import.

### Firestore conventions

- Patient data lives under `/users/{uid}/` with sub-collections: `readings`, `medications`, `alerts`, `suggestions`, `messages`
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

# Nuvita — Project Memory

## Project Overview
- App Name: Nuvita
- Type: Flutter Android mobile application
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
- Background: #D6F3F4
- Primary: #004346
- Cards: #74B3CE
- Secondary: #508991
- Text: #172A3A
- Card Radius: 16
- Style: Minimal, elderly friendly

## Completed Features
- Flutter + Firebase setup
- App theme and colour palette
- Reusable widgets: NuvitaTextField, NuvitaButton, HealthMetricCard
- Authentication: Login, Register, AuthService
- Onboarding: 7 step flow, SharedPreferences, PreferencesService
- Homepage: Health metric cards, status badges, inline lifestyle tips per card
- Bottom Navigation: MainShell with IndexedStack, 4 tabs
- Profile: Firestore load, sign out, guest Create Account section
- Health History: Filter chips, grouped readings, loading spinner, Firestore-backed
- Medication Reminders: MyTherapy UX, Today schedule, local notifications
- Lifestyle Suggestions: LifestyleEngine (12 rules), inline tips on HealthMetricCard
- Firebase Readings Sync: readings saved to /users/{uid}/readings, restored on app start
- Health Insights Panel: notification icon (replaces avatar) with red badge, SuggestionsPanelScreen showing weekly summary, suggestion cards, appointments placeholder
- Emergency Alert: SOS icon on disease banner, 10-second countdown dialog (barrierDismissible false), cancel window, alert sent confirmation dialog, Simulate Critical Reading button below banner, weekly BP trend snackbar (once per day via SharedPreferences flag)
- PDF Report Generation: ReportService generates A4 PDF (header, patient summary, readings tables with avg/high/low per metric, medications list, disclaimer), ReportScreen with summary card + Preview and Share buttons, entry card on ProfileScreen above Sign Out

## Firestore Structure
/users/{uid}/profile — name, diseaseType
/users/{uid}/readings/{readingId} — metricType, value, unit, status, timestamp, note
/users/{uid}/medications/{medicationId} — id, name, dosage, frequency, times, startDate (Timestamp), isActive, notes

## Completed Features (continued)
- Appointment Reminders: AppointmentModel + AppointmentService (SharedPrefs), AppointmentsScreen (Upcoming/Past tabs, swipe-to-delete, mark as done, day badges), AddAppointmentScreen (form with date/time/reminder picker), NotificationService extended with scheduleNotification + cancelNotification, SuggestionsPanelScreen appointments section live, ProfileScreen appointments tile
- Health Charts: FL Chart integration with trend lines, zone bands (normal/warning/danger), and insights per metric type
- Navigation Fix: LoginScreen checks onboarding flag before routing Create Account (OnboardingScreen if not done, RegisterScreen if done); RegisterScreen back button + Sign In link both return to OnboardingScreen; registration marks onboarding complete via PreferencesService; WillPopScope guards both screens
- Onboarding Step 6 Fix: Removed Doctor Reports and Emergency Alerts from service preferences list — kept only Medications, Measurements, Activities, Appointments (these are core features, not optional services)
- Firestore Security Rules: firestore.rules created in project root — covers /users/{uid} and all sub-collections (auth + uid match), /share_tokens (public read, auth write); must be manually published in Firebase Console
- Homepage Improvements: Daily summary card (readings today, meds scheduled, last reading time), trend arrows on metric cards (red ↑ worse / green ↓ better per metric type, heart rate moves-toward-75 logic), warning action prompts per metric/status that replace lifestyle suggestion when in warning or critical range
- Medication Firebase Sync: MedicationService syncs to /users/{uid}/medications — add/delete/update mirror to Firestore after local SharedPreferences write; syncFromFirebase(uid) fetches on app start and merges (Firestore wins on same ID, local-only entries kept); guest users remain local only; all Firebase calls fail silently
- Health History Improvements: swipe-to-delete on each reading tile (optimistic — Firestore delete deferred until 3 s undo snackbar expires without undo action); long-press to edit (modal bottom sheet, pre-filled value, per-metric validation ranges, status recalculated on save); HealthHistoryProvider extended with removeReading, restoreReading, patchReading; HealthReadingService extended with updateReading

## Known Issues — Resolved
~~Create Account button directs to Homepage instead of Onboarding.~~
Fixed: login_screen.dart + register_screen.dart updated on feature/navigation-fix branch.

## Current Pending Features
None — all planned features complete.

## Completed Features (continued)
- Medication Detail View and Low Pill Supply Alert: MedicationModel extended with pillsRemaining (int?), pillsPerDose (int=1), lowSupplyNotified (bool); MedicationDetailScreen (name card, details card, pills card, Take Now button, Edit/Delete actions); AddMedicationScreen updated to support edit mode (existing: MedicationModel?) and optional pills remaining field; MedicationScreen shows orange low supply banner (dismiss for session, tap to show refill dialog), medication card taps open detail screen; NotificationService extended with scheduleLowSupplyAlert + cancelLowSupplyAlert; MedicationService extended with takeMedication, checkLowSupply, getLowSupplyMedications, updatePillsRemaining

- Patient ID Authentication (branch: feature/patient-id-auth):
  - AuthService: signUp() now returns patientId (String); saves patientId, name, email, createdAt, registered:true to Firestore root doc; added signInWithPatientId(), resolveEmailFromPatientId(), saveOnboardingProfile()
  - LoginScreen: accepts Email OR 6-char alphanumeric Patient ID; validator updated; routes to signInWithPatientId if no @ and matches pattern
  - RegisterScreen: receives patientId from signUp, reads SharedPrefs (gender/dob/name), calls saveOnboardingProfile() then shows Patient ID dialog before navigating to MainShell
  - ProfileScreen: loads patientId from Firestore root doc; Patient ID card with copy + share (share_plus) buttons; name fix (falls back data['name'] if profile['name'] missing)

- Doctor Dashboard Web App (branch: feature/web-doctor-dashboard):
  - Flutter web platform enabled via flutterfire configure
  - main.dart: kIsWeb → DoctorLoginScreen, else existing mobile routing
  - lib/features/doctor/services/doctor_service.dart: isDoctorAccount, getDoctorName, getAllPatients, getPatientReadings, getPatientMedications, updateMedication, sendSuggestion, getCriticalReadingsCount, getLowMedicationsCount, getTotalSuggestionsCount, getRecentReadingsAllPatients (collectionGroup)
  - lib/features/doctor/screens/doctor_login_screen.dart: web login, checks /doctors/{uid} existence, rejects non-doctors
  - lib/features/doctor/screens/doctor_dashboard_screen.dart: 220px sidebar (#004346), IndexedStack for Overview/Patients/Settings
  - lib/features/doctor/screens/doctor_overview_screen.dart: 4 stat cards, recent activity feed via collectionGroup
  - lib/features/doctor/screens/doctor_patients_screen.dart: search + disease filter, patient cards grid, tap → detail
  - lib/features/doctor/screens/doctor_patient_detail_screen.dart: personal info, disease-aware metric cards, inline medication edit, readings table, send suggestion; now requires doctorName param; sendSuggestion stores patientName + patientId in the doc
  - lib/features/doctor/screens/doctor_settings_screen.dart: account card, change password (re-auth + updatePassword), sign out
  - firestore.rules updated: isDoctor() helper, /users allow read if isDoctor(), collectionGroup rules for readings + suggestions

- Password Management (branch: feature/patient-id-auth):
  - lib/features/auth/screens/change_password_screen.dart: for users who know current password — Email/Patient ID + current password + new password + confirm; re-authenticates via EmailAuthProvider then updatePassword(); signs out on success
  - lib/features/auth/screens/forgot_password_sent_screen.dart: "Check your inbox" screen — shown after reset email is sent; email icon, instructions, spam reminder, Back to Sign In button
  - login_screen.dart: "Forgot password?" opens _ForgotPasswordDialog (email/Patient ID field + Send Link); on success pops dialog and pushes ForgotPasswordSentScreen; controller owned by dialog state (fixes disposal crash)
  - Forgot password flow: dialog → sendPasswordResetEmail (resolves Patient ID first if needed) → ForgotPasswordSentScreen; user clicks Firebase email link to complete reset on web, then signs in

## Firestore Security Rules
- Rules file: `firestore.rules` in project root
- Applied: 2026-05-02 on branch feature/firebase-security-rules; updated 2026-05-06 for doctor access
- Coverage: /users/{userId} (read/write own data OR isDoctor()), /readings, /alerts, /medications, /profile sub-collections, /share_tokens (public read, auth write), /doctors/{doctorId} (read own only), collectionGroup readings + suggestions (doctor read)
- Must be manually copied into Firebase Console → Firestore Database → Rules tab and published

- Doctor Suggestions History (branch: feature/doctor-suggestions):
  - Root cause fix: DoctorPatientDetailScreen was saving suggestions with doctorName='Doctor' (wrong field); now doctorName flows Dashboard → PatientsScreen → PatientDetailScreen via required param
  - DoctorService.sendSuggestion: now stores patientName + patientId in the suggestion doc (optional named params, old calls unaffected)
  - DoctorService.getSentSuggestionsHistory(doctorName): queries each patient's /suggestions subcollection individually (regular collection queries, no composite index needed); enriches old suggestions with patientName/patientId from patient doc; sorts client-side newest first
  - DoctorService.getTotalSuggestionsCount: delegates to getSentSuggestionsHistory, returns length
  - doctor_suggestions_history_screen.dart: list of all suggestions sent by this doctor; each item shows patient avatar, name, patient ID badge, message body, formatted date; pull-to-refresh; empty state; debugPrint on error
  - doctor_overview_screen.dart: "Suggestions Sent" card tappable → opens DoctorSuggestionsHistoryScreen; refreshes count on return; _loadData refactored to fault-tolerant per-stat try/catch — one failing collectionGroup query no longer zeros out all counts
  - DoctorPatientsScreen: now requires doctorName param; passes it to DoctorPatientDetailScreen
  - DoctorDashboardScreen: passes doctorName to DoctorPatientsScreen
  - No Firebase Console changes required — per-patient subcollection queries use auto-indexed single fields; existing rules already cover doctor read on /users/{uid}/suggestions

- Doctor Suggestions in Patient App (branch: feature/doctor-suggestions):
  - lib/features/doctor/services/patient_suggestion_service.dart: listenToAllSuggestions (realtime stream ordered by timestamp desc), listenToUnreadCount (stream of unread count for badge), markAsRead (uid + suggestionId, rethrows on error), timeAgo (manual calc — Just now / X minutes / X hours / X days)
  - home_screen.dart: bell badge now combines unread doctor messages + warning/critical readings; guest users skip stream; StreamBuilder<int> on listenToUnreadCount drives badge; _buildBellIcon extracted for reuse
  - suggestions_panel_screen.dart: doctor messages section added at very top (logged-in only); StreamBuilder on listenToAllSuggestions; cards with left border (primary=unread, grey=read), expand/collapse via _expandedIds Set, markAsRead on tap, UNREAD chip, timeAgo timestamp; empty state with message icon; all existing sections (weekly summary, lifestyle, appointments) preserved below

## Firestore Structure (continued)
/users/{uid}/suggestions/{suggestionId} — text, doctorName, timestamp, read (bool)

- Daily Medication Reminders + Wellness Reminder (branch: feature/medication-daily-reminders):
  - MedicationModel: added reminderEnabled (bool, default false) to constructor, copyWith, toMap, fromMap
  - MedicationService: added getById(String id) — returns null if not found; updated _toFirestoreMap + _fromFirestoreDoc for reminderEnabled
  - NotificationService: navigatorKey param added to initialize(); tap routing via _onNotificationTap → med: payload prefix; _handleMedicationTap shows "Did you take [name]?" dialog, calls takeMedication on confirm; scheduleDailyMedicationReminder (IDs 1,100,000–1,200,000, payload med:id, daily repeat); cancelDailyMedicationReminders; scheduleDailyWellnessReminder (fixed ID 1200001, 09:00 daily, wellness_reminders channel); cancelWellnessReminder
  - medication_detail_screen.dart: _reminderToggleRow in details card (only shown when times non-empty); _onReminderToggle saves + schedules/cancels + snackbar; _onDelete now also cancels daily reminders if enabled
  - medication_screen.dart: _delete cancels daily reminders if med.reminderEnabled
  - main.dart: top-level navigatorKey passed to MaterialApp + NotificationService.initialize(); scheduleDailyWellnessReminder called on app start when user is logged in
  - profile_screen.dart: cancelWellnessReminder called before signOut

- Appointment Confirmation via Notification Tap (branch: feature/medication-daily-reminders):
  - AppointmentModel: added isConfirmed (bool, default false) to constructor, copyWith, toMap, fromMap
  - AppointmentService: added getAppointmentById(id), updateAppointment(model); scheduleReminder now passes payload 'appt:{id}' to scheduleNotification
  - NotificationService: added _appointmentTapHandler callback slot + setAppointmentTapHandler(); _onNotificationTap routes 'appt:' prefix to the handler; scheduleNotification gains optional String? payload param — avoids circular import since appointment_service already imports notification_service
  - appointment_detail_screen.dart: shows doctor name, speciality, date/time, location, reminder, notes; 'Confirmed' chip when isConfirmed=true; if showConfirmDialog=true auto-shows "Will you attend?" dialog via addPostFrameCallback; Yes → updateAppointment(isConfirmed:true) + snackbar; Reschedule → close dialog
  - main.dart: imports appointment_service + appointment_detail_screen; sets appointment tap handler after NotificationService.initialize — loads appointment, pushes AppointmentDetailScreen(showConfirmDialog:true) via navigatorKey

- Doctor Dashboard Improvements + Medicine Library (branch: feature/doctor-suggestions):
  - emergency_service.dart: _logAlert() writes to /users/{uid}/alerts on SOS fire and on cancel — both _onCountdownComplete and _cancel call it; fields: timestamp, triggerType, cancelled, patientName, diseaseType
  - Mod 1 — Session persistence: doctor_login_screen.dart sets Persistence.LOCAL before sign-in (web only); doctor_dashboard_screen.dart _buildSessionIndicator() green dot + "Session active" + Refresh inkwell (calls getIdToken(true))
  - Mod 2 — Patient messaging: profile_screen.dart "Message Your Doctor" bottom sheet saves to /users/{uid}/messages; doctor_messages_screen.dart StreamBuilder on getPatientMessages(), mark-as-read on tap; real-time unread badge in doctor_overview_screen.dart via getUnreadMessagesCount() stream; firestore.rules updated for /messages subcollection + collectionGroup
  - Mod 3 — Medicine library: lib/features/doctor/data/medicine_library.dart — Medicine class + 24 medicines across 8 categories; doctor_patient_detail_screen.dart "Assign" button → _AssignMedicationSheet (search, select, dosage/frequency/pills form, saves via addMedication()); DoctorService.addMedication() creates doc in /users/{uid}/medications
  - Mod 4 — Critical alerts today: DoctorService.getEmergencyAlertsToday() uses collectionGroup('alerts'), filters cancelled==false + timestamp >= today midnight; critical_alerts_screen.dart shows patient avatar, name, ID badge, disease chip, trigger type chip, red/orange left border; doctor_overview_screen.dart "Critical Today" card taps to CriticalAlertsScreen
  - Mod 5 — Soft-delete patients: DoctorService.deactivatePatient/restorePatient/getDeactivatedPatients(); doctor_patients_screen.dart person_remove icon → confirm dialog → deactivate; deleted_patients_screen.dart shows deactivated patients with restore button; doctor_overview_screen.dart "Deactivated" stat card; login_screen.dart + main.dart check active==false on sign-in/startup → sign out + error dialog; getAllPatients() filters active!=false in-memory

- Profile Screen Redesign (branch: feature/profile-redesign):
  - profile_screen.dart fully rewritten: guest view (sign in + create account); logged-in view with CircleAvatar, name, patient ID; 4 section cards (Account, Health, Notifications, About); _showPersonalInfoSheet (read-only: name, gender, DOB, patient ID + copy); _showMessageDoctorSheet (try/finally + .timeout(10s), saves to /users/{uid}/messages); _showBugReportSheet (saves to /bugReports); _recommendApp (share_plus SharePlus.instance.share); _showSignOutDialog confirmation before sign out
  - firestore.rules: added /bugReports (anyone write, doctor read); /users/{userId}/messages (owner + doctor read/write); collectionGroup alerts + messages (doctor read/write)

## Firestore Structure (continued)
/users/{uid}/messages/{msgId} — text, timestamp, readByDoctor, patientName, patientId
/bugReports/{reportId} — text, timestamp, patientId, patientName

## Modifications List — Do Later
- (none — all modifications complete)

## Folder Structure
lib/core/theme/ — app_colors, app_text_styles, app_theme
lib/core/services/ — preferences_service, notification_service
lib/features/auth/ — login_screen, register_screen, change_password_screen, forgot_password_sent_screen, auth_service
lib/features/onboarding/ — onboarding_screen, welcome_splash (dormant)
lib/features/disease/ — disease_selection (dormant)
lib/features/home/ — home_screen, main_shell
lib/features/medication/ — medication_screen, add_medication, model, service
lib/features/history/ — history_screen
lib/features/profile/ — profile_screen
lib/features/dashboard/ — health_provider, health_history_provider
lib/features/health/models/ — health_reading
lib/features/health/services/ — health_reading_service, health_log_service (legacy)
lib/features/lifestyle/models/ — lifestyle_suggestion
lib/features/lifestyle/services/ — lifestyle_engine
lib/features/lifestyle/widgets/ — suggestion_card
lib/features/lifestyle/screens/ — lifestyle_screen (dormant — built, not wired to nav)
lib/features/notifications/screens/ — suggestions_panel_screen
lib/features/emergency/ — emergency_service, trend_warning_service
lib/features/report/ — report_service, report_screen
lib/features/doctor/data/ — medicine_library
lib/features/doctor/screens/ — doctor_login_screen, doctor_dashboard_screen, doctor_overview_screen, doctor_patients_screen, doctor_patient_detail_screen, doctor_settings_screen, doctor_messages_screen, doctor_suggestions_history_screen, critical_alerts_screen, deleted_patients_screen
lib/features/doctor/services/ — doctor_service, patient_suggestion_service
lib/shared/widgets/ — nuvita_text_field, nuvita_button, health_metric_card

## Key Providers
- HealthProvider (scoped to HomeScreen only — not accessible from sibling screens) — current session metric values, inline tip logic, Firestore save/load
- HealthHistoryProvider (global, app root in main.dart) — full readings list, loaded from Firestore once per session; supports removeReading, restoreReading, patchReading for history edits

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