# Scraper Refactor Summary

## What Changed

### Removed
- ❌ All per-user filter logic (`JOB_INCLUDE_WORDS_ANY`, `JOB_EXCLUDE_WORDS_ANY`, `JOB_INCLUDE_WORDS_COUNT`, `JOB_EXCLUDE_MIN_MATCHES`, `JOB_EXCLUDE_WORDS_COUNT`, `JOB_EXCLUDE_MIN_MATCHES`)
- ❌ All `ntfy` notification code (`notify()` function, `NTFY_TOPIC` env var)
- ❌ All auto-accept logic (`try_accept_job_block()`, `try_accept_from_filtered_snapshot()`, `_handle_dom_confirm_if_present()`, etc.)
- ❌ Self-test that tests auto-accept functionality
- ❌ Filter application functions (`apply_job_filters_to_snapshot()`, `count_matches()`, etc.)
- ❌ Change detection and diff logic (no longer needed)

### Kept
- ✅ Job extraction logic (`try_extract_available_job_blocks()`, `get_available_jobs_snapshot()`)
- ✅ Login/authentication logic
- ✅ Session management and re-login on expiry
- ✅ DOM parsing for job data

### Added
- ✅ Firestore integration (`firebase-admin`, `google-cloud-firestore`)
- ✅ Event publishing (`publish_job_event()`)
- ✅ Event ID generation for deduplication (`generate_event_id()`)
- ✅ Keyword extraction (`extract_keywords()`)
- ✅ Job block parsing (`parse_job_block()`)
- ✅ Multi-scraper offset support
- ✅ Hot window scheduling logic

## Environment Variables

### Required (Keep in .env)
```env
# Frontline credentials (controller/partner account)
FRONTLINE_USERNAME=partner_username
FRONTLINE_PASSWORD=partner_password

# Controller identification
CONTROLLER_ID=controller_1  # Must be controller_1 through controller_5
DISTRICT_ID=district_12345   # Frontline district identifier

# Firebase configuration
FIREBASE_PROJECT_ID=sub67-d4648
FIREBASE_CREDENTIALS_PATH=/path/to/service-account.json
```

### Removed (No longer needed)
```env
# These can be removed from .env:
NTFY_TOPIC=...
JOB_INCLUDE_WORDS_ANY=...
JOB_EXCLUDE_WORDS_ANY=...
JOB_INCLUDE_WORDS_COUNT=...
JOB_INCLUDE_MIN_MATCHES=...
JOB_EXCLUDE_WORDS_COUNT=...
JOB_EXCLUDE_MIN_MATCHES=...
DRY_RUN_ACCEPT=...
SELFTEST_ON_START=...
SENT_STARTUP_NOTIFY=...
```

## New Dependencies

Add to `requirements_raw.txt` (or install via pip):
```
firebase-admin>=6.0.0
google-cloud-firestore>=2.0.0
```

Install with:
```bash
pip install firebase-admin google-cloud-firestore
```

## Firebase Setup

1. **Create Service Account:**
   - Go to Firebase Console → Project Settings → Service Accounts
   - Click "Generate New Private Key"
   - Save JSON file to your server
   - Set `FIREBASE_CREDENTIALS_PATH` to this file path

2. **Firestore Security Rules:**
   - Allow write access to `job_events` collection for authenticated service accounts
   - The scraper uses service account authentication (not user auth)

## How It Works Now

1. **Scraper runs on schedule:**
   - Each of 5 instances runs every 15 seconds
   - Offset by 3 seconds each (0s, 3s, 6s, 9s, 12s)
   - Combined cadence: ~3 seconds
   - Hot windows: 6-8 AM, 2-4 PM (aggressive scraping)
   - Outside hot windows: 60-second intervals

2. **Job extraction:**
   - Scraper extracts all available jobs from Frontline
   - No filtering applied (that happens in Dispatcher)

3. **Event publishing:**
   - For each job found, creates normalized `job_event` document
   - Generates stable `eventId` hash for deduplication
   - Checks if event already exists in Firestore
   - If new, writes to `job_events/{eventId}`

4. **Deduplication:**
   - Event ID = SHA256(districtId|jobId|date|startTime|location)
   - Same job won't be published twice
   - Firestore document existence check is atomic

## Testing

1. **Test Firestore connection:**
   ```python
   # Should print "[firebase] Initialized successfully"
   ```

2. **Test job extraction:**
   - Scraper should log job blocks found
   - Check logs for "[publish] ✅ Published job event"

3. **Test deduplication:**
   - Run scraper twice quickly
   - Second run should show "[publish] Event ... already exists, skipping"

4. **Verify in Firestore:**
   - Check `job_events` collection in Firebase Console
   - Should see documents with `source: "frontline"`, `controllerId`, `districtId`, etc.

## Migration Steps

1. **Backup current `frontline_watcher.py`**
2. **Install new dependencies:**
   ```bash
   pip install firebase-admin google-cloud-firestore
   ```
3. **Update `.env` file:**
   - Remove filter-related variables
   - Remove `NTFY_TOPIC`
   - Add `CONTROLLER_ID`, `DISTRICT_ID`, `FIREBASE_PROJECT_ID`, `FIREBASE_CREDENTIALS_PATH`
4. **Download Firebase service account JSON**
5. **Replace `frontline_watcher.py` with refactored version**
6. **Test with one instance first**
7. **Deploy to all 5 instances with different `CONTROLLER_ID` values**

## Notes

- Scraper no longer sends any notifications directly
- Scraper no longer auto-accepts jobs
- All filtering and user matching happens in Cloud Functions Dispatcher
- Each scraper instance should have unique `CONTROLLER_ID` (1-5)
- Each scraper can monitor different districts via `DISTRICT_ID`

