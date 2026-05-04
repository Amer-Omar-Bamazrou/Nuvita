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

## Known Issue — Resolved
~~Create Account button directs to Homepage instead of Onboarding.~~
Fixed: login_screen.dart + register_screen.dart updated on feature/navigation-fix branch.

## Current Pending Features
None — all planned features complete.

## Completed Features (continued)
- Medication Detail View and Low Pill Supply Alert: MedicationModel extended with pillsRemaining (int?), pillsPerDose (int=1), lowSupplyNotified (bool); MedicationDetailScreen (name card, details card, pills card, Take Now button, Edit/Delete actions); AddMedicationScreen updated to support edit mode (existing: MedicationModel?) and optional pills remaining field; MedicationScreen shows orange low supply banner (dismiss for session, tap to show refill dialog), medication card taps open detail screen; NotificationService extended with scheduleLowSupplyAlert + cancelLowSupplyAlert; MedicationService extended with takeMedication, checkLowSupply, getLowSupplyMedications, updatePillsRemaining

## Firestore Security Rules
- Rules file: `firestore.rules` in project root
- Applied: 2026-05-02 on branch feature/firebase-security-rules
- Coverage: /users/{userId} (read/write own data), /readings, /alerts, /medications, /profile sub-collections (auth + uid match), /share_tokens (public read, auth write)
- Must be manually copied into Firebase Console → Firestore Database → Rules tab and published

## Modifications List — Do Later
- (none — all modifications complete)

## Folder Structure
lib/core/theme/ — app_colors, app_text_styles, app_theme
lib/core/services/ — preferences_service, notification_service
lib/features/auth/ — login, register, auth_service
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