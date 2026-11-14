import 'package:flutter/material.dart' hide Text;

import '../core/app_locale.dart';
import '../core/theme.dart';
import '../data/ads_service.dart';
import '../data/app_store.dart';
import 'translated_text.dart';

/// A native feed ad: a clearly labelled ("Reklam" / "Ad") card, visually separate from posts. It renders nothing at all
/// until an ad has loaded, and nothing again if loading fails, so there is never an empty placeholder or a gap.
class NativeFeedAd extends StatefulWidget {
  const NativeFeedAd({super.key, this.height = 120});
  final double height;

  @override
  State<NativeFeedAd> createState() => _NativeFeedAdState();
}

class _NativeFeedAdState extends State<NativeFeedAd>
    with AutomaticKeepAliveClientMixin {
  NativeAdHandle? handle;
  bool loaded = false, failed = false, started = false;

  @override
  bool get wantKeepAlive => loaded;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (started) return;
    started = true;
    final ads = StoreScope.of(context).ads;
    final platform = ads.platform;
    final unit = ads.nativeUnit;
    if (platform == null || unit == null || !ads.available) {
      failed = true;
      return;
    }
    handle = platform.createNative(
      unitId: unit,
      teen: ads.teen,
      onLoaded: () {
        if (mounted) {
          setState(() => loaded = true);
          updateKeepAlive();
        }
      },
      onFailed: () {
        if (mounted) setState(() => failed = true);
        handle = null;
      },
    );
  }

  @override
  void dispose() {
    handle?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final ad = handle;
    if (failed || !loaded || ad == null) return const SizedBox.shrink();
    return Container(
      key: const Key('native-feed-ad'),
      margin: const EdgeInsets.only(bottom: Space.md),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: AppShape.card(color: const Color(0xFFFAFAFF)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Semantics(
              label: context.l10n.adLabel,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.surfaceBlue,
                  borderRadius: BorderRadius.circular(AppShape.pill),
                  border: Border.all(color: const Color(0xFFD6E4F7)),
                ),
                child: Text(
                  context.l10n.adLabel,
                  key: const Key('ad-label'),
                  style: AppTypography.metadata.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.muted,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: widget.height, child: ad.widget),
        ],
      ),
    );
  }
}
