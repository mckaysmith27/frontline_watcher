#!/bin/bash
# Deploy Cloud Functions Dispatcher
# Run: ./deploy-functions.sh

set -e

echo "🚀 Deploying Cloud Functions Dispatcher"
echo ""

# Check if Firebase CLI is installed
if ! command -v firebase &> /dev/null; then
    echo "❌ Firebase CLI not found. Install with:"
    echo "   npm install -g firebase-tools"
    exit 1
fi

# Check if functions directory exists
if [ ! -d "functions" ]; then
    echo "❌ functions/ directory not found"
    exit 1
fi

# Install dependencies
echo "📦 Installing dependencies..."
cd functions
npm install

# Deploy functions
echo ""
echo "🔧 Deploying Cloud Functions..."
cd ..

# Check if firebase.json exists and has functions config
if ! grep -q '"functions"' firebase.json 2>/dev/null; then
    echo "⚠️  firebase.json missing functions config, creating it..."
    cat > firebase.json << 'EOF'
{
  "functions": {
    "source": "functions"
  }
}
EOF
fi

firebase deploy --only functions --project sub67-d4648

echo ""
echo "✅ Cloud Functions deployed!"
echo ""
echo "View logs with:"
echo "  firebase functions:log"
echo ""
echo "Or in Firebase Console:"
echo "  https://console.firebase.google.com/project/sub67-d4648/functions"

