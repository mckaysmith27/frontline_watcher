#!/bin/bash

# Quick launch script for iOS

echo "📱 Launching on iOS..."
echo ""

# Check if device is connected
DEVICES=$(flutter devices | grep -i ios)

if [ -z "$DEVICES" ]; then
    echo "⚠️  No iOS device found!"
    echo ""
    echo "Options:"
    echo "1. Connect a physical iOS device via USB"
    echo "2. Start an iOS simulator from Xcode"
    echo ""
    echo "Then run: flutter devices"
    exit 1
fi

# Launch the app
flutter run -d ios

