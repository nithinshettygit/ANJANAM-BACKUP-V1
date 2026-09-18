import 'web_seo_stub.dart'
    if (dart.library.html) 'web_seo_web.dart' as impl;

/// Updates browser document metadata on Flutter web (title, OG, Twitter, canonical).
class WebSeo {
  static const defaultTitle = 'ANJANAM — Shop Online in India';
  static const defaultDescription =
      'Shop products, digital articles, videos, books, and music on ANJANAM. Secure checkout with Razorpay.';
  static const siteOrigin = 'https://anjanam.store';
  static const defaultImage = '$siteOrigin/icons/Icon-512.png';

  static void updateSharePage({
    required String title,
    required String description,
    required String path,
    String? imageUrl,
    String ogType = 'website',
    Map<String, dynamic>? structuredData,
  }) {
    impl.updateSharePage(
      title: title,
      description: description,
      path: path,
      imageUrl: imageUrl ?? defaultImage,
      ogType: ogType,
      structuredData: structuredData,
    );
  }

  static void resetToDefault() => impl.resetToDefault();

  static void setRobots(String directive) => impl.setRobots(directive);
}
