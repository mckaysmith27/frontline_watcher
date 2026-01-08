# Firebase Configuration Setup for Mobile Testing

## Quick Setup Instructions

Your Flutter app is already configured with Firebase options in `lib/firebase_options.dart`. However, you still need to download the platform-specific config files from Firebase Console.

## Step 1: Download Firebase Config Files

### For Android:

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project: **sub67-d4648**
3. Click the gear icon ⚙️ > **Project Settings**
4. Scroll down to **Your apps** section
5. Find your **Android app** (or click **Add app** > **Android** if you don't have one)
   - Package name should be: `com.example.sub67`
6. Click **Download google-services.json**
7. Save the file to: `android/app/google-services.json`

### For iOS:

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project: **sub67-d4648**
3. Click the gear icon ⚙️ > **Project Settings**
4. Scroll down to **Your apps** section
5. Find your **iOS app** (or click **Add app** > **iOS** if you don't have one)
   - Bundle ID should be: `com.sub67.app`
6. Click **Download GoogleService-Info.plist**
7. **Add to Xcode project**:
   - Open `ios/Runner.xcworkspace` in Xcode (NOT .xcodeproj)
   - Drag `GoogleService-Info.plist` into the `Runner` folder in Xcode
   - Make sure "Copy items if needed" is checked
   - Make sure "Runner" is selected in "Add to targets"

## Step 2: Verify Configuration

### Android:
- ✅ Google Services plugin added to `android/app/build.gradle.kts`
- ✅ Project-level plugin added to `android/build.gradle.kts`
- ⚠️  **You need to**: Place `google-services.json` in `android/app/`

### iOS:
- ✅ Firebase options configured in `lib/firebase_options.dart`
- ⚠️  **You need to**: Add `GoogleService-Info.plist` to Xcode project

## Step 3: Test the Setup

After adding the config files:

```bash
# Check available devices
flutter devices

# Run on Android
flutter run -d android

# Run on iOS
flutter run -d ios
```

## Troubleshooting

### Android Issues:

**"google-services.json not found"**
- Make sure the file is at: `android/app/google-services.json`
- Check that the package name in the file matches `com.example.sub67`

**"Plugin with id 'com.google.gms.google-services' not found"**
- The plugin is already added to the build files
- Try: `cd android && ./gradlew clean && cd ..`

### iOS Issues:

**"GoogleService-Info.plist not found"**
- Make sure you added it to the Xcode project (not just the file system)
- Open `ios/Runner.xcworkspace` (NOT .xcodeproj) in Xcode
- Verify the file appears in the Xcode project navigator

**"CocoaPods error"**
```bash
cd ios
pod install
cd ..
```

**"Signing error"**
- Open `ios/Runner.xcworkspace` in Xcode
- Select Runner project > Signing & Capabilities
- Select your Team (your Apple ID)

## Your Firebase Project Info

- **Project ID**: sub67-d4648
- **Android Package**: com.example.sub67
- **iOS Bundle ID**: com.sub67.app

## Next Steps

Once config files are in place:
1. Run `flutter devices` to see available devices
2. Connect a physical device or start an emulator/simulator
3. Run `flutter run -d <device-id>`
4. Test Firebase Authentication, Firestore, and Push Notifications

