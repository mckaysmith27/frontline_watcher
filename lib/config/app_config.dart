class AppConfig {
  // Backend API URL - Update this with your actual backend URL
  static const String backendUrl = 'https://your-backend-api.com';
  
  // NTFY topic for notifications
  static String getNtfyTopic(String userId) {
    return 'sub67_$userId';
  }
  
  // Promo codes for premium unlock
  static const List<String> premiumPromoCodes = [
    'PremiumVIP',
    'VIP26',
    'UrCute',
    'PrettyCute',
    'VIPCute',
    'VIP67',
    'VIP41',
    '4Libby<3',
    '4Libby',
    '4Kim',
    '4Kim<3',
  ];
  
  // Promo codes for bi-weekly credit purchase (one-time use)
  static const List<String> creditPromoCodes = [
    'VIP10q7N0110',
    'VIP108kN0210',
    'VIP10p4N0310',
    'VIP106aN0410',
    'VIP10n5N0510',
    'VIP103rN0610',
    'VIP10m9N0710',
    'VIP105kN0810',
    'VIP102pN0910',
    'VIP10r3N1010',
    'VIP26',
    'UrCute',
    'PrettyCute',
    'VIPCute',
    'VIP67',
    'VIP41',
    '4Libby<3',
    '4Libby',
    '4Kim',
    '4Kim<3',
  ];
  
  // Subscription tier pricing (continuous days; timestamp-based)
  static const Map<String, Map<String, dynamic>> subscriptionTiers = {
    'daily': {'days': 1, 'price': 1.99},
    'weekly': {'days': 7, 'price': 4.99},
    'bi-weekly': {'days': 14, 'price': 8.99},
    'monthly': {'days': 30, 'price': 15.99},
    'annually': {'days': 365, 'price': 89.99},
  };

  // Stripe (publishable) key for client-side card entry (PaymentSheet).
  // DO NOT put secret keys in the app. Configure secret key in Cloud Functions.
  static const String stripePublishableKey = '';
  static const String stripeMerchantDisplayName = 'Sub67';
  
  // Default filters dictionary
  static const Map<String, List<String>> defaultFilters = {
    "subjects": ["science", "math", "english", "art", "history"],
    "specialties": ["sped", "social studies", "psychology"],
    "premium-classes": ["ap", "honors"],
    "premium-workdays": [
      "early-out (with a full-day pay)",
      "prep period included",
      "free lunch coupon",
      "extra pay (SPED teacher)"
    ],
  };
}




