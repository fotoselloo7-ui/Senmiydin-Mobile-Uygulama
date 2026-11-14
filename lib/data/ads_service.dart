import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../core/ads_config.dart';

/// Result of the consent + SDK start sequence.
class AdsStartResult {
  const AdsStartResult({
    required this.canRequestAds,
    required this.privacyOptionsRequired,
  });
  final bool canRequestAds, privacyOptionsRequired;
}

/// A loaded (or loading) native ad that can be drawn and released.
abstract class NativeAdHandle {
  Widget get widget;
  void dispose();
}

/// The thin seam around the Google Mobile Ads SDK. The app talks only to this, so tests use a fake and the SDK is
/// never touched without consent, without an ad unit or in unit tests.
abstract class AdsPlatform {
  /// Runs the UMP consent flow and, only when ads may be requested, starts the SDK with the age treatment.
  Future<AdsStartResult> start({required bool teen});
  Future<void> showPrivacyOptions();

  /// Creates a native ad. The request never carries a location, keywords or any SenMiydin data.
  NativeAdHandle createNative({
    required String unitId,
    required bool teen,
    required VoidCallback onLoaded,
    required VoidCallback onFailed,
  });
}

class GoogleAdsPlatform implements AdsPlatform {
  @override
  Future<AdsStartResult> start({required bool teen}) async {
    final consent = ConsentInformation.instance;
    // Teen accounts (16–17) are flagged as under the age of consent: no personalized ads, no consent form needed.
    final params = ConsentRequestParameters(tagForUnderAgeOfConsent: teen);
    final updated = Completer<void>();
    consent.requestConsentInfoUpdate(
      params,
      () => updated.complete(),
      (error) => updated.complete(),
    );
    await updated.future;
    final shown = Completer<void>();
    await ConsentForm.loadAndShowConsentFormIfRequired((_) => shown.complete());
    await shown.future;
    final can = await consent.canRequestAds();
    final options =
        await consent.getPrivacyOptionsRequirementStatus() ==
        PrivacyOptionsRequirementStatus.required;
    if (can) {
      await MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(
          ageRestrictedTreatment: teen
              ? AgeRestrictedTreatment.teen
              : AgeRestrictedTreatment.unspecified,
          maxAdContentRating: teen ? MaxAdContentRating.t : null,
        ),
      );
      await MobileAds.instance.initialize();
    }
    return AdsStartResult(canRequestAds: can, privacyOptionsRequired: options);
  }

  @override
  Future<void> showPrivacyOptions() async {
    await ConsentForm.showPrivacyOptionsForm((_) {});
  }

  @override
  NativeAdHandle createNative({
    required String unitId,
    required bool teen,
    required VoidCallback onLoaded,
    required VoidCallback onFailed,
  }) {
    late final NativeAd ad;
    ad = NativeAd(
      adUnitId: unitId,
      // A plain request: no location, no keywords, no content url. Teens get non-personalized ads on top of the
      // under-age treatment configured at start.
      request: AdRequest(nonPersonalizedAds: teen ? true : null),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.small,
        cornerRadius: 12,
      ),
      listener: NativeAdListener(
        onAdLoaded: (_) => onLoaded(),
        onAdFailedToLoad: (failed, _) {
          failed.dispose();
          onFailed();
        },
      ),
    )..load();
    return _GoogleNativeHandle(ad);
  }
}

class _GoogleNativeHandle implements NativeAdHandle {
  _GoogleNativeHandle(this.ad);
  final NativeAd ad;
  @override
  Widget get widget => AdWidget(ad: ad);
  @override
  void dispose() => ad.dispose();
}

/// App-level ads state: consent result, age treatment and "may a feed show ads right now".
class AdsService extends ChangeNotifier {
  AdsService({AdsPlatform? platform, this.unitId})
    : platform =
          platform ?? (AdsConfig.platformEnabled ? GoogleAdsPlatform() : null);

  final AdsPlatform? platform;

  /// Overrides the build/platform ad unit (tests).
  final String? unitId;
  bool started = false, canRequestAds = false, privacyOptionsRequired = false;
  bool teen = false;
  bool _starting = false;

  String? get nativeUnit => unitId ?? AdsConfig.nativeUnitId();

  /// True only when consent allows requests, the SDK is up and an ad unit exists.
  bool get available =>
      platform != null && started && canRequestAds && nativeUnit != null;

  Future<void> start({required bool teen}) async {
    final target = platform;
    if (target == null || nativeUnit == null || _starting) return;
    if (started && this.teen == teen) return;
    _starting = true;
    try {
      final result = await target.start(teen: teen);
      this.teen = teen;
      started = true;
      canRequestAds = result.canRequestAds;
      privacyOptionsRequired = result.privacyOptionsRequired;
      notifyListeners();
    } catch (_) {
      // Consent or SDK failures simply mean: no ads. The rest of the app is unaffected.
      started = false;
      canRequestAds = false;
    } finally {
      _starting = false;
    }
  }

  Future<void> showPrivacyOptions() async {
    await platform?.showPrivacyOptions();
    final target = platform;
    if (target != null) {
      try {
        final result = await target.start(teen: teen);
        canRequestAds = result.canRequestAds;
        privacyOptionsRequired = result.privacyOptionsRequired;
        notifyListeners();
      } catch (_) {
        // Keep the previous state.
      }
    }
  }

  /// Back to "no ads" (sign-out): the next account decides its own treatment.
  void reset() {
    started = false;
    canRequestAds = false;
    privacyOptionsRequired = false;
    teen = false;
    notifyListeners();
  }
}
