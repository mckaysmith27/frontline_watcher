class SocialLink {
  final String platform;
  final String url;

  SocialLink({
    required this.platform,
    required this.url,
  });

  factory SocialLink.fromMap(Map<String, dynamic> map) {
    return SocialLink(
      platform: map['platform'] ?? '',
      url: map['url'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'platform': platform,
      'url': url,
    };
  }

  static const Map<String, String> platformTemplates = {
    'Facebook': 'https://facebook.com/username',
    'Instagram': 'https://instagram.com/username',
    'Twitter / X': 'https://x.com/username',
    'Threads': 'https://threads.net/@username',
    'Snapchat': 'https://snapchat.com/add/username',
    'TikTok': 'https://tiktok.com/@username',
    'Pinterest': 'https://pinterest.com/username',
    'YouTube': 'https://youtube.com/@username',
    'Personal Website': 'https://yourname.com',
    'About.me': 'https://about.me/username',
  };
}

