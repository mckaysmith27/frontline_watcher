#!/bin/bash

# Script to help move GoogleService-Info.plist to iOS project

echo "📁 Moving iOS Firebase Config File"
echo "===================================="
echo ""

TARGET="ios/Runner/GoogleService-Info.plist"

# Check if already in place
if [ -f "$TARGET" ]; then
    echo "✅ GoogleService-Info.plist is already in the ios/Runner/ directory!"
    ls -lh "$TARGET"
    echo ""
    echo "Next: Add it to Xcode project (see instructions below)"
    exit 0
fi

# Search for the file
echo "🔍 Searching for GoogleService-Info.plist..."
echo ""

FOUND_FILES=$(find ~/Downloads ~/Desktop ~/Documents -name "GoogleService-Info.plist" -type f 2>/dev/null)

if [ -z "$FOUND_FILES" ]; then
    echo "❌ GoogleService-Info.plist not found in common locations"
    echo ""
    echo "Please:"
    echo "1. Make sure you downloaded the file from Firebase Console"
    echo "2. Note where you saved it"
    echo "3. Run this command manually:"
    echo "   cp /path/to/GoogleService-Info.plist ios/Runner/"
    exit 1
fi

# Show found files
echo "Found the following files:"
echo "$FOUND_FILES" | nl -w2 -s'. '
echo ""

# Use the first one found
SOURCE=$(echo "$FOUND_FILES" | head -1)

echo "📋 Copying file:"
echo "   From: $SOURCE"
echo "   To:   $TARGET"
echo ""

# Create directory if it doesn't exist
mkdir -p ios/Runner

# Copy the file
if cp "$SOURCE" "$TARGET"; then
    echo "✅ Successfully copied GoogleService-Info.plist to ios/Runner/"
    echo ""
    echo "File details:"
    ls -lh "$TARGET"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📱 NEXT STEP: Add to Xcode Project"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "1. Open Xcode:"
    echo "   open ios/Runner.xcworkspace"
    echo ""
    echo "2. In Xcode:"
    echo "   - Find 'Runner' folder in the left sidebar (Project Navigator)"
    echo "   - Right-click on 'Runner' folder"
    echo "   - Select 'Add Files to "Runner"...'"
    echo "   - Navigate to: ios/Runner/GoogleService-Info.plist"
    echo "   - IMPORTANT: Check 'Copy items if needed'"
    echo "   - Make sure 'Runner' is checked in 'Add to targets'"
    echo "   - Click 'Add'"
    echo ""
    echo "3. Verify:"
    echo "   - The file should appear in the Runner folder in Xcode"
    echo "   - It should be blue (not red) in the file list"
    echo ""
    echo "✅ After adding to Xcode, your iOS Firebase config is complete!"
else
    echo "❌ Failed to copy file"
    echo "Please run manually: cp \"$SOURCE\" \"$TARGET\""
    exit 1
fi

