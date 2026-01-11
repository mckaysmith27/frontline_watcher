# Admin System Setup Guide

## Overview

This document explains the admin approval system for posts. The system automatically detects potentially risky content and requires admin approval before posts are visible to other users.

## Features

1. **Automatic Content Detection**: Posts with links, images, LGBTQ+ emojis, or sexual emojis are flagged for approval
2. **User Experience**: Users see their posts as if they posted successfully, but others don't see them until approved
3. **Admin Approval Queue**: Admins can review and approve/reject posts
4. **Partial Approval**: Admins can block images or content separately while allowing the rest
5. **User Blocking**: Admins can block malicious users and their IPs

## Setting Up Admin Users

To make a user an admin, update their Firestore document:

```javascript
// In Firebase Console or via Cloud Function
await admin.firestore().collection('users').doc('USER_ID').update({
  role: 'admin',  // or
  isAdmin: true
});
```

Or manually in Firestore Console:
1. Go to `users` collection
2. Find the user document
3. Add field: `role` = `"admin"` (or `isAdmin` = `true`)

## Post Approval Statuses

- **`approved`**: Post is visible to everyone (default for safe posts)
- **`pending`**: Post requires admin approval (user sees it, others don't)
- **`partially_approved`**: Post is partially visible (some content blocked)
- **`rejected`**: Post was rejected (user still sees it on their page)

## Content Detection Rules

Posts are flagged for approval if they contain:

1. **Links**: Any URL pattern (http, https, www, or domain patterns)
2. **Images**: Any attached images
3. **LGBTQ+ Emojis**: 🏳️‍🌈, 🏳️‍⚧️, ⚧️, etc.
4. **Sexual Emojis**: 🍆, 🍑, 🍌, 🌭, 💦, 👅, 💋, etc.

## Admin Actions

### 1. Block User (Flag + Person Icon)
- Blocks the user completely from the app
- Blacklists their IP addresses if available
- Shows confirmation dialog: "Are you sure you want to block this user and associated IP(s) from the app?"
- Updates post status to `rejected`

### 2. Block Image (Flag + Photo Icon)
- Blocks the image from showing to others
- User still sees their image
- Others see broken image placeholder
- Sets `imageBlocked: true` and `approvalStatus: 'partially_approved'`

### 3. Block Content (Flag + Message Icon)
- Blocks the message text from showing to others
- User still sees their content on their mypage
- Others don't see the content
- Sets `contentBlocked: true` and `approvalStatus: 'partially_approved'`

### 4. Full Approval (Checkmark Icon)
- Approves the post completely
- Makes it visible to everyone
- Sets `approvalStatus: 'approved'`, `imageBlocked: false`, `contentBlocked: false`

## Database Schema

### Post Document
```javascript
{
  userId: string,
  userNickname: string,
  userPhotoUrl: string?,
  content: string,
  imageUrls: string[],
  createdAt: Timestamp,
  approvalStatus: 'approved' | 'pending' | 'partially_approved' | 'rejected',
  imageBlocked: boolean?,
  contentBlocked: boolean?,
  blockedReason: string?,
  // ... other fields
}
```

### User Document (Admin)
```javascript
{
  role: 'admin',  // or
  isAdmin: true,
  // ... other fields
}
```

### Blocked IPs Collection
```javascript
{
  userId: string,
  ipAddresses: string[],
  blockedAt: Timestamp,
  blockedBy: string (admin userId)
}
```

## Cloud Functions

The following Cloud Functions are available:

1. **`isAdmin`**: Check if current user is admin
2. **`blockUser`**: Block user and their IPs
3. **`blockImage`**: Block image from post
4. **`blockContent`**: Block content from post
5. **`approvePost`**: Fully approve post

## Firestore Security Rules

- Admins can read/write any user document
- Admins can read/update any post
- Regular users can only see approved posts (except their own)
- Blocked IPs collection is admin-only

## Frontend Implementation Notes

1. **Admin Navigation**: Add a second nav bar below the first with a social post icon with checkmark for the "Approvals" page
2. **Approval Queue**: Show pending and partially approved posts
3. **Action Buttons**: Four icons per post:
   - Flag + Person (block user)
   - Flag + Photo (block image)
   - Flag + Message (block content)
   - Checkmark (approve)
4. **Confirmation Dialog**: Show confirmation when blocking user

## Testing

1. Create a post with a link → Should be flagged as `pending`
2. Create a post with an image → Should be flagged as `pending`
3. Create a post with 🍆 emoji → Should be flagged as `pending`
4. As admin, approve post → Should become `approved`
5. As admin, block image → Should become `partially_approved` with `imageBlocked: true`
6. As regular user, view feed → Should only see approved posts (except own)

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

## Next Steps

1. Create the admin approval UI page in Flutter
2. Add admin navigation bar
3. Implement the four action buttons
4. Add confirmation dialogs
5. Test the full flow
