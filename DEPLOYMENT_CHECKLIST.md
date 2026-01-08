# Cloud Run Deployment Checklist

## Pre-Deployment

- [ ] Google Cloud Project set up (same as Firebase project)
- [ ] `gcloud` CLI installed and authenticated
- [ ] APIs enabled:
  ```bash
  gcloud services enable run.googleapis.com
  gcloud services enable secretmanager.googleapis.com
  gcloud services enable cloudbuild.googleapis.com
  ```
- [ ] Firebase service account JSON file downloaded
- [ ] Have FRONTLINE_USERNAME and FRONTLINE_PASSWORD ready
- [ ] Know your DISTRICT_ID

## Files Required

- [ ] `Dockerfile.cloudrun` exists
- [ ] `requirements_raw.txt` exists
- [ ] `frontline_watcher_refactored.py` exists
- [ ] `setup-secrets.sh` is executable
- [ ] `deploy-all.sh` is executable

## Deployment Steps

### Option A: Automated (Recommended)

1. [ ] Run `./deploy-all.sh`
   - This does everything automatically
   - Will prompt for secrets if needed
   - Will build and deploy all controllers

### Option B: Manual Step-by-Step

1. [ ] Set up secrets: `./setup-secrets.sh`
2. [ ] Build image: `gcloud builds submit --tag gcr.io/PROJECT_ID/frontline-scraper:latest`
3. [ ] Deploy Controller 1: (see QUICK_DEPLOY.md)
4. [ ] Check logs: `gcloud run services logs read frontline-scraper-controller-1 --region us-central1`
5. [ ] Deploy Controllers 2-5: `./deploy-controllers-2-5.sh`

## Post-Deployment Verification

- [ ] All 5 services are running:
  ```bash
  gcloud run services list --region us-central1 --filter="name:frontline-scraper-controller"
  ```

- [ ] Logs show successful initialization:
  ```bash
  gcloud run services logs read frontline-scraper-controller-1 --region us-central1 --limit 50
  ```
  Look for:
  - `[firebase] Initialized successfully`
  - `[init] Controller: controller_1, District: ...`
  - `[*] Monitoring started.`

- [ ] Firestore has `job_events` collection:
  - Go to Firebase Console
  - Navigate to Firestore Database
  - Check for `job_events` collection
  - Documents should appear as jobs are found

- [ ] Jobs are being published:
  - Check logs for `[publish] ✅ Published job event: ...`
  - Verify documents in Firestore `job_events` collection

## Troubleshooting

### Secrets Issues
- [ ] Verify secrets exist: `gcloud secrets list`
- [ ] Check IAM permissions: `gcloud secrets get-iam-policy SECRET_NAME`
- [ ] Re-run `./setup-secrets.sh` if needed

### Build Issues
- [ ] Check Dockerfile.cloudrun exists
- [ ] Verify requirements_raw.txt has all dependencies
- [ ] Check Cloud Build logs: `gcloud builds list`

### Deployment Issues
- [ ] Verify image was built: `gcloud container images list`
- [ ] Check service logs: `gcloud run services logs read SERVICE_NAME --region us-central1`
- [ ] Verify secrets are accessible to Cloud Run service account

### Runtime Issues
- [ ] Check logs for Firebase initialization errors
- [ ] Verify DISTRICT_ID is correct
- [ ] Check Firestore permissions allow writes to `job_events`
- [ ] Verify Frontline credentials are valid

## Next Steps After Deployment

- [ ] Set up Cloud Functions Dispatcher (see BACKEND_REFACTOR_PLAN.md)
- [ ] Configure Firestore security rules for `job_events`
- [ ] Set up monitoring/alerts for service failures
- [ ] Consider switching to Cloud Run Jobs for cost savings (see CLOUD_RUN_DEPLOYMENT.md)

## Cost Monitoring

- [ ] Monitor Cloud Run costs in GCP Console
- [ ] Consider switching to Cloud Run Jobs if costs are high
- [ ] Review logs for unnecessary resource usage

