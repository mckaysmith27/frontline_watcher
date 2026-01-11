# Controller 1 Credentials Issue - Diagnosis & Fix

## Problem Summary

You're experiencing SSO/Captcha errors with `controller_1`, and suspect the username/password might be incorrect. This is a **very likely possibility** because:

1. **Controller_1 hasn't successfully scraped jobs** since moving to AWS
2. **Controller_1 wasn't working even before AWS migration** (only controller_2 was working)
3. **SSO/Captcha errors can be misleading** - wrong credentials often appear as SSO/Captcha errors

## Why Wrong Credentials Look Like SSO/Captcha Errors

The login code checks if the URL changes from the login page. If credentials are wrong:
- The page stays on the login page
- The code interprets this as "SSO/Captcha blocking"
- But the real issue is incorrect username/password

## Solution

### Step 1: Check Current Credentials

Run this script to see what credentials are currently configured:

```bash
./check-controller-credentials.sh [ec2-host]
```

Example:
```bash
./check-controller-credentials.sh sub67-watcher
```

This will show:
- Current username (password is hidden)
- Service status
- Recent error logs

### Step 2: Update Credentials

If the credentials look wrong or you want to update them:

```bash
./update-controller-credentials.sh [ec2-host]
```

Example:
```bash
./update-controller-credentials.sh sub67-watcher
```

This script will:
1. Prompt for new username and password
2. Backup the existing .env file
3. Update credentials on EC2
4. Restart the service
5. Show you how to monitor logs

### Step 3: Monitor Logs

After updating, watch the logs to see if login succeeds:

```bash
ssh sub67-watcher 'sudo journalctl -u frontline-watcher-controller_1 -f'
```

**Look for these SUCCESS messages:**
- ✅ `Initial login attempt successful`
- ✅ `Verified logged in - not redirected to login page`
- ✅ `Frontline watcher started`

**If you see credential errors:**
- ❌ `credential error detected: [error message]`
- This means the username/password is still wrong

**If you see SSO/Captcha errors:**
- ❌ `Initial login failed - SSO/captcha may be blocking`
- This means credentials might be correct but Frontline is blocking automated logins

## Code Improvements

I've also improved the login code to better detect credential errors:

1. **Added `check_login_error_messages()` function** - Detects error messages on the login page
2. **Better error detection** - Distinguishes between:
   - Wrong credentials (shows specific error message)
   - SSO/Captcha blocking (no specific error, just stays on login page)

## Manual Verification

If you want to manually verify credentials on EC2:

```bash
ssh sub67-watcher
sudo cat /opt/frontline-watcher/.env.controller_1
```

Or manually edit:
```bash
ssh sub67-watcher
sudo nano /opt/frontline-watcher/.env.controller_1
# Edit FRONTLINE_USERNAME and FRONTLINE_PASSWORD
sudo systemctl restart frontline-watcher-controller_1
```

## Next Steps

1. **Run the check script** to see current credentials
2. **Verify the username/password** are correct for controller_1
3. **Update if needed** using the update script
4. **Monitor logs** to confirm login succeeds
5. **Check Firestore** to see if job events start appearing

## Important Notes

- **Controller_2 was working** - This suggests controller_2's credentials were correct
- **Controller_1 never worked** - This strongly suggests controller_1's credentials were never set correctly
- **The credentials might have been placeholder values** when the EC2 instance was set up

## If Credentials Are Correct But Still Failing

If you're certain the credentials are correct but still getting errors:

1. **Try manual login** - Log into Frontline manually with controller_1 credentials to verify they work
2. **Check for account issues** - Account might be locked, disabled, or require password reset
3. **SSO/Captcha blocking** - Frontline may have detected automation and is blocking the account
4. **Consider using saved browser context** - Use the `save-auth-context.py` script to manually authenticate once, then save the session
