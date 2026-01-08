# Action Plan - Complete Setup

## ✅ What's Already Done

1. ✅ Cloud Functions deployed and active
2. ✅ DISTRICT_ID updated to "alpine_school_district"
3. ✅ Scraper code ready (supports saved context)
4. ✅ All scripts created

## 🎯 What You Need to Do Now

### Option A: Quick Test (2 minutes) - Test Cloud Function

**Goal**: Verify the Cloud Function works without needing scraper authentication.

1. **Install firebase-admin** (if not already):
   ```bash
   pip install firebase-admin
   ```

2. **Create test job event**:
   ```bash
   python3 create-test-job-event.py
   ```

3. **Check if function triggered**:
   ```bash
   firebase functions:log --project sub67-d4648 --limit 20
   ```

4. **Check Firestore**:
   - Go to: https://console.firebase.google.com/project/sub67-d4648/firestore
   - Look for `job_events` collection
   - Should see a test event

5. **Check deliveries**:
   - Look in `job_events/{eventId}/deliveries` subcollection
   - Should see delivery records if users matched

**Expected Result**: Cloud Function triggers, matches users, sends notifications (if users exist with matching filters).

---

### Option B: Full Setup (15-30 minutes) - Enable Real Scraping

**Goal**: Get the scraper working so it can publish real job events.

#### Step 1: Manual SSO Authentication

1. **Run the authentication script**:
   ```bash
   python3 save-auth-context.py
   ```

2. **Follow the prompts**:
   - Browser will open
   - Manually log in with one of your 5 controller accounts
   - Complete SSO/2FA if needed
   - Get to the jobs page
   - Press Enter in terminal when done

3. **Verify session saved**:
   ```bash
   ls -lh /tmp/frontline_storage_state.json
   ```
   Should see the file exists.

#### Step 2: Upload to Secret Manager

**Option 1: Use the automated script**:
```bash
./setup-sso-auth.sh
```

**Option 2: Manual steps**:
```bash
# Create or update secret
gcloud secrets create frontline-browser-context \
  --data-file=/tmp/frontline_storage_state.json \
  --project sub67-d4648

# Or if secret exists, add new version:
gcloud secrets versions add frontline-browser-context \
  --data-file=/tmp/frontline_storage_state.json \
  --project sub67-d4648

# Grant Cloud Run access
PROJECT_NUMBER=$(gcloud projects describe sub67-d4648 --format="value(projectNumber)")
SERVICE_ACCOUNT="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"

gcloud secrets add-iam-policy-binding frontline-browser-context \
  --member="serviceAccount:${SERVICE_ACCOUNT}" \
  --role="roles/secretmanager.secretAccessor" \
  --project sub67-d4648
```

#### Step 3: Update Cloud Run Jobs (If Needed)

The scraper code already supports loading saved context, but you may need to:

1. **Check if jobs need secret mounted**:
   - Go to Cloud Run Jobs console
   - Check each controller job configuration
   - Ensure `STORAGE_STATE_PATH` environment variable is set

2. **Or update via gcloud** (for each controller):
   ```bash
   gcloud run jobs update frontline-scraper-controller-1 \
     --set-env-vars="STORAGE_STATE_PATH=/tmp/frontline_storage_state.json" \
     --region us-central1 \
     --project sub67-d4648
   ```

#### Step 4: Test Scraper

1. **Run a test execution**:
   ```bash
   gcloud run jobs execute frontline-scraper-controller-1 --region us-central1
   ```

2. **Check logs**:
   ```bash
   # Get execution name from output, then:
   gcloud run jobs executions logs read <execution-name> \
     --region us-central1 \
     --project sub67-d4648
   ```

3. **Check Firestore**:
   - Look for `job_events` collection
   - Should see real job events if scraping worked

---

## 🔍 Verification Checklist

After completing either option:

- [ ] `job_events` collection exists in Firestore
- [ ] Cloud Function logs show processing
- [ ] Delivery tracking in `job_events/{eventId}/deliveries`
- [ ] Users with matching filters receive notifications (if any exist)

## 📊 Monitoring

**View Cloud Function logs**:
```bash
firebase functions:log --project sub67-d4648
```

**View Cloud Run logs**:
```bash
gcloud logging read "resource.type=cloud_run_job" --project sub67-d4648 --limit 20
```

**View in Console**:
- Functions: https://console.firebase.google.com/project/sub67-d4648/functions
- Firestore: https://console.firebase.google.com/project/sub67-d4648/firestore
- Cloud Run: https://console.cloud.google.com/run/jobs?project=sub67-d4648

## 🆘 Troubleshooting

**No job_events created**:
- Check Cloud Run job logs for errors
- Verify SSO authentication worked
- Check that scraper found jobs (may be "NO_AVAILABLE_JOBS")

**Cloud Function not triggering**:
- Verify function is deployed: `firebase functions:list --project sub67-d4648`
- Check Firestore security rules
- Check function logs for errors

**No notifications sent**:
- Verify user has `automationActive: true`
- Verify user has `districtIds: ["alpine_school_district"]`
- Verify user has `notifyEnabled: true`
- Verify user has `fcmTokens` array
- Check function logs for matching logic

## 🎉 Success Criteria

You'll know it's working when:
1. Scraper publishes job events to Firestore
2. Cloud Function triggers automatically
3. Function logs show user matching
4. FCM notifications are sent (if users match)
5. Delivery tracking records are created

