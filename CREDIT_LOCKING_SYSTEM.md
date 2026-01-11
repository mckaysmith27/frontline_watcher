# Credit-Based Feature Locking System

## Overview

Certain features are locked when users have no credits AND no green days (committed dates). Users can still access the community page and settings page regardless of their credit status.

## Locked Features

### 1. Apply Filters Button
- **Location**: Filters Screen (bottom navigation bar)
- **Lock Condition**: Locked when `credits == 0 AND committedDates.isEmpty`
- **Behavior When Locked**:
  - Button shows lock icon
  - Button is disabled (grayed out)
  - Label shows "Apply Filters (Locked)"
- **Behavior When Unlocked**:
  - Button shows checkmark icon
  - Button is enabled
  - Label shows "Apply Filters"
- **Filtering Behavior**:
  - When locked: Only filters for committed dates (green days) are active
  - When unlocked: Full filtering for all dates
  - Notifications are automatically disabled when locked

### 2. Sync Calendar Button
- **Location**: Schedule Screen (bottom navigation bar)
- **Lock Condition**: Locked when `credits == 0 AND committedDates.isEmpty`
- **Behavior When Locked**:
  - Button shows lock icon
  - Button is disabled (grayed out)
  - Label shows "Sync Calendar (Locked)"
  - Button is always visible (never disappears)
- **Behavior When Unlocked**:
  - Button shows sync icon (circular arrows - `Icons.sync`)
  - Button is enabled
  - Label shows "Sync Calendar"
  - Button is always visible

## Always Available Features

These features are always accessible regardless of credit status:

1. **Community Page** (Social features)
   - Users can view and interact with posts
   - Users can create posts
   - All social features remain active

2. **Settings Page**
   - Users can access all settings
   - Profile management
   - Account settings

## Automatic Notification Management

- **Auto-Disable**: When user has `credits == 0 AND committedDates.isEmpty`, notifications are automatically disabled
- **Auto-Enable**: When user gains credits or commits dates, notifications can be re-enabled by applying filters
- **Monitoring**: The `CreditsProvider` automatically checks and updates notification status when credits or committed dates change

## Implementation Details

### Lock Condition Logic

```dart
final isLocked = creditsProvider.credits == 0 && 
                creditsProvider.committedDates.isEmpty;
```

### Filter Application Logic

When locked:
- Only committed dates (green days) are included in filtering
- Date keywords for other days are NOT added to included words
- Notifications are disabled (`notifyEnabled: false`)

When unlocked:
- All date keywords are added to included words
- Full filtering is active
- Notifications are enabled (`notifyEnabled: true`)

### Icon States

**Apply Filters Button:**
- Locked: `Icons.lock`
- Unlocked: `Icons.check_circle`

**Sync Calendar Button:**
- Locked: `Icons.lock`
- Unlocked: `Icons.sync` (circular arrows)

## User Experience Flow

1. **User has credits or green days**:
   - Apply Filters button: Enabled with checkmark
   - Sync Calendar button: Enabled with sync icon
   - Notifications: Enabled
   - Full filtering: Active

2. **User runs out of credits AND has no green days**:
   - Apply Filters button: Disabled with lock icon
   - Sync Calendar button: Disabled with lock icon
   - Notifications: Automatically disabled
   - Filtering: Only works for committed dates (if any)

3. **User gains credits or commits dates**:
   - Buttons become enabled again
   - User can re-apply filters to enable notifications
   - Full filtering becomes active

## Database Updates

When locked, the following Firestore fields are updated:
- `notifyEnabled: false` - Disables push notifications
- `automationConfig.committedDates` - Only contains committed dates (green days)

## Testing Scenarios

1. **No Credits, No Green Days**:
   - ✅ Apply Filters button shows lock icon and is disabled
   - ✅ Sync Calendar button shows lock icon and is disabled
   - ✅ Notifications are automatically disabled
   - ✅ Community page is accessible
   - ✅ Settings page is accessible

2. **Has Credits, No Green Days**:
   - ✅ Apply Filters button is enabled
   - ✅ Sync Calendar button is enabled
   - ✅ Notifications can be enabled

3. **No Credits, Has Green Days**:
   - ✅ Apply Filters button is enabled
   - ✅ Sync Calendar button is enabled
   - ✅ Filtering works for green days only
   - ✅ Notifications can be enabled

4. **Has Credits AND Green Days**:
   - ✅ All features fully enabled
   - ✅ Full filtering active
   - ✅ Notifications enabled
