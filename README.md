# Sub67 - Frontline Watcher App

A Flutter mobile and web application for automating substitute teacher job bookings through the Frontline Education (ESS) platform.

## Features

- **Authentication**: Secure sign-up/login with password strength indicator
- **Filters**: Dynamic job filtering with keyword selection (green/gray/red tags)
- **Premium Features**: Unlockable premium keyword categories with promo codes
- **Automation**: Automated job acceptance based on user-defined filters
- **Schedule Management**: Calendar view with credit commitment and job tracking
- **Social Feed**: Reddit-style social feed with posts, upvotes, and engagement
- **Profile Management**: User profile with photo upload, verification, and settings
- **Dark/Light Mode**: Theme switching support

## Tech Stack

- **Frontend**: Flutter (Dart) - Android, iOS, Web
- **Backend**: Firebase (Authentication, Firestore, Storage)
- **Automation**: Python with Playwright for web scraping
- **Security**: Flutter Secure Storage for sensitive credentials

## Setup Instructions

### 1. Flutter Setup

```bash
# Install Flutter dependencies
flutter pub get

# Run the app
flutter run
```

### 2. Firebase Configuration

1. Create a Firebase project at https://console.firebase.google.com
2. Enable Authentication (Email/Password)
3. Create a Firestore database
4. Enable Firebase Storage
5. Download `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)
6. Place configuration files in appropriate directories:
   - Android: `android/app/google-services.json`
   - iOS: `ios/Runner/GoogleService-Info.plist`
   - Web: Follow Firebase web setup instructions

### 3. Backend Architecture

**Current Setup:**
- **Scrapers**: Running on AWS EC2 (2 controllers)
- **Cloud Functions**: Processes job events, sends FCM notifications
- **Firestore**: Stores job events and user data
- **FCM**: Push notifications to mobile devices

**Deployment:**
- EC2 scrapers: See `ec2/` directory for setup and deployment
- Cloud Functions: Deploy with `firebase deploy --only functions`

### 5. Environment Variables

Create a `.env` file for the Python script (if running locally):

```
FRONTLINE_USERNAME=your_ess_username
FRONTLINE_PASSWORD=your_ess_password
NTFY_TOPIC=your_ntfy_topic
```

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── models/                   # Data models
│   ├── job.dart
│   └── post.dart
├── providers/                # State management
│   ├── auth_provider.dart
│   ├── credits_provider.dart
│   ├── filters_provider.dart
│   └── theme_provider.dart
├── screens/                  # UI screens
│   ├── auth/
│   ├── filters/
│   ├── profile/
│   ├── schedule/
│   └── social/
├── services/                 # Business logic
│   ├── automation_service.dart
│   ├── job_service.dart
│   └── social_service.dart
└── widgets/                  # Reusable widgets
    ├── filter_column.dart
    ├── password_strength_indicator.dart
    └── tag_chip.dart
```

## Key Features Implementation

### Filters System

- Dynamic columns based on `filters_dict`
- Tag states: Green (included), Gray (neutral), Red (excluded), Purple (premium selected)
- Custom tag creation with validation
- Premium unlock with promo codes or payment

### Credits System

- Credits are consumed only when a job is successfully booked
- Calendar integration for committing credits to specific dates
- Credit packages: Daily, Weekly, Bi-weekly, Monthly, Annually

### Social Feed

- Real-time posts with Firestore streams
- Upvote/downvote system (1 vote per 10 credits)
- View tracking (10 views per unique user)
- Pinned posts (max 3 per user)
- Automatic engagement bonuses

## Security Considerations

- ESS credentials stored in Flutter Secure Storage (encrypted)
- Firebase Authentication for user accounts
- Backend API should handle credential encryption/decryption
- Never log or expose sensitive credentials

## Promo Codes

### Premium Unlock Codes
- PremiumVIP, VIP26, UrCute, PrettyCute, VIPCute, VIP67, VIP41, 4Libby<3, 4Libby, 4Kim, 4Kim<3

### Credit Purchase Codes (Bi-weekly only, one-time use)
- VIP10q7N0110, VIP108kN0210, VIP10p4N0310, VIP106aN0410, VIP10n5N0510, VIP103rN0610, VIP10m9N0710, VIP105kN0810, VIP102pN0910, VIP10r3N1010
- Also: VIP26, UrCute, PrettyCute, VIPCute, VIP67, VIP41, 4Libby<3, 4Libby, 4Kim, 4Kim<3

## Payment Integration

The app includes payment UI but requires integration with:
- Stripe (recommended)
- In-App Purchase (for mobile)
- PayPal, Venmo, Apple Pay, Google Pay

Update `lib/screens/filters/payment_screen.dart` with actual payment processing.

## License

Proprietary - All rights reserved

## Support

For support, email: sub67support@gmail.com




