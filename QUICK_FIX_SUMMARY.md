# Quick Fix Summary - Rate Limiting & Controller Management

## Problems Fixed

1. **Rate Limiting Issue**: Code was hammering Frontline when blocked, causing IP bans
2. **No Controller Control**: Couldn't easily stop/start individual controllers
3. **Wrong Wait States**: Using `networkidle` instead of `load` (too aggressive)

## Changes Made

### 1. Exponential Backoff for Login Retries
- **Before**: Immediate retry with 5-10 second delays (hammering the site)
- **After**: Exponential backoff: 1min, 2min, 4min, 8min (max 5min)
- **Result**: Prevents triggering rate limits when blocked

### 2. Controller Management Script
- **New file**: `control-controllers.sh`
- **Usage**:
  ```bash
  ./control-controllers.sh stop 2    # Stop controller 2 only
  ./control-controllers.sh start 1   # Start controller 1 only
  ./control-controllers.sh status    # Check all controllers
  ```

### 3. Wait State Changes (Match Old Working Code)
- **Before**: `wait_for_load_state("networkidle")` - waits for network to settle
- **After**: `wait_for_load_state("load")` - waits for full page load (more conservative)
- **Why**: `networkidle` can be too aggressive and trigger rate limits

## Key Differences from Old Code

The old `frontline_watcher.py` used:
- `wait_for_load_state("load", timeout=30000)` ✅ More conservative
- Simple retry logic with fixed delays

The new `frontline_watcher_refactored.py` was using:
- `wait_for_load_state("networkidle")` ❌ Too aggressive
- No backoff when blocked ❌ Hammering the site

**Now fixed to match old working behavior!**

## Next Steps

1. **Stop controller 2** (if blocked):
   ```bash
   ./control-controllers.sh stop 2
   ```

2. **Deploy updated code**:
   ```bash
   ./deploy-fix.sh
   ```

3. **Check controller 1 status**:
   ```bash
   ./control-controllers.sh status
   ./view-ec2-logs.sh 1 follow
   ```

4. **Wait for rate limit to clear** (usually 15-60 minutes) before restarting controller 2

## Verification

To verify the fix is working:
- Check logs for "Backing off" messages when login fails
- Should see longer delays between retries (1min, 2min, 4min, etc.)
- Should stop after 5 failures instead of hammering indefinitely
