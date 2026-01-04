# Setup Checklist

Use this checklist to ensure all components are properly configured.

## Flutter App Setup

- [ ] Install Flutter SDK (3.0.0 or higher)
- [ ] Run `flutter pub get` to install dependencies
- [ ] Set up Firebase project
- [ ] Enable Firebase Authentication (Email/Password)
- [ ] Create Firestore database
- [ ] Enable Firebase Storage
- [ ] Download `google-services.json` (Android)
- [ ] Download `GoogleService-Info.plist` (iOS)
- [ ] Configure Firebase for Web (if deploying web)
- [ ] Update `lib/config/app_config.dart` with backend URL
- [ ] Test authentication flow
- [ ] Test filters functionality
- [ ] Test calendar and job sync

## Backend API Setup

- [ ] Set up backend server (Flask/FastAPI/Node.js/etc.)
- [ ] Implement `/api/start-automation` endpoint
- [ ] Implement `/api/stop-automation` endpoint
- [ ] Implement `/api/sync-jobs` endpoint
- [ ] Implement `/api/cancel-job` endpoint
- [ ] Implement `/api/remove-excluded-date` endpoint
- [ ] Set up credential encryption/decryption
- [ ] Configure Firebase Admin SDK
- [ ] Set up process management for Python scripts
- [ ] Configure API authentication (Firebase tokens)
- [ ] Set up error logging and monitoring
- [ ] Test all API endpoints

## Python Script Integration

- [ ] Modify `frontline_watcher.py` to accept API configuration
- [ ] Add API callback for job acceptance
- [ ] Add API callback for job filtering
- [ ] Test script with API configuration
- [ ] Set up script to run as service/daemon
- [ ] Configure automatic restarts on failure
- [ ] Test end-to-end automation flow

## Payment Integration

- [ ] Set up Stripe account (or payment provider)
- [ ] Configure payment API keys
- [ ] Implement payment processing in `payment_screen.dart`
- [ ] Test payment flow
- [ ] Set up webhook for payment confirmations
- [ ] Test credit addition after payment

## Security

- [ ] Review credential storage implementation
- [ ] Ensure all API endpoints require authentication
- [ ] Set up HTTPS for all API calls
- [ ] Review and test encryption/decryption
- [ ] Set up rate limiting
- [ ] Review Firestore security rules
- [ ] Review Firebase Storage security rules

## Testing

- [ ] Test user registration and login
- [ ] Test filter selection and saving
- [ ] Test premium unlock with promo codes
- [ ] Test credit purchase flow
- [ ] Test calendar date selection
- [ ] Test job sync functionality
- [ ] Test job cancellation
- [ ] Test social feed posting
- [ ] Test upvote/downvote functionality
- [ ] Test profile photo upload
- [ ] Test password reset
- [ ] Test dark/light mode toggle
- [ ] Test automation start/stop
- [ ] Test end-to-end job acceptance

## Deployment

- [ ] Build Android APK/AAB
- [ ] Build iOS IPA
- [ ] Build Web version
- [ ] Deploy backend API
- [ ] Deploy Python script service
- [ ] Configure production Firebase project
- [ ] Set up production environment variables
- [ ] Configure monitoring and alerts
- [ ] Set up backup procedures

## Documentation

- [ ] Update README with deployment instructions
- [ ] Document API endpoints
- [ ] Document environment variables
- [ ] Create user guide
- [ ] Document troubleshooting steps

## Launch Preparation

- [ ] Test with real ESS credentials (carefully)
- [ ] Verify all promo codes work
- [ ] Test payment processing
- [ ] Verify notification system (NTFY)
- [ ] Set up customer support email
- [ ] Prepare app store listings
- [ ] Create privacy policy and terms of service
- [ ] Set up analytics tracking
- [ ] Prepare marketing materials



