# Security Architecture - Credential Management

## Overview

This document outlines the secure credential management architecture that complies with best practices and ensures user credentials are never stored in databases or transmitted to backend services.

## Architecture Principles

1. **5 Controller Accounts (Hardcoded)**: Partner/service accounts for scraping jobs
2. **End User Credentials (Device-Only)**: Stored exclusively in device keychain
3. **No Backend Credential Storage**: Backend never receives or stores user Frontline credentials
4. **Direct Authentication**: Users authenticate directly with Frontline in-app

## Component Breakdown

### 1. Cloud Run Scrapers (5 Instances)

**Purpose**: Discover and publish job events to Firestore

**Credentials**:
- **Type**: Partner/Service accounts (hardcoded)
- **Storage**: Google Secret Manager
- **Usage**: Used by 5 Cloud Run Jobs to scrape Frontline for available jobs
- **Scope**: Read-only job discovery

**Configuration**:
```bash
# Each controller has its own credentials in Secret Manager
frontline-username (controller account)
frontline-password (controller account)
```

**Security**:
- ✅ Stored in Google Secret Manager (encrypted at rest)
- ✅ Accessible only to Cloud Run service accounts
- ✅ Never exposed to end users
- ✅ Rotated independently of user accounts

### 2. End User Credentials (Device-Only)

**Purpose**: Allow users to accept jobs directly in-app

**Storage**: FlutterSecureStorage (device keychain)
- **iOS**: Keychain Services
- **Android**: EncryptedSharedPreferences (backed by Android Keystore)
- **Web**: Encrypted localStorage (browser security)

**Code Location**: `lib/providers/auth_provider.dart`
```dart
// Credentials stored with user-specific keys
await _secureStorage.write(
  key: 'ess_username_${_user!.uid}',
  value: username,
);
await _secureStorage.write(
  key: 'ess_password_${_user!.uid}',
  value: password,
);
```

**Usage**:
- ✅ Used ONLY for in-app job acceptance via WebView
- ✅ Never sent to backend APIs
- ✅ Never stored in Firestore
- ✅ Never logged or exposed
- ✅ Deleted when user signs out

**Security**:
- ✅ Encrypted at rest (device keychain)
- ✅ Protected by device biometrics/passcode (where supported)
- ✅ Isolated per user (uid-based keys)
- ✅ Automatically cleared on app uninstall

### 3. Backend Services

**What Backend Receives**:
- ✅ User preferences (filters, keywords, committed dates)
- ✅ User ID (Firebase Auth UID)
- ✅ FCM tokens (for notifications)
- ❌ **NEVER receives Frontline credentials**

**What Backend Does**:
1. **Cloud Run Scrapers**: Discover jobs using controller accounts
2. **Cloud Functions Dispatcher**: Match job events to user preferences
3. **FCM Notifications**: Send job alerts to matched users
4. **Firestore**: Store job events and user preferences (no credentials)

### 4. Job Acceptance Flow

**Current Implementation**:
1. User receives FCM notification with job URL
2. User taps notification → Opens `JobWebViewScreen`
3. User manually logs into Frontline in WebView (using device-stored credentials if available)
4. User manually clicks "Accept" button
5. Job is accepted directly with Frontline (no backend involved)

**Future Enhancement** (Optional):
- Pre-authenticate WebView using device-stored credentials
- Auto-fill login form (credentials never leave device)
- User still manually clicks "Accept" (no auto-accept for compliance)

## Data Flow

```
┌─────────────────────────────────────────────────────────────┐
│                    CLOUD RUN SCRAPERS                        │
│  (5 instances with hardcoded controller accounts)            │
│                                                               │
│  Controller Accounts → Frontline → Job Events → Firestore    │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│              CLOUD FUNCTIONS DISPATCHER                      │
│                                                               │
│  Job Events + User Preferences → Match → FCM Notifications │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                    FLUTTER APP (User Device)                │
│                                                               │
│  FCM Notification → WebView → User Accepts Job              │
│                                                               │
│  Credentials: Device Keychain Only (FlutterSecureStorage)    │
└─────────────────────────────────────────────────────────────┘
```

## Security Compliance

### ✅ Best Practices Followed

1. **Zero-Knowledge Architecture**: Backend never sees user Frontline credentials
2. **Device-Only Storage**: Credentials encrypted in device keychain
3. **No Credential Transmission**: Credentials never sent over network (except to Frontline directly)
4. **Isolated Storage**: Per-user encryption keys prevent cross-user access
5. **Automatic Cleanup**: Credentials deleted on sign-out/uninstall
6. **Separate Accounts**: Controller accounts isolated from user accounts

### ✅ Compliance Benefits

- **GDPR**: No sensitive credentials in databases
- **CCPA**: Minimal data collection (preferences only)
- **SOC 2**: Reduced attack surface (no credential database)
- **PCI DSS**: No payment credentials stored (if applicable)
- **FERPA**: Educational data handled securely

## Migration Notes

### What Changed

**Before** (Insecure):
- `automation_service.dart` sent credentials to backend API
- Backend would have stored/processed user credentials
- Higher security risk

**After** (Secure):
- Credentials stored only in device keychain
- Backend receives only preferences (filters, dates)
- Zero credential exposure

### Code Changes

1. **`lib/services/automation_service.dart`**:
   - Removed `essUsername` and `essPassword` parameters
   - Removed backend API credential transmission
   - Now only saves user preferences to Firestore

2. **`lib/screens/filters/automation_bottom_sheet.dart`**:
   - Credentials saved to FlutterSecureStorage (device keychain)
   - No credentials sent to backend

3. **`lib/providers/auth_provider.dart`**:
   - Already using FlutterSecureStorage ✅
   - No changes needed

## Testing

### Verify Credential Isolation

1. **Check Firestore**: No `essUsername` or `essPassword` fields in user documents
2. **Check Network**: No credentials in API requests (use network inspector)
3. **Check Logs**: No credentials in application logs
4. **Check Device**: Credentials exist only in keychain (verify with device tools)

### Verify Functionality

1. **Automation Setup**: User can set preferences without credentials being sent
2. **Job Notifications**: Users receive notifications based on preferences
3. **Job Acceptance**: Users can accept jobs in WebView (manual process)

## Troubleshooting

**"Credentials not found"**:
- Check FlutterSecureStorage permissions
- Verify user is signed in
- Check device keychain access

**"Automation not working"**:
- Verify Cloud Run scrapers are running
- Check Firestore `job_events` collection
- Verify user preferences are saved in Firestore

**"Can't accept jobs"**:
- User must manually log into Frontline in WebView
- Credentials in keychain can pre-fill login (future enhancement)
- No auto-accept (compliance requirement)

## Future Enhancements

1. **WebView Pre-Authentication**: Use device credentials to auto-fill login form
2. **Biometric Protection**: Require biometrics to access stored credentials
3. **Credential Rotation**: Allow users to update credentials without re-entering all preferences
4. **Session Management**: Cache Frontline session cookies (device-only)

