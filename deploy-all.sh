#!/bin/bash
# Master Deployment Script - Complete Cloud Run Setup
# This script does everything: secrets, build, and deploy

set -e

PROJECT_ID=$(gcloud config get-value project)
REGION="us-central1"
IMAGE_NAME="gcr.io/${PROJECT_ID}/frontline-scraper"
IMAGE_TAG="latest"

echo "🚀 Frontline Scraper - Complete Cloud Run Deployment"
echo "======================================================"
echo "Project: ${PROJECT_ID}"
echo "Region: ${REGION}"
echo ""

# ============================================================================
# STEP 1: Verify Prerequisites
# ============================================================================
echo "📋 Step 1: Checking prerequisites..."

# Check if required files exist
if [ ! -f "Dockerfile.cloudrun" ]; then
    echo "❌ Dockerfile.cloudrun not found!"
    exit 1
fi

if [ ! -f "requirements_raw.txt" ]; then
    echo "❌ requirements_raw.txt not found!"
    exit 1
fi

if [ ! -f "frontline_watcher_refactored.py" ]; then
    echo "❌ frontline_watcher_refactored.py not found!"
    exit 1
fi

echo "✅ All required files found"
echo ""

# ============================================================================
# STEP 2: Set Up Secrets
# ============================================================================
echo "📋 Step 2: Setting up secrets..."
echo ""

# Check if secrets already exist
SECRETS_EXIST=true
for SECRET in frontline-username frontline-password firebase-credentials district-id firebase-project-id; do
    if ! gcloud secrets describe ${SECRET} --project ${PROJECT_ID} &>/dev/null; then
        SECRETS_EXIST=false
        break
    fi
done

if [ "$SECRETS_EXIST" = false ]; then
    echo "⚠️  Some secrets are missing. Running setup-secrets.sh..."
    echo ""
    if [ -f "setup-secrets.sh" ]; then
        ./setup-secrets.sh
    else
        echo "❌ setup-secrets.sh not found. Please create secrets manually:"
        echo "   gcloud secrets create SECRET_NAME --data-file=-"
        exit 1
    fi
else
    echo "✅ All secrets already exist"
    echo ""
    read -p "Do you want to recreate secrets? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "⚠️  You'll need to delete existing secrets first, then run ./setup-secrets.sh"
        echo "   Or continue with existing secrets..."
        read -p "Continue with existing secrets? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
fi

# ============================================================================
# STEP 3: Build Docker Image
# ============================================================================
echo ""
echo "📦 Step 3: Building Docker image..."
echo ""

# Backup original Dockerfile if it exists
if [ -f "Dockerfile" ] && [ ! -f "Dockerfile.backup" ]; then
    cp Dockerfile Dockerfile.backup
    echo "💾 Backed up original Dockerfile to Dockerfile.backup"
fi

# Use Dockerfile.cloudrun for build
cp Dockerfile.cloudrun Dockerfile
echo "📝 Using Dockerfile.cloudrun for build..."

echo "🔨 Building container image (this may take a few minutes)..."
gcloud builds submit --tag ${IMAGE_NAME}:${IMAGE_TAG} --project ${PROJECT_ID}

# Restore original Dockerfile if backup exists
if [ -f "Dockerfile.backup" ]; then
    mv Dockerfile.backup Dockerfile
    echo "💾 Restored original Dockerfile"
fi

echo "✅ Image built successfully: ${IMAGE_NAME}:${IMAGE_TAG}"
echo ""

# ============================================================================
# STEP 4: Deploy Controller 1 (Test)
# ============================================================================
echo "🔧 Step 4: Deploying Controller 1 (test deployment)..."
echo ""

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

# ============================================================================
# STEP 5: Check Logs
# ============================================================================
echo "📊 Step 5: Checking Controller 1 logs..."
echo ""
echo "Recent logs:"
gcloud run services logs read frontline-scraper-controller-1 --region ${REGION} --limit 20

echo ""
read -p "Do the logs look good? Continue with Controllers 2-5? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "⏸️  Deployment paused. Check logs and fix any issues, then run:"
    echo "   ./deploy-controllers-2-5.sh"
    exit 0
fi

# ============================================================================
# STEP 6: Deploy Controllers 2-5
# ============================================================================
echo ""
echo "🔧 Step 6: Deploying Controllers 2-5..."
echo ""

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
# STEP 7: Verify Deployment
# ============================================================================
echo ""
echo "🎉 Deployment Complete!"
echo "======================"
echo ""
echo "📊 All services:"
gcloud run services list --region ${REGION} --filter="name:frontline-scraper-controller"

echo ""
echo "📋 Useful Commands:"
echo "  View logs:     gcloud run services logs read frontline-scraper-controller-1 --region ${REGION}"
echo "  Tail logs:     gcloud run services logs tail frontline-scraper-controller-1 --region ${REGION}"
echo "  List services: gcloud run services list --region ${REGION}"
echo ""
echo "🔍 Next Steps:"
echo "  1. Check Firestore Console for 'job_events' collection"
echo "  2. Monitor logs to verify jobs are being published"
echo "  3. Set up Cloud Functions Dispatcher (see BACKEND_REFACTOR_PLAN.md)"
echo ""

