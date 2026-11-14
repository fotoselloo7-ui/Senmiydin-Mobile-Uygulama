import 'dart:io';

import 'package:flutter/foundation.dart';

/// Central AdMob configuration. Nothing real is hard-coded here: production ids arrive as build defines
/// (`--dart-define=ADMOB_NATIVE_AD_UNIT_ANDROID=...`, `ADMOB_NATIVE_AD_UNIT_IOS=...`; the application ids are
/// `ADMOB_APP_ID_ANDROID` / the iOS xcconfig value). Debug builds use Google's published sample ad units; a release
/// build without a real ad unit id renders no ad area at all.
class AdsConfig {
  AdsConfig._();

  /// Google's documented sample "Native Advanced" ad units (test ads only).
  static const androidTestNativeUnit = 'ca-app-pub-3940256099942544/2247696110';
  static const iosTestNativeUnit = 'ca-app-pub-3940256099942544/3986624511';

  static const _androidUnit = String.fromEnvironment(
    'ADMOB_NATIVE_AD_UNIT_ANDROID',
  );
  static const _iosUnit = String.fromEnvironment('ADMOB_NATIVE_AD_UNIT_IOS');
  static const _disabled = bool.fromEnvironment('ADS_DISABLED');

  /// First native ad appears after this many organic posts; the next ones every `feed_ad_interval` posts.
  static const firstAdAfter = 7;
  static const defaultInterval = 11;
  static const minimumInterval = 8;

  /// The Google Mobile Ads SDK is only started on real devices (never in unit tests, never when disabled by a define).
  static bool get platformEnabled =>
      !_disabled &&
      !kIsWeb &&
      (Platform.isAndroid || Platform.isIOS) &&
      !Platform.environment.containsKey('FLUTTER_TEST');

  /// Native ad unit for this platform: the sample unit in debug, the build-defined one in release (null = no ads).
  static String? nativeUnitId({
    bool? debug,
    TargetPlatform? platform,
    String? androidUnit,
    String? iosUnit,
  }) {
    final target = platform ?? defaultTargetPlatform;
    final isDebug = debug ?? kDebugMode;
    final android = androidUnit ?? _androidUnit;
    final ios = iosUnit ?? _iosUnit;
    final configured = target == TargetPlatform.iOS ? ios : android;
    if (configured.isNotEmpty) return configured;
    if (isDebug) {
      return target == TargetPlatform.iOS
          ? iosTestNativeUnit
          : androidTestNativeUnit;
    }
    return null;
  }

  /// Where ads sit in a feed of [organic] posts: one after the 7th organic post, then one every [interval] posts
  /// (never more often than [minimumInterval]); an ad is only placed when more content follows it, so the list never
  /// ends on an ad. The result depends on the count only, so paging in more posts never moves an earlier ad.
  static List<int> adPositions(int organic, int interval) {
    final step = interval < minimumInterval ? minimumInterval : interval;
    final positions = <int>[];
    for (var after = firstAdAfter; after < organic; after += step) {
      positions.add(after);
    }
    return positions;
  }
}

/// One row of a feed with ads mixed in: either the organic post at [organic] or an ad slot numbered [adSlot].
class FeedRow {
  const FeedRow.post(this.organic) : adSlot = null;
  const FeedRow.ad(this.adSlot) : organic = null;
  final int? organic;
  final int? adSlot;
  bool get isAd => adSlot != null;
}

/// Interleaves [organic] posts with ads at [AdsConfig.adPositions]. With [ads] false it is simply the posts.
List<FeedRow> feedRows(int organic, {required bool ads, int? interval}) {
  final positions = ads
      ? AdsConfig.adPositions(organic, interval ?? AdsConfig.defaultInterval)
      : const <int>[];
  final rows = <FeedRow>[];
  var slot = 0;
  var next = 0;
  for (var i = 0; i < organic; i++) {
    rows.add(FeedRow.post(i));
    if (next < positions.length && positions[next] == i + 1) {
      rows.add(FeedRow.ad(slot++));
      next++;
    }
  }
  return rows;
}
