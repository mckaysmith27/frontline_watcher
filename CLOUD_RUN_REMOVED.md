# Cloud Run Services - Removed

## Status: ❌ All Cloud Run Services Removed

As of the EC2 migration, all Cloud Run services have been removed from the codebase and infrastructure.

## What Was Removed

### Deleted Scripts:
- `deploy-cloudrun.sh` - Cloud Run deployment script
- `deploy-jobs.sh` - Cloud Run Jobs deployment
- `deploy-controllers-2-5.sh` - Multi-controller deployment
- `deploy-all.sh` - Full deployment script
- `setup-scrapers-configurable.sh` - Scraper setup
- `setup-scheduler-configurable.sh` - Scheduler setup
- `setup-scheduler.sh` - Scheduler configuration
- `control-scrapers.sh` - Scraper control script
- `Dockerfile.cloudrun` - Cloud Run-specific Dockerfile
- `QUICK_SETUP_2_SCRAPERS.sh` - Quick setup script
- `complete-setup-controller-2.sh` - Controller 2 setup
- `setup-controller-2-interactive.sh` - Interactive setup
- `deploy-steps.sh` - Deployment steps
- `QUICK_DEPLOY.md` - Quick deploy guide
- `CLOUD_RUN_DEPLOYMENT.md` - Deployment guide
- `CLOUD_RUN_VS_EC2.md` - Comparison doc
- `ENABLE_AUTO_SCRAPING.md` - Auto-scraping guide
- `CONFIGURABLE_SCRAPER_SETUP.md` - Scraper setup guide
- `SCRAPER_SCHEDULE_CONTROL.md` - Schedule control
- `READY_TO_SETUP_CONTROLLER_2.md` - Controller 2 guide

### Deleted Infrastructure:
- All 5 Cloud Run Jobs (deleted)
- All Cloud Schedulers (deleted)

## Current Architecture

✅ **EC2 Scrapers**: Running on AWS EC2
- 2 controllers active (controller_1, controller_2)
- Services managed via systemd
- Auto-restart on failure

✅ **Cloud Functions**: Still active (needed)
- `onJobEventCreated`: Processes job events, sends notifications
- Very low cost (~$0.01/month)

## Migration Date

January 8, 2026

## Cost Impact

- **Before**: ~$150-300/month (Cloud Run)
- **After**: ~$8-10/month (EC2 + Cloud Functions)
- **Savings**: ~95% reduction

## Notes

- All Cloud Run references removed from code
- Documentation updated to reflect EC2 architecture
- Historical docs preserved but marked as deprecated
- No way to accidentally deploy to Cloud Run anymore
