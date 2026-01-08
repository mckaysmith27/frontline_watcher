# Quick Test Guide

## Option 1: Test with Manual Job Event (Fastest - 2 minutes)

This tests the Cloud Function without needing the scraper to work.

### Steps:

1. **Create test job event**:
   ```bash
   python3 create-test-job-event.py
   ```

2. **Check Cloud Function logs**:
   ```bash
   firebase functions:log --project sub67-d4648 --limit 20
   ```

3. **Check Firestore**:
   - Go to Firebase Console → Firestore
   - Look for `job_events` collection
   - Check `job_events/{eventId}/deliveries` subcollection for delivery tracking

4. **Check if notifications were sent**:
   - If you have a user with `automationActive: true` and matching filters
   - The function should have sent FCM notifications
   - Check user's `fcmTokens` in Firestore

## Option 2: Fix SSO Authentication (For Real Scraping)

This allows the scraper to actually scrape jobs from Frontline.

### Steps:

1. **Run SSO setup script**:
   ```bash
   ./setup-sso-auth.sh
   ```
   
   This will:
   - Open a browser for manual login
   - Save the session cookies
   - Upload to Secret Manager
   - Grant Cloud Run access

2. **Update Cloud Run Jobs** (if needed):
   - The scraper code already supports loading saved context
   - You may need to ensure the secret is mounted in Cloud Run Jobs
   - Check the job configuration in Cloud Console

3. **Test scraper**:
   ```bash
   gcloud run jobs execute frontline-scraper-controller-1 --region us-central1
   ```

4. **Check for job events**:
   - Go to Firestore Console
   - Look for `job_events` collection
   - Should see real job events if scraping works

## Troubleshooting

### No job_events in Firestore:
- **If using test script**: Check that `firebase-service-account.json` exists and is valid
- **If using scraper**: Check Cloud Run job logs for SSO errors

### Cloud Function not triggering:
- Check that the function is deployed: `firebase functions:list --project sub67-d4648`
- Check Firestore security rules allow writes to `job_events`
- Check function logs for errors

### No notifications sent:
- Verify user has `automationActive: true` in Firestore
- Verify user has `districtIds` array containing "alpine_school_district"
- Verify user has `notifyEnabled: true`
- Verify user has `fcmTokens` array with valid tokens
- Check function logs for matching logic

## Expected Flow

1. **Scraper** → Publishes job event to `job_events/{eventId}`
2. **Cloud Function** → Triggers on document create
3. **Function** → Queries users matching `districtId` and `notifyEnabled: true`
4. **Function** → Applies filter matching (include/exclude words)
5. **Function** → Sends FCM notifications to matched users
6. **Function** → Creates delivery tracking in `job_events/{eventId}/deliveries/{userId}`

## Quick Commands

```bash
# Create test event
python3 create-test-job-event.py

# View function logs
firebase functions:log --project sub67-d4648

# View Cloud Run logs
gcloud logging read "resource.type=cloud_run_job" --project sub67-d4648 --limit 20

# Execute scraper
gcloud run jobs execute frontline-scraper-controller-1 --region us-central1

# Setup SSO
./setup-sso-auth.sh
```

