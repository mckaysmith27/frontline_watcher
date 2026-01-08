/// Keyword mapping utility for matching alternative terms
class KeywordMapper {
  /// Maps alternative terms to their canonical keyword
  static const Map<String, String> keywordMappings = {
    // PE variations
    "physical education": "pe",
    "p.e.": "pe",
    "p. e.": "pe",
    
    // SPED variations
    "special ed": "sped",
    "special ed.": "sped",
    "special edu": "sped",
    "special education": "sped",
    
    // ESL variations
    "english sign language": "esl",
    
    // ELL variations
    "english language learning": "ell",
    "english language learner": "ell",
    
    // Art variations
    "arts": "art",
    
    // Job type variations
    "half day": "half",
    "full day": "full",
  };
  
  /// Duration mappings for half day (01:00 to 04:00 in 15-min increments)
  static const List<String> halfDayDurations = [
    "0100", "0115", "0130", "0145",
    "0200", "0215", "0230", "0245",
    "0300", "0315", "0330", "0345",
    "0400"
  ];
  
  /// Duration mappings for full day (04:15 to 09:15 in 15-min increments)
  static const List<String> fullDayDurations = [
    "0415", "0430", "0445",
    "0500", "0515", "0530", "0545",
    "0600", "0615", "0630", "0645",
    "0700", "0715", "0730", "0745",
    "0800", "0815", "0830", "0845",
    "0900", "0915"
  ];
  
  /// Convert a date string to keyword format (e.g., "Mon, 2/5/2026" -> "2_5_2026")
  /// Also handles "2024-01-15" -> "1_15_2024" (removes leading zeros)
  static String dateToKeyword(String dateStr) {
    // Handle formats like "Mon, 2/5/2026" or "2/5/2026" or "2024-01-15"
    String cleaned = dateStr.trim();
    
    // Remove weekday prefix if present (e.g., "Mon, " or "Monday, ")
    if (cleaned.contains(',')) {
      cleaned = cleaned.split(',').last.trim();
    }
    
    // Handle ISO format "2024-01-15" -> "1_15_2024"
    if (cleaned.contains('-') && cleaned.length >= 10) {
      final parts = cleaned.split('-');
      if (parts.length == 3) {
        try {
          final year = parts[0];
          final month = int.parse(parts[1]); // Remove leading zero
          final day = int.parse(parts[2]); // Remove leading zero
          return '${month}_${day}_${year}';
        } catch (e) {
          // Fall through to default handling
        }
      }
    }
    
    // Replace slashes with underscores for other formats
    return cleaned.replaceAll('/', '_').replaceAll('-', '_');
  }
  
  /// Convert a duration string to 4-digit format (e.g., "01:15" -> "0115")
  static String durationToKeyword(String durationStr) {
    // Remove spaces and convert to lowercase
    String cleaned = durationStr.trim().toLowerCase();
    
    // Handle formats like "01:15", "1:15", "1h 15m", etc.
    // Try to extract hours and minutes
    if (cleaned.contains(':')) {
      final parts = cleaned.split(':');
      if (parts.length >= 2) {
        try {
          int hours = int.parse(parts[0].trim());
          int minutes = int.parse(parts[1].trim().split(' ')[0]);
          return '${hours.toString().padLeft(2, '0')}${minutes.toString().padLeft(2, '0')}';
        } catch (e) {
          // If parsing fails, try to extract numbers
          return cleaned.replaceAll(RegExp(r'[^0-9]'), '').padLeft(4, '0');
        }
      }
    }
    
    // If no colon, try to extract numbers
    final numbers = cleaned.replaceAll(RegExp(r'[^0-9]'), '');
    if (numbers.length >= 3) {
      return numbers.padLeft(4, '0').substring(0, 4);
    }
    
    return cleaned.replaceAll(RegExp(r'[^0-9]'), '').padLeft(4, '0');
  }
  
  /// Get all mapped keywords for a given term (including the term itself)
  static List<String> getMappedKeywords(String term) {
    final termLower = term.toLowerCase().trim();
    final keywords = <String>[termLower];
    
    // Add direct mappings
    if (keywordMappings.containsKey(termLower)) {
      keywords.add(keywordMappings[termLower]!);
    }
    
    // Add reverse mappings (find all terms that map to this one)
    keywordMappings.forEach((key, value) {
      if (value == termLower && key != termLower) {
        keywords.add(key);
      }
    });
    
    return keywords.toSet().toList();
  }
  
  /// Check if a duration keyword matches half day
  static bool isHalfDay(String durationKeyword) {
    return halfDayDurations.contains(durationKeyword);
  }
  
  /// Check if a duration keyword matches full day
  static bool isFullDay(String durationKeyword) {
    return fullDayDurations.contains(durationKeyword);
  }
  
  /// Normalize a text string and check if it matches any mapped keywords
  static bool matchesKeyword(String text, String keyword) {
    final textLower = text.toLowerCase();
    final keywordLower = keyword.toLowerCase();
    
    // Direct match
    if (textLower.contains(keywordLower)) {
      return true;
    }
    
    // Check mapped keywords
    final mappedKeywords = getMappedKeywords(keywordLower);
    for (final mapped in mappedKeywords) {
      if (textLower.contains(mapped)) {
        return true;
      }
    }
    
    return false;
  }
}

