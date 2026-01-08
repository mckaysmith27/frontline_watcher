# Quick Install Guide - What You Need to Do

## ✅ What's Already Done Automatically

1. ✅ Flutter project configured for Android and iOS
2. ✅ Google Services plugin added to Android
3. ✅ Flutter dependencies installed
4. ✅ Xcode Command Line Tools detected
5. ✅ Project structure ready

## 🔧 What You Need to Install Manually

### 1. Install CocoaPods (for iOS) - REQUIRES YOUR PASSWORD

Open Terminal and run:
```bash
sudo gem install cocoapods
```

Then install iOS dependencies:
```bash
cd /Users/mckay/Sub67/frontline_watcher/ios
pod install
cd ..
```

### 2. Install Xcode (for iOS) - REQUIRES APP STORE

1. Open **App Store** on your Mac
2. Search for **"Xcode"**
3. Click **"Get"** or **"Install"** (it's free but large ~15GB)
4. After installation, open Xcode once to complete setup
5. Accept the license:
   ```bash
   sudo xcodebuild -license accept
   ```
6. Set Xcode path:
   ```bash
   sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
   ```

### 3. Install Android Studio (for Android) - REQUIRES DOWNLOAD

1. Download from: https://developer.android.com/studio
2. Install the .dmg file
3. Open Android Studio
4. Complete the setup wizard (it will install Android SDK automatically)
5. Accept Android licenses:
   ```bash
   flutter doctor --android-licenses
   ```
   (Press 'y' for each license)

### 4. Download Firebase Config Files - REQUIRES FIREBASE CONSOLE ACCESS

#### Android:
1. Go to: https://console.firebase.google.com
2. Select project: **sub67-d4648**
3. Project Settings > Your apps > Android app
4. Download `google-services.json`
5. Place at: `android/app/google-services.json`

#### iOS:
1. Go to: https://console.firebase.google.com
2. Select project: **sub67-d4648**
3. Project Settings > Your apps > iOS app
4. Download `GoogleService-Info.plist`
5. Open `ios/Runner.xcworkspace` in Xcode
6. Drag the file into the Runner folder

## 🚀 Quick Start Commands

After installing everything above:

```bash
# Check your setup
flutter doctor

# See available devices
flutter devices

# Run on Android
flutter run -d android

# Run on iOS
flutter run -d ios
```

## 📋 Installation Checklist

- [ ] Install CocoaPods: `sudo gem install cocoapods`
- [ ] Install iOS pods: `cd ios && pod install && cd ..`
- [ ] Install Xcode from App Store
- [ ] Complete Xcode first-time setup
- [ ] Accept Xcode license: `sudo xcodebuild -license accept`
- [ ] Install Android Studio
- [ ] Complete Android Studio setup wizard
- [ ] Accept Android licenses: `flutter doctor --android-licenses`
- [ ] Download `google-services.json` from Firebase
- [ ] Download `GoogleService-Info.plist` from Firebase
- [ ] Configure iOS signing in Xcode
- [ ] Run `flutter doctor` to verify everything
- [ ] Run `flutter devices` to see available devices

## ⚡ Fastest Path to Testing

**For iOS (if you have an iPhone/iPad):**
1. Install CocoaPods: `sudo gem install cocoapods && cd ios && pod install && cd ..`
2. Install Xcode from App Store
3. Download Firebase iOS config
4. Connect your device and run: `flutter run -d ios`

**For Android (if you have an Android device):**
1. Install Android Studio
2. Enable USB debugging on your device
3. Download Firebase Android config
4. Connect your device and run: `flutter run -d android`

## 🆘 Need Help?

- See `MOBILE_SETUP_COMPLETE.md` for detailed instructions
- See `FIREBASE_CONFIG_SETUP.md` for Firebase setup
- See `TESTING_GUIDE.md` for comprehensive testing guide

