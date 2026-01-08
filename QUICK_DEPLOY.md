# Quick Cloud Run Deployment Guide

## Prerequisites Check

1. ✅ APIs enabled (you already did this)
2. ⏳ Secrets need to be set up
3. ⏳ Docker image needs to be built
4. ⏳ Services need to be deployed

## Step-by-Step Commands

### Step 1: Set Up Secrets

Run the interactive script:
```bash
./setup-secrets.sh
```

This will prompt you for:
- FRONTLINE_USERNAME
- FRONTLINE_PASSWORD  
- Path to Firebase service account JSON file
- DISTRICT_ID
- FIREBASE_PROJECT_ID (defaults to your current project)

### Step 2: Build Docker Image

```bash
PROJECT_ID=$(gcloud config get-value project)

# Temporarily use Dockerfile.cloudrun as Dockerfile
cp Dockerfile.cloudrun Dockerfile
gcloud builds submit --tag gcr.io/${PROJECT_ID}/frontline-scraper:latest

# Optionally restore original Dockerfile if you had one
# (Dockerfile.cloudrun is the one we want for Cloud Run)
```

### Step 3: Deploy Controller 1 (Test First)

```bash
PROJECT_ID=$(gcloud config get-value project)
REGION="us-central1"

gcloud run deploy frontline-scraper-controller-1 \
  --image gcr.io/${PROJECT_ID}/frontline-scraper:latest \
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
  --set-secrets="FRONTLINE_USERNAME=frontline-username:latest,FRONTLINE_PASSWORD=frontline-password:latest,FIREBASE_CREDENTIALS=firebase-credentials:latest,DISTRICT_ID=district-id:latest,FIREBASE_PROJECT_ID=firebase-project-id:latest"
```

### Step 4: Check Logs

```bash
gcloud run services logs read frontline-scraper-controller-1 --region us-central1 --limit 50
```

Look for:
- `[firebase] Initialized successfully`
- `[init] Controller: controller_1, District: ...`
- `[*] Monitoring started.`
- `[publish] ✅ Published job event: ...` (when jobs are found)

### Step 5: Deploy Controllers 2-5

```bash
PROJECT_ID=$(gcloud config get-value project)
REGION="us-central1"
IMAGE_NAME="gcr.io/${PROJECT_ID}/frontline-scraper:latest"

for i in {2..5}; do
  gcloud run deploy frontline-scraper-controller-${i} \
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
    --set-env-vars="CONTROLLER_ID=controller_${i}" \
    --set-secrets="FRONTLINE_USERNAME=frontline-username:latest,FRONTLINE_PASSWORD=frontline-password:latest,FIREBASE_CREDENTIALS=firebase-credentials:latest,DISTRICT_ID=district-id:latest,FIREBASE_PROJECT_ID=firebase-project-id:latest"
done
```

## OR: Use the Master Automated Script (Recommended)

**One command does everything:**
```bash
./deploy-all.sh
```

This script will:
1. ✅ Check prerequisites
2. ✅ Set up secrets (if needed)
3. ✅ Build Docker image
4. ✅ Deploy Controller 1 (test)
5. ✅ Show logs and ask for confirmation
6. ✅ Deploy Controllers 2-5

**Or use the step-by-step script:**
```bash
./deploy-steps.sh
```

This will guide you through all steps interactively.

## Verify Deployment

1. **List all services:**
   ```bash
   gcloud run services list --region us-central1 --filter="name:frontline-scraper-controller"
   ```

2. **Check Firestore:**
   - Go to Firebase Console
   - Navigate to Firestore Database
   - Look for `job_events` collection
   - You should see documents being created as jobs are found

3. **Monitor logs:**
   ```bash
   # Watch logs in real-time
   gcloud run services logs tail frontline-scraper-controller-1 --region us-central1
   ```

## Troubleshooting

**If secrets are missing:**
```bash
# List secrets
gcloud secrets list

# Check secret access
gcloud secrets get-iam-policy frontline-username
```

**If build fails:**
- Make sure `Dockerfile.cloudrun` exists
- Make sure `requirements_raw.txt` exists
- Make sure `frontline_watcher_refactored.py` exists

**If deployment fails:**
- Check that secrets exist: `gcloud secrets list`
- Verify service account has access: `gcloud secrets get-iam-policy SECRET_NAME`
- Check logs: `gcloud run services logs read SERVICE_NAME --region us-central1`

**If no jobs are being published:**
- Verify DISTRICT_ID is correct
- Check Firebase credentials are valid
- Verify Firestore permissions allow writes to `job_events` collection

