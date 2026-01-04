# Flutter App Setup Guide

This guide explains how to run the Flutter mobile/web app **separately** from the Python scraping script.

## Architecture Overview

```
┌─────────────────┐         ┌──────────────┐         ┌─────────────────┐
│   Flutter App   │  ←→     │ Backend API  │  ←→     │ Python Script   │
│  (iOS/Android/  │         │  (Future)    │         │ (frontline_     │
│     Web)        │         │              │         │  watcher.py)    │
└─────────────────┘         └──────────────┘         └─────────────────┘
       ↓                            ↓                          ↓
  Firebase Auth              Firestore DB              ESS Website
  Firestore
  Storage
```

**Important**: The Flutter app and Python script are **completely separate**:
- **Flutter App**: User interface for managing filters, viewing jobs, social features
- **Python Script**: Runs independently, scrapes ESS website, accepts jobs based on filters

## Step 1: Install Flutter

### macOS Installation

1. **Download Flutter SDK**:
   ```bash
   # Option A: Using Homebrew (recommended)
   brew install --cask flutter
   
   # Option B: Manual download
   # Visit https://flutter.dev/docs/get-started/install/macos
   # Download and extract Flutter SDK
   ```

2. **Verify Installation**:
   ```bash
   flutter doctor
   ```
   This will check your setup and show what needs to be configured.

3. **Install Xcode** (for iOS development):
   ```bash
   # Install from App Store, then:
   sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
   sudo xcodebuild -runFirstLaunch
   ```

4. **Install Android Studio** (for Android development):
   - Download from https://developer.android.com/studio
   - Install Android SDK and create an emulator

5. **Accept Android Licenses**:
   ```bash
   flutter doctor --android-licenses
   ```

## Step 2: Install Flutter Dependencies

Navigate to your project directory and install dependencies:

```bash
cd /Users/mckay/Sub67/frontline_watcher
flutter pub get
```

This will download all packages listed in `pubspec.yaml`.

## Step 3: Firebase Setup (Required)

The app uses Firebase for authentication, database, and storage. You have two options:

### Option A: Set Up Firebase (Full Functionality)

1. **Create Firebase Project**:
   - Go to https://console.firebase.google.com
   - Click "Add project"
   - Follow the setup wizard

2. **Enable Services**:
   - **Authentication**: Enable Email/Password sign-in
   - **Firestore Database**: Create database in test mode
   - **Storage**: Enable Firebase Storage

3. **Add Firebase to Your App**:
   
   **For iOS**:
   - Download `GoogleService-Info.plist` from Firebase Console
   - Place it in `ios/Runner/GoogleService-Info.plist`
   
   **For Android**:
   - Download `google-services.json` from Firebase Console
   - Place it in `android/app/google-services.json`
   
   **For Web**:
   - Follow Firebase web setup instructions
   - Add Firebase config to `web/index.html`

4. **Update Firebase Configuration**:
   - The app will automatically use the config files you added

### Option B: Run Without Firebase (Limited Functionality)

If you want to test the UI without Firebase, you'll need to modify the code to skip Firebase initialization. This is not recommended for production.

## Step 4: Run the Flutter App

### Check Available Devices

```bash
flutter devices
```

This shows all available devices/emulators.

### Run on Different Platforms

**iOS Simulator** (macOS only):
```bash
# Open iOS Simulator first, then:
flutter run -d ios
```

**Android Emulator**:
```bash
# Start Android emulator first, then:
flutter run -d android
```

**Chrome (Web)**:
```bash
flutter run -d chrome
```

**Physical Device**:
```bash
# Connect device via USB, enable developer mode, then:
flutter run
```

### Development Mode

The app runs in debug mode by default. You'll see:
- Hot reload (press `r` in terminal)
- Hot restart (press `R` in terminal)
- Debug console output

## Step 5: Understanding the App Structure

### Main Screens

1. **Login Screen** (`lib/screens/auth/login_screen.dart`)
   - User authentication
   - Requires Firebase Auth

2. **Filters Screen** (`lib/screens/filters/filters_screen.dart`)
   - Configure job filters
   - Set included/excluded keywords
   - Premium features

3. **Schedule Screen** (`lib/screens/schedule/schedule_screen.dart`)
   - View scheduled jobs
   - Calendar view
   - Credit management

4. **Social Screen** (`lib/screens/social/social_screen.dart`)
   - Social feed
   - Posts and engagement

5. **Profile Screen** (`lib/screens/profile/profile_screen.dart`)
   - User settings
   - Account management

### State Management

The app uses **Provider** for state management:
- `AuthProvider`: User authentication state
- `FiltersProvider`: Job filter configuration
- `CreditsProvider`: Credit balance and packages
- `ThemeProvider`: Dark/light mode

## Step 6: Running Python Script Separately

The Python script (`frontline_watcher.py`) runs **independently** from the Flutter app:

```bash
# Activate virtual environment
source .venv/bin/activate

# Run the script
python frontline_watcher.py
```

The script:
- Reads configuration from `.env` file
- Scrapes ESS website
- Applies filters
- Auto-accepts jobs (if enabled)
- Sends notifications via NTFY

## Current State: App vs Script

**Right Now**:
- ✅ Python script works independently with `.env` file
- ✅ Flutter app exists but needs Firebase setup
- ❌ No backend API connecting them yet

**Future Integration** (per `BACKEND_INTEGRATION.md`):
- Backend API will connect Flutter app → Python script
- App will send filter config to API
- API will start/stop Python script with user's filters
- Script will report back to API/Firestore

## Troubleshooting

### Flutter Not Found
```bash
# Add Flutter to PATH (if installed manually)
export PATH="$PATH:[PATH_TO_FLUTTER]/bin"
```

### Firebase Errors
- Ensure `google-services.json` / `GoogleService-Info.plist` are in correct locations
- Check Firebase project settings match your app bundle ID
- Verify Firebase services are enabled in console

### Build Errors
```bash
# Clean and rebuild
flutter clean
flutter pub get
flutter run
```

### iOS Build Issues
```bash
# Install CocoaPods dependencies
cd ios
pod install
cd ..
flutter run
```

## Next Steps

1. **Set up Firebase** (if you want full functionality)
2. **Run the app** on your preferred platform
3. **Test the UI** and features
4. **Build backend API** (see `BACKEND_INTEGRATION.md`) to connect app and script
5. **Deploy** when ready

## Quick Start Commands

```bash
# Install dependencies
flutter pub get

# Check setup
flutter doctor

# Run on web (easiest to start)
flutter run -d chrome

# Run on iOS
flutter run -d ios

# Run on Android
flutter run -d android
```

---

**Note**: The Flutter app and Python script are designed to work together through a backend API, but can be developed and tested independently. The Python script can run standalone with the `.env` file, while the Flutter app provides the user interface for managing filters and viewing results.

