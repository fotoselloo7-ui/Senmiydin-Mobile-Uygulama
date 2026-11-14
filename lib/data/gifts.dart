import '../core/app_locale.dart' show tr;

/// One entry of the server-controlled gift catalog (free in this release; the price fields exist for a paid future).
class GiftItem {
  const GiftItem({
    required this.slug,
    required this.name,
    required this.asset,
    this.priceMinor = 0,
    this.currency,
  });

  factory GiftItem.fromJson(Map<String, dynamic> json) => GiftItem(
    slug: json['slug'] as String,
    name: json['name'] as String? ?? json['slug'] as String,
    asset: json['asset'] as String? ?? 'gift',
    priceMinor: (json['price_minor'] as num?)?.toInt() ?? 0,
    currency: json['currency'] as String?,
  );

  final String slug, name, asset;
  final int priceMinor;
  final String? currency;
  bool get isFree => priceMinor == 0;

  /// The name in the language the app is showing now (the server's text is passed through for gifts added later).
  String get label => tr(name);
}

/// Artwork keys the app ships (assets/gifts/KEY.svg). A key the app does not know falls back to the gift box, so a
/// gift added on the server later never breaks an older app.
const giftAssets = {
  'heart',
  'rose',
  'coffee',
  'flower',
  'star',
  'clover',
  'cake',
  'gift',
};

String giftAssetPath(String key) =>
    'assets/gifts/${giftAssets.contains(key) ? key : 'gift'}.svg';
