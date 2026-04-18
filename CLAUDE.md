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
- FL Chart (pending)
- Flutter PDF (pending)

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
- Homepage: Health metric cards, status badges, health evaluation rules
- Bottom Navigation: MainShell with IndexedStack, 4 tabs
- Profile: Firestore load, sign out, guest Create Account section
- Health History: Filter chips, grouped readings, HealthHistoryProvider
- Medication Reminders: MyTherapy UX, Today schedule, local notifications

## Known Issue — Critical
Create Account button directs to Homepage instead of Onboarding.
Correct flow: Open App → Onboarding → Create Account → Homepage
This needs to be fixed.

## Current Pending Features
1. Lifestyle Suggestions (next)
2. Emergency Alert
3. PDF Report Generation
4. Appointment Reminders
5. Health Charts (FL Chart)
6. Firebase sync for readings and medications

## Modifications List — Do Later
- Medication: tap card → detail view, Firebase sync, low pill alert
- Homepage: daily summary card, trend indicators, warning advice
- Navigation: fix Create Account → Onboarding flow
- Security: update Firestore rules before submission

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
