# Deployment Status

## Current Architecture

✅ **EC2 Scrapers**: Running on AWS EC2 (2 controllers)
- Controller 1: Active on EC2
- Controller 2: Active on EC2
- Controllers 3-5: Disabled (not needed)

✅ **Cloud Functions**: Active
- `onJobEventCreated`: Processes job events, sends FCM notifications
- Cost: ~$0.01/month (essentially free)

❌ **Cloud Run**: Removed (migrated to EC2)
- All Cloud Run Jobs deleted
- All Cloud Schedulers deleted
- Cost saved: ~$5-10/day

## Deployment Commands

### Update Cloud Function:
```bash
cd functions
firebase deploy --only functions --project sub67-d4648
```

### Update EC2 Scrapers:
```bash
./ec2/quick-deploy.sh sub67-watcher
```

### Check EC2 Status:
```bash
./QUICK_STATUS_CHECK.sh
# Or manually:
ssh sub67-watcher 'cd /opt/frontline-watcher && ./ec2/monitor-services.sh status'
```

## What Was Updated

### Cloud Function (`functions/index.js`)
- ✅ Creates user-level job event records in `users/{uid}/matched_jobs/{eventId}`
- ✅ Enhanced FCM notifications with organized keywords
- ✅ Deep links to app: `sub67://job/{eventId}?url={jobUrl}`
- ✅ Email notification support (placeholder - needs email service)
- ✅ High-priority notifications for faster delivery

### Python Scraper (`frontline_watcher_refactored.py`)
- ✅ Updated time windows:
  - 4:30 AM - 9:30 AM
  - 11:30 AM - 11:00 PM
- ✅ Fixed job event recording (separated from NTFY notifications)
- ✅ Fixed controller ID format (controller_1, controller_2, etc.)
- ✅ Optimized for EC2 deployment

### Flutter App (`lib/screens/job/job_webview_screen.dart`)
- ✅ Enhanced WebView with accept button guidance overlay
- ✅ Pre-authentication with device-stored credentials
- ✅ Cookie persistence for session management
- ✅ Visual highlighting of Accept button

## Testing

1. **Test Cloud Function:**
   ```bash
   # Create a test job event
   ./create-test-job-event.py
   
   # Check logs
   firebase functions:log --project sub67-d4648
   ```

2. **Test EC2 Scrapers:**
   ```bash
   # Check status
   ssh sub67-watcher 'sudo systemctl status frontline-watcher-controller_1'
   
   # View logs
   ssh sub67-watcher 'sudo journalctl -u frontline-watcher-controller_1 -f'
   ```

3. **Verify User-Level Records:**
   - Go to Firebase Console > Firestore
   - Check `users/{uid}/matched_jobs` collection
   - Should see job events when filters match

4. **Test Notifications:**
   - Ensure user has FCM tokens registered
   - Ensure `automationActive: true` and `notifyEnabled: true`
   - Create a job event that matches user filters
   - Check device for notification

## Cost Estimate

- **EC2 t3.micro**: ~$7.50/month (2 controllers on 1 instance)
- **Cloud Functions**: ~$0.01/month (very low cost, only runs when job events created)
- **Firestore**: ~$0.06 per 100K reads/writes
- **Total**: ~$8-10/month (down from ~$150-300/month with Cloud Run)

## Migration Complete

✅ All Cloud Run services removed
✅ EC2 scrapers running
✅ Cloud Functions active (needed for notifications)
✅ Cost reduced by ~95%
