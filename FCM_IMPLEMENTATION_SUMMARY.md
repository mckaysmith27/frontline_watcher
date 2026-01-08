# FCM Push Notifications Implementation Summary

## Flutter Changes Completed

### Files Created
1. **`lib/services/push_notification_service.dart`**
   - Singleton service for FCM handling
   - Requests notification permissions
   - Manages FCM token lifecycle
   - Handles foreground/background/terminated notification states
   - Exposes stream for notification tap events

2. **`lib/screens/job/job_webview_screen.dart`**
   - WebView screen for displaying job URLs
   - No automation - user must manually tap Accept
   - Supports cookie/session persistence

### Files Modified
1. **`pubspec.yaml`**
   - Added `firebase_messaging: ^15.1.3`
   - Added `flutter_local_notifications: ^18.0.1`
   - Added `webview_flutter: ^4.9.0`

2. **`lib/main.dart`**
   - Converted to StatefulWidget
   - Added GlobalKey<NavigatorState> for navigation
   - Initializes PushNotificationService
   - Listens for notification taps and routes to JobWebViewScreen
   - Added route for `/job` with jobUrl parameter

3. **`lib/providers/auth_provider.dart`**
   - Initializes PushNotificationService on user sign-in
   - Saves FCM token to Firestore `users/{uid}.fcmTokens` array
   - Uses `FieldValue.arrayUnion()` to add tokens

### Firestore Schema Updates
**Collection: `users/{uid}`**
- Added field: `fcmTokens: string[]` (array of FCM device tokens)
- Tokens are added via `FieldValue.arrayUnion()` to support multiple devices

## Platform-Specific Setup Required

### Android
1. Add to `android/app/build.gradle`:
```gradle
dependencies {
    implementation platform('com.google.firebase:firebase-bom:32.7.0')
}
```

2. Create `android/app/src/main/res/values/strings.xml`:
```xml
<resources>
    <string name="default_notification_channel_id">job_notifications</string>
</resources>
```

3. Update `AndroidManifest.xml` to include notification channel and permissions (usually auto-added by FlutterFire)

### iOS
1. Enable Push Notifications capability in Xcode
2. Add to `ios/Runner/Info.plist`:
```xml
<key>FirebaseAppDelegateProxyEnabled</key>
<false/>
```

3. Update `ios/Podfile` to ensure Firebase pods are included

## Notification Payload Format
Backend should send notifications with this data structure:
```json
{
  "notification": {
    "title": "New Job Available",
    "body": "A new job matches your filters"
  },
  "data": {
    "jobUrl": "https://ess.com/job/123456",
    "jobId": "123456",
    "eventId": "abc123",
    "districtId": "district_12345"
  }
}
```

## Testing Checklist
- [ ] Request notification permissions on first launch
- [ ] FCM token retrieved and saved to Firestore
- [ ] Token refresh updates Firestore
- [ ] Foreground notifications display correctly
- [ ] Background notification tap routes to WebView
- [ ] Terminated app launch from notification routes to WebView
- [ ] WebView loads job URL correctly
- [ ] Multiple devices per user supported (multiple tokens)

## Next Steps
1. Run `flutter pub get` to install new dependencies
2. Configure Android/iOS platform-specific settings
3. Test with Firebase Console test notification
4. Deploy backend dispatcher to send real notifications

