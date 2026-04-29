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
- FL Chart (pending)

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

## Known Issue — Critical
Create Account button directs to Homepage instead of Onboarding.
Correct flow: Open App → Onboarding → Create Account → Homepage
This needs to be fixed.

## Completed Features (continued)
- Appointment Reminders: AppointmentModel + AppointmentService (SharedPrefs), AppointmentsScreen (Upcoming/Past tabs, swipe-to-delete, mark as done, day badges), AddAppointmentScreen (form with date/time/reminder picker), NotificationService extended with scheduleNotification + cancelNotification, SuggestionsPanelScreen appointments section live, ProfileScreen appointments tile

## Current Pending Features
1. Health Charts (FL Chart)

## Modifications List — Do Later
- Medication: tap card → detail view, Firebase sync, low pill alert
- Homepage: daily summary card, trend indicators, warning advice
- Navigation: fix Create Account → Onboarding flow
- Security: update Firestore rules before submission (readings sub-collection needs read/write rule)

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
- HealthProvider (scoped to HomeScreen) — current session metric values, inline tip logic, Firestore save/load
- HealthHistoryProvider (global, app root in main.dart) — full readings list, loaded from Firestore once per session

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