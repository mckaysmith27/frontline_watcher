# Implementation Files List

## FLUTTER-ONLY TASK: FCM Push Notifications + WebView

### Files Created
1. **`lib/services/push_notification_service.dart`** (NEW)
   - Singleton service for FCM token management
   - Handles foreground/background/terminated notification states
   - Exposes stream for notification tap events
   - Saves FCM tokens to Firestore

2. **`lib/screens/job/job_webview_screen.dart`** (NEW)
   - WebView screen for displaying job URLs
   - User manually taps Accept (no automation)
   - Cookie/session persistence enabled

3. **`FCM_IMPLEMENTATION_SUMMARY.md`** (NEW)
   - Documentation for FCM setup and testing

### Files Modified
1. **`pubspec.yaml`**
   - Added: `firebase_messaging: ^15.1.3`
   - Added: `flutter_local_notifications: ^18.0.1`
   - Added: `webview_flutter: ^4.9.0`

2. **`lib/main.dart`**
   - Converted to StatefulWidget
   - Added GlobalKey<NavigatorState> for navigation
   - Initializes PushNotificationService
   - Listens for notification taps and routes to JobWebViewScreen
   - Added `/job` route
   - Background message handler setup

3. **`lib/providers/auth_provider.dart`**
   - Initializes PushNotificationService on user sign-in
   - Saves FCM token to Firestore `users/{uid}.fcmTokens` array
   - Uses `FieldValue.arrayUnion()` for token management

## BACKEND-ONLY TASK: Scraper + Dispatcher Architecture

### Files to Create
1. **`functions/index.js`** (NEW - Firebase Cloud Functions)
   - Dispatcher function triggered on `job_events/{eventId}` creation
   - User matching logic based on filters
   - FCM notification sending
   - Delivery tracking to prevent duplicates

2. **`functions/package.json`** (NEW)
   - Dependencies: firebase-admin, firebase-functions

3. **`functions/.gitignore`** (NEW)
   - Standard Node.js ignores

4. **`BACKEND_REFACTOR_PLAN.md`** (NEW)
   - Complete implementation guide for backend refactor

### Files to Modify
1. **`frontline_watcher.py`**
   - Remove: All per-user filter logic
   - Remove: All `ntfy` notification code
   - Remove: All auto-accept logic
   - Add: `publish_job_event()` function
   - Add: `generate_event_id()` function
   - Add: Firestore client initialization
   - Modify: Main loop to publish events instead of notifying users

2. **`requirements_raw.txt`**
   - Add: `firebase-admin>=6.0.0`
   - Add: `google-cloud-firestore>=2.0.0`

### Environment Variables to Add
Each scraper instance needs:
- `CONTROLLER_ID` (controller_1 through controller_5)
- `DISTRICT_ID` (Frontline district identifier)
- `FIREBASE_PROJECT_ID`
- `FIREBASE_CREDENTIALS_PATH`

## Firestore Schema Updates

### Collection: `users/{uid}`
**New Fields:**
- `fcmTokens: string[]` - Array of FCM device tokens
- `districtIds: string[]` - Array of district IDs user wants jobs from
- `includeAny: string[]` - Keywords that must appear (any)
- `excludeAny: string[]` - Keywords that must not appear (any)
- `includeCount: string[]` - Keywords to count for matching
- `includeMinMatches: number` - Minimum matches from includeCount
- `excludeCount: string[]` - Keywords to count for exclusion
- `excludeMinMatches: number` - Minimum matches to exclude
- `notifyEnabled: boolean` - Whether user wants notifications

### Collection: `job_events/{eventId}` (NEW)
**Fields:**
- `source: "frontline"`
- `controllerId: string`
- `districtId: string`
- `jobId: string`
- `jobUrl: string`
- `snapshotText: string`
- `keywords: string[]`
- `createdAt: Timestamp`
- `jobData: object`

### Subcollection: `job_events/{eventId}/deliveries/{uid}` (NEW)
**Fields:**
- `userId: string`
- `deliveredAt: Timestamp`

## Next Steps

### Flutter
1. Run `flutter pub get`
2. Configure Android/iOS platform settings (see FCM_IMPLEMENTATION_SUMMARY.md)
3. Test FCM token retrieval and storage
4. Test notification tap routing

### Backend
1. Refactor `frontline_watcher.py` per BACKEND_REFACTOR_PLAN.md
2. Set up Firebase Cloud Functions project
3. Deploy dispatcher function
4. Configure 5 scraper instances with offsets
5. Test end-to-end flow: scraper → event → dispatcher → FCM → app

