#!/bin/bash

# Deploy Updated Code - Cloud Function Only
# Note: Scrapers now run on EC2, not Cloud Run
# This script only deploys the Cloud Function (Dispatcher)

set -e

PROJECT_ID="sub67-d4648"

echo "🚀 Deploying Cloud Function (Dispatcher)"
echo "Project: ${PROJECT_ID}"
echo ""
echo "ℹ️  Note: Scrapers run on EC2, not Cloud Run"
echo "   Use ./ec2/quick-deploy.sh to update EC2 scrapers"
echo ""

# Deploy Cloud Function
echo "📦 Deploying Cloud Function..."
echo ""
cd functions
firebase deploy --only functions --project ${PROJECT_ID}
cd ..
echo "✅ Cloud Function deployed"
echo ""

echo "🎉 Deployment complete!"
echo ""
echo "📋 What was deployed:"
echo "  ✅ Cloud Function (onJobEventCreated) - Processes job events, sends notifications"
echo ""
echo "📋 To update EC2 scrapers:"
echo "  ./ec2/quick-deploy.sh sub67-watcher"
echo ""
echo "🔍 Verify Cloud Function:"
echo "  firebase functions:log --project ${PROJECT_ID}"
