# SSO Authentication vs App Users - Clarification

## 🔴 SSO Authentication (Controller Accounts)

**What it is**: Your 5 controller/master accounts need to log into **Frontline's website** to scrape jobs.

**Who**: Your 5 controller accounts (master accounts you own/control)

**Where**: Frontline's website (absencesub.frontlineeducation.com)

**Purpose**: Allow the scrapers to access Frontline's job listings

**Problem**: Frontline uses SSO (Single Sign-On) which requires human interaction that headless browsers can't automate.

**This is NOT**:
- ❌ About your app users
- ❌ About setting up filters
- ❌ About your Flutter app

**This IS**:
- ✅ About your scraper accounts logging into Frontline
- ✅ A one-time setup (authenticate once, save cookies)
- ✅ Needed so scrapers can access Frontline's website

---

## ✅ App Users (Your Flutter App)

**What it is**: End users (substitute teachers) who use your Flutter app.

**Who**: Your app users (substitute teachers)

**Where**: Your Flutter app (iOS/Android/Web)

**Purpose**: 
1. Users sign up/log in to your app (Firebase Auth)
2. Users set up their preferences (filters, keywords, dates)
3. Users receive notifications when jobs match their filters
4. Users accept jobs directly in the app

**This is separate from SSO** - app users don't need to deal with SSO at all.

---

## 🔄 How They Work Together

```
┌─────────────────────────────────────────────────────────┐
│  YOUR 5 CONTROLLER ACCOUNTS                             │
│  (Master accounts you own)                              │
│                                                          │
│  Problem: Need SSO authentication with Frontline        │
│  Solution: Manual login once, save cookies              │
│                                                          │
│  These accounts:                                         │
│  - Log into Frontline website                           │
│  - Scrape ALL available jobs                           │
│  - Publish to Firestore                                 │
│  - Do NOT have filters (they scrape everything)        │
└─────────────────────────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────┐
│  CLOUD FUNCTION                                          │
│                                                          │
│  Receives job events from scrapers                      │
│  Matches jobs to app user preferences                   │
│  Sends FCM notifications                                │
└─────────────────────────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────┐
│  YOUR APP USERS                                          │
│  (Substitute teachers using your app)                    │
│                                                          │
│  These users:                                            │
│  - Log into YOUR Flutter app (Firebase Auth)           │
│  - Set up THEIR filters/preferences                     │
│  - Receive notifications when jobs match                │
│  - Accept jobs in WebView                               │
│                                                          │
│  NO SSO needed - they use Firebase Auth                 │
└─────────────────────────────────────────────────────────┘
```

## 📋 Key Differences

| Aspect | Controller Accounts (SSO) | App Users |
|--------|---------------------------|-----------|
| **Who** | Your 5 master accounts | End users (substitute teachers) |
| **Where** | Frontline's website | Your Flutter app |
| **Purpose** | Scrape jobs | Receive notifications, accept jobs |
| **Authentication** | Frontline SSO (problematic) | Firebase Auth (working) |
| **Filters** | None (scrape everything) | Each user has their own |
| **Credentials** | Stored in Secret Manager | Stored in device keychain |

## 🎯 Answer to Your Question

**"Do they need to be set up as a user on my site?"**

**NO** - The controller accounts don't need to be set up as users on your site. They:
- Are separate master accounts you own
- Only log into Frontline's website (not your app)
- Scrape jobs and publish to Firestore
- Don't have filters or preferences

**Your app users** (the substitute teachers):
- DO sign up on your site/app
- DO set up filters/preferences
- DO receive notifications
- Use Firebase Auth (not SSO)

## 💡 Summary

**SSO Authentication** = Your 5 controller accounts logging into Frontline (one-time manual setup needed)

**App Users** = End users using your Flutter app (already working, no SSO needed)

The SSO issue only affects your controller accounts' ability to scrape Frontline. Once fixed, your app users will automatically start receiving notifications when jobs match their filters!

