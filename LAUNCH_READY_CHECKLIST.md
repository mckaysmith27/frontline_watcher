# Launch Ready Checklist

## ✅ Completed

1. **Infrastructure**
   - ✅ 2 EC2 scrapers deployed (controllers 1 & 2)
   - ❌ Cloud Run Jobs removed (migrated to EC2)
   - ✅ Docker image built and pushed
   - ✅ Secrets configured (5 secrets in Secret Manager)
   - ✅ APIs enabled

2. **Code**
   - ✅ Scraper refactored (publishes events only)
   - ✅ Cloud Functions Dispatcher created
   - ✅ Flutter app security updated
   - ✅ FCM push notifications implemented
   - ✅ WebView for job acceptance

3. **Security**
   - ✅ Credentials stored only in device keychain
   - ✅ No backend credential storage
   - ✅ Controller accounts isolated

## ⏳ Required Before Launch (In Order)

### 1. Deploy Cloud Functions (5 minutes)

**Status**: Code created, needs deployment

```bash
cd functions
npm install
cd ..
firebase deploy --only functions
```

Or use the script:
```bash
./deploy-functions.sh
```

**What it does**: Matches job events to users and sends FCM notifications

### 2. Update DISTRICT_ID (1 minute)

**Status**: Currently "district_placeholder", needs real value

```bash
echo -n "alpine_school_district" | gcloud secrets versions add district-id --data-file=- --project sub67-d4648
```

### 3. Set Up SSO Authentication (15-30 minutes)

**Status**: Scrapers failing due to SSO

**Option A: Manual Authentication (Recommended)**
```bash
# Run locally to create authenticated session
python save-auth-context.py

# Upload to Secret Manager
gcloud secrets create frontline-browser-context \
  --data-file=/tmp/frontline_storage_state.json \
  --project sub67-d4648

# Grant access
PROJECT_NUMBER=$(gcloud projects describe sub67-d4648 --format="value(projectNumber)")
SERVICE_ACCOUNT="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"
gcloud secrets add-iam-policy-binding frontline-browser-context \
  --member="serviceAccount:${SERVICE_ACCOUNT}" \
  --role="roles/secretmanager.secretAccessor" \
  --project sub67-d4648

# Update Cloud Run Jobs to use saved context
# (Modify deploy-jobs.sh or update manually)
```

**Option B: Test Without SSO First**
- Deploy and test the flow
- Handle SSO later if needed

### 4. Set Up Cloud Scheduler (Optional - 15 minutes)

**Status**: Not set up (jobs can be run manually for testing)

**For Production**: Set up Cloud Scheduler to run jobs every 15 seconds with offsets

**For Testing**: Can run jobs manually:
```bash
ssh sub67-watcher 'sudo systemctl status frontline-watcher-controller_1'
```

### 5. Verify Firestore Schema (5 minutes)

**Check user documents have**:
- ✅ `districtIds: ["alpine_school_district"]` (added by automation service)
- ✅ `notifyEnabled: true` (added by automation service)
- ✅ `automationActive: true` (when automation is active)
- ✅ `automationConfig.includedWords: string[]`
- ✅ `automationConfig.excludedWords: string[]`
- ✅ `fcmTokens: string[]` (added by auth provider)

**Action**: Test automation setup in Flutter app to verify fields are saved

### 6. Create Firestore Indexes (If Needed)

**Status**: Firestore will prompt if indexes are needed

**Likely needed**:
- `users` collection: `districtIds` (array-contains) + `notifyEnabled` (==)

**Action**: Firestore will provide a link to create indexes when needed

### 7. Test End-to-End Flow (30 minutes)

**Test Steps**:

1. **Deploy Functions**:
   ```bash
   ./deploy-functions.sh
   ```

2. **Update DISTRICT_ID**:
   ```bash
   echo -n "alpine_school_district" | gcloud secrets versions add district-id --data-file=- --project sub67-d4648
   ```

3. **Run Scraper Manually**:
   ```bash
   ssh sub67-watcher 'sudo systemctl status frontline-watcher-controller_1'
   ```

4. **Check Firestore**:
   - Go to Firebase Console → Firestore
   - Check `job_events` collection for new documents

5. **Check Cloud Functions Logs**:
   ```bash
   firebase functions:log
   ```
   - Should see dispatcher processing events
   - Should see FCM notifications being sent

6. **Test in Flutter App**:
   - Set up automation preferences
   - Verify user document has required fields
   - Wait for notification (or trigger manually)
   - Tap notification → Verify WebView opens
   - Test job acceptance

## Quick Launch Commands

```bash
# 1. Deploy Cloud Functions
./deploy-functions.sh

# 2. Update DISTRICT_ID
echo -n "alpine_school_district" | gcloud secrets versions add district-id --data-file=- --project sub67-d4648

# 3. Test scraper (manual run)
ssh sub67-watcher 'sudo systemctl status frontline-watcher-controller_1'

# 4. Check logs
firebase functions:log --limit 20
gcloud logging read "resource.type=cloud_run_job" --project sub67-d4648 --limit 20
```

## What Works Right Now

✅ **Infrastructure**: All deployed and ready
✅ **Code**: All written and ready
✅ **Security**: Compliant architecture
⏳ **SSO**: Needs manual authentication context
⏳ **Testing**: Needs end-to-end verification

## Estimated Time to Launch

- **Minimum** (without SSO, manual testing): 10-15 minutes
- **Full** (with SSO, Cloud Scheduler): 30-45 minutes

## Priority

1. **Deploy Cloud Functions** (blocks notifications) - 5 min
2. **Update DISTRICT_ID** (needs real value) - 1 min
3. **Test manually** (verify flow works) - 15 min
4. **Set up SSO** (if needed for production) - 30 min
5. **Set up Cloud Scheduler** (for production) - 15 min

