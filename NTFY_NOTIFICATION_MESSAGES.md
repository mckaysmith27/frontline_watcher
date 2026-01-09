# NTFY Notification Messages Explained

## Startup Messages

### ✅ "🚀 Frontline watcher started"
**When:** After successful initial login and verification
**Meaning:** The scraper has successfully started and is monitoring for jobs
**Includes:** Controller ID, District ID, NTFY Topic
**Example:**
```
🚀 Frontline watcher started
Controller: controller_1
District: alpine_school_district
NTFY Topic: frontline-jobs-mckay
```

## Error Messages

### ❌ "Initial login failed"
**When:** During startup, if the first login attempt fails
**Meaning:** The scraper couldn't log in at all - SSO/captcha is blocking
**Action:** Scraper stops immediately (doesn't try retry strategies)
**Example:**
```
❌ Frontline watcher: Initial login failed. SSO/captcha may be blocking automated login. Cannot proceed.
```

### ❌ "Initial login appeared successful but was redirected"
**When:** During startup, if login check passes but then redirects back to login page
**Meaning:** The login appeared to work, but Frontline redirected us back (SSO/captcha detected automation)
**Action:** Scraper stops immediately
**Example:**
```
❌ Frontline watcher: Initial login appeared successful but was redirected to login page. SSO/captcha may be blocking. Cannot proceed.
```

### 🔥 "All 3 login strategies failed"
**When:** After startup, if session expires and all 3 retry strategies fail
**Meaning:** The scraper was running, session expired, tried 3 different login approaches, all failed
**Action:** Scraper stops to avoid rate limiting
**Example:**
```
🔥 Frontline watcher: Session expired and all 3 re-login strategies failed (Simple, Delayed, Clear Cookies). Blocked by SSO/captcha. Stopping to avoid rate limiting.
```

## Job Notification Messages

### 🆕 "NEW FRONTLINE JOB"
**When:** A new job is posted that matches your filters
**Meaning:** A job was found and published to Firestore
**Includes:** Date, Time, Duration, Location, Teacher, Title, Confirmation #
**Example:**
```
🆕 NEW FRONTLINE JOB

📅 Date: Mon, 1/8/2026
⏰ Time: 8:00 AM - 3:00 PM
⏱️  Duration: Full Day
📍 Location: Elementary School
👤 Teacher: John Smith
📚 Title: Math Teacher
🔢 Confirmation #: 12345

Controller: controller_1
District: alpine_school_district
```

## Message Flow Example

**Normal Startup:**
1. `🚀 Frontline watcher started` ← Success!

**If Initial Login Fails:**
1. `❌ Frontline watcher: Initial login failed...` ← Stops immediately

**If Session Expires Later:**
1. `🚀 Frontline watcher started` ← Was running fine
2. (Session expires during monitoring)
3. `🔥 Frontline watcher: Session expired and all 3 re-login strategies failed...` ← After trying all strategies

## Why You Might See Multiple Messages

If you see the startup message followed immediately by an error:
- **Most likely:** Initial login check passed, but when navigating to JOBS_URL, Frontline redirected back to login
- **What happens:** The scraper detects this and stops immediately
- **Fix:** The code now verifies we're actually logged in after navigation (checks for redirect)

## What Each Message Means for You

| Message | What It Means | What To Do |
|---------|---------------|------------|
| `🚀 Frontline watcher started` | ✅ Everything working | Nothing - monitor for jobs |
| `❌ Initial login failed` | Can't log in at all | Check credentials, SSO may be blocking |
| `❌ Initial login redirected` | Login appeared to work but Frontline rejected it | SSO/captcha detected automation - may need manual login |
| `🔥 All 3 strategies failed` | Was working, session expired, can't re-login | Check if Frontline changed login system, may need manual intervention |
| `🆕 NEW FRONTLINE JOB` | New job found! | Check the job details |
