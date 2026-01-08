# SSO Authentication Guide for Frontline Scraper

## Problem

Frontline uses SSO (Single Sign-On) which requires human interaction and cannot be automated in a headless browser. The scraper will fail with "Re-login failed / still gated by SSO" errors.

## Solution: Manual Authentication + Cookie Persistence

The scraper now supports loading saved browser context (cookies, localStorage) from a previous successful authentication.

## Method 1: Pre-authenticate Locally and Upload Cookies

### Step 1: Authenticate Manually (One Time)

1. **Run the scraper locally (not in Cloud Run) with a visible browser:**

```bash
# Set environment variable to use visible browser
export HEADLESS=false

# Or modify the code temporarily:
# Change: browser = await p.chromium.launch(headless=True)
# To:     browser = await p.chromium.launch(headless=False)
```

2. **When the browser opens, manually complete SSO authentication:**
   - Enter your credentials
   - Complete any 2FA/MFA steps
   - Navigate through SSO redirects
   - Get to the jobs page successfully

3. **The scraper will automatically save the browser context to:**
   - `/tmp/frontline_storage_state.json` (default)
   - Or path specified by `STORAGE_STATE_PATH` environment variable

### Step 2: Upload Saved Context to Secret Manager

```bash
# Create secret with saved browser context
gcloud secrets create frontline-browser-context \
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

### Step 3: Update Cloud Run Jobs to Use Saved Context

The scraper will automatically load the context if `STORAGE_STATE_PATH` points to a file, or if the file exists at the default path.

**Option A: Mount as file in Cloud Run Job**

```bash
gcloud run jobs update frontline-scraper-controller-1 \
  --set-secrets="/tmp/frontline_storage_state.json=frontline-browser-context:latest" \
  --set-env-vars="STORAGE_STATE_PATH=/tmp/frontline_storage_state.json" \
  --region us-central1
```

**Option B: Load from environment variable (JSON string)**

Modify the code to accept context as JSON string from environment variable.

## Method 2: Use Persistent Browser Context (Advanced)

For long-running sessions, you can:

1. **Run a separate "auth keeper" service** that:
   - Maintains an authenticated browser session
   - Periodically refreshes cookies
   - Exposes cookies via API or shared storage

2. **Scraper fetches fresh cookies** before each run

## Method 3: Alternative Authentication (If Available)

Check if Frontline offers:
- API access with API keys
- OAuth2 flow that can be automated
- Service account authentication

## Current Status

The scraper code now:
- ✅ Saves browser context after successful login
- ✅ Loads saved context on startup
- ✅ Falls back to username/password if no saved context

**Next Step:** Manually authenticate once locally, save the context, and upload it to Secret Manager.

## Troubleshooting

**Context expires:**
- Browser contexts typically expire after some time
- You'll need to re-authenticate and save a new context
- Consider setting up automatic context refresh

**Context not loading:**
- Check file path: `STORAGE_STATE_PATH` environment variable
- Verify file exists and is valid JSON
- Check Cloud Run logs for context loading errors

**SSO still required:**
- Some SSO systems require fresh authentication each time
- May need to use Method 2 (persistent auth keeper)
- Or contact Frontline about API access

