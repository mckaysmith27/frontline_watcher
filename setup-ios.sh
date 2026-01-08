#!/bin/bash

# iOS Setup Script for Frontline Watcher
# This script sets up everything needed to run the app on iOS simulator

set -e

echo "🚀 Setting up iOS development environment..."

# Check if CocoaPods is installed
if ! command -v pod &> /dev/null; then
    echo "📦 Installing CocoaPods..."
    sudo gem install cocoapods
else
    echo "✅ CocoaPods already installed"
    pod --version
fi

# Navigate to iOS directory
cd ios

# Install pods
echo "📥 Installing iOS dependencies (this may take a few minutes)..."
pod install

cd ..

echo ""
echo "✅ iOS setup complete!"
echo ""
echo "Next steps:"
echo "1. Open iOS Simulator: open -a Simulator"
echo "2. Run the app: flutter run -d ios"
echo ""
echo "Or use the launch script: ./launch-ios.sh"
