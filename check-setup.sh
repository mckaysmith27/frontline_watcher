#!/bin/bash

# Comprehensive setup checker - verifies everything is ready

echo "🔍 Checking Mobile Development Setup"
echo "====================================="
echo ""

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

ALL_GOOD=true

# 1. Flutter
echo -e "${BLUE}1️⃣ Flutter${NC}"
if command -v flutter &> /dev/null; then
    echo -e "${GREEN}✅ Flutter installed${NC}"
    flutter --version | head -1
else
    echo -e "${RED}❌ Flutter not found${NC}"
    ALL_GOOD=false
fi
echo ""

# 2. Android Studio
echo -e "${BLUE}2️⃣ Android Studio${NC}"
if [ -d "/Applications/Android Studio.app" ]; then
    echo -e "${GREEN}✅ Android Studio installed${NC}"
    if [ -d "$HOME/Library/Android/sdk" ]; then
        echo -e "${GREEN}✅ Android SDK found${NC}"
    else
        echo -e "${YELLOW}⚠️  Android SDK not found - complete Android Studio setup${NC}"
    fi
else
    echo -e "${RED}❌ Android Studio not installed${NC}"
    ALL_GOOD=false
fi
echo ""

# 3. Xcode
echo -e "${BLUE}3️⃣ Xcode${NC}"
if [ -d "/Applications/Xcode.app" ]; then
    echo -e "${GREEN}✅ Xcode installed${NC}"
    if xcode-select -p &> /dev/null; then
        echo -e "${GREEN}✅ Xcode command line tools configured${NC}"
    else
        echo -e "${YELLOW}⚠️  Xcode CLI tools not configured${NC}"
    fi
else
    echo -e "${RED}❌ Xcode not installed${NC}"
    ALL_GOOD=false
fi
echo ""

# 4. CocoaPods
echo -e "${BLUE}4️⃣ CocoaPods${NC}"
if command -v pod &> /dev/null; then
    echo -e "${GREEN}✅ CocoaPods installed${NC}"
    pod --version
else
    echo -e "${RED}❌ CocoaPods not installed${NC}"
    echo "   Run: sudo gem install cocoapods"
    ALL_GOOD=false
fi
echo ""

# 5. iOS Dependencies
echo -e "${BLUE}5️⃣ iOS Dependencies${NC}"
if [ -d "ios/Pods" ]; then
    echo -e "${GREEN}✅ iOS Pods installed${NC}"
else
    echo -e "${YELLOW}⚠️  iOS Pods not installed${NC}"
    echo "   Run: cd ios && pod install && cd .."
fi
echo ""

# 6. Firebase Config Files
echo -e "${BLUE}6️⃣ Firebase Configuration${NC}"
if [ -f "android/app/google-services.json" ]; then
    echo -e "${GREEN}✅ Android Firebase config found${NC}"
else
    echo -e "${RED}❌ android/app/google-services.json missing${NC}"
    ALL_GOOD=false
fi

if [ -f "ios/Runner/GoogleService-Info.plist" ]; then
    echo -e "${GREEN}✅ iOS Firebase config found${NC}"
else
    echo -e "${RED}❌ ios/Runner/GoogleService-Info.plist missing${NC}"
    ALL_GOOD=false
fi
echo ""

# 7. Flutter Dependencies
echo -e "${BLUE}7️⃣ Flutter Dependencies${NC}"
if [ -d ".dart_tool" ] && [ -f "pubspec.lock" ]; then
    echo -e "${GREEN}✅ Flutter dependencies installed${NC}"
else
    echo -e "${YELLOW}⚠️  Flutter dependencies may need updating${NC}"
    echo "   Run: flutter pub get"
fi
echo ""

# 8. Available Devices
echo -e "${BLUE}8️⃣ Available Devices${NC}"
DEVICES=$(flutter devices 2>/dev/null | grep -E "(android|ios|chrome)" | wc -l)
if [ "$DEVICES" -gt 0 ]; then
    echo -e "${GREEN}✅ Devices available${NC}"
    flutter devices 2>/dev/null | grep -E "(android|ios|chrome)" || true
else
    echo -e "${YELLOW}⚠️  No devices found${NC}"
    echo "   Connect a device or start an emulator/simulator"
fi
echo ""

# 9. Project Structure
echo -e "${BLUE}9️⃣ Project Structure${NC}"
if [ -d "android" ] && [ -d "ios" ] && [ -d "lib" ]; then
    echo -e "${GREEN}✅ Project structure complete${NC}"
else
    echo -e "${RED}❌ Project structure incomplete${NC}"
    ALL_GOOD=false
fi
echo ""

# Final Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ "$ALL_GOOD" = true ]; then
    echo -e "${GREEN}✅ Setup looks good!${NC}"
    echo ""
    echo "You can now:"
    echo "  - Run: flutter devices"
    echo "  - Run: flutter run -d <device-id>"
    echo "  - Or use: ./launch-android.sh or ./launch-ios.sh"
else
    echo -e "${YELLOW}⚠️  Some setup steps are incomplete${NC}"
    echo ""
    echo "Please complete the missing items above, then run this script again."
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

