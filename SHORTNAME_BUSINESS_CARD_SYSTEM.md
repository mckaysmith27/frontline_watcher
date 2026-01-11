# Shortname & Business Card System

## Overview

Users can create a unique shortname that generates a public profile URL (`sub67.com/<shortname>`) and a shareable business card with QR code.

## Features

### 1. Shortname Management
- **Location**: Business Card screen (new icon in main navigation)
- **Requirements**: 
  - Minimum 3 characters
  - Must contain at least 1 number
  - Must be unique (checked in real-time)
- **Validation**: 
  - Real-time validation as user types
  - Shows "not available" (red) if taken
  - Shows "Required: @ least 3 char, 1 num" if format invalid
  - Shows "available!" (green) if valid and available

### 2. Business Card View
After submitting shortname, animates to business card showing:
- **QR Code** (right side) - Links to `sub67.com/<shortname>`
- **Name** (top left, big bold professional font, aligned right in row)
- **Phone Number** (next row, aligned right)
- **Email** (next row, aligned right)
- **URL** (bottom row, in its own container)

### 3. Public Booking Page
- **URL**: `sub67.com/<shortname>`
- **Content**:
  - User profile photo (centered)
  - Name, phone, email (centered below photo)
  - Calendar for date selection
  - "Book Sub" button

### 4. Booking Flow
1. Teacher visits `sub67.com/<shortname>`
2. Selects dates on calendar
3. Clicks "Book Sub" button
4. Modal opens with:
   - Terms of Service checkbox
   - ESS Username input
   - ESS Password input
   - Credentials saved locally (device keychain/browser localStorage)
5. WebView opens to ESS teacher portal
6. Guided overlay shows steps to submit request
7. Credentials auto-filled in ESS form

## Database Schema

### User Document (Updated)
```javascript
{
  shortname: string,        // Unique shortname for URL
  nickname: string,         // Display name (legacy, kept for compatibility)
  phoneNumber: string?,     // Phone for business card
  photoUrl: string?,        // Profile photo
  // ... other fields
}
```

## Cloud Functions

### `checkShortnameAvailability`
**Input:**
```javascript
{
  shortname: string
}
```

**Output:**
```javascript
{
  available: boolean,
  reason?: string
}
```

**Validation:**
- Minimum 3 characters
- Must contain at least 1 number
- Must be unique (case-insensitive)

### `getUserByShortname`
**Input:**
```javascript
{
  shortname: string
}
```

**Output:**
```javascript
{
  name: string,
  phone: string?,
  email: string?,
  photoUrl: string?
}
```

## Files Created/Modified

### New Files
- `lib/screens/profile/business_card_screen.dart` - Shortname management and business card
- `lib/screens/booking/booking_web_screen.dart` - Booking flow with WebView
- `web/booking.html` - Public booking page template

### Modified Files
- `lib/screens/main_navigation.dart` - Added business card icon
- `lib/screens/profile/profile_screen.dart` - Changed "Nickname" to "Shortname"
- `lib/services/social_service.dart` - Updated to use shortname
- `lib/providers/auth_provider.dart` - Added shortname field on signup
- `functions/index.js` - Added shortname validation and user lookup functions
- `pubspec.yaml` - Added `qr_flutter` and `clipboard` packages

## Navigation Updates

Main navigation now has 5 tabs:
1. Filters
2. Schedule
3. Community
4. **Business Card** (new - business card icon)
5. Settings

## UI/UX Details

### Shortname Input Screen
- Centered layout
- Shows `sub67.com/` prefix
- Large text input for shortname
- Real-time validation feedback
- Submit button (enabled only when available)

### Business Card
- White card with shadow
- Professional layout
- QR code on right (140x140)
- Name in large bold font (28px)
- Phone and email in smaller font (16px)
- URL at bottom in gray container
- Copy URL button
- Edit button to change shortname

### Booking Page (Web)
- Responsive design
- Profile photo and info centered
- Calendar component for date selection
- "Book Sub" call-to-action button
- Modal for terms and credentials
- WebView with guided overlay

## Security

- ESS credentials stored only locally (FlutterSecureStorage on mobile, localStorage on web)
- Never sent to backend
- Used only for auto-filling ESS forms in WebView
- Shortname is public (for booking page access)

## Next Steps

1. Deploy Cloud Functions:
   ```bash
   firebase deploy --only functions
   ```

2. Set up web hosting for booking pages:
   - Configure Firebase Hosting or similar
   - Route `sub67.com/<shortname>` to booking page
   - Pass shortname to page for user data lookup

3. Update Flutter dependencies:
   ```bash
   flutter pub get
   ```

4. Test shortname creation and business card generation
5. Test booking flow end-to-end
