# Nuvita — Project Memory

## Project Overview
- App Name: Nuvita
- Type: Flutter Android mobile application
- Purpose: Smart health companion for chronic patients
- Developer: Amer Omar Bamazrrou
- University: De Montfort University Leicester
- Module: CTEC3451 Final Year Project

## Tech Stack
- Flutter + Dart (mobile app)
- Firebase Authentication (login/register)
- Firebase Firestore (database)
- Firebase Storage (PDF storage)
- Firebase Cloud Messaging (notifications)
- FL Chart (health charts)
- Flutter PDF (report generation)
- Provider (state management)

## Design System
- Background: #D6F3F4
- Primary: #004346
- Cards: #74B3CE
- Secondary: #508991
- Text: #172A3A
- Style: Minimal, clean, elderly friendly

## Project Structure
```
lib/
  features/
    auth/screens/       — login, register
    auth/services/      — auth service
    dashboard/screens/  — home screen
    disease/screens/    — disease selection
    health/screens/     — health logging
    medication/screens/ — medication
    onboarding/screens/ — onboarding
  shared/widgets/       — reusable widgets
  core/theme/           — colours, styles, theme
```

## Completed Features
- Flutter setup and Firebase connection
- App theme and colour palette
- Reusable widgets (NuvitaTextField, NuvitaButton)
- Login screen UI
- Register screen UI
- Firebase Authentication (login + register connected to Firebase)
- Firestore database created
- Disease Selection Screen (Stage 1: condition picker, Stage 2: 7-step personal info flow)
- PatientModel + PatientService (saves to /users/{uid} profile field)
- Homepage Dashboard (greeting, avatar, disease banner, metric cards grid, bottom sheet readings)
- HealthProvider (local session state for metric values + clinical status evaluation)
- HealthMetricCard widget (reusable, status badge, add-reading bottom sheet)
- MainShell (IndexedStack + 4-tab bottom nav: Home, Medications, History, Profile)
- ProfileScreen (Firestore load, initials avatar, disease badge, sign-out)
- Medication + History placeholder screens

## Current Branch
feature/homepage-dashboard

## In Progress
- None

## Pending Features (in order)
1. ~~Firebase Authentication connection~~ DONE
2. ~~Disease Selection Screen~~ DONE
3. ~~Homepage Dashboard~~ DONE
4. Health Data Logging
5. Health Trend Charts
6. Medication Reminders
7. Lifestyle Suggestion Engine
8. Emergency Alert
9. PDF Report Generation
10. Appointment Reminders
11. Onboarding Screen (last)

## Coding Rules (ALWAYS FOLLOW)
- Natural developer style comments only
- Never AI style comments
- Clean modular code
- Follow existing folder structure strictly
- Never change UI design unless asked
- Scan for errors after every file
- Tell me each file created or updated
- Build one feature at a time
- Never regenerate existing working code

## Git Branch Strategy
- main: stable working code only
- feature/xxx: one branch per feature
- Always commit before switching branches

## Important Notes
- Project folder: C:\Projects\chronic_care_app
- GitHub: github.com/Amer-Omar-Bamazrou/Nuvita
- No real patient data — dummy data only
- Target: Android only
