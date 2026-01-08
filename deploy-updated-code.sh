#!/bin/bash

# Deploy Updated Code - Cloud Function and Python Scraper
# Run this after billing account is enabled

set -e

PROJECT_ID="sub67-d4648"
REGION="us-central1"

echo "🚀 Deploying Updated Code"
echo "Project: ${PROJECT_ID}"
echo ""

# Step 1: Deploy Cloud Function
echo "📦 Step 1: Deploying Cloud Function..."
echo ""
cd functions
firebase deploy --only functions --project ${PROJECT_ID}
cd ..
echo "✅ Cloud Function deployed"
echo ""

# Step 2: Build and deploy Python scraper
echo "📦 Step 2: Building Python scraper Docker image..."
echo ""
gcloud builds submit --tag gcr.io/${PROJECT_ID}/frontline-scraper:latest --project ${PROJECT_ID}
echo "✅ Docker image built"
echo ""

# Step 3: Update all Cloud Run Jobs with new image
echo "📦 Step 3: Updating Cloud Run Jobs..."
echo ""
for i in {1..5}; do
  JOB_NAME="frontline-scraper-controller-${i}"
  echo "Updating ${JOB_NAME}..."
  gcloud run jobs update ${JOB_NAME} \
    --image gcr.io/${PROJECT_ID}/frontline-scraper:latest \
    --region ${REGION} \
    --project ${PROJECT_ID} \
    --quiet
  echo "✅ ${JOB_NAME} updated"
done

echo ""
echo "🎉 All deployments complete!"
echo ""
echo "📋 What was deployed:"
echo "  ✅ Cloud Function with user-level job event records"
echo "  ✅ Enhanced FCM notifications with keywords"
echo "  ✅ Email notification support (placeholder)"
echo "  ✅ Python scraper with new time windows (4:30am-9:30am, 11:30am-11:00pm)"
echo ""
echo "🔍 Next steps:"
echo "  1. Verify Cloud Function is active: firebase functions:log --project ${PROJECT_ID}"
echo "  2. Test by running a scraper: gcloud run jobs execute frontline-scraper-controller-1 --region ${REGION}"
echo "  3. Check Firestore for user-level job events in users/{uid}/matched_jobs"
