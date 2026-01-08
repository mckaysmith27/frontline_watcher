# Fixed Login Issue - networkidle vs load

## The Problem

The refactored code was using `wait_for_load_state("load")` but the working EC2 code uses `wait_for_load_state("networkidle")`.

## Why This Matters

Frontline's login system is a **Single Page Application (SPA)** that uses client-side routing. 

- `"load"` - Waits for the page load event, which fires **before** the SPA finishes routing
- `"networkidle"` - Waits for the network to be idle (no requests for 500ms), which ensures the SPA has **finished routing** before we check the URL

## Changes Made

Updated all wait states to match the working EC2 code:

1. **`ensure_logged_in()` function**:
   - Changed: `wait_for_load_state("load", timeout=30000)`
   - To: `wait_for_load_state("networkidle", timeout=15000)`

2. **After initial page load**:
   - Changed: `wait_for_load_state("load", timeout=60000)`
   - To: `wait_for_load_state("networkidle")`

3. **In the reload loop**:
   - Changed: `page.reload(wait_until="load")`
   - To: `page.reload(wait_until="networkidle")`

4. **After successful login redirect**:
   - Changed: `page.goto(JOBS_URL, wait_until="load", timeout=60000)`
   - To: `page.goto(JOBS_URL, wait_until="networkidle", timeout=60000)`

## Why EC2 vs Cloud Run Doesn't Matter

The issue wasn't about the server environment (EC2 vs Cloud Run). It was about **waiting for the SPA to finish routing** before checking if login was successful.

Both environments can work the same way - we just needed to use the correct wait state!

## Testing

The Docker image has been rebuilt and jobs updated. Test with:

```bash
gcloud run jobs execute frontline-scraper-controller-1 --region us-central1
```

Then check logs to see if login succeeds:

```bash
gcloud logging read "resource.type=cloud_run_job" --project sub67-d4648 --limit 30
```

Look for:
- `[auth] Login appears successful` ✅
- `[publish] Published job...` ✅

