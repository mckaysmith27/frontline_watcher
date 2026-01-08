#!/bin/bash
# Cloud Run Deployment Script for Frontline Scraper
# Deploys 5 controller instances with proper configuration

set -e

PROJECT_ID=${GOOGLE_CLOUD_PROJECT:-$(gcloud config get-value project)}
REGION=${REGION:-us-central1}
IMAGE_NAME="gcr.io/${PROJECT_ID}/frontline-scraper"
IMAGE_TAG=${IMAGE_TAG:-latest}

echo "🚀 Deploying Frontline Scraper to Cloud Run"
echo "Project: ${PROJECT_ID}"
echo "Region: ${REGION}"
echo "Image: ${IMAGE_NAME}:${IMAGE_TAG}"
echo ""

# Build the container image
echo "📦 Building container image..."
gcloud builds submit --tag ${IMAGE_NAME}:${IMAGE_TAG} --project ${PROJECT_ID}

# Deploy each controller
for i in {1..5}; do
  SERVICE_NAME="frontline-scraper-controller-${i}"
  CONTROLLER_ID="controller_${i}"
  
  echo ""
  echo "🔧 Deploying ${SERVICE_NAME} (${CONTROLLER_ID})..."
  
  gcloud run deploy ${SERVICE_NAME} \
    --image ${IMAGE_NAME}:${IMAGE_TAG} \
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
done

echo ""
echo "🎉 All controllers deployed successfully!"
echo ""
echo "View logs with:"
echo "  gcloud run services logs read frontline-scraper-controller-1 --region ${REGION}"
echo ""
echo "List services with:"
echo "  gcloud run services list --region ${REGION}"

