import 'package:flutter/material.dart' hide Text;

import '../core/app_locale.dart';
import '../core/navigation.dart';
import '../core/theme.dart';
import '../data/app_store.dart';
import '../data/location_api.dart';
import '../data/memories_api.dart';
import '../data/models.dart';
import 'common.dart';
import 'memory_widgets.dart';
import 'social.dart';
import 'translated_text.dart';

/// Home: "Yakındaki Anılar". A strip of the memories people shared in the viewer's own area, newest first. A memory with a
/// photo shows that photo in the circle; one without shows its author's profile picture (with a small memory badge).
/// Which memories appear is decided by the server (their visibility); the first item adds one of your own.
class HomeMemoriesStrip extends StatefulWidget {
  const HomeMemoriesStrip({super.key});

  @override
  State<HomeMemoriesStrip> createState() => _HomeMemoriesStripState();
}

class _HomeMemoriesStripState extends State<HomeMemoriesStrip> {
  Object? loadedKey;
  Future<({List<MemoryPin> pins, bool locationRequired})>? request;

  static String shortPlace(String label) {
    final cut = label.split(' · ').first.trim();
    return cut.isEmpty ? label : cut;
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final key = (
      store.city,
      store.radiusMeters,
      store.locationVersion,
      store.memoriesVersion,
    );
    if (loadedKey != key) {
      loadedKey = key;
      request = store.loadMemoriesAround();
    }
    return FutureBuilder(
      future: request,
      builder: (context, snapshot) {
        // The server's order: nearest first once the device position is known, otherwise newest first.
        final shown = [...?snapshot.data?.pins].take(12).toList();
        final waiting = snapshot.connectionState != ConnectionState.done;
        return SizedBox(
          key: const Key('home-memories'),
          height: 74 + 10 * (MediaQuery.textScalerOf(context).scale(1) - 1),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: shown.length + 1 + (shown.isEmpty ? 1 : 0),
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (_, i) {
              if (i == 0) return _AddMemory(onTap: () => _add(context));
              if (shown.isEmpty) {
                return SizedBox(
                  width: MediaQuery.sizeOf(context).width - 130,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      waiting
                          ? 'Anılar yükleniyor…'
                          : snapshot.hasError
                          ? 'Anılar yüklenemedi.'
                          : 'Bu bölgede henüz paylaşılmış bir anı yok.',
                      key: const Key('home-memories-empty'),
                      style: AppTypography.metadata,
                    ),
                  ),
                );
              }
              return _MemoryBubble(
                shown[i - 1],
                place: shown[i - 1].distanceMeters != null
                    ? locationDistance(shown[i - 1].distanceMeters!)
                    : shortPlace(shown[i - 1].placeLabel),
                onTap: () => openPage(context, '/memory', shown[i - 1].id),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _add(BuildContext context) async {
    await startMemoryCreation(context);
  }
}

class _AddMemory extends StatelessWidget {
  const _AddMemory({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: tr('Anı Ekle'),
    excludeSemantics: true,
    child: InkWell(
      key: const Key('home-memories-add'),
      borderRadius: BorderRadius.circular(AppShape.pill),
      onTap: onTap,
      child: SizedBox(
        width: 68,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 66,
              height: 66,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surfaceBlue,
                border: Border.all(color: const Color(0xFFD6E4F7), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: .12),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(
                Icons.add_rounded,
                color: AppColors.primary,
                size: 28,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _MemoryBubble extends StatelessWidget {
  const _MemoryBubble(this.pin, {required this.place, required this.onTap});
  final MemoryPin pin;
  final String place;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final person = Person(
      id: 'memory-author-${pin.authorId}',
      name: pin.authorName,
      handle: pin.authorUsername,
      photo: pin.authorPhoto,
      remote: true,
    );
    return Semantics(
      button: true,
      label: '${tr('Anı')}, ${memoryDate(pin.occurredAt)}, ${pin.placeLabel}',
      excludeSemantics: true,
      child: InkWell(
        key: Key('home-memory-${pin.id}'),
        borderRadius: AppShape.control,
        onTap: onTap,
        child: SizedBox(
          width: 68,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 66,
                height: 66,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(
                            color: pin.hasPhoto
                                ? AppColors.brandLilac
                                : const Color(0xFFD6E4F7),
                            width: 2,
                          ),
                        ),
                        child: ClipOval(
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              pin.hasPhoto
                                  ? socialMediaImage(
                                      store,
                                      pin.coverThumb,
                                      fit: BoxFit.cover,
                                      width: 58,
                                      height: 58,
                                    )
                                  : Avatar(person, size: 58),
                              // The distance (or the place) is a band along the lower rim of the circle: flush with the edge,
                              // curved by the circle itself, nothing floating on the photo.
                              Align(
                                alignment: Alignment.bottomCenter,
                                child: Container(
                                  key: Key('home-memory-label-${pin.id}'),
                                  width: double.infinity,
                                  height: 21,
                                  alignment: Alignment.center,
                                  padding: const EdgeInsets.only(bottom: 2),
                                  color: AppColors.navy.withValues(alpha: .62),
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.location_on_rounded,
                                            size: 10,
                                            color: Colors.white,
                                          ),
                                          const SizedBox(width: 1),
                                          Text(
                                            place,
                                            maxLines: 1,
                                            softWrap: false,
                                            style: const TextStyle(
                                              fontSize: 10,
                                              height: 1.1,
                                              color: Colors.white,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (!pin.hasPhoto)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          key: Key('home-memory-badge-${pin.id}'),
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: AppColors.brandPurple,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          child: const Icon(
                            Icons.auto_stories_rounded,
                            size: 11,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
