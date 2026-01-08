#!/bin/bash
# Deploy as Cloud Run Jobs (better for long-running scrapers)
# This is the recommended approach from CLOUD_RUN_DEPLOYMENT.md

set -e

PROJECT_ID=$(gcloud config get-value project)
REGION="us-central1"
IMAGE_NAME="gcr.io/${PROJECT_ID}/frontline-scraper:latest"

echo "🚀 Deploying Frontline Scraper as Cloud Run Jobs"
echo "Project: ${PROJECT_ID}"
echo "Region: ${REGION}"
echo ""

# Delete the failed service first
echo "🧹 Cleaning up failed service..."
gcloud run services delete frontline-scraper-controller-1 \
  --region ${REGION} \
  --project ${PROJECT_ID} \
  --quiet 2>&1 || echo "Service doesn't exist or already deleted"

# Create Cloud Run Jobs for each controller
echo ""
echo "🔧 Creating Cloud Run Jobs..."

for i in {1..5}; do
  JOB_NAME="frontline-scraper-controller-${i}"
  CONTROLLER_ID="controller_${i}"
  
  echo ""
  echo "Creating ${JOB_NAME} (${CONTROLLER_ID})..."
  
  gcloud run jobs create ${JOB_NAME} \
    --image ${IMAGE_NAME} \
    --region ${REGION} \
    --memory 2Gi \
    --cpu 2 \
    --max-retries 3 \
    --task-timeout 3600 \
    --set-env-vars="CONTROLLER_ID=${CONTROLLER_ID}" \
    --set-secrets="FRONTLINE_USERNAME=frontline-username:latest,FRONTLINE_PASSWORD=frontline-password:latest,FIREBASE_CREDENTIALS=firebase-credentials:latest,DISTRICT_ID=district-id:latest,FIREBASE_PROJECT_ID=firebase-project-id:latest" \
    --project ${PROJECT_ID}
  
  echo "✅ Created ${JOB_NAME}"
done

echo ""
echo "🎉 All Cloud Run Jobs created!"
echo ""
echo "📋 Next: Set up Cloud Scheduler to run these jobs on a schedule"
echo "   See CLOUD_RUN_DEPLOYMENT.md for scheduler setup"
echo ""
echo "To manually run a job:"
echo "  gcloud run jobs execute frontline-scraper-controller-1 --region ${REGION}"

