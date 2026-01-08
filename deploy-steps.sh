#!/bin/bash
# Complete Cloud Run Deployment Steps
# Run each section in order

set -e

PROJECT_ID=$(gcloud config get-value project)
REGION="us-central1"
IMAGE_NAME="gcr.io/${PROJECT_ID}/frontline-scraper"
IMAGE_TAG="latest"

echo "🚀 Cloud Run Deployment for Frontline Scraper"
echo "Project: ${PROJECT_ID}"
echo "Region: ${REGION}"
echo ""

# ============================================================================
# STEP 1: Verify APIs are enabled (you already did this)
# ============================================================================
echo "✅ Step 1: APIs enabled (already done)"
echo ""

# ============================================================================
# STEP 2: Set up secrets (run setup-secrets.sh or do manually)
# ============================================================================
echo "📋 Step 2: Setting up secrets..."
echo "Run: ./setup-secrets.sh"
echo "OR manually create secrets (see below)"
echo ""
read -p "Have you set up secrets? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Please run ./setup-secrets.sh first, then continue with this script"
    exit 1
fi

# ============================================================================
# STEP 3: Build the Docker image
# ============================================================================
echo ""
echo "📦 Step 3: Building Docker image..."
echo "Using Dockerfile.cloudrun..."
# Copy Dockerfile.cloudrun to Dockerfile for build, or use --file flag
if [ -f "Dockerfile.cloudrun" ]; then
    cp Dockerfile.cloudrun Dockerfile
    gcloud builds submit --tag ${IMAGE_NAME}:${IMAGE_TAG} --project ${PROJECT_ID}
    # Restore original if it exists
    if [ -f "Dockerfile.original" ]; then
        mv Dockerfile.original Dockerfile
    fi
else
    echo "❌ Dockerfile.cloudrun not found!"
    exit 1
fi

# ============================================================================
# STEP 4: Deploy Controller 1 (test first)
# ============================================================================
echo ""
echo "🔧 Step 4: Deploying Controller 1 (test deployment)..."
gcloud run deploy frontline-scraper-controller-1 \
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
  --set-env-vars="CONTROLLER_ID=controller_1" \
  --set-secrets="FRONTLINE_USERNAME=frontline-username:latest,FRONTLINE_PASSWORD=frontline-password:latest,FIREBASE_CREDENTIALS=firebase-credentials:latest,DISTRICT_ID=district-id:latest,FIREBASE_PROJECT_ID=firebase-project-id:latest" \
  --project ${PROJECT_ID}

echo "✅ Controller 1 deployed"
echo ""
read -p "Test Controller 1 logs? Check for errors, then continue? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Viewing logs..."
    gcloud run services logs read frontline-scraper-controller-1 --region ${REGION} --limit 50
fi

# ============================================================================
# STEP 5: Deploy Controllers 2-5
# ============================================================================
echo ""
echo "🔧 Step 5: Deploying Controllers 2-5..."
for i in {2..5}; do
  SERVICE_NAME="frontline-scraper-controller-${i}"
  CONTROLLER_ID="controller_${i}"
  
  echo ""
  echo "Deploying ${SERVICE_NAME} (${CONTROLLER_ID})..."
  
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

# ============================================================================
# STEP 6: Verify deployment
# ============================================================================
echo ""
echo "🎉 All controllers deployed successfully!"
echo ""
echo "📊 Listing all services:"
gcloud run services list --region ${REGION} --filter="name:frontline-scraper-controller"

echo ""
echo "📋 Useful commands:"
echo "  View logs: gcloud run services logs read frontline-scraper-controller-1 --region ${REGION}"
echo "  List services: gcloud run services list --region ${REGION}"
echo "  Check Firestore: Go to Firebase Console > Firestore > job_events collection"
echo ""

