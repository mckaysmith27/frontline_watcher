# Scraper Verification Report

## ✅ Confirmed: Only AWS EC2 Servers Are Scraping

### Verification Results

1. **Cloud Run Jobs**: ✅ **0 items** (All removed)
   - Verified: `gcloud run jobs list` returns 0 items
   - All Cloud Run Jobs have been deleted

2. **Cloud Schedulers**: ✅ **0 items** (All removed)
   - Verified: `gcloud scheduler jobs list` returns 0 items
   - All Cloud Schedulers have been deleted

3. **EC2 Services**: ✅ **Only 2 controllers active**
   - Controller 1: `frontline-watcher-controller_1` (systemd service)
   - Controller 2: `frontline-watcher-controller_2` (systemd service)
   - Controllers 3-5: Not configured/disabled

4. **Python Scripts**:
   - `frontline_watcher_refactored.py` - ✅ **Active** (used by EC2)
   - `frontline_watcher.py` - ⚠️ **Old version** (not used, kept for reference)

### Current Architecture

```
┌─────────────────────────────────────┐
│   AWS EC2 Instance (t3.micro)       │
│   ┌─────────────────────────────┐   │
│   │ Controller 1 (systemd)      │   │
│   │ → frontline_watcher.py      │   │
│   └─────────────────────────────┘   │
│   ┌─────────────────────────────┐   │
│   │ Controller 2 (systemd)      │   │
│   │ → frontline_watcher.py      │   │
│   └─────────────────────────────┘   │
└─────────────────────────────────────┘
           ↓
    Frontline Website
```

### What Was Removed

- ❌ All 5 Cloud Run Jobs (deleted)
- ❌ All Cloud Schedulers (deleted)
- ❌ Cloud Run deployment scripts (removed from codebase)

### What Remains

- ✅ **EC2 systemd services** (2 controllers)
- ✅ **Cloud Functions** (processes job events, sends notifications)
  - Not a scraper - just processes events after they're created

### Verification Commands

```bash
# Check Cloud Run (should return 0)
gcloud run jobs list --region=us-central1 --project=sub67-d4648

# Check Schedulers (should return 0)
gcloud scheduler jobs list --location=us-central1 --project=sub67-d4648

# Check EC2 services (should show 2 active)
ssh sub67-watcher 'sudo systemctl list-units --type=service --state=running | grep frontline'
```

### Conclusion

**✅ YES - Only AWS EC2 servers are scraping Frontline.**

All Cloud Run infrastructure has been removed. The only active scrapers are:
- 2 systemd services running on EC2
- Both use `frontline_watcher.py` (which should be `frontline_watcher_refactored.py` - see note below)

### ⚠️ Note: Service File Mismatch

The systemd service file (`ec2/install-service.sh`) references `frontline_watcher.py`, but the active code is `frontline_watcher_refactored.py`. This should be updated to ensure the correct file is being used.
