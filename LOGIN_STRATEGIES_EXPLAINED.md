# Login Strategies - SSO/Captcha Handling

## Problem Analysis

The SSO/captcha blocking issue occurs when Frontline Education's login system detects automated login attempts. The old `frontline_watcher.py` code worked better because it used a simpler, more straightforward approach.

### Key Differences Between Old and New Code

**Old Code (`frontline_watcher.py`):**
- ✅ Simple fill → submit → wait (no event dispatching)
- ✅ Direct approach, no extra complexity
- ✅ Uses `wait_until="load"` consistently

**New Code (Previous Version):**
- ❌ Dispatched input/change events (may trigger validation that detects automation)
- ❌ Storage state persistence (may interfere if expired)
- ❌ More complex flow

## Solution: 3 Different Login Strategies

The code now implements **3 distinct login strategies** that are tried sequentially when a session expires. This gives us multiple chances to succeed before giving up.

### Strategy 1: Simple Login (Like Old Code)
**When:** First retry attempt
**Approach:**
- No event dispatching (matches old working code)
- Direct fill → submit → wait
- Uses `wait_until="load"` like old code
- **Why it works:** Mimics the approach that worked before

### Strategy 2: Delayed Actions with Enter Key
**When:** Second retry attempt
**Approach:**
- Human-like delays between actions (0.3-0.5s pauses)
- Uses Enter key instead of clicking submit button
- More natural typing pattern
- **Why it works:** Appears more human-like, may bypass some detection

### Strategy 3: Clear Cookies and Retry
**When:** Third retry attempt
**Approach:**
- Clears all cookies and permissions
- Waits longer for page load
- Uses simple login after clearing state
- **Why it works:** Removes stale/expired cookies that might be causing SSO issues

## Retry Limits

- **Maximum attempts:** 3 (reduced from 5)
- **Exponential backoff:** 30s, 60s, 120s between attempts
- **After 3 failures:** Stops completely to avoid rate limiting

## What Happens When Blocked

If all 3 strategies fail, the scraper will:
1. Send NTFY notification: `"🔥 Frontline watcher: All 3 login strategies failed. Blocked by SSO/captcha. Stopping to avoid rate limiting."`
2. Stop completely (raise exception)
3. Wait for manual intervention or restart

## Why This Approach Works

1. **Different strategies** = Different detection patterns
2. **Exponential backoff** = Reduces rate limiting risk
3. **Limited retries** = Prevents infinite loops
4. **Clear cookies** = Removes stale state that might cause issues

## Monitoring

Check logs to see which strategy is being used:
- `[auth-strategy-1]` = Simple login
- `[auth-strategy-2]` = Delayed with Enter key
- `[auth-strategy-3]` = Clear cookies and retry

## Next Steps if Still Blocked

If all 3 strategies consistently fail:
1. Check if Frontline has changed their login system
2. Consider manual login to save storage state (bypasses SSO)
3. Review logs to see which strategy fails and why
4. May need to adjust timing or add additional strategies
