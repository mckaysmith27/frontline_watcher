#!/bin/bash

# Quick launch script for Android

echo "📱 Launching on Android..."
echo ""

# Check if device is connected
DEVICES=$(flutter devices | grep -i android)

if [ -z "$DEVICES" ]; then
    echo "⚠️  No Android device found!"
    echo ""
    echo "Options:"
    echo "1. Connect a physical Android device via USB"
    echo "2. Start an Android emulator from Android Studio"
    echo ""
    echo "Then run: flutter devices"
    exit 1
fi

# Launch the app
flutter run -d android

