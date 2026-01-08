#!/bin/bash

# Script to help move google-services.json to the correct location

echo "📁 Moving Firebase Config File"
echo "==============================="
echo ""

TARGET="android/app/google-services.json"

# Check if already in place
if [ -f "$TARGET" ]; then
    echo "✅ google-services.json is already in the correct location!"
    ls -lh "$TARGET"
    exit 0
fi

# Search for the file
echo "🔍 Searching for google-services.json..."
echo ""

FOUND_FILES=$(find ~/Downloads ~/Desktop ~/Documents -name "google-services.json" -type f 2>/dev/null)

if [ -z "$FOUND_FILES" ]; then
    echo "❌ google-services.json not found in common locations"
    echo ""
    echo "Please:"
    echo "1. Make sure you downloaded the file from Firebase Console"
    echo "2. Note where you saved it"
    echo "3. Run this command manually:"
    echo "   cp /path/to/google-services.json android/app/"
    exit 1
fi

# Show found files
echo "Found the following files:"
echo "$FOUND_FILES" | nl -w2 -s'. '
echo ""

# Use the first one found
SOURCE=$(echo "$FOUND_FILES" | head -1)

echo "📋 Moving file:"
echo "   From: $SOURCE"
echo "   To:   $TARGET"
echo ""

# Create directory if it doesn't exist
mkdir -p android/app

# Copy the file
if cp "$SOURCE" "$TARGET"; then
    echo "✅ Successfully moved google-services.json to android/app/"
    echo ""
    echo "File details:"
    ls -lh "$TARGET"
    echo ""
    echo "✅ Android Firebase configuration complete!"
else
    echo "❌ Failed to copy file"
    echo "Please run manually: cp \"$SOURCE\" \"$TARGET\""
    exit 1
fi

