# Cloud Run Deployment Guide

## Why Cloud Run?

✅ **Serverless** - Pay only when running, no idle costs  
✅ **Auto-scaling** - Handles traffic spikes automatically  
✅ **Integrated with Firebase** - Same Google Cloud ecosystem  
✅ **Container-based** - Use your existing Dockerfile  
✅ **Long-running support** - Can run continuously (up to 60 minutes per request, or use always-on)  
✅ **Easy secrets management** - Use Google Secret Manager  
✅ **Built-in logging** - Integrated with Cloud Logging  

## Architecture

Instead of 5 separate EC2 instances, you'll have:
- **5 Cloud Run services** (one per controller)
- Each service runs continuously with `--no-allow-unauthenticated` (private)
- Each service has different `CONTROLLER_ID` (1-5)
- Services can be set to "always allocate CPU" for consistent performance

## Prerequisites

1. **Google Cloud Project** (same as your Firebase project)
2. **Enable APIs:**
   ```bash
   gcloud services enable run.googleapis.com
   gcloud services enable secretmanager.googleapis.com
   gcloud services enable cloudbuild.googleapis.com
   ```
3. **Install gcloud CLI** (if not already installed)
4. **Docker** (for local testing)

## Step 1: Update Dockerfile for Cloud Run

The Dockerfile needs to install Playwright browsers. Here's the updated version:

```dockerfile
FROM mcr.microsoft.com/playwright/python:v1.45.0-jammy

WORKDIR /app

# Copy requirements and install Python dependencies
COPY requirements_raw.txt /app/
RUN pip install --no-cache-dir -r requirements_raw.txt

# Install Playwright browsers (required for scraping)
RUN playwright install chromium
RUN playwright install-deps chromium

# Copy application code
COPY frontline_watcher_refactored.py /app/frontline_watcher.py

ENV PYTHONUNBUFFERED=1

# Cloud Run expects the container to listen on PORT, but we don't need HTTP
# We'll use a long-running process instead
CMD ["python", "frontline_watcher.py"]
```

## Step 2: Store Secrets in Secret Manager

Instead of `.env` files, use Google Secret Manager:

```bash
# Create secrets for each credential
gcloud secrets create frontline-username --data-file=- <<< "your_username"
gcloud secrets create frontline-password --data-file=- <<< "your_password"
gcloud secrets create firebase-credentials --data-file=service-account.json
gcloud secrets create district-id --data-file=- <<< "district_12345"
gcloud secrets create firebase-project-id --data-file=- <<< "sub67-d4648"
```

**Grant Cloud Run access to secrets:**
```bash
PROJECT_NUMBER=$(gcloud projects describe $(gcloud config get-value project) --format="value(projectNumber)")
SERVICE_ACCOUNT="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"

gcloud secrets add-iam-policy-binding frontline-username \
    --member="serviceAccount:${SERVICE_ACCOUNT}" \
    --role="roles/secretmanager.secretAccessor"

gcloud secrets add-iam-policy-binding frontline-password \
    --member="serviceAccount:${SERVICE_ACCOUNT}" \
    --role="roles/secretmanager.secretAccessor"

gcloud secrets add-iam-policy-binding firebase-credentials \
    --member="serviceAccount:${SERVICE_ACCOUNT}" \
    --role="roles/secretmanager.secretAccessor"

gcloud secrets add-iam-policy-binding district-id \
    --member="serviceAccount:${SERVICE_ACCOUNT}" \
    --role="roles/secretmanager.secretAccessor"

gcloud secrets add-iam-policy-binding firebase-project-id \
    --member="serviceAccount:${SERVICE_ACCOUNT}" \
    --role="roles/secretmanager.secretAccessor"
```

## Step 3: Update Code to Use Secret Manager (Optional)

You can either:
- **Option A:** Use Cloud Run's built-in secret mounting (recommended)
- **Option B:** Modify code to fetch from Secret Manager API

**Option A is simpler** - Cloud Run will mount secrets as environment variables automatically.

## Step 4: Build and Deploy Each Controller

### Build the container image:

```bash
# Build locally (for testing)
docker build -t gcr.io/YOUR_PROJECT_ID/frontline-scraper:latest .

# Or use Cloud Build
gcloud builds submit --tag gcr.io/YOUR_PROJECT_ID/frontline-scraper:latest
```

### Deploy Controller 1:

```bash
gcloud run deploy frontline-scraper-controller-1 \
  --image gcr.io/YOUR_PROJECT_ID/frontline-scraper:latest \
  --platform managed \
  --region us-central1 \
  --no-allow-unauthenticated \
  --memory 2Gi \
  --cpu 2 \
  --timeout 3600 \
  --max-instances 1 \
  --min-instances 1 \
  --cpu-always-allocated \
  --set-env-vars="CONTROLLER_ID=controller_1" \
  --set-secrets="FRONTLINE_USERNAME=frontline-username:latest,FRONTLINE_PASSWORD=frontline-password:latest,FIREBASE_CREDENTIALS_PATH=/secrets/firebase-credentials.json,FIREBASE_CREDENTIALS=firebase-credentials:latest,DISTRICT_ID=district-id:latest,FIREBASE_PROJECT_ID=firebase-project-id:latest"
```

**Note:** For `FIREBASE_CREDENTIALS_PATH`, you'll need to mount the secret as a file. See "Alternative: Mount Secret as File" below.

### Deploy Controllers 2-5:

Repeat with different `CONTROLLER_ID`:

```bash
# Controller 2
gcloud run deploy frontline-scraper-controller-2 \
  --image gcr.io/YOUR_PROJECT_ID/frontline-scraper:latest \
  --platform managed \
  --region us-central1 \
  --no-allow-unauthenticated \
  --memory 2Gi \
  --cpu 2 \
  --timeout 3600 \
  --max-instances 1 \
  --min-instances 1 \
  --cpu-always-allocated \
  --set-env-vars="CONTROLLER_ID=controller_2" \
  --set-secrets="FRONTLINE_USERNAME=frontline-username:latest,FRONTLINE_PASSWORD=frontline-password:latest,FIREBASE_CREDENTIALS=firebase-credentials:latest,DISTRICT_ID=district-id:latest,FIREBASE_PROJECT_ID=firebase-project-id:latest"

# Repeat for controllers 3, 4, 5...
```

## Alternative: Mount Secret as File (For Firebase Credentials)

Since Firebase credentials need to be a JSON file, you can:

1. **Mount secret as volume:**
```bash
gcloud run deploy frontline-scraper-controller-1 \
  --image gcr.io/YOUR_PROJECT_ID/frontline-scraper:latest \
  --platform managed \
  --region us-central1 \
  --no-allow-unauthenticated \
  --memory 2Gi \
  --cpu 2 \
  --timeout 3600 \
  --max-instances 1 \
  --min-instances 1 \
  --cpu-always-allocated \
  --set-env-vars="CONTROLLER_ID=controller_1,FIREBASE_CREDENTIALS_PATH=/secrets/firebase-credentials.json" \
  --set-secrets="FRONTLINE_USERNAME=frontline-username:latest,FRONTLINE_PASSWORD=frontline-password:latest,DISTRICT_ID=district-id:latest,FIREBASE_PROJECT_ID=firebase-project-id:latest,/secrets/firebase-credentials.json=firebase-credentials:latest"
```

2. **Or modify code to use environment variable instead of file path:**

Update `frontline_watcher_refactored.py` to accept credentials as JSON string:

```python
# Instead of FIREBASE_CREDENTIALS_PATH, use FIREBASE_CREDENTIALS_JSON
FIREBASE_CREDENTIALS_JSON = os.getenv("FIREBASE_CREDENTIALS")

if FIREBASE_CREDENTIALS_JSON:
    import json
    cred_info = json.loads(FIREBASE_CREDENTIALS_JSON)
    cred = credentials.Certificate(cred_info)
else:
    # Fallback to file path
    FIREBASE_CREDENTIALS_PATH = os.getenv("FIREBASE_CREDENTIALS_PATH")
    if not FIREBASE_CREDENTIALS_PATH or not os.path.exists(FIREBASE_CREDENTIALS_PATH):
        print("ERROR: FIREBASE_CREDENTIALS or FIREBASE_CREDENTIALS_PATH required")
        sys.exit(1)
    cred = credentials.Certificate(FIREBASE_CREDENTIALS_PATH)
```

## Step 5: Monitor and Logs

View logs:
```bash
# All controllers
gcloud logging read "resource.type=cloud_run_revision" --limit 50

# Specific controller
gcloud run services logs read frontline-scraper-controller-1 --limit 50
```

## Step 6: Update/Deploy New Versions

```bash
# Rebuild image
gcloud builds submit --tag gcr.io/YOUR_PROJECT_ID/frontline-scraper:v2

# Update all services
for i in {1..5}; do
  gcloud run deploy frontline-scraper-controller-$i \
    --image gcr.io/YOUR_PROJECT_ID/frontline-scraper:v2 \
    --platform managed \
    --region us-central1
done
```

## Cost Comparison

### AWS EC2 (5 instances):
- **t3.medium** (2 vCPU, 4GB RAM): ~$30/month each = **$150/month**
- Plus data transfer, storage, etc.

### Cloud Run (5 services):
- **2 vCPU, 2GB RAM, always-on**: ~$50/month each = **$250/month**
- **BUT**: Can use "CPU only during requests" to save ~60% = **~$100/month**
- **OR**: Use Cloud Scheduler + Cloud Run Jobs (runs on schedule) = **~$5-10/month**

### Recommended: Cloud Run Jobs (Scheduled) - MUCH CHEAPER!

Instead of always-on services, use **Cloud Run Jobs** triggered by Cloud Scheduler. This runs the scraper on a schedule instead of continuously, saving ~95% on costs!

### Step 1: Create Cloud Run Jobs

```bash
PROJECT_ID=$(gcloud config get-value project)
PROJECT_NUMBER=$(gcloud projects describe ${PROJECT_ID} --format="value(projectNumber)")

# Create Job for Controller 1 (runs immediately, then exits)
gcloud run jobs create frontline-scraper-controller-1 \
  --image gcr.io/${PROJECT_ID}/frontline-scraper:latest \
  --region us-central1 \
  --memory 2Gi \
  --cpu 2 \
  --max-retries 3 \
  --task-timeout 3600 \
  --set-env-vars="CONTROLLER_ID=controller_1" \
  --set-secrets="FRONTLINE_USERNAME=frontline-username:latest,FRONTLINE_PASSWORD=frontline-password:latest,FIREBASE_CREDENTIALS=firebase-credentials:latest,DISTRICT_ID=district-id:latest,FIREBASE_PROJECT_ID=firebase-project-id:latest"

# Repeat for controllers 2-5
for i in {2..5}; do
  gcloud run jobs create frontline-scraper-controller-${i} \
    --image gcr.io/${PROJECT_ID}/frontline-scraper:latest \
    --region us-central1 \
    --memory 2Gi \
    --cpu 2 \
    --max-retries 3 \
    --task-timeout 3600 \
    --set-env-vars="CONTROLLER_ID=controller_${i}" \
    --set-secrets="FRONTLINE_USERNAME=frontline-username:latest,FRONTLINE_PASSWORD=frontline-password:latest,FIREBASE_CREDENTIALS=firebase-credentials:latest,DISTRICT_ID=district-id:latest,FIREBASE_PROJECT_ID=firebase-project-id:latest"
done
```

### Step 2: Create Cloud Scheduler Jobs (with offsets)

**Note:** Cloud Scheduler minimum interval is 1 minute, so we'll use different schedules:

```bash
# Controller 1: Every minute at :00 seconds
gcloud scheduler jobs create http frontline-scraper-controller-1-schedule \
  --location us-central1 \
  --schedule="* * * * *" \
  --uri="https://${REGION}-run.googleapis.com/apis/run.googleapis.com/v1/namespaces/${PROJECT_ID}/jobs/frontline-scraper-controller-1:run" \
  --http-method POST \
  --oauth-service-account-email ${PROJECT_NUMBER}-compute@developer.gserviceaccount.com \
  --time-zone="America/Denver"

# Controller 2: Every minute at :12 seconds (offset)
gcloud scheduler jobs create http frontline-scraper-controller-2-schedule \
  --location us-central1 \
  --schedule="* * * * *" \
  --uri="https://${REGION}-run.googleapis.com/apis/run.googleapis.com/v1/namespaces/${PROJECT_ID}/jobs/frontline-scraper-controller-2:run" \
  --http-method POST \
  --oauth-service-account-email ${PROJECT_NUMBER}-compute@developer.gserviceaccount.com \
  --time-zone="America/Denver"

# Controller 3: Every minute at :24 seconds
# Controller 4: Every minute at :36 seconds  
# Controller 5: Every minute at :48 seconds
# (Similar pattern for 3-5)
```

**Better Approach:** Since Cloud Scheduler can't do sub-minute intervals, modify the scraper to run once per execution and exit. Then schedule each job every minute with different start times.

**Cost:** ~$5-10/month total for all 5 jobs! (vs $250/month for always-on services)

## Migration Checklist

- [ ] Enable required Google Cloud APIs
- [ ] Create secrets in Secret Manager
- [ ] Update Dockerfile to install Playwright browsers
- [ ] Build and push container image
- [ ] Deploy Controller 1 and test
- [ ] Deploy Controllers 2-5
- [ ] Set up Cloud Scheduler (if using Jobs)
- [ ] Monitor logs and verify job events in Firestore
- [ ] Set up alerts for failures

## Troubleshooting

**Container crashes:**
- Check logs: `gcloud run services logs read SERVICE_NAME`
- Verify secrets are accessible
- Check memory limits (Playwright needs ~1GB)

**No jobs being published:**
- Verify Firebase credentials are correct
- Check Firestore permissions
- Verify DISTRICT_ID matches your district

**High costs:**
- Switch from always-on services to Cloud Run Jobs
- Reduce memory/CPU if possible
- Use "CPU only during requests" instead of always-allocated

