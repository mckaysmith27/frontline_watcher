# Testing on Android and iOS

This guide will help you test your Flutter app on Android and iOS devices.

## Prerequisites

### For Android:
1. **Android Studio** installed
2. **Android SDK** installed (comes with Android Studio)
3. **Physical Android device** OR **Android Emulator**
4. **USB Debugging** enabled on physical device (Settings > Developer Options > USB Debugging)

### For iOS:
1. **Xcode** installed (from Mac App Store)
2. **Xcode Command Line Tools**: `xcode-select --install`
3. **Physical iOS device** OR **iOS Simulator**
4. **Apple Developer Account** (free account works for testing on your own device)
5. **CocoaPods** installed: `sudo gem install cocoapods`

## Step 1: Check Flutter Setup

Run these commands in your terminal:

```bash
cd /Users/mckay/Sub67/frontline_watcher
flutter doctor
flutter devices
```

`flutter doctor` will show what's installed and what's missing.
`flutter devices` will list available devices/emulators.

## Step 2: Setup Android

### Option A: Physical Android Device

1. **Enable Developer Options** on your Android device:
   - Go to Settings > About Phone
   - Tap "Build Number" 7 times
   - Go back to Settings > Developer Options
   - Enable "USB Debugging"

2. **Connect device via USB** and accept the debugging prompt

3. **Verify device is detected**:
   ```bash
   flutter devices
   ```
   You should see your device listed.

### Option B: Android Emulator

1. **Open Android Studio**
2. **Open AVD Manager** (Tools > Device Manager)
3. **Create Virtual Device** (if you don't have one):
   - Click "Create Device"
   - Choose a device (e.g., Pixel 5)
   - Choose a system image (e.g., Android 13)
   - Finish setup
4. **Start the emulator** from AVD Manager
5. **Verify it's detected**:
   ```bash
   flutter devices
   ```

## Step 3: Setup iOS

### Option A: Physical iOS Device

1. **Connect your iPhone/iPad via USB**

2. **Trust the computer** on your device (if prompted)

3. **Open Xcode** and accept license if needed:
   ```bash
   sudo xcodebuild -license accept
   ```

4. **Configure signing**:
   ```bash
   cd ios
   pod install
   cd ..
   ```
   
   Then open `ios/Runner.xcworkspace` in Xcode:
   - Select your device in the device dropdown
   - Go to "Signing & Capabilities"
   - Select your Team (your Apple ID)
   - Xcode will automatically create a provisioning profile

5. **Verify device is detected**:
   ```bash
   flutter devices
   ```

### Option B: iOS Simulator

1. **Open Xcode**
2. **Open Simulator**: Xcode > Open Developer Tool > Simulator
3. **Create/Start a simulator**:
   - File > New Simulator
   - Choose device (e.g., iPhone 14)
   - Choose iOS version
   - Click Create
4. **Verify it's detected**:
   ```bash
   flutter devices
   ```

## Step 4: Run the App

### For Android:

```bash
# List available devices
flutter devices

# Run on specific device (replace DEVICE_ID with actual ID from flutter devices)
flutter run -d DEVICE_ID

# Or run on first available Android device
flutter run -d android
```

### For iOS:

```bash
# List available devices
flutter devices

# Run on specific device (replace DEVICE_ID with actual ID from flutter devices)
flutter run -d DEVICE_ID

# Or run on first available iOS device
flutter run -d ios
```

## Step 5: Firebase Configuration

### Android Firebase Setup

1. **Download `google-services.json`** from Firebase Console:
   - Go to Firebase Console > Project Settings
   - Under "Your apps", select Android app
   - Download `google-services.json`

2. **Place the file**:
   ```bash
   # Copy the file to android/app/
   cp ~/Downloads/google-services.json android/app/
   ```

3. **Verify** `android/app/build.gradle` has:
   ```gradle
   apply plugin: 'com.google.gms.google-services'
   ```

### iOS Firebase Setup

1. **Download `GoogleService-Info.plist`** from Firebase Console:
   - Go to Firebase Console > Project Settings
   - Under "Your apps", select iOS app
   - Download `GoogleService-Info.plist`

2. **Add to Xcode**:
   - Open `ios/Runner.xcworkspace` in Xcode
   - Drag `GoogleService-Info.plist` into the `Runner` folder in Xcode
   - Make sure "Copy items if needed" is checked
   - Make sure it's added to the target

## Common Issues & Solutions

### Android Issues:

**Issue**: "SDK location not found"
```bash
# Set Android SDK location
export ANDROID_HOME=$HOME/Library/Android/sdk
export PATH=$PATH:$ANDROID_HOME/tools
export PATH=$PATH:$ANDROID_HOME/platform-tools
```

**Issue**: "Gradle build failed"
```bash
cd android
./gradlew clean
cd ..
flutter clean
flutter pub get
```

### iOS Issues:

**Issue**: "CocoaPods not installed"
```bash
sudo gem install cocoapods
cd ios
pod install
cd ..
```

**Issue**: "Signing for Runner requires a development team"
- Open `ios/Runner.xcworkspace` in Xcode
- Select Runner project > Signing & Capabilities
- Select your Team (your Apple ID)

**Issue**: "No devices found"
- Make sure device is unlocked
- For physical device: Trust the computer on device
- For simulator: Make sure it's running

### General Issues:

**Issue**: "Firebase not initialized"
- Make sure `google-services.json` (Android) or `GoogleService-Info.plist` (iOS) is in the correct location
- Make sure Firebase is properly configured in `lib/main.dart`

**Issue**: "Build fails"
```bash
flutter clean
flutter pub get
# For Android
cd android && ./gradlew clean && cd ..
# For iOS
cd ios && pod install && cd ..
```

## Testing Checklist

- [ ] App launches successfully
- [ ] Firebase Authentication works (login/signup)
- [ ] Firestore reads/writes work
- [ ] Push notifications work (FCM)
- [ ] Calendar sync works (add_2_calendar)
- [ ] WebView for job acceptance works
- [ ] All screens navigate correctly
- [ ] Filters save and load correctly
- [ ] Credits system works
- [ ] Social features work (posts, comments, voting)

## Debugging Tips

1. **View logs**:
   ```bash
   flutter run -d DEVICE_ID
   # Logs will appear in terminal
   ```

2. **Hot reload**: Press `r` in terminal while app is running

3. **Hot restart**: Press `R` in terminal while app is running

4. **Open DevTools**:
   ```bash
   flutter pub global activate devtools
   flutter pub global run devtools
   ```

5. **Check Firebase Console** for real-time database activity

## Next Steps

Once testing is complete:
1. Fix any issues found
2. Test on multiple devices if possible
3. Test on different Android/iOS versions
4. Prepare for app store submission (if needed)
