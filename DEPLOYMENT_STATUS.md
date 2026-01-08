# Deployment Status

## Current Issue: Billing Account

Both Cloud Function and Cloud Run deployments are currently blocked because:
- **Billing account is disabled/closed** for project `sub67-d4648`
- Error: "The billing account for the owning project is disabled in state closed"

## What Needs to Be Done

### 1. Enable Billing Account
1. Go to: https://console.cloud.google.com/billing?project=sub67-d4648
2. Enable billing for the project
3. Ensure billing account is active (not closed)

### 2. Deploy Updated Code

Once billing is enabled, run:
```bash
./deploy-updated-code.sh
```

Or deploy manually:

#### Deploy Cloud Function:
```bash
cd functions
firebase deploy --only functions --project sub67-d4648
cd ..
```

#### Deploy Python Scraper:
```bash
# Build Docker image
gcloud builds submit --tag gcr.io/sub67-d4648/frontline-scraper:latest --project sub67-d4648

# Update all 5 Cloud Run Jobs
for i in {1..5}; do
  gcloud run jobs update frontline-scraper-controller-${i} \
    --image gcr.io/sub67-d4648/frontline-scraper:latest \
    --region us-central1 \
    --project sub67-d4648
done
```

## What Was Updated

### Cloud Function (`functions/index.js`)
- ✅ Creates user-level job event records in `users/{uid}/matched_jobs/{eventId}`
- ✅ Enhanced FCM notifications with organized keywords
- ✅ Deep links to app: `sub67://job/{eventId}?url={jobUrl}`
- ✅ Email notification support (placeholder - needs email service)
- ✅ High-priority notifications for faster delivery

### Python Scraper (`frontline_watcher_refactored.py`)
- ✅ Updated time windows:
  - 4:30 AM - 9:30 AM
  - 11:30 AM - 11:00 PM
- ✅ Fixed job event recording (separated from NTFY notifications)
- ✅ Fixed controller ID format (controller_1, controller_2, etc.)

### Flutter App (`lib/screens/job/job_webview_screen.dart`)
- ✅ Enhanced WebView with accept button guidance overlay
- ✅ Pre-authentication with device-stored credentials
- ✅ Cookie persistence for session management
- ✅ Visual highlighting of Accept button

## Testing After Deployment

1. **Test Cloud Function:**
   ```bash
   # Create a test job event
   ./create-test-job-event.py
   
   # Check logs
   firebase functions:log --project sub67-d4648
   ```

2. **Test Python Scraper:**
   ```bash
   # Run a controller manually
   gcloud run jobs execute frontline-scraper-controller-1 --region us-central1
   
   # Check logs
   gcloud run jobs logs read frontline-scraper-controller-1 --region us-central1 --limit 50
   ```

3. **Verify User-Level Records:**
   - Go to Firebase Console > Firestore
   - Check `users/{uid}/matched_jobs` collection
   - Should see job events when filters match

4. **Test Notifications:**
   - Ensure user has FCM tokens registered
   - Ensure `automationActive: true` and `notifyEnabled: true`
   - Create a job event that matches user filters
   - Check device for notification

## Cost Estimate

- **Cloud Functions**: ~$0.40 per million invocations (very low cost)
- **Cloud Run Jobs**: Pay per execution (~$0.00001 per job run)
- **Firestore**: ~$0.06 per 100K reads/writes
- **Total**: Likely < $5/month for normal usage
