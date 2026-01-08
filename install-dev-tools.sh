#!/bin/bash

# Automated installation script for Android and iOS development tools
# This script attempts to install what can be automated

set -e

echo "🔧 Installing Development Tools for Flutter Mobile Testing"
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo -e "${RED}❌ This script is for macOS only${NC}"
    exit 1
fi

# 1. Install CocoaPods
echo "1️⃣ Installing CocoaPods..."
if command -v pod &> /dev/null; then
    echo -e "${GREEN}✅ CocoaPods already installed${NC}"
    pod --version
else
    echo "Installing CocoaPods..."
    if sudo gem install cocoapods; then
        echo -e "${GREEN}✅ CocoaPods installed successfully${NC}"
    else
        echo -e "${YELLOW}⚠️  CocoaPods installation failed. You may need to run: sudo gem install cocoapods${NC}"
    fi
fi
echo ""

# 2. Install iOS dependencies
echo "2️⃣ Installing iOS CocoaPods dependencies..."
if [ -d "ios" ]; then
    cd ios
    if pod install; then
        echo -e "${GREEN}✅ iOS dependencies installed${NC}"
    else
        echo -e "${YELLOW}⚠️  iOS pod install failed. Make sure CocoaPods is installed.${NC}"
    fi
    cd ..
else
    echo -e "${YELLOW}⚠️  ios/ directory not found${NC}"
fi
echo ""

# 3. Check Xcode Command Line Tools
echo "3️⃣ Checking Xcode Command Line Tools..."
if xcode-select -p &> /dev/null; then
    echo -e "${GREEN}✅ Xcode Command Line Tools installed${NC}"
    xcode-select -p
else
    echo -e "${YELLOW}⚠️  Xcode Command Line Tools not installed${NC}"
    echo "   Attempting to install..."
    if xcode-select --install 2>&1 | grep -q "already installed"; then
        echo -e "${GREEN}✅ Xcode Command Line Tools already installed${NC}"
    else
        echo -e "${YELLOW}⚠️  Please install Xcode Command Line Tools manually:${NC}"
        echo "   Run: xcode-select --install"
        echo "   Or install Xcode from the App Store"
    fi
fi
echo ""

# 4. Check for Android SDK
echo "4️⃣ Checking for Android SDK..."
ANDROID_SDK_FOUND=false

if [ -d "$HOME/Library/Android/sdk" ]; then
    ANDROID_SDK="$HOME/Library/Android/sdk"
    ANDROID_SDK_FOUND=true
elif [ -d "$HOME/Android/Sdk" ]; then
    ANDROID_SDK="$HOME/Android/Sdk"
    ANDROID_SDK_FOUND=true
fi

if [ "$ANDROID_SDK_FOUND" = true ]; then
    echo -e "${GREEN}✅ Android SDK found at: $ANDROID_SDK${NC}"
    flutter config --android-sdk "$ANDROID_SDK" 2>&1 || true
else
    echo -e "${YELLOW}⚠️  Android SDK not found${NC}"
    echo "   Please install Android Studio from: https://developer.android.com/studio"
    echo "   Android Studio will install the Android SDK automatically"
fi
echo ""

# 5. Accept Android licenses (if SDK is found)
if [ "$ANDROID_SDK_FOUND" = true ]; then
    echo "5️⃣ Accepting Android licenses..."
    if flutter doctor --android-licenses 2>&1 | grep -q "All SDK package licenses accepted"; then
        echo -e "${GREEN}✅ Android licenses accepted${NC}"
    else
        echo -e "${YELLOW}⚠️  Android licenses may need to be accepted${NC}"
        echo "   Run: flutter doctor --android-licenses"
    fi
    echo ""
fi

# 6. Flutter setup
echo "6️⃣ Verifying Flutter setup..."
flutter pub get
flutter clean
echo ""

# 7. Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 Installation Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

flutter doctor

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📝 Next Steps (Manual Installation Required):"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if ! command -v pod &> /dev/null; then
    echo "❌ CocoaPods: sudo gem install cocoapods"
fi

if ! xcode-select -p &> /dev/null; then
    echo "❌ Xcode: Install from Mac App Store, then run: xcode-select --install"
fi

if [ "$ANDROID_SDK_FOUND" = false ]; then
    echo "❌ Android Studio: Download from https://developer.android.com/studio"
    echo "   After installation, Android SDK will be automatically installed"
fi

echo ""
echo "📱 Firebase Config Files (Download from Firebase Console):"
echo "   - android/app/google-services.json"
echo "   - ios/Runner/GoogleService-Info.plist (add via Xcode)"
echo ""

echo "✅ Automated setup complete!"
echo "   Run 'flutter devices' to see available devices"
echo "   Run 'flutter run -d <device-id>' to test"

