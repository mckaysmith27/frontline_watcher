# Pre-Launch Checklist

## ✅ Completed

1. **EC2 Infrastructure** ✅
   - ✅ 2 EC2 scrapers deployed (controllers 1 & 2)
   - ✅ Systemd services configured
   - ✅ Secrets configured in Secret Manager
   - ✅ APIs enabled (Cloud Functions, Secret Manager)
   - ❌ Cloud Run removed (migrated to EC2)

2. **Scraper Code**
   - ✅ Refactored to publish job events only
   - ✅ Firestore integration added
   - ✅ Event deduplication implemented
   - ✅ SSO authentication support added

3. **Flutter App Security**
   - ✅ Credentials stored only in device keychain
   - ✅ No backend credential transmission
   - ✅ WebView for job acceptance
   - ✅ FCM push notifications implemented

## ⏳ Required Before Launch

### 1. Cloud Functions Dispatcher (CRITICAL - Missing)

**Status**: ❌ Not created yet

**What it does**:
- Triggers when new job events are created in Firestore
- Matches job events to user preferences
- Sends FCM notifications to matched users
- Tracks deliveries to prevent duplicates

**Files to create**:
- `functions/index.js` - Dispatcher logic
- `functions/package.json` - Dependencies
- `functions/.gitignore` - Standard ignores

**Action**: Create and deploy Cloud Functions

### 2. Update DISTRICT_ID

**Status**: ⚠️ Currently set to "district_placeholder"

**Action**: Update with real Alpine School District ID
```bash
echo -n "alpine_school_district" | gcloud secrets versions add district-id --data-file=- --project sub67-d4648
```

### 3. SSO Authentication Context

**Status**: ⚠️ Scrapers hitting SSO login failures

**Action**: 
- Run `python save-auth-context.py` locally
- Manually authenticate with one of the 5 controller accounts
- Upload saved context to Secret Manager
- Update EC2 scrapers (already configured via .env files)

### 4. Cloud Scheduler (For Scheduled Execution)

**Status**: ❌ Not set up yet

**What it does**:
- EC2 scrapers run continuously (no scheduler needed)
- Much cheaper than always-on services

**Action**: Set up Cloud Scheduler jobs for each controller

### 5. Firestore Schema Updates

**Status**: ⚠️ Need to ensure user documents have required fields

**Required fields in `users/{uid}`**:
```typescript
{
  districtIds: string[];           // Array of district IDs user wants
  includeAny: string[];            // Keywords to include (any match)
  excludeAny: string[];            // Keywords to exclude (any match)
  includeCount: string[];           // Keywords to include (count-based)
  includeMinMatches: number;       // Minimum matches required
  excludeCount: string[];           // Keywords to exclude (count-based)
  excludeMinMatches: number;       // Minimum exclude matches to filter out
  fcmTokens: string[];              // FCM tokens for notifications
  notifyEnabled: boolean;           // Whether user wants notifications
  automationActive: boolean;        // Whether automation is active
  automationConfig: {
    includedWords: string[];
    excludedWords: string[];
    committedDates: string[];
  }
}
```

**Action**: Ensure Flutter app saves these fields when user sets up automation

### 6. Firestore Indexes

**Status**: ⚠️ May need composite indexes

**Required indexes**:
- `users` collection: `districtIds` (array-contains) + `notifyEnabled` (==)
- `job_events` collection: `createdAt` (orderBy) - optional for queries

**Action**: Create indexes if Firestore prompts for them

### 7. Firestore Security Rules

**Status**: ⚠️ Need to verify rules allow:
- Scrapers to write to `job_events`
- Cloud Functions to read `users` and write `deliveries`
- Users to read their own data

**Action**: Review and update Firestore security rules

### 8. Test End-to-End Flow

**Status**: ❌ Not tested yet

**Test steps**:
1. Scraper publishes job event → Verify in Firestore
2. Cloud Function triggers → Verify matching logic
3. FCM notification sent → Verify user receives notification
4. User taps notification → Verify WebView opens
5. User accepts job → Verify job acceptance works

## Quick Start Guide

### Step 1: Create Cloud Functions Dispatcher

```bash
# Initialize Firebase Functions (if not already done)
firebase init functions

# Or create manually:
mkdir functions
cd functions
npm init -y
npm install firebase-admin firebase-functions
```

Then create `functions/index.js` with dispatcher logic (see BACKEND_REFACTOR_PLAN.md)

### Step 2: Deploy Cloud Functions

```bash
firebase deploy --only functions
```

### Step 3: Update DISTRICT_ID

```bash
echo -n "alpine_school_district" | gcloud secrets versions add district-id --data-file=- --project sub67-d4648
```

### Step 4: Set Up SSO Authentication

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
```

### Step 5: Set Up Cloud Scheduler (Optional but Recommended)

See `CLOUD_RUN_DEPLOYMENT.md` for Cloud Scheduler setup

### Step 6: Test

1. Check EC2 scraper status: `ssh sub67-watcher 'sudo systemctl status frontline-watcher-controller_1'`
2. Check Firestore for `job_events` collection
3. Verify Cloud Function triggers
4. Check FCM notifications are sent

## Priority Order

1. **HIGH**: Create Cloud Functions Dispatcher (blocks notifications)
2. **HIGH**: Update DISTRICT_ID (needs real value)
3. **MEDIUM**: Set up SSO authentication (blocks scraping)
4. **MEDIUM**: Set up Cloud Scheduler (for cost savings)
5. **LOW**: Firestore indexes (will prompt if needed)
6. **LOW**: Security rules review (may already be fine)

## Estimated Time

- Cloud Functions: 30-60 minutes
- DISTRICT_ID update: 1 minute
- SSO setup: 15-30 minutes
- Cloud Scheduler: 15-30 minutes
- Testing: 30-60 minutes

**Total**: ~2-3 hours to fully operational

