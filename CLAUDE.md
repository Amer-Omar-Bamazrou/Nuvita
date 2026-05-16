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
- Background: #F7F9FB (was #D6F3F4 — migrated to neutral near-white)
- Input Fill: #F0F4F6 (was #EAF7F8)
- Divider: #E2EAED (was #B0D8DC)
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
- Navigation Fix: LoginScreen checks onboarding flag before routing Create Account (OnboardingScreen if not done, RegisterScreen if done); RegisterScreen back button + Sign In link both return to OnboardingScreen; registration marks onboarding complete via PreferencesService; PopScope guards both screens (migrated from WillPopScope on 2026-05-15)
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
- Coverage: /users/{userId} (read/write own data OR isDoctor()), /readings, /alerts, /medications, /profile, /suggestions, /messages, /appointments, /emergency_contacts, /adherence sub-collections, /share_tokens (public read, auth write), /doctors/{doctorId} (read own only), /bugReports (anyone write, doctor read), collectionGroup readings + suggestions + alerts + messages (doctor read)
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

- Add Today's Reading Redesign (branch: feature/profile-redesign):
  - Replaced the old 3-stacked-bottom-sheet flow (add sheet → measurement sheet → TextField input sheet) with two full-screen Navigator.push pages
  - lib/features/health/models/metric_config.dart: shared MetricConfig data class (title, icon, unit, min, max) — extracted from home_screen so new screens can import it
  - lib/features/health/widgets/ruler_picker.dart: custom horizontal ruler picker — tick marks with major/minor intervals, center indicator line, edge fade gradients, HapticFeedback.selectionClick() on each tick change; no new packages
  - lib/features/health/screens/add_reading_list_screen.dart: full-screen measurement list; search bar; "Popular for you" section (disease-aware — diabetes → bloodSugarBefore/After/weight, blood_pressure/heart → BP/weight, other → BP/weight/temperature); "All measurements" section with 5 items; routes single metrics to AddReadingInputScreen, Blood Pressure to BloodPressureInputScreen; pops itself with true after a successful save so home screen receives the result
  - lib/features/health/screens/add_reading_input_screen.dart: full-screen input for single-metric readings; large value display (64sp); RulerPicker; editable Date row (blocks future dates) + Time row (defaults to now); "Track now" NuvitaButton; pops with true on success
  - lib/features/health/screens/blood_pressure_input_screen.dart: combined BP input; Sys/Dia/Pulse segment tabs; shared ruler updates per active tab; summary chips show all three values simultaneously (tap to jump to that field); "Track now" saves all 3 readings in parallel via Future.wait (systolic, diastolic, heartRate) with the same timestamp; pops with true on success
  - health_provider.dart: added bloodSugarBefore, bloodSugarAfter, temperature to HealthMetric enum; added clinical thresholds to getStatus() and tips to getSuggestionForMetric() for all three
  - health_history_provider.dart: extended _unitForMetric() switch to cover new metric types (was non-exhaustive)
  - home_screen.dart: _configs map updated to MetricConfig type + new entries for bloodSugarBefore/After/temperature; _showMeasurementSheet now async — awaits Navigator.push to AddReadingListScreen and shows green snackbar on return; _saveReading signature changed to (HealthMetric, double, DateTime) — custom timestamp stored in Firestore; bloodSugarBefore/After also satisfy a generic 'bloodSugar' task card; old _MetricInputSheet widget deleted

- Doctor Patient Detail — Metrics Fix (branch: feature/profile-redesign):
  - Fixed wrong Firestore keys: was looking for bloodPressureSystolic/Diastolic, corrected to systolic/diastolic
  - All 7 metric cards now always shown (Systolic BP, Diastolic BP, Heart Rate, Blood Sugar Before/After Meal, Weight, Temperature) — "—" displayed for unrecorded metrics so doctors see the full picture without needing the patient to have logged every type
  - Blood Pressure merged into one card: single _Card with three columns (Sys / Dia / Pulse) separated by vertical dividers; each column shows value, unit, and _StatusBadge independently — implemented via _BPSubValue and _BPDivider private widgets

- Tracking Page (branch: feature/tracking-page):
  - Replaced Medications tab (index 1) with Tracking tab in MainShell; icon: track_changes_rounded
  - lib/features/tracking/screens/tracking_screen.dart: 3 cards (Medications, Appointments, Health Report) with progress indicators and guest mode handling; Medications card shows today's dose completion from SharedPreferences; Appointments card shows upcoming count; Health Report card shows readings in last 30 days
  - profile_screen.dart: removed Health Report + Appointments tiles (moved to Tracking)
  - Onboarding skip: "Already have an account? Sign in" link on name step → marks onboarding complete → LoginScreen
  - Home screen task list: cleaned up to show medication tasks only (removed reading tasks); simplified DailyTask class; removed TaskType enum

- Medication Enhancements (branch: feature/medication-enhancements-v2):
  - Enhancement 1 — Visual Completion: medication_screen.dart taken state now persisted to SharedPreferences using key pattern `taken_${medId}_${time}_${yyyy-MM-dd}`; _restoreTakenState() loads on screen init; _toggleTaken() writes to prefs + calls MedicationService.takeMedication(); green "Taken" badge shown on completed doses; medication_detail_screen.dart _checkTodayDoses() reads prefs on init, "Take Now" button shows "All Doses Taken" (green, disabled) when all scheduled doses completed
  - Enhancement 2 — Missed Dose Badges: _isMissed() compares current time vs scheduled time; untaken past doses show red "Missed" badge + red left border on the row; time text turns red for missed entries
  - Enhancement 3 — Medicine Search: add_medication_screen.dart search field at top (add mode only); searches medicineLibrary by name or category; dropdown results with name, category, dosage, type; selecting auto-fills name, dosage, frequency fields; search section hides after selection
  - Enhancement 4 — Adherence History: medication_history_screen.dart shows last 7 days of dose adherence; each day card with date, day name, coloured progress bar (green 100% / orange 50%+ / red below), "X/Y doses (Z%)" text; empty state when no data; calendar_month_rounded icon button added to medication_screen.dart AppBar
  - Enhancement 5 — Undo Snackbar: _toggleTaken() shows 5-second snackbar after marking dose taken; "Undo" action removes SharedPreferences key, restores pillsRemaining by pillsPerDose, resets lowSupplyNotified if count > 7, cancels low supply notification, refreshes UI via _load()
  - Bug Fix — Undo Pill Count: undo callback now fetches medication via getById(), increments pillsRemaining by pillsPerDose, updates via MedicationService.update() to persist to SharedPreferences + Firestore

- Medication Adherence Sync (branch: feature/adherence-sync):
  - MedicationService: added saveDoseToFirebase(), removeDoseFromFirebase(), getAdherenceHistory() — writes/deletes/reads from /users/{uid}/adherence/{date_medId_time}; doc fields: medicationId, medicationName, dosage, timeSlot, date, taken, timestamp
  - medication_screen.dart: _toggleTaken() now calls saveDoseToFirebase on take and removeDoseFromFirebase on untoggle + undo; all Firebase calls fire-and-forget alongside existing SharedPreferences writes
  - medication_history_screen.dart: _load() fetches Firestore adherence via getAdherenceHistory() when logged in; merges with SharedPreferences — dose counts as taken if either source says true; survives reinstalls
  - DoctorService: added getPatientAdherence(uid, days) — queries /users/{uid}/adherence filtered by date
  - doctor_patient_detail_screen.dart: new "Medication Adherence" section in right column between Medications and Readings; _loadAdherence() cross-references adherence docs with medication schedules; 7-day progress bars (green 100% / orange 50%+ / red below); _AdherenceDay data class
  - firestore.rules: added /users/{userId}/adherence/{doseId} rule (owner + doctor read/write)

- Blood Pressure Dual Line Chart (branch: feature/charts-bp-dual):
  - ChartDataService: added getBPChartData(uid, days) — single Firestore query returning Map<String, List<ChartDataPoint>> with 'systolic' and 'diastolic' keys
  - HealthChartWidget: added optional secondaryData, secondaryLabel, secondaryColor params; dual line mode draws second line with outlined circle dots; _alignSecondarySpots() matches diastolic to systolic x-axis by date; _dualTooltip() shows combined "Sys: 125 / Dia: 82" on tap; gradient fill disabled in dual mode
  - charts_screen.dart: _loadChartData() calls getBPChartData() when BP selected; trend header shows both Sys/Dia values with coloured dots; average shows "Avg Sys 125 / Dia 80 mmHg"; _getBPInsight() considers both values (sys normal + dia elevated, etc.); legend row with Systolic + Diastolic dots; trend calculated from systolic only
  - Design: Systolic #004346 solid dots, Diastolic #508991 outlined dots, zone bands systolic only

- Doctor Patient Health Trends (branch: feature/charts-bp-dual):
  - doctor_patient_detail_screen.dart: added imports for ChartDataPoint, ChartDataService, HealthChartWidget; new "Health Trends" section at top of right column; _loadChart() picks metric by patient disease type (BP→systolic dual line, diabetes→bloodSugar, heart→heartRate); inline HealthChartWidget at 200px with legend dots + trend badge (Improving/Stable/Worsening); empty state "No chart data available"

- PDF Report Charts (branch: feature/pdf-charts):
  - report_service.dart: added _buildMetricChart() using pw.CustomPaint with PdfGraphics canvas drawing; draws line chart for each metric with 2+ readings below its table; zone bands (green normal, orange warning) from MetricThresholds; horizontal grid lines, axis labels, data dots; BP dual line with systolic (#004346) + diastolic (#508991) and "— Systolic — Diastolic" legend; chart height 150pt, full page width

## Firestore Structure (continued)
/users/{uid}/adherence/{date_medId_time} — medicationId, medicationName, dosage, timeSlot, date, taken, timestamp

- Full App & Dashboard Bug Audit (2026-05-15):
  - Notification Logic Fixes (notification_service.dart + appointment_service.dart):
    - Fix 1: Added _plugin.initialize(settings) in _onBackgroundAction — background isolate notification actions (snooze, supply remind, follow-up) were calling _plugin.show()/_plugin.zonedSchedule() on uninitialized plugin
    - Fix 2: Moved _snoozedMedNotificationId from 1,600,000 to 2,000,000 — was colliding with _followUpId range
    - Fix 3: Added appointmentDateTime param to scheduleAppointmentReminder — body text was showing reminder fire time instead of actual appointment time
    - Fix 4: Moved _appointmentNotificationId from id.hashCode.abs() % 999990 to 2,100,000+ — overlapped with _notificationId range (0–99,999)
    - Fix 5: Added payload 'critical:$readingId' to showCriticalReadingNotification + critical: handler in _onNotificationTap — tapping critical reading notifications previously did nothing
  - Codebase Logic Fixes:
    - Fix 6: Removed unused import 'change_password_screen.dart' from login_screen.dart
    - Fix 7: Fixed stale _allDosesTaken in medication_detail_screen.dart — _onTakeNow() incremented _takenTodayCount but never re-evaluated _allDosesTaken, so "Take Now" button wouldn't switch to "All Doses Taken" until full screen rebuild
    - Fix 8: Added MedicationService.saveDoseToFirebase() call to home_screen.dart _markMedTaken() — doses taken from home screen task list were only saved to SharedPreferences, not synced to Firestore adherence (doctor dashboard couldn't see them)
  - Deprecation & Lint Cleanup (148 → 0 analyzer issues):
    - Migrated all .withOpacity() → .withValues(alpha:) across 31 files (134 occurrences)
    - Migrated WillPopScope → PopScope in login_screen.dart + register_screen.dart
    - Migrated activeColor → activeThumbColor on Switch widgets in medication_detail_screen.dart + medication_screen.dart
    - Migrated value → initialValue on DropdownButtonFormField in doctor_patient_detail_screen.dart (2 occurrences)
    - Fixed unnecessary double underscores (__) → (_) in separatorBuilder callbacks across 5 files
    - Renamed _val/_status local functions to getVal/getStatus in doctor_patient_detail_screen.dart (leading underscore lint)
    - Migrated if (current != null) current → ?current null-aware element in onboarding_screen.dart
  - Notification ID Ranges (updated):
    - 0–99,999: base notifications (_notificationId)
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
  - flutter analyze result: 0 errors, 0 warnings, 0 info — fully clean

- UI Polish & Design System Standardisation (branch: feature/ui-polish):
  - Full design system created externally (CSS tokens, JSX component recreations, HTML previews) then implemented across 42 files
  - Colour Token Migration: app_colors.dart updated — background #D6F3F4→#F7F9FB, inputFill #EAF7F8→#F0F4F6, divider #B0D8DC→#E2EAED (teal-heavy palette to neutral near-white)
  - Card Shadows: neutralised from AppColors.primary-based to AppColors.textDark 6% alpha; doctor portal cards switched from box shadows to 1px #EEEEEE border
  - Status Badges: solid coloured backgrounds → outlined pill style (12% alpha fill + 40% alpha border + coloured text, borderRadius 20) across patient app and doctor portal
  - NuvitaButton Refactor: wrapped ElevatedButton in Container with BoxDecoration shadow (primary 16% alpha, blurRadius 10, offset 0,3); 56px height, 14 radius; outlined variant with 2px primary border
  - Auth Screens: login_screen.dart + register_screen.dart switched to white background (was teal)
  - Doctor Login Rework: maxWidth 420 container with border+shadow, row layout for logo+title, "Sign in" heading, "Access your patient dashboard" subtitle, 52px button, security footer with shield icon, input fields radius 14 + fillColor #F0F4F6
  - Doctor Overview: stat cards changed from horizontal Row to vertical Column layout (icon on top, 28px number, label below), 240px wide, #EEEEEE border; activity feed bottom-border rows instead of zebra-striping; "Recent Patient Activity" title
  - Doctor Patient Detail: all _Card widgets radius 8→12, boxShadow→#EEEEEE border; all Colors.grey.shade* → explicit hex constants (#EEEEEE, #9AA3AB, #6E7A82)
  - Charts Screen: time range toggle changed from bordered buttons to iOS-style segmented control (inputFill background, white active segment with shadow); metric chips gained outlined border when unselected; empty states now 96px circle containers with 8% primary fill + 48px icon
  - app_theme.dart: card elevation 3→2, shadow neutralised, ElevatedButton elevation→0 with transparent shadow, input border width 1→1.5
  - Consistent updates across: onboarding, home, tracking, history, profile, medication (all screens), appointments (all screens), emergency contacts, suggestions panel, disease selection, doctor messages, doctor suggestions history, critical alerts, deleted patients, doctor settings, doctor patients, forgot password, change password, blood pressure input, add reading screens, lifestyle screen

- Health Report Fixes (branch: feature/ui-polish, 2026-05-16):
  - report_screen.dart: added full-screen loading overlay ("Generating your report...") with semi-transparent background when PDF is generating — replaced tiny spinner inside Preview button
  - report_screen.dart: added MedicationService.syncFromFirebase(uid) in _loadData() before loadAll() — doctor-assigned medications now appear in summary card and generated PDF (previously only locally-added meds showed)

- Measurement Entry Screens Redesign (branch: feature/ui-polish, 2026-05-16):
  - Design source: `C:\Users\lenovo\Downloads\Nuvita Design System (1)\ui_kits\patient_app\PatientSecondary.jsx` (AddTemperatureScreen, AddBloodPressureScreen, AddWeightScreen, AddBloodSugarBeforeScreen, AddBloodSugarAfterScreen)
  - add_reading_input_screen.dart: full rewrite — ruler picker replaced with +/− stepper buttons (56px circles, haptic feedback); hero card with icon tile, kicker text, 72sp value, status badge (Normal/High/Low with colored dot), range hint; "Type a value" link opens dialog for keyboard entry; date/time card with icon tiles + chevrons; context chips per metric type; blood sugar Before/After Meal segmented toggle that switches metric type; sticky "Save Reading" button with top border
  - blood_pressure_input_screen.dart: full rewrite — removed segment tabs + ruler + summary chips; hero card shows combined sys/dia display with heart icon + status badge; separate Systolic and Diastolic stepper cards with +/− buttons; date/time card with icon tiles; context chips; sticky "Save Reading" button

- Add Today's Entry Sheet Redesign (branch: feature/ui-polish, 2026-05-16):
  - home_screen.dart: replaced simple 2-row ListTile bottom sheet with modern design — grab handle, "Add Today's Entry" title + date, "What would you like to log?" subtitle, QUICK MEASUREMENT 3×2 grid of colored icon chips (Sugar, BP, Heart, Weight, Steps, Temp), divider, OTHER section with Medication + Appointment rows
  - Quick chips navigate directly to specific measurement screens (skip Add Reading List page): Sugar→bloodSugarBefore, BP→BloodPressureInputScreen, Heart→heartRate, Weight→weight, Steps→walking, Temp→temperature
  - New _navigateToMetric() method handles direct routing + success snackbar
  - Removed unused _showMeasurementSheet(), _showMedTasks, _showReadingTasks, AddReadingListScreen import
  - Added imports: AddReadingInputScreen, BloodPressureInputScreen, AddAppointmentScreen

- Walking / Steps Feature (branch: feature/ui-polish, 2026-05-16):
  - home_screen.dart: steps config changed from "Daily Steps / steps / 0–100,000" to "Walking / min / 0–300"
  - add_reading_input_screen.dart: full walking support — purple icon (#7B1FA2), "WALKING MINUTES" kicker, status (Great ≥30min / Good ≥15min / Low activity), range hint "Aim for at least 30 minutes daily", context chips (Walking, Jogging, Errands, Exercise), default 30 min
  - health_history_provider.dart: steps unit changed from "steps" to "min"
  - doctor_patient_detail_screen.dart: added Walking card (metricType 'steps', unit 'min') to singleMetrics list — doctors see patient walking data
  - Firebase: saved to /users/{uid}/readings as metricType: "steps", unit: "min" — same readings pipeline, no new rules needed

## Modifications List — Do Later
- (none — all modifications complete)

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
lib/features/health/screens/ — add_reading_list_screen (legacy — no longer wired to home), add_reading_input_screen, blood_pressure_input_screen
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