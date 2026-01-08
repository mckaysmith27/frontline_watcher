# Scraper Schedule Control

## Current Status

**🟡 MANUAL ONLY - No Automatic Scheduling**

- ✅ All 5 Cloud Run Jobs are created and ready
- ❌ Cloud Scheduler is **NOT** set up
- ❌ Jobs do **NOT** run automatically
- ✅ Jobs can be run manually on-demand

**Refresh Rate**: **NONE** (jobs only run when you manually execute them)

## Quick Commands

### Check Status
```bash
./control-scrapers.sh status
```

### Run a Job Manually
```bash
# Run controller 1
gcloud run jobs execute frontline-scraper-controller-1 --region us-central1

# Run all controllers
for i in {1..5}; do
  gcloud run jobs execute frontline-scraper-controller-${i} --region us-central1
done
```

### Enable Automatic Scheduling

**Step 1: Enable Cloud Scheduler API**
```bash
gcloud services enable cloudscheduler.googleapis.com --project sub67-d4648
```

**Step 2: Set up schedulers**
```bash
./setup-scheduler.sh
```

This will create schedulers that run each controller **every 1 minute** with 12-second offsets.

### Control Automatic Scheduling

Once schedulers are set up:

```bash
# Check status
./control-scrapers.sh status

# Stop/Pause all scrapers (disable automatic runs)
./control-scrapers.sh stop

# Start/Resume all scrapers (enable automatic runs)
./control-scrapers.sh start
```

## Schedule Options

### Current (After Setup): Every 1 Minute
- Controller 1: Runs at :00 seconds
- Controller 2: Runs at :12 seconds  
- Controller 3: Runs at :24 seconds
- Controller 4: Runs at :36 seconds
- Controller 5: Runs at :48 seconds
- **Combined effect**: ~12 second intervals between scrapes

### To Change Schedule Frequency

**Option 1: Via Script (Edit `setup-scheduler.sh`)**
- Change the `SCHEDULE` variable
- Cron format: `* * * * *` = every minute
- Examples:
  - `*/2 * * * *` = every 2 minutes
  - `*/5 * * * *` = every 5 minutes
  - `*/15 * * * *` = every 15 minutes

**Option 2: Via Cloud Console**
1. Go to: https://console.cloud.google.com/cloudscheduler?project=sub67-d4648
2. Edit each scheduler job
3. Change the schedule (cron format)

**Option 3: Via gcloud**
```bash
# Update a specific scheduler
gcloud scheduler jobs update http frontline-scraper-controller-1-schedule \
  --schedule="*/5 * * * *" \
  --location us-central1 \
  --project sub67-d4648
```

## Cost Implications

### Current (Manual Only)
- **Cost**: $0 (only pay when you manually run jobs)
- **Refresh Rate**: None (manual only)

### With Scheduler (Every 1 Minute)
- **Cost**: ~$5-10/month for all 5 schedulers
- **Refresh Rate**: Every 12 seconds (combined)
- **Runs per day**: ~7,200 per controller = 36,000 total

### With Scheduler (Every 5 Minutes)
- **Cost**: ~$5-10/month
- **Refresh Rate**: Every 60 seconds (combined)
- **Runs per day**: ~1,440 per controller = 7,200 total

## Recommended Schedule

For production, consider:
- **High traffic periods**: Every 1-2 minutes
- **Normal periods**: Every 5 minutes
- **Low traffic periods**: Every 15 minutes

You can create multiple schedulers with different schedules for different times of day.

## Troubleshooting

**"Scheduler not found"**
- Run `./setup-scheduler.sh` to create schedulers

**"API not enabled"**
- Run: `gcloud services enable cloudscheduler.googleapis.com --project sub67-d4648`

**"Jobs not running"**
- Check status: `./control-scrapers.sh status`
- Check if paused: `gcloud scheduler jobs describe frontline-scraper-controller-1-schedule --location us-central1`
- Resume if paused: `./control-scrapers.sh start`

## Summary

**Right Now**: 
- ❌ No automatic refreshing
- ✅ Jobs run manually only
- ✅ Zero cost (only pay when you run jobs)

**To Enable Auto-Refresh**:
1. Enable Cloud Scheduler API
2. Run `./setup-scheduler.sh`
3. Jobs will run every 1 minute automatically
4. Use `./control-scrapers.sh stop` to pause
5. Use `./control-scrapers.sh start` to resume

