#!/bin/bash
# Deploy Controllers 2-5 only
# Use this if Controller 1 is already deployed and working

set -e

PROJECT_ID=$(gcloud config get-value project)
REGION="us-central1"
IMAGE_NAME="gcr.io/${PROJECT_ID}/frontline-scraper:latest"

echo "🔧 Deploying Controllers 2-5..."
echo ""

for i in {2..5}; do
  SERVICE_NAME="frontline-scraper-controller-${i}"
  CONTROLLER_ID="controller_${i}"
  
  echo "Deploying ${SERVICE_NAME} (${CONTROLLER_ID})..."
  
  gcloud run deploy ${SERVICE_NAME} \
    --image ${IMAGE_NAME} \
    --platform managed \
    --region ${REGION} \
    --no-allow-unauthenticated \
    --memory 2Gi \
    --cpu 2 \
    --timeout 3600 \
    --max-instances 1 \
    --min-instances 1 \
    --cpu-always-allocated \
    --set-env-vars="CONTROLLER_ID=${CONTROLLER_ID}" \
    --set-secrets="FRONTLINE_USERNAME=frontline-username:latest,FRONTLINE_PASSWORD=frontline-password:latest,FIREBASE_CREDENTIALS=firebase-credentials:latest,DISTRICT_ID=district-id:latest,FIREBASE_PROJECT_ID=firebase-project-id:latest" \
    --project ${PROJECT_ID}
  
  echo "✅ ${SERVICE_NAME} deployed"
  echo ""
done

echo "🎉 All controllers deployed!"
echo ""
echo "List services: gcloud run services list --region ${REGION}"

