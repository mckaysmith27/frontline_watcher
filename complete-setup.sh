#!/bin/bash

# Complete setup script - runs everything that can be automated
# For things requiring manual steps, it provides clear instructions

set -e

echo "🚀 Complete Mobile Development Setup"
echo "======================================"
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# 1. Check and setup CocoaPods
echo -e "${BLUE}1️⃣ Setting up CocoaPods...${NC}"
if command -v pod &> /dev/null; then
    echo -e "${GREEN}✅ CocoaPods already installed${NC}"
    pod --version
elif [ -f "$HOME/.gem/ruby/2.6.0/bin/pod" ]; then
    export PATH="$HOME/.gem/ruby/2.6.0/bin:$PATH"
    echo -e "${GREEN}✅ CocoaPods found in user directory${NC}"
    pod --version
else
    echo -e "${YELLOW}⚠️  CocoaPods not found${NC}"
    echo "   Installing CocoaPods (requires your password)..."
    if sudo gem install cocoapods; then
        echo -e "${GREEN}✅ CocoaPods installed${NC}"
    else
        echo -e "${RED}❌ CocoaPods installation failed${NC}"
        echo "   Please run manually: sudo gem install cocoapods"
    fi
fi

# Install iOS pods
if [ -d "ios" ]; then
    echo ""
    echo -e "${BLUE}Installing iOS dependencies...${NC}"
    cd ios
    if command -v pod &> /dev/null || [ -f "$HOME/.gem/ruby/2.6.0/bin/pod" ]; then
        export PATH="$HOME/.gem/ruby/2.6.0/bin:$PATH"
        pod install
        echo -e "${GREEN}✅ iOS dependencies installed${NC}"
    else
        echo -e "${YELLOW}⚠️  Skipping pod install - CocoaPods not available${NC}"
    fi
    cd ..
fi
echo ""

# 2. Check Xcode
echo -e "${BLUE}2️⃣ Checking Xcode...${NC}"
if [ -d "/Applications/Xcode.app" ]; then
    echo -e "${GREEN}✅ Xcode found${NC}"
    echo "   Configuring Xcode..."
    sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer 2>&1 || true
    sudo xcodebuild -license accept 2>&1 || echo "   Note: License may need manual acceptance"
    echo -e "${GREEN}✅ Xcode configured${NC}"
else
    echo -e "${YELLOW}⚠️  Xcode not installed${NC}"
    echo "   Please install from App Store:"
    echo "   1. Open App Store"
    echo "   2. Search for 'Xcode'"
    echo "   3. Click 'Get' or 'Install'"
    echo "   4. After installation, run this script again"
fi
echo ""

# 3. Check Android Studio
echo -e "${BLUE}3️⃣ Checking Android Studio...${NC}"
if [ -d "/Applications/Android Studio.app" ]; then
    echo -e "${GREEN}✅ Android Studio found${NC}"
    if [ -d "$HOME/Library/Android/sdk" ]; then
        echo -e "${GREEN}✅ Android SDK found${NC}"
        flutter config --android-sdk "$HOME/Library/Android/sdk" 2>&1 || true
        echo "   Accepting Android licenses..."
        flutter doctor --android-licenses <<< "y" 2>&1 | head -20 || echo "   Note: May need to accept licenses manually"
    else
        echo -e "${YELLOW}⚠️  Android SDK not found${NC}"
        echo "   Please complete Android Studio setup wizard"
    fi
else
    echo -e "${YELLOW}⚠️  Android Studio not installed${NC}"
    echo "   Please download and install from:"
    echo "   https://developer.android.com/studio"
    echo "   After installation, run this script again"
fi
echo ""

# 4. Flutter setup
echo -e "${BLUE}4️⃣ Verifying Flutter setup...${NC}"
flutter pub get
flutter clean
echo -e "${GREEN}✅ Flutter dependencies ready${NC}"
echo ""

# 5. Check Firebase config
echo -e "${BLUE}5️⃣ Checking Firebase configuration...${NC}"
if [ -f "android/app/google-services.json" ]; then
    echo -e "${GREEN}✅ Android Firebase config found${NC}"
else
    echo -e "${YELLOW}⚠️  android/app/google-services.json missing${NC}"
    echo "   Download from Firebase Console and place in android/app/"
fi

if [ -f "ios/Runner/GoogleService-Info.plist" ]; then
    echo -e "${GREEN}✅ iOS Firebase config found${NC}"
else
    echo -e "${YELLOW}⚠️  ios/Runner/GoogleService-Info.plist missing${NC}"
    echo "   Download from Firebase Console and add via Xcode"
fi
echo ""

# 6. Final status
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${BLUE}📋 Setup Status${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
flutter doctor
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}✅ Automated setup complete!${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Next steps:"
echo "1. Install Xcode from App Store (if not installed)"
echo "2. Install Android Studio (if not installed)"
echo "3. Download Firebase config files"
echo "4. Run: flutter devices"
echo "5. Run: flutter run -d <device-id>"

