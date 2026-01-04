# Firebase Quick Start Guide

## Quick Setup Steps

### 1. Create Firebase Project (5 minutes)

1. Go to https://console.firebase.google.com/
2. Click **"Add project"**
3. Name it: `Sub67`
4. Click through the setup (disable analytics if you want)
5. Click **Continue**

### 2. Enable Services (2 minutes)

#### Authentication
- Click **Authentication** → **Get started**
- Click **Sign-in method** → **Email/Password** → **Enable** → **Save**

#### Firestore
- Click **Firestore Database** → **Create database**
- Choose **Start in test mode**
- Select location → **Enable**

#### Storage
- Click **Storage** → **Get started**
- Choose **Start in test mode**
- Select location → **Done**

### 3. Get Your Firebase Config (1 minute)

1. Click **⚙️** (gear icon) → **Project settings**
2. Scroll to **"Your apps"** section
3. Click **Web icon** (`</>`)
4. Register app: Name it `Sub67 Web`
5. Click **Register app**
6. **Copy the config object** - you'll see something like:

```javascript
const firebaseConfig = {
  apiKey: "AIzaSyC...",
  authDomain: "sub67-xxxxx.firebaseapp.com",
  projectId: "sub67-xxxxx",
  storageBucket: "sub67-xxxxx.appspot.com",
  messagingSenderId: "123456789",
  appId: "1:123456789:web:abcdef123456"
};
```

### 4. Add Config to Your App (2 minutes)

Open `lib/config/firebase_config.dart` and replace the `web` configuration:

```dart
static const FirebaseOptions web = FirebaseOptions(
  apiKey: 'AIzaSyC...',  // ← Paste your apiKey here
  appId: '1:123456789:web:abcdef123456',  // ← Paste your appId here
  messagingSenderId: '123456789',  // ← Paste your messagingSenderId here
  projectId: 'sub67-xxxxx',  // ← Paste your projectId here
  authDomain: 'sub67-xxxxx.firebaseapp.com',  // ← Paste your authDomain here
  storageBucket: 'sub67-xxxxx.appspot.com',  // ← Paste your storageBucket here
);
```

### 5. Test It! (1 minute)

```bash
flutter run -d chrome
```

The app should now connect to Firebase! 🎉

## What You'll See

- ✅ No Firebase errors in console
- ✅ Login screen appears
- ✅ You can create an account
- ✅ You can sign in

## Security Rules (Important for Production)

After testing, update your Firestore and Storage rules in Firebase Console:

**Firestore Rules** (Firestore Database → Rules):
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

**Storage Rules** (Storage → Rules):
```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /users/{userId}/{allPaths=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    match /{allPaths=**} {
      allow read, write: if false;
    }
  }
}
```

## Troubleshooting

**"Firebase App not initialized"**
- Check that you've replaced all the placeholder values in `firebase_config.dart`
- Make sure there are no typos in the config values

**"Permission denied"**
- Make sure you're signed in (create an account first)
- Check that Firestore is in "test mode" (allows reads/writes for 30 days)

**Still having issues?**
- Check the browser console for specific error messages
- Make sure `localhost` is in authorized domains (Firebase Console → Authentication → Settings)

---

**Total time: ~10 minutes** ⏱️


