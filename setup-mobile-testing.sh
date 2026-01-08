#!/bin/bash

# Setup script for Android and iOS testing
# This script helps configure Firebase and prepare the project for mobile testing

set -e

echo "📱 Setting up Flutter app for Android and iOS testing..."
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check Flutter installation
echo "1️⃣ Checking Flutter installation..."
if ! command -v flutter &> /dev/null; then
    echo -e "${RED}❌ Flutter is not installed or not in PATH${NC}"
    echo "Please install Flutter from: https://flutter.dev/docs/get-started/install"
    exit 1
fi

flutter --version
echo ""

# Check Flutter doctor
echo "2️⃣ Running Flutter doctor..."
flutter doctor
echo ""

# Get dependencies
echo "3️⃣ Getting Flutter dependencies..."
flutter pub get
echo ""

# Check if Android directory exists
if [ ! -d "android" ]; then
    echo "4️⃣ Creating Android platform files..."
    flutter create --platforms=android .
    echo ""
fi

# Check if iOS directory exists
if [ ! -d "ios" ]; then
    echo "5️⃣ Creating iOS platform files..."
    flutter create --platforms=ios .
    echo ""
fi

# Check for Firebase config files
echo "6️⃣ Checking Firebase configuration..."

# Android Firebase config
if [ ! -f "android/app/google-services.json" ]; then
    echo -e "${YELLOW}⚠️  android/app/google-services.json is missing${NC}"
    echo "   Please download it from Firebase Console:"
    echo "   1. Go to https://console.firebase.google.com"
    echo "   2. Select your project"
    echo "   3. Go to Project Settings > Your apps"
    echo "   4. Click on Android app (or add one if needed)"
    echo "   5. Download google-services.json"
    echo "   6. Place it in: android/app/google-services.json"
    echo ""
else
    echo -e "${GREEN}✅ android/app/google-services.json found${NC}"
fi

# iOS Firebase config
if [ ! -f "ios/Runner/GoogleService-Info.plist" ]; then
    echo -e "${YELLOW}⚠️  ios/Runner/GoogleService-Info.plist is missing${NC}"
    echo "   Please download it from Firebase Console:"
    echo "   1. Go to https://console.firebase.google.com"
    echo "   2. Select your project"
    echo "   3. Go to Project Settings > Your apps"
    echo "   4. Click on iOS app (or add one if needed)"
    echo "   5. Download GoogleService-Info.plist"
    echo "   6. Add it to Xcode project (see TESTING_GUIDE.md)"
    echo ""
else
    echo -e "${GREEN}✅ ios/Runner/GoogleService-Info.plist found${NC}"
fi

# Setup Android
echo "7️⃣ Setting up Android..."
if [ -d "android" ]; then
    # Check if google-services plugin is in build.gradle
    if ! grep -q "com.google.gms.google-services" android/app/build.gradle 2>/dev/null; then
        echo -e "${YELLOW}⚠️  Need to add Google Services plugin to android/app/build.gradle${NC}"
        echo "   Add this line at the bottom of android/app/build.gradle:"
        echo "   apply plugin: 'com.google.gms.google-services'"
        echo ""
    else
        echo -e "${GREEN}✅ Android Google Services plugin configured${NC}"
    fi
fi

# Setup iOS
echo "8️⃣ Setting up iOS..."
if [ -d "ios" ]; then
    if command -v pod &> /dev/null; then
        echo "   Installing CocoaPods dependencies..."
        cd ios
        pod install
        cd ..
        echo -e "${GREEN}✅ iOS CocoaPods dependencies installed${NC}"
    else
        echo -e "${YELLOW}⚠️  CocoaPods not installed${NC}"
        echo "   Install with: sudo gem install cocoapods"
        echo ""
    fi
fi

# Check available devices
echo "9️⃣ Checking available devices..."
flutter devices
echo ""

echo -e "${GREEN}✅ Setup complete!${NC}"
echo ""
echo "Next steps:"
echo "1. Download Firebase config files if missing (see warnings above)"
echo "2. For iOS: Open ios/Runner.xcworkspace in Xcode and configure signing"
echo "3. Run: flutter run -d <device-id>"
echo ""
echo "For detailed instructions, see TESTING_GUIDE.md"

