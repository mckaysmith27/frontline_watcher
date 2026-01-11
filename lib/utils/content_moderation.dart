/// Utility functions for content moderation and approval detection

class ContentModeration {
  /// Check if post content contains risky elements that require approval
  static bool requiresApproval({
    required String content,
    required List<String> imageUrls,
  }) {
    // Check for links (http, https, www)
    if (_containsLinks(content)) {
      return true;
    }

    // Check for images
    if (imageUrls.isNotEmpty) {
      return true;
    }

    // Check for LGBTQ+ emojis
    if (_containsLGBTQEmojis(content)) {
      return true;
    }

    // Check for ambiguous sexual emojis
    if (_containsSexualEmojis(content)) {
      return true;
    }

    return false;
  }

  /// Check if content contains links
  static bool _containsLinks(String content) {
    final linkPatterns = [
      RegExp(r'https?://', caseSensitive: false),
      RegExp(r'www\.', caseSensitive: false),
      RegExp(r'[a-zA-Z0-9-]+\.[a-zA-Z]{2,}', caseSensitive: false), // Domain pattern
    ];

    for (final pattern in linkPatterns) {
      if (pattern.hasMatch(content)) {
        return true;
      }
    }
    return false;
  }

  /// Check if content contains LGBTQ+ emojis
  static bool _containsLGBTQEmojis(String content) {
    // LGBTQ+ flag emojis and related symbols
    final lgbtqEmojis = [
      '🏳️‍🌈', // Rainbow flag
      '🏳️‍⚧️', // Transgender flag
      '⚧️', // Transgender symbol
      '🏳️', // White flag (sometimes used in context)
    ];

    for (final emoji in lgbtqEmojis) {
      if (content.contains(emoji)) {
        return true;
      }
    }
    return false;
  }

  /// Check if content contains ambiguous sexual emojis
  static bool _containsSexualEmojis(String content) {
    // Ambiguous sexual emojis that might need moderation
    final sexualEmojis = [
      '🍆', // Eggplant
      '🍑', // Peach
      '🍌', // Banana
      '🌭', // Hot dog
      '🥒', // Cucumber
      '🌮', // Taco
      '🌯', // Burrito
      '💦', // Sweat droplets
      '🔥', // Fire (sometimes used sexually)
      '👅', // Tongue
      '💋', // Kiss mark
      '👄', // Mouth
      '🍒', // Cherries
      '🍓', // Strawberry
      '🥭', // Mango
    ];

    for (final emoji in sexualEmojis) {
      if (content.contains(emoji)) {
        return true;
      }
    }
    return false;
  }

  /// Get the reason why content requires approval
  static List<String> getApprovalReasons({
    required String content,
    required List<String> imageUrls,
  }) {
    final reasons = <String>[];

    if (_containsLinks(content)) {
      reasons.add('Contains links');
    }

    if (imageUrls.isNotEmpty) {
      reasons.add('Contains images');
    }

    if (_containsLGBTQEmojis(content)) {
      reasons.add('Contains LGBTQ+ emojis');
    }

    if (_containsSexualEmojis(content)) {
      reasons.add('Contains potentially sexual emojis');
    }

    return reasons;
  }
}
