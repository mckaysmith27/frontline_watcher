#!/bin/bash

# Script to help configure Xcode capabilities
# Run this after opening ios/Runner.xcworkspace in Xcode

echo "📱 Xcode Capabilities Setup Guide"
echo "=================================="
echo ""
echo "After opening ios/Runner.xcworkspace in Xcode:"
echo ""
echo "1. Select 'Runner' project in left sidebar"
echo "2. Select 'Runner' target"
echo "3. Go to 'Signing & Capabilities' tab"
echo "4. Click '+ Capability' and add:"
echo "   ✅ Push Notifications"
echo "   ✅ Background Modes (check 'Remote notifications')"
echo ""
echo "5. In 'Signing & Capabilities':"
echo "   - Check 'Automatically manage signing'"
echo "   - Select your Team (Apple ID)"
echo ""
echo "6. Add GoogleService-Info.plist:"
echo "   - Download from Firebase Console"
echo "   - Drag into Runner folder in Xcode"
echo "   - Make sure 'Copy items if needed' is checked"
echo ""
echo "✅ Done! Your iOS app is configured."

