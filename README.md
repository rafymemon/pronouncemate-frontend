# PronounceMate — Flutter App
AI-Powered Pronunciation Detection & Improvement System
FYP 2025 | Mehran University | Batch 22SW | Group 04

---

## COLOR THEME (from Figma)
- Background:  Light Cyan  #CFE BEE / #D6EFF2
- Buttons:     Olive Green #8A9A2C  (pill-shaped)
- Cards:       White #FFFFFF with soft cyan shadow
- Accent:      Teal #4AABBA
- Text:        Dark #1A2A2A

---

## FILE STRUCTURE
lib/
├── main.dart
├── theme/app_theme.dart
├── widgets/common_widgets.dart
└── screens/
    ├── login_screen.dart
    ├── signup_screen.dart
    ├── main_shell.dart
    ├── home_screen.dart
    ├── practice_mode_screen.dart
    ├── dashboard_screen.dart
    └── profile_screen.dart

---

## HOW TO RUN (Step by Step)

### Step 1 — Create fresh Flutter project
  flutter create pronouncemate
  cd pronouncemate

### Step 2 — Delete default lib folder
  Delete everything inside the lib/ folder

### Step 3 — Copy files
  Copy all .dart files from this zip into your lib/ folder
  keeping the same folder structure (screens/, theme/, widgets/)

### Step 4 — Replace pubspec.yaml
  Copy the pubspec.yaml from this zip into your project root

### Step 5 — Get packages
  flutter pub get

### Step 6 — Run
  flutter run

---

## EMULATOR TROUBLESHOOTING

### Problem 1: "No devices found"
  Solution: Open Android Studio → Device Manager → Start an emulator
  OR run: flutter emulators --launch <emulator_id>
  Check available emulators: flutter emulators

### Problem 2: "Sdk location not found"
  Solution: Open Android Studio → SDK Manager
  Note the SDK path and create local.properties:
  echo "sdk.dir=/Users/YourName/Library/Android/sdk" > android/local.properties

### Problem 3: "minSdkVersion" error
  Solution: Open android/app/build.gradle and set:
  minSdkVersion 21

### Problem 4: Gradle build fails
  Solution:
  cd android
  ./gradlew clean
  cd ..
  flutter run

### Problem 5: "flutter: command not found"
  Solution: Add Flutter to PATH in your terminal config file (.bashrc or .zshrc):
  export PATH="$PATH:/path/to/flutter/bin"

### Problem 6: "Could not find a file named pubspec.yaml"
  You are in the wrong folder. cd into the project root first.

### Quick diagnostic — run these and share output if still stuck:
  flutter doctor
  flutter devices

---

## SCREENS INCLUDED
- Login: Sign In card (Figma style), cyan blobs background, olive LOG IN button
- Signup: CREATE ACCOUNT card, level selector pills
- Home: greeting, goal banner, stat grid, mode cards, recent sessions
- Practice Tab: mode hub with big cards
- Practice Mode: level picker, script list, active session with live feedback
- Dashboard: bar chart, accuracy by mode, recurring mistakes, history
- Profile: user card, settings toggles, logout with confirm dialog
