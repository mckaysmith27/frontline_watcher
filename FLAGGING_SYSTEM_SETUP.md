# User Flagging System Setup Guide

## Overview

Users can flag posts they deem inappropriate. When 2+ users flag a post, it's automatically sent to the admin approval queue.

## Features

1. **User Flagging**: Any user can flag/unflag posts
2. **Auto-Queue**: Posts with 2+ flags are sent to admin queue
3. **User Experience**: Flagged posts are hidden/blocked for users who flagged them
4. **Author Experience**: Post authors always see their posts normally
5. **Admin Visibility**: Flagged posts show flag icon in admin queue

## How It Works

### User Flagging Flow

1. **User Flags Post**: User toggles flag icon on a post
   - Post is covered/broken for that user
   - Shows "Flagged as inappropriate" message
   - User can toggle it off to see the post again

2. **2+ Flags Trigger**: When 2 or more users flag a post:
   - Post is marked as `isFlagged: true`
   - Post status changes to `pending` (if it was `approved`)
   - Post appears in admin approval queue with flag icon
   - Post is hidden from all other users (except author)

3. **Admin Review**: Admin sees flagged post in queue:
   - Flag icon indicates 2+ users flagged it
   - Admin can take any action (block user, block image, block content, approve)

4. **After Admin Action**:
   - If approved (fully or partially): Post becomes visible to others, but users who flagged it still see it blocked
   - If user is blocked: All their posts are deleted immediately
   - If content/image blocked: Post shows as partially approved

### Post Visibility Rules

- **Author**: Always sees their own posts normally, regardless of flags/approval
- **Users who flagged**: See the post as blocked/covered with "Flagged as inappropriate"
- **Other users**: 
  - If post has 2+ flags and not approved → Hidden
  - If post is approved → Visible
  - If post is partially approved → Visible with restrictions

## Database Schema

### Post Document (Updated)
```javascript
{
  // ... existing fields
  flagCount: number,        // Number of users who flagged
  isFlagged: boolean,       // True if 2+ flags
  // ... other fields
}
```

### Flags Subcollection
```
posts/{postId}/flags/{userId}
{
  flagged: boolean,
  flaggedAt: Timestamp,
  userId: string
}
```

## API Methods

### FlaggingService

```dart
// Check if user has flagged a post
Future<bool> hasUserFlagged(String postId)

// Toggle flag on/off
Future<void> toggleFlag(String postId, bool isFlagged)

// Stream of flag status
Stream<bool> hasUserFlaggedStream(String postId)
```

### Cloud Function: `togglePostFlag`

**Input:**
```javascript
{
  postId: string,
  isFlagged: boolean
}
```

**Behavior:**
- Adds/removes flag from `posts/{postId}/flags/{userId}`
- Updates `flagCount` on post
- If `flagCount >= 2`: Sets `isFlagged: true` and changes status to `pending` if needed
- If `flagCount < 2`: Sets `isFlagged: false`

## Frontend Implementation

### Flag Toggle Button

Replace the thumbtack icon on posts with a flag toggle icon:

```dart
// In post_card.dart or similar
IconButton(
  icon: Icon(
    hasFlagged ? Icons.flag : Icons.outlined_flag,
    color: hasFlagged ? Colors.red : Colors.grey,
  ),
  onPressed: () async {
    await flaggingService.toggleFlag(postId, !hasFlagged);
  },
)
```

### Displaying Flagged Posts

When a user has flagged a post, show it as blocked:

```dart
if (hasUserFlagged) {
  return Container(
    child: Column(
      children: [
        Text('Flagged as inappropriate'),
        // Optionally show toggle to unflag
        TextButton(
          onPressed: () => flaggingService.toggleFlag(postId, false),
          child: Text('Show post'),
        ),
      ],
    ),
  );
}
```

### Admin Queue Display

In admin approval page, show flag icon for flagged posts:

```dart
if (post.isFlagged) {
  Icon(Icons.flag, color: Colors.red),
  Text('${post.flagCount} users flagged this post'),
}
```

## Firestore Security Rules

Flags subcollection is accessible to:
- Users can read/write their own flag document
- Admins can read all flags

## Testing

1. **Single Flag**: User flags post → Post blocked for that user only
2. **Two Flags**: Second user flags → Post sent to admin queue, hidden from others
3. **Unflag**: User unflags → Post visible again (if < 2 total flags)
4. **Admin Approval**: Admin approves flagged post → Visible to others, but still blocked for users who flagged it
5. **User Block**: Admin blocks user → All their posts deleted immediately

## Deployment

1. Deploy Cloud Functions:
   ```bash
   firebase deploy --only functions
   ```

2. Deploy Firestore Rules:
   ```bash
   firebase deploy --only firestore:rules
   ```

3. Update Flutter dependencies:
   ```bash
   flutter pub get
   ```

## Notes

- Users can toggle their flag on/off at any time
- Flag count is maintained even if some users unflag
- Once a post reaches 2+ flags, it stays in queue until admin action
- Post authors never see their posts as flagged
- When admin blocks a user, all their posts are deleted (not just hidden)
