# Authentication Explained - Two Different Systems

## 🔐 Two Separate Authentication Systems

There are **TWO completely different** authentication systems in play:

### 1. Scraper Authentication (SSO Issue) 🔴

**What**: The 5 controller/master accounts need to log into **Frontline's website** to scrape jobs.

**Who**: Your 5 controller accounts (master accounts you own)

**Where**: Frontline's website (absencesub.frontlineeducation.com)

**Problem**: Frontline uses SSO (Single Sign-On) which requires:
- Human interaction (clicking through authentication flows)
- 2FA/MFA steps
- Browser-based authentication that headless browsers can't handle automatically

**Solution**: Manual authentication once, then save the session cookies:
```bash
python3 save-auth-context.py  # Opens browser, you manually log in
./setup-sso-auth.sh           # Saves cookies to Secret Manager
```

**This is NOT about your app users** - this is about your scraper accounts logging into Frontline.

---

### 2. App User Authentication (Your Flutter App) ✅

**What**: End users log into **your Flutter app** and set up their preferences.

**Who**: Your app users (substitute teachers using your app)

**Where**: Your Flutter app (iOS/Android/Web)

**How it works**:
1. User signs up/logs in via Firebase Auth (email/password, Google, Apple)
2. User sets up automation preferences (filters, keywords, dates)
3. User's preferences saved to Firestore: `users/{uid}`
4. When scrapers find jobs matching user's filters → user gets FCM notification
5. User taps notification → opens WebView → user manually accepts job

**This is working fine** - no issues here!

---

## 🔄 How They Work Together

```
┌─────────────────────────────────────────────────────────┐
│  YOUR 5 CONTROLLER ACCOUNTS (Master Accounts)           │
│                                                          │
│  Need to authenticate with Frontline website (SSO)      │
│  ↓                                                       │
│  Scrape jobs from Frontline                             │
│  ↓                                                       │
│  Publish job events to Firestore                        │
└─────────────────────────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────┐
│  CLOUD FUNCTION DISPATCHER                              │
│                                                          │
│  Matches job events to user preferences                 │
│  ↓                                                       │
│  Sends FCM notifications to matched users              │
└─────────────────────────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────┐
│  YOUR APP USERS (End Users)                             │
│                                                          │
│  Logged into YOUR Flutter app (Firebase Auth)          │
│  Have set up filters/preferences                        │
│  ↓                                                       │
│  Receive FCM notification                               │
│  ↓                                                       │
│  Tap notification → Open WebView                        │
│  ↓                                                       │
│  Manually accept job (using their own Frontline login) │
└─────────────────────────────────────────────────────────┘
```

## 📋 Summary

**SSO Authentication** = Your 5 controller accounts logging into Frontline's website
- **NOT** about your app users
- **IS** about your scrapers being able to access Frontline
- **Problem**: Frontline's SSO requires human interaction
- **Solution**: Manual authentication once, save cookies

**App User Authentication** = End users logging into your Flutter app
- **NOT** related to SSO issue
- **IS** about users setting up preferences
- **Status**: Working fine (Firebase Auth)

## 🎯 Current Status

✅ **App Users**: Can sign up, log in, set preferences (working)
✅ **Cloud Function**: Processes events, matches users, sends notifications (working)
✅ **Scrapers**: Running automatically (but blocked by SSO)
⏳ **SSO Fix**: Need to manually authenticate controller accounts once

## 💡 Key Point

**Your app users don't need to do anything special** - they just:
1. Sign up/log in to your app
2. Set up their filters
3. Receive notifications when jobs match

**The SSO issue only affects your 5 controller accounts** that do the scraping. Once you fix SSO authentication for those accounts, they'll be able to scrape jobs, and your app users will start receiving notifications automatically.

