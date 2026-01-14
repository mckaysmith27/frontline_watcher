# Business Card System Redesign - Implementation Summary

## Overview
Complete redesign of the business card system with form-based card creation, simplified ordering, and admin order management.

## ✅ Completed Changes

### 1. Business Card Screen Redesign (`lib/screens/profile/business_card_screen.dart`)
- **Card as Form**: Initial page now shows the business card as an editable form
- **Business Card Proportions**: Card sized like a real business card (approximately 3.5" x 2" aspect ratio)
- **Sharp Corners**: Removed border radius for sharp corners like a physical business card
- **Form Fields**:
  - First Name and Last Name on first row
  - Phone and Email on second row (left side)
  - QR Code placeholder on right side (shows dummy message until form complete)
  - Shortname field at bottom: `sub67.com/<shortname>` (no https:// or www.)
- **Auto-save**: All fields save to Firestore in real-time as user types
- **QR Code**: Shows dummy QR code with message until form is complete and terms are agreed
- **Terms & Conditions**: Custom terms widget below card explaining data use permissions
- **Checkout Button**: Only enabled when form is complete and terms are agreed

### 2. Order Screen Updates (`lib/screens/profile/business_card_order_screen.dart`)
- **Renamed**: "Order Business Cards" → "Order Cards"
- **Card Preview**: Shows non-editable business card preview above quantity selection
- **Quantity Options**: 
  - Removed "Business" from labels (now "5 Cards", "10 Cards", etc.)
  - "20 Cards" shows "(recommended)" in italic font
- **Pricing & Discounts**:
  - Users with credits/subscription get:
    - 10% off on orders up to 20 cards
    - 20% off on orders 50 cards or more
  - Regular prices shown crossed out when discount applies
- **Shipping Options**:
  - USPS 10-14 business days (free, default)
  - USPS 4-7 business days ($3.99)
- **Removed**: Free 5 cards offer for credits/subscription
- **Access**: All users can now use business card feature (no credits/subscription required)

### 3. Admin Orders Queue Screen (`lib/screens/admin/business_card_orders_queue_screen.dart`)
- **New Screen**: Admin-only screen for managing business card orders
- **Order Display**:
  - Shows all orders sorted by creation date (newest first)
  - Uncompleted orders at top
  - Completed orders at bottom (grayed out with "COMPLETED" badge)
- **Order Information**:
  - Order ID (7-character alphanumeric)
  - User name and shortname
  - Quantity and total price
  - Order date
  - Shipping address
  - Business card image preview (when available)
- **Admin Actions**:
  - ✅ **Mark Order Complete**: Moves order to bottom, marks as completed
  - 🖨️ **Print Order**: Print individual order (placeholder for now)
  - 🖨️ **Print All Uncompleted**: Batch print all pending orders (placeholder for now)

### 4. Cloud Function Updates (`functions/index.js`)
- **Order ID Generation**: Random 7-character alphanumeric order IDs
- **New Order Structure**:
  ```javascript
  {
    orderId: string,           // 7-char alphanumeric
    userId: string,
    shortname: string,
    firstName: string,
    lastName: string,
    userPhone: string?,
    userEmail: string?,
    orderQuantity: number,
    orderTimestamp: Timestamp,
    basePrice: number,
    discount: number,          // 0.10 or 0.20
    discountedPrice: number,
    shippingOption: string,    // 'standard' or 'express'
    shippingPrice: number,
    totalPrice: number,
    shippingAddress: object,
    status: string,            // 'pending', 'completed'
    cardImageUrl: string?,     // For printable image (TODO)
    estimatedDelivery: string,
    createdAt: Timestamp,
    completedAt: Timestamp?,
  }
  ```
- **Discount Logic**: Calculates discounts based on user credits/subscription status
- **Image Generation**: Placeholder for printable business card image (TODO)

### 5. Terms and Conditions
- **Custom Terms**: New terms specific to business cards
- **Permissions Granted**:
  - Sub67 and affiliates can use form data
  - Data transmission to visitors accessing professional page
  - Use for preferred sub, reservations, professional contact
  - Advertising and promotion per iOS/Google Play/web policies
- **Legal Wording**: Properly formatted terms explaining data use

## ⚠️ Pending Items

### 1. Business Card Image Generation
- **Status**: Placeholder implemented
- **Requirement**: Generate printable-quality business card images
- **Options**:
  - Use Flutter `screenshot` package to capture widget as image
  - Use Cloud Function with image generation library (canvas, sharp, etc.)
  - Use external service for image generation
- **Storage**: Images should be stored in Firebase Storage and URL saved to order document

### 2. Print Functionality
- **Status**: Placeholders implemented
- **Requirement**: Implement actual print functionality for:
  - Individual order printing
  - Batch printing of uncompleted orders
- **Options**:
  - Use Flutter printing packages (`printing`, `pdf`)
  - Generate PDFs server-side via Cloud Function
  - Integrate with printing service API

## Database Schema Updates

### Business Card Orders Collection
```javascript
{
  orderId: string,              // 7-char alphanumeric
  userId: string,
  shortname: string,
  firstName: string,
  lastName: string,
  userPhone: string?,
  userEmail: string?,
  orderQuantity: number,
  orderTimestamp: Timestamp,
  basePrice: number,
  discount: number,
  discountedPrice: number,
  shippingOption: string,
  shippingPrice: number,
  totalPrice: number,
  shippingAddress: {
    name: string,
    address1: string,
    address2: string?,
    city: string,
    state: string,
    zip: string,
  },
  status: 'pending' | 'completed',
  cardImageUrl: string?,        // Firebase Storage URL
  estimatedDelivery: string,
  createdAt: Timestamp,
  completedAt: Timestamp?,
}
```

### User Document Updates
- `firstName`: string (auto-saved from business card form)
- `lastName`: string (auto-saved from business card form)
- `phoneNumber`: string (auto-saved from business card form)
- `email`: string (auto-saved from business card form)
- `shortname`: string (auto-saved from business card form)

## Firestore Rules
- ✅ Already configured for `business_card_orders` collection
- Users can read their own orders
- Admins can read all orders
- Users can create orders
- Only admins can update orders (for fulfillment)

## Navigation
- Admin orders queue screen can be accessed via admin navigation (to be integrated)
- Screen path: `lib/screens/admin/business_card_orders_queue_screen.dart`

## Testing Checklist
- [ ] Business card form autosaves correctly
- [ ] QR code generates when form is complete
- [ ] Terms checkbox enables checkout button
- [ ] Order creation with discounts works correctly
- [ ] Shipping options save properly
- [ ] Admin can view orders queue
- [ ] Admin can mark orders as complete
- [ ] Order IDs are unique and properly formatted
- [ ] Discounts apply correctly for users with credits/subscription

## Next Steps
1. Implement business card image generation
2. Implement print functionality
3. Integrate admin orders queue into admin navigation
4. Test full order flow end-to-end
5. Deploy Cloud Functions with updated order creation logic
