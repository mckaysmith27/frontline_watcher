# Firebase Setup Guide

This guide will help you set up Firebase for your Flutter app.

## Step 1: Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click **"Add project"** or **"Create a project"**
3. Enter project name: `Sub67` (or your preferred name)
4. Click **Continue**
5. **Disable Google Analytics** (optional, or enable if you want it)
6. Click **Create project**
7. Wait for project creation to complete, then click **Continue**

## Step 2: Enable Required Services

### Enable Authentication

1. In Firebase Console, click **Authentication** in the left sidebar
2. Click **Get started**
3. Click on **Sign-in method** tab
4. Click on **Email/Password**
5. Toggle **Enable** to ON
6. Click **Save**

### Enable Firestore Database

1. Click **Firestore Database** in the left sidebar
2. Click **Create database**
3. Select **Start in test mode** (for development)
4. Choose a location (select closest to you)
5. Click **Enable**

### Enable Storage

1. Click **Storage** in the left sidebar
2. Click **Get started**
3. Select **Start in test mode** (for development)
4. Click **Next**
5. Choose a location (same as Firestore if possible)
6. Click **Done**

## Step 3: Register Web App

1. In Firebase Console, click the **gear icon** (⚙️) next to "Project Overview"
2. Click **Project settings**
3. Scroll down to **"Your apps"** section
4. Click the **Web icon** (`</>`)
5. Register app:
   - **App nickname**: `Sub67 Web` (or any name)
   - **Firebase Hosting**: Leave unchecked (unless you want it)
6. Click **Register app**
7. **Copy the Firebase configuration object** - it looks like this:

```javascript
const firebaseConfig = {
  apiKey: "AIza...",
  authDomain: "your-project.firebaseapp.com",
  projectId: "your-project-id",
  storageBucket: "your-project.appspot.com",
  messagingSenderId: "123456789",
  appId: "1:123456789:web:abcdef"
};
```

## Step 4: Add Firebase Config to Flutter App

You have two options:

### Option A: Add to `lib/config/firebase_config.dart` (Recommended)

Create a new file with your Firebase config (see instructions below).

### Option B: Add to `web/index.html` (Alternative)

Add Firebase SDK scripts to `web/index.html` (we'll update this file).

## Step 5: Update Security Rules (Important!)

### Firestore Security Rules

1. Go to **Firestore Database** → **Rules** tab
2. Update rules to allow authenticated users:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can read/write their own data
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
      
      // Users can read/write their own scheduled jobs
      match /scheduledJobs/{jobId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
      
      // Users can read/write their own posts
      match /posts/{postId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
    }
    
    // Public posts (social feed)
    match /posts/{postId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == resource.data.userId;
    }
    
    // Default: deny all
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

3. Click **Publish**

### Storage Security Rules

1. Go to **Storage** → **Rules** tab
2. Update rules:

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // Users can upload/read their own files
    match /users/{userId}/{allPaths=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Default: deny all
    match /{allPaths=**} {
      allow read, write: if false;
    }
  }
}
```

3. Click **Publish**

## Step 6: Test the Setup

After completing all steps, run your Flutter app:

```bash
flutter run -d chrome
```

The app should now connect to Firebase successfully!

## Troubleshooting

### "Firebase App not initialized"
- Make sure you've added the Firebase config to `lib/config/firebase_config.dart`
- Check that `main.dart` is importing and using the config

### "Permission denied" errors
- Check Firestore and Storage security rules
- Make sure you're signed in (authentication required)

### "Auth domain not authorized"
- Go to Firebase Console → Authentication → Settings → Authorized domains
- Make sure `localhost` is in the list (it should be by default)

## Next Steps

After Firebase is set up:
1. Test user registration/login
2. Test creating documents in Firestore
3. Test uploading files to Storage
4. Update security rules for production

---

**Note**: For production, you'll want to:
- Update security rules to be more restrictive
- Enable additional authentication methods if needed
- Set up proper error handling
- Consider enabling Firebase Analytics



