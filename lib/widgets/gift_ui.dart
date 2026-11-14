import 'package:flutter/material.dart' hide Text;
import 'package:flutter_svg/flutter_svg.dart';

import '../core/app_locale.dart';
import '../core/theme.dart';
import '../data/gifts.dart';
import 'translated_text.dart';

/// The artwork of one gift (own flat vector set in assets/gifts); unknown keys show the gift box.
class GiftArt extends StatelessWidget {
  const GiftArt(this.asset, {super.key, this.size = 56});
  final String asset;
  final double size;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    giftAssetPath(asset),
    width: size,
    height: size,
    semanticsLabel: asset,
  );
}

/// "Bir hediye gönder": compact catalog sheet. [load] fetches the server catalog; the chosen gift is returned.
Future<GiftItem?> showGiftSheet(
  BuildContext context,
  Future<List<GiftItem>> Function() load,
) => showModalBottomSheet<GiftItem>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (sheet) => _GiftSheet(load: load),
);

class _GiftSheet extends StatefulWidget {
  const _GiftSheet({required this.load});
  final Future<List<GiftItem>> Function() load;
  @override
  State<_GiftSheet> createState() => _GiftSheetState();
}

class _GiftSheetState extends State<_GiftSheet> {
  late Future<List<GiftItem>> items = widget.load();

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final columns = width < 340 ? 3 : 4;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr('Bir hediye gönder'),
              key: const Key('gift-sheet-title'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 2),
            Text(tr('Hediyeler ücretsiz.'), style: AppTypography.metadata),
            const SizedBox(height: Space.md),
            FutureBuilder<List<GiftItem>>(
              future: items,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const SizedBox(
                    height: 120,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final gifts = snapshot.data;
                if (snapshot.hasError || gifts == null || gifts.isEmpty) {
                  return SizedBox(
                    height: 120,
                    child: Center(
                      child: TextButton.icon(
                        key: const Key('gift-retry'),
                        onPressed: () => setState(() => items = widget.load()),
                        icon: const Icon(Icons.refresh_rounded),
                        label: Text(tr('Hediyeler yüklenemedi. Tekrar dene.')),
                      ),
                    ),
                  );
                }
                return GridView.count(
                  key: const Key('gift-grid'),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: columns,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: .86,
                  children: [
                    for (final gift in gifts)
                      InkWell(
                        key: ValueKey('gift-${gift.slug}'),
                        borderRadius: AppShape.rounded,
                        onTap: () => Navigator.pop(context, gift),
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.surfaceBlue,
                            borderRadius: AppShape.rounded,
                            border: Border.all(color: const Color(0xFFD6E4F7)),
                          ),
                          padding: const EdgeInsets.all(6),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              GiftArt(gift.asset, size: 44),
                              const SizedBox(height: 6),
                              Text(
                                gift.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: AppTypography.metadata.copyWith(
                                  color: AppColors.navy,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// The inside of a gift message bubble: artwork, name and a "sent you a gift" line
class GiftBubbleBody extends StatelessWidget {
  const GiftBubbleBody({
    super.key,
    required this.gift,
    required this.mine,
    required this.senderName,
    required this.color,
  });
  final GiftItem gift;
  final bool mine;
  final String senderName;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    key: Key('gift-card-${gift.slug}'),
    width: 190,
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: mine ? .16 : .85),
      borderRadius: AppShape.rounded,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GiftArt(gift.asset, size: 64),
        const SizedBox(height: 6),
        Text(
          gift.label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: mine ? Colors.white : AppColors.navy,
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          mine
              ? tr('Hediye gönderdin.')
              : trf('{0} sana bir hediye gönderdi.', [senderName]),
          textAlign: TextAlign.center,
          style: AppTypography.metadata.copyWith(
            color: mine ? Colors.white70 : AppColors.muted,
          ),
        ),
      ],
    ),
  );
}
