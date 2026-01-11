# Business Card Ordering System

## Overview

Users can order physical business cards with their shortname/profile URL. Free cards are available for users with credits or subscriptions, with additional quantities available for purchase.

## Features

### 1. Order Button
- **Location**: Business Card screen (below the business card display)
- **Label**: "Order Business Cards" with "free*" indicator
- **Behavior**: Opens ordering screen

### 2. Free Business Cards
- **Quantity**: 5 cards
- **Eligibility**: Users with:
  - Active credits (> 0), OR
  - Active subscription (`subscriptionActive: true` or `hasActiveSubscription: true`)
- **Shipping**: Free via USPS (10-14 business days)
- **Note**: If user doesn't have credits/subscription, shows "Subscribe Now" option

### 3. Paid Options
- **10 cards**: $5.99
- **20 cards**: $9.99
- **50 cards**: $19.00
- **100 cards**: $34.99
- **500 cards**: $89.99
- **Shipping**: Included via USPS (10-14 business days)

### 4. Ordering Flow
1. User selects quantity (radio buttons)
2. Enters shipping address:
   - Full Name *
   - Address Line 1 *
   - Address Line 2 (optional)
   - City *
   - State * (2 letters)
   - ZIP * (5 digits)
3. Reviews order summary
4. Clicks "Order" button
5. For free orders: Confirmed immediately
6. For paid orders: Payment processing → Confirmed after payment

### 5. Order Tracking
- Orders stored in `business_card_orders` collection
- Status: `confirmed` (free) or `pending_payment` → `confirmed` (paid)
- Estimated delivery: 10-14 days from order date
- Shipping address saved to user profile for future orders

## Database Schema

### Business Card Orders Collection
```javascript
{
  userId: string,
  shortname: string,
  userName: string,
  userPhone: string?,
  userEmail: string?,
  quantity: number,          // 5, 10, 20, 50, 100, 500
  price: number,             // 0.00 for free, or paid amount
  isFree: boolean,
  shippingAddress: {
    name: string,
    address1: string,
    address2: string?,
    city: string,
    state: string,
    zip: string,
  },
  status: 'confirmed' | 'pending_payment' | 'shipped' | 'delivered',
  estimatedDelivery: string,  // Date string (MM/DD/YYYY)
  createdAt: Timestamp,
  paidAt: Timestamp?,         // For paid orders
  shippedAt: Timestamp?,      // When cards are shipped
}
```

### User Document (Updated)
```javascript
{
  shippingAddress: {
    name: string,
    address1: string,
    address2: string?,
    city: string,
    state: string,
    zip: string,
  },
  subscriptionActive: boolean?,      // For subscription check
  hasActiveSubscription: boolean?,   // Alternative subscription field
  // ... other fields
}
```

## Cloud Functions

### `createBusinessCardOrder`
**Input:**
```javascript
{
  quantity: number,
  shortname: string,
  shippingAddress: {
    name: string,
    address1: string,
    address2: string?,
    city: string,
    state: string,
    zip: string,
  }
}
```

**Output:**
```javascript
{
  orderId: string,
  isFree: boolean,
  price: number,
  estimatedDelivery: string
}
```

**Logic:**
- Checks if user has credits or subscription
- Calculates price based on quantity and eligibility
- Creates order document
- Returns order details

## Pricing Structure

```javascript
const pricing = {
  5: 0.0,      // Free (if has credits/subscription)
  10: 5.99,
  20: 9.99,
  50: 19.00,
  100: 34.99,
  500: 89.99,
};
```

## UI Components

### Order Screen Features
- **Quantity Selection**: Radio buttons for each option
- **Free Indicator**: Shows "Free*" for 5 cards if eligible
- **Shipping Form**: Full address collection
- **Order Summary**: Shows quantity, price, shipping info
- **Subscribe CTA**: Shown if user selects free option but isn't eligible
- **Order Button**: "Order Free Business Cards" or "Pay $X.XX & Order"

### Business Card Screen
- **Order Button**: Below business card display
- **Label**: "Order Business Cards free*"
- **Note**: "*Free with active credits or subscription"

## Payment Integration

Currently uses simulated payment. To integrate with Stripe:

1. Update `_processPayment()` method in `business_card_order_screen.dart`
2. Add Stripe Checkout or Payment Sheet
3. Handle payment success/failure
4. Update order status based on payment result

## Shipping

- **Method**: USPS (United States Postal Service)
- **Delivery Time**: 10-14 business days
- **Tracking**: Can be added to order document when shipped
- **Address**: Saved to user profile for future orders

## Files Created/Modified

### New Files
- `lib/screens/profile/business_card_order_screen.dart` - Ordering screen

### Modified Files
- `lib/screens/profile/business_card_screen.dart` - Added order button
- `functions/index.js` - Added `createBusinessCardOrder` function
- `firestore.rules` - Added rules for `business_card_orders` collection

## Testing Scenarios

1. **User with Credits**:
   - ✅ 5 cards show as "Free*"
   - ✅ Can order 5 cards for free
   - ✅ Other quantities show paid prices

2. **User with Subscription**:
   - ✅ 5 cards show as "Free*"
   - ✅ Can order 5 cards for free

3. **User without Credits/Subscription**:
   - ✅ 5 cards show as "Free*" but with subscribe CTA
   - ✅ Can order paid quantities
   - ✅ Subscribe button shown for free option

4. **Order Processing**:
   - ✅ Free orders confirmed immediately
   - ✅ Paid orders require payment
   - ✅ Shipping address saved
   - ✅ Order document created in Firestore

## Next Steps

1. **Integrate Payment Provider**:
   - Add Stripe SDK
   - Implement payment processing
   - Handle payment webhooks

2. **Fulfillment System**:
   - Admin dashboard to view orders
   - Mark orders as shipped
   - Add tracking numbers

3. **Email Notifications**:
   - Order confirmation email
   - Shipping notification
   - Delivery confirmation

4. **Order History**:
   - Show past orders in app
   - Track order status
   - Re-order functionality
