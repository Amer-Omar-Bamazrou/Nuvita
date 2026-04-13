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
- Firebase Authentication enabled
- Firestore database created

## Current Branch
feature/firebase-authentication

## In Progress
- Connecting login/register to real Firebase Auth

## Pending Features (in order)
1. Firebase Authentication connection
2. Disease Selection Screen
3. Homepage Dashboard
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
