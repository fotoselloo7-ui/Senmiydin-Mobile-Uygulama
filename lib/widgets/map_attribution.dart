import '../core/app_locale.dart';
import 'package:flutter/material.dart' hide Text;

import 'translated_text.dart';

import 'package:url_launcher/url_launcher.dart';

import '../core/theme.dart';

/// The one OpenStreetMap attribution every map in the app uses: a small translucent pill in the top-left corner of
/// the map. It stays visible and tappable (opens the copyright page), but never sits in the bottom controls area
/// next to buttons. Place it inside the `FlutterMap.children` list.
class MapAttribution extends StatelessWidget {
  const MapAttribution({super.key});

  static const _provider = String.fromEnvironment(
    'MAP_ATTRIBUTION',
    defaultValue: 'OpenStreetMap contributors',
  );
  static const url = String.fromEnvironment(
    'MAP_ATTRIBUTION_URL',
    defaultValue: 'https://www.openstreetmap.org/copyright',
  );

  /// Free space overlays at the top of a map keep clear so they never cover the attribution.
  static const clearance = 30.0;

  /// Short text for small screens: "© OpenStreetMap" (the link still goes to the full copyright page).
  static String get label =>
      '© ${_provider.replaceFirst(RegExp(r'\s+contributors$'), '')}';

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 6, top: 4),
        child: Semantics(
          link: true,
          label: trf('{0}, telif bilgisi', [_provider]),
          excludeSemantics: true,
          child: GestureDetector(
            key: const Key('map-attribution'),
            behavior: HitTestBehavior.opaque,
            onTap: () =>
                launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
            // Extra transparent padding makes the small pill easy to hit without growing its look.
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .78),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      height: 1.2,
                      fontWeight: FontWeight.w600,
                      color: AppColors.navy.withValues(alpha: .72),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
