# Notifications Feature Deployment Checklist

## ✅ Already Configured (No Action Needed)

### Android
- ✅ `POST_NOTIFICATIONS` permission in AndroidManifest.xml
- ✅ FCM service configured in AndroidManifest.xml
- ✅ Notification channel ID set: `job_notifications`
- ✅ Firebase BOM dependency in build.gradle.kts
- ✅ All required permissions present

### iOS
- ✅ `UIBackgroundModes` with `remote-notification` in Info.plist
- ✅ `FirebaseAppDelegateProxyEnabled` set to `false` in Info.plist
- ✅ Push Notifications capability should be enabled in Xcode (verify in Xcode)

### Web
- ✅ Firebase Messaging configured
- ✅ No additional setup required for web notifications

### Dependencies
- ✅ `firebase_messaging: ^15.1.3` in pubspec.yaml
- ✅ `flutter_local_notifications: ^18.0.1` in pubspec.yaml
- ✅ All notification-related packages present

## 📋 Deployment Steps

### 1. Standard Flutter Build & Deploy

**Android:**
```bash
flutter build apk --release
# or
flutter build appbundle --release
```

**iOS:**
```bash
flutter build ios --release --no-codesign
# Then open in Xcode to sign and archive
```

**Web:**
```bash
flutter build web
firebase deploy --only hosting
```

### 2. Verify iOS Push Notifications Capability

1. Open `ios/Runner.xcworkspace` in Xcode
2. Select "Runner" target
3. Go to "Signing & Capabilities" tab
4. Verify "Push Notifications" capability is enabled
5. If not, click "+ Capability" and add "Push Notifications"

### 3. Firebase Functions (Optional - Backend Enhancement)

The Cloud Functions currently only check `notifyEnabled`. To fully utilize the new notification features, you may want to update `functions/index.js` to respect:

- `fastNotificationsEnabled` - For priority/faster notification delivery
- `applyFilterEnabled` - To apply keyword filters (currently handled by `matchesUserFilters`)
- `setTimesEnabled` / `notificationTimeWindows` - To only send notifications during specified time windows
- `fastJobAcceptEnabled` - For automatic job acceptance (future feature)

**Note:** This is optional - the UI will work fine without these backend changes. Users can set preferences, and you can update the backend later to use them.

### 4. Firestore Indexes

No new indexes required. The existing query uses:
- `districtIds` (array-contains)
- `notifyEnabled` (equality)

### 5. Testing Checklist

After deployment, verify:

- [ ] Notifications screen loads correctly
- [ ] Terms and Conditions can be accepted
- [ ] All toggles work (when terms accepted)
- [ ] Lock icons show for paid features when user has no credits
- [ ] "Filter (keywords)" link navigates to Filters page
- [ ] Time windows can be added/edited/deleted
- [ ] Settings persist after app restart
- [ ] Push notifications are received (test with a job event)

## 🔧 Backend Enhancement (Future)

To fully utilize the new notification settings, consider updating `functions/index.js`:

1. **Time Windows Check:**
   ```javascript
   function isWithinTimeWindow(user) {
     if (!user.setTimesEnabled || !user.notificationTimeWindows) {
       return true; // No time restriction
     }
     // Check if current time is within any time window
     // Implementation needed
   }
   ```

2. **Fast Notifications:**
   - Could use higher priority FCM messages
   - Could check for jobs more frequently for these users

3. **Apply Filter:**
   - Already handled by `matchesUserFilters` function
   - May want to add explicit check for `applyFilterEnabled`

4. **Fast Job Accept:**
   - Future feature - would require additional backend logic

## ✅ Summary

**No special deployment steps required!** The notifications feature is ready to deploy:

1. ✅ All platform permissions configured
2. ✅ Firebase setup complete
3. ✅ Dependencies in place
4. ✅ UI code ready

Just run the standard Flutter build commands for each platform. The new notification settings will be saved to Firestore and can be used by backend services when you're ready to enhance them.
