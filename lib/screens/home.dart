import 'package:flutter/rendering.dart';

import '../core/polling.dart';

import 'dart:async';

import 'package:flutter/material.dart' hide Text;

import '../widgets/translated_text.dart';

import '../core/ads_config.dart';
import '../core/theme.dart';
import '../core/navigation.dart';
import '../data/app_store.dart';
import '../data/location_api.dart';
import '../data/models.dart';
import '../widgets/app_drawer.dart';
import '../widgets/common.dart';
import '../widgets/location_ui.dart';
import '../widgets/native_feed_ad.dart';
import '../widgets/notifications_sheet.dart';
import '../widgets/social.dart';
import '../widgets/social_page.dart';
import 'discovery.dart';
import 'profile.dart';
import 'messages.dart';
import '../core/app_locale.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int tab = 0;
  RoutePolling? encounterClock;
  int configTicks = 0;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final store = StoreScope.of(context);
    if (!store.connected) return;
    encounterClock ??= RoutePolling(
      interval: const Duration(seconds: 8),
      fetch: () async {
        if (!mounted || !store.authenticated) return false;
        final healthy = await store.refreshUnread();
        if (++configTicks % 4 == 1) await store.refreshHomeConfig();
        await store.push?.sync();
        return healthy;
      },
    );
    encounterClock!.attach(context);
  }

  @override
  void dispose() {
    encounterClock?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    if (store.maintenanceNotice case final notice?) {
      return AppPage(
        title: tr('Bakım çalışması'),
        child: ListView(
          padding: Space.page,
          children: [
            InfoNote(notice),
            const SizedBox(height: Space.md),
            SecondaryButton('Tekrar Dene', onPressed: store.refreshHomeConfig),
          ],
        ),
      );
    }
    return PopScope(
      canPop: tab == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && tab != 0) {
          setState(() => tab = 0);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leadingWidth: 46,
          leading: Builder(
            builder: (ctx) => IconButton(
              tooltip: tr('Menü'),
              icon: const Icon(Icons.menu_rounded, size: 24),
              onPressed: () => Scaffold.of(ctx).openDrawer(),
            ),
          ),
          title: const Brand(size: 26, alignment: Alignment.centerLeft),
          centerTitle: false,
          titleSpacing: 0,
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(height: 1, thickness: 1, color: AppColors.line),
          ),
          actions: tab == 4
              ? [
                  IconButton(
                    tooltip: tr('Ayarlar'),
                    icon: const Icon(Icons.settings_outlined, size: 24),
                    onPressed: () => openPage(context, '/settings'),
                  ),
                  const SizedBox(width: 4),
                ]
              : [
                  IconButton(
                    tooltip: tr('Ara'),
                    icon: const Icon(Icons.search_rounded, size: 24),
                    onPressed: () => openPage(context, '/search'),
                  ),
                  IconButton(
                    tooltip: tr('Bildirimler'),
                    onPressed: () => showNotificationsSheet(context),
                    icon: Badge(
                      isLabelVisible: store.connected
                          ? store.unreadNotifications > 0
                          : store.unreadNotices > 0,
                      label: store.connected
                          ? Text(
                              store.unreadNotifications > 99
                                  ? '99+'
                                  : '${store.unreadNotifications}',
                            )
                          : null,
                      smallSize: 8,
                      backgroundColor: AppColors.encounterPink,
                      child: const Icon(
                        Icons.notifications_none_rounded,
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
        ),
        drawerScrimColor: Colors.black.withValues(alpha: 0.52),
        drawerEdgeDragWidth: 28,
        drawer: AppDrawer(
          currentRoute: '/home',
          onProfile: () {
            setState(() => tab = 4);
          },
        ),
        body: SafeArea(
          top: false,
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: switch (tab) {
                1 => const MapContent(),
                3 => const MessagesContent(),
                4 => ProfileContent(personId: store.me.id),
                _ => HomeContent(onMap: () => setState(() => tab = 1)),
              },
            ),
          ),
        ),
        bottomNavigationBar: AppBottomNav(
          selected: tab,
          unread: store.unreadMessages,
          onChanged: (v) {
            if (v == 2) {
              openPage(context, '/compose');
            } else {
              setState(() => tab = v);
            }
          },
        ),
      ),
    );
  }
}

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.selected,
    this.unread = 0,
    required this.onChanged,
  });
  final int selected, unread;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      border: const Border(top: BorderSide(color: AppColors.line)),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF10233F).withValues(alpha: .06),
          blurRadius: 12,
          offset: const Offset(0, -2),
        ),
      ],
    ),
    child: SafeArea(
      top: false,
      child: SizedBox(
        height:
            AppDimensions.bottomNav +
            40 * (MediaQuery.textScalerOf(context).scale(1) - 1),
        child: Row(
          children: List.generate(5, (i) {
            if (i == 2) {
              return Expanded(
                child: Center(
                  child: Semantics(
                    button: true,
                    label: tr('Paylaşım oluştur'),
                    child: InkWell(
                      key: const Key('compose-button'),
                      borderRadius: BorderRadius.circular(25),
                      onTap: () => onChanged(i),
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          gradient: AppShape.activeTabGradient,
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: .32),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.add_rounded,
                          size: 29,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }
            final active = i == selected;
            return Expanded(
              child: InkWell(
                key: Key('nav-$i'),
                onTap: () => onChanged(i),
                child: Semantics(
                  selected: active,
                  button: true,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Badge(
                        isLabelVisible: i == 3 && unread > 0,
                        label: Text(unread > 99 ? '99+' : '$unread'),
                        backgroundColor: AppColors.encounterPink,
                        child: Icon(
                          [
                            active ? Icons.home_rounded : Icons.home_outlined,
                            active
                                ? Icons.location_on_rounded
                                : Icons.location_on_outlined,
                            Icons.add,
                            active
                                ? Icons.chat_bubble_rounded
                                : Icons.chat_bubble_outline_rounded,
                            active
                                ? Icons.person_rounded
                                : Icons.person_outline_rounded,
                          ][i],
                          size: 23,
                          color: active ? AppColors.primary : AppColors.muted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        ['Ana Sayfa', 'Harita', '', 'Mesajlar', 'Profil'][i],
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: active
                              ? FontWeight.w800
                              : FontWeight.w600,
                          color: active ? AppColors.primary : AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    ),
  );
}

/// Compact Home module: only when the user has unopened letters left near them (never an empty / begging card).
class _NearbyLettersCard extends StatelessWidget {
  const _NearbyLettersCard({required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: trf('Yakınında {0} yeni mektup var. Haritada keşfet.', [count]),
    child: Material(
      color: AppColors.surfaceLilac,
      shape: RoundedRectangleBorder(
        borderRadius: AppShape.rounded,
        side: const BorderSide(color: AppColors.borderLilac),
      ),
      child: InkWell(
        key: const Key('nearby-letters-card'),
        borderRadius: AppShape.rounded,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            children: [
              const AppIconBox(
                icon: Icons.mail_outline_rounded,
                size: AppDimensions.iconSM,
                containerSize: AppDimensions.iconContainerSM,
                color: AppColors.brandPurple,
                backgroundColor: Colors.white,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trf('Yakınında {0} yeni mektup var', [count]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.body.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy,
                      ),
                    ),
                    Text(
                      'Haritada keşfet',
                      style: AppTypography.metadata.copyWith(
                        color: AppColors.brandPurple,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.brandPurple,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class HomeContent extends StatelessWidget {
  const HomeContent({super.key, required this.onMap});
  final VoidCallback onMap;
  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    if (!store.connected) {
      return feedContent(
        context,
        store,
        store.feed,
        null,
        () async => store.refresh(),
      );
    }
    return PagedContent<Post>(
      key: ValueKey((
        store.city,
        store.filter,
        store.postsVersion,
        store.locationVersion,
        store.location?.synced,
        store.location?.allowed,
      )),
      fetch: store.loadFeed,
      id: (post) => post.id,
      visible: (post) => !store.blocked.contains(post.authorId),
      builder: (context, posts, footer, refresh) =>
          feedContent(context, store, posts, footer, refresh),
    );
  }

  Widget feedContent(
    BuildContext context,
    AppStore store,
    List<Post> posts,
    Widget? footer,
    Future<void> Function() refresh,
  ) {
    return RefreshIndicator(
      onRefresh: refresh,
      child: CustomScrollView(
        key: const PageStorageKey('home-feed'),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(Space.lg, Space.sm, Space.lg, 0),
            sliver: SliverList.list(
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: Space.md),
                  child: _FeedControls(store),
                ),
                InfoBanner(
                  'Şehrindeki insanları keşfet',
                  'Yakınındaki hikâyelere göz at.',
                  trailing: FilledButton.tonal(
                    onPressed: onMap,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.primary,
                      minimumSize: const Size(0, 36),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppShape.pill),
                      ),
                      textStyle: const TextStyle(
                        fontFamily: 'NunitoSans',
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                    child: const Text('Haritada Gör'),
                  ),
                ),
                if (store.homeAnnouncement case (final title, final body))
                  Padding(
                    padding: const EdgeInsets.only(top: Space.sm),
                    child: InfoBanner(
                      title,
                      body,
                      icon: Icons.campaign_outlined,
                      prominent: false,
                    ),
                  ),
                if (store.connected &&
                    store.nearbyNotesEnabled &&
                    store.nearbyUnread.visible)
                  Padding(
                    padding: const EdgeInsets.only(top: Space.sm),
                    child: _NearbyLettersCard(
                      count: store.nearbyUnread.count,
                      onTap: () {
                        store.openMapInNotes = true;
                        onMap();
                      },
                    ),
                  ),
                const SizedBox(height: Space.sm),
                if (store.nearbyModuleEnabled) ...[
                  SectionHeader(
                    'Yakınındaki İnsanlar',
                    icon: Icons.location_on_rounded,
                    onTap: () => openPage(context, '/nearby'),
                  ),
                  if (store.connected)
                    NearbyResults(
                      limit: 12,
                      builder: (context, people, status, retry) => nearbyStrip(
                        context,
                        store,
                        posts,
                        people
                            .map(
                              (entry) => (
                                entry.person,
                                locationDistance(entry.meters),
                              ),
                            )
                            .toList(),
                        status,
                        retry,
                      ),
                    )
                  else
                    nearbyStrip(
                      context,
                      store,
                      posts,
                      store.nearbyPeople
                          .where((person) => person.id != store.me.id)
                          .map((person) => (person, person.distanceLabel))
                          .toList(),
                      null,
                      null,
                    ),
                  const SizedBox(height: Space.xs),
                ],
                if (store.featuredModuleEnabled) ...[
                  SectionHeader(
                    'Öne Çıkan Karşılaşmalar',
                    icon: Icons.favorite_rounded,
                    onTap: () => openPage(context, '/featured'),
                  ),
                  if (store.connected)
                    PagedContent<Post>(
                      key: ValueKey((store.city, store.encounterVersion)),
                      fetch: store.loadFeaturedEncounters,
                      visible: (post) => post.storyParticipants.every(
                        (person) => !store.blocked.contains(person.id),
                      ),
                      builder: (context, posts, footer, _) => posts.isNotEmpty
                          ? FeaturedEncounterCarousel(
                              published: posts.take(8).toList(),
                            )
                          : footer ??
                                const InfoNote(
                                  'Yayınlanan karşılaşma hikâyeleri burada görünecek.',
                                ),
                    )
                  else if (store.featured.isNotEmpty)
                    FeaturedEncounterCarousel()
                  else
                    const InfoNote(
                      'Doğrulanan karşılaşmalar burada yerini alacak.',
                    ),
                ],
                const SizedBox(height: Space.md),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: AppShape.card(
                    color: Colors.white,
                    borderColor: const Color(0xFFDCE7F5),
                    elevated: true,
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 6),
                      Avatar(store.me, size: 38),
                      Expanded(
                        child: InkWell(
                          borderRadius: AppShape.control,
                          onTap: () => openPage(context, '/compose'),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 15,
                            ),
                            child: Text(
                              'Bir anını paylaş',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: Color(0xFF4E607D),
                              ),
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: tr('Fotoğraflı paylaşım'),
                        onPressed: () => openPage(context, '/compose', 'photo'),
                        icon: const Icon(
                          Icons.image_outlined,
                          color: AppColors.primaryBlue,
                          size: 21,
                        ),
                      ),
                      IconButton(
                        tooltip: tr('Paylaşım yeri'),
                        onPressed: () =>
                            openPage(context, '/compose', 'location'),
                        icon: const Icon(
                          Icons.location_on_outlined,
                          color: AppColors.primaryBlue,
                          size: 21,
                        ),
                      ),
                      IconButton(
                        tooltip: tr('Kamera'),
                        onPressed: () =>
                            openPage(context, '/compose', 'camera'),
                        icon: const Icon(
                          Icons.camera_alt_outlined,
                          color: AppColors.primaryBlue,
                          size: 21,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Space.md),
              ],
            ),
          ),
          if (posts.isEmpty && footer == null && store.filter.sort == 'Takip')
            SliverToBoxAdapter(
              child: FutureBuilder<bool>(
                key: ValueKey(store.followsVersion),
                future: store.followsAnyone(),
                builder: (context, snapshot) {
                  final following = snapshot.data ?? false;
                  return EmptyState(
                    following
                        ? 'Takip ettiklerin henüz bir şey paylaşmadı.'
                        : 'Henüz kimseyi takip etmiyorsun.',
                    following
                        ? 'Yeni paylaşımları burada görünecek. Anonim paylaşımlar Takip akışında yer almaz.'
                        : 'İlgini çeken insanları takip et; paylaşımları şehrinin akışından ayrı olarak burada görünsün.',
                    action: SecondaryButton(
                      'İnsanları Keşfet',
                      icon: Icons.search_rounded,
                      onPressed: () => openPage(context, '/search'),
                    ),
                  );
                },
              ),
            )
          else if (posts.isEmpty && footer == null)
            SliverToBoxAdapter(
              child: EmptyState(
                store.connected &&
                        store.radiusMeters != null &&
                        store.location?.synced != true
                    ? 'Mesafe filtresi için cihaz konumu gerekli.'
                    : 'Burada henüz bir iz yok.',
                'Filtrelerini değiştir veya şehrinin ilk hikâyesini paylaş.',
                action: SecondaryButton(
                  'Filtreleri Temizle',
                  onPressed: () {
                    store.applyFilter(FeedFilter());
                  },
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: Space.lg),
              sliver: Builder(
                builder: (context) {
                  // Native ads: after the 7th organic post, then every `feed_ad_interval` posts. The layout depends
                  // only on how many organic posts are loaded, so paging never shuffles what is already on screen.
                  final rows = feedRows(
                    posts.length,
                    ads: store.showFeedAds,
                    interval: store.feedAdInterval,
                  );
                  return SliverList.builder(
                    itemCount: rows.length,
                    itemBuilder: (_, i) {
                      final row = rows[i];
                      if (row.isAd) {
                        return NativeFeedAd(
                          key: ValueKey('feed-ad-${row.adSlot}'),
                        );
                      }
                      final post = posts[row.organic!];
                      return PostCard(post, key: ValueKey(post.id));
                    },
                  );
                },
              ),
            ),
          if (footer != null) SliverToBoxAdapter(child: footer),
          const SliverToBoxAdapter(child: SizedBox(height: Space.xl)),
        ],
      ),
    );
  }

  Widget nearbyStrip(
    BuildContext context,
    AppStore store,
    List<Post> posts,
    List<(Person, String)> nearby,
    String? status,
    VoidCallback? retry,
  ) {
    Widget composeItem() => Semantics(
      button: true,
      label: tr('Paylaşım oluştur'),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppShape.pill),
        onTap: () => openPage(context, '/compose'),
        child: SizedBox(
          width: 68,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surfaceBlue,
                  border: Border.all(
                    color: const Color(0xFFD6E4F7),
                    width: 1.5,
                  ),
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

    final List<(Person, String)> items;
    if (nearby.isNotEmpty) {
      items = nearby;
    } else {
      final list = <(Person, String, double)>[];
      final seen = <String>{store.me.id};
      for (final p in posts) {
        final participants = p.storyParticipants.isNotEmpty
            ? p.storyParticipants
            : [if (!p.anonymous) store.person(p.authorId)];
        for (final person in participants) {
          if (seen.add(person.id) && !store.blocked.contains(person.id)) {
            final double distKm =
                (p.distanceMeters != null && p.distanceMeters! > 0)
                ? p.distanceMeters! / 1000.0
                : (p.distance > 0
                      ? p.distance
                      : (person.distance > 0
                            ? person.distance
                            : (0.4 + (list.length * 0.4))));
            final distStr =
                '${distKm.toStringAsFixed(1).replaceAll('.', ',')} km';
            list.add((person, distStr, distKm));
          }
        }
      }
      if (list.isEmpty) {
        for (final person in store.nearbyPeople) {
          if (seen.add(person.id) &&
              person.id != store.me.id &&
              !store.blocked.contains(person.id)) {
            final distKm = person.distance > 0
                ? person.distance
                : (0.4 + (list.length * 0.4));
            final distStr =
                '${distKm.toStringAsFixed(1).replaceAll('.', ',')} km';
            list.add((person, distStr, distKm));
          }
        }
      }
      if (list.isEmpty) {
        for (final person in store.people) {
          if (seen.add(person.id) &&
              person.id != store.me.id &&
              !store.blocked.contains(person.id)) {
            final distKm = person.distance > 0
                ? person.distance
                : (0.4 + (list.length * 0.4));
            final distStr =
                '${distKm.toStringAsFixed(1).replaceAll('.', ',')} km';
            list.add((person, distStr, distKm));
          }
        }
      }
      list.sort((a, b) => a.$3.compareTo(b.$3));
      items = list.map((e) => (e.$1, e.$2)).toList();
    }

    if (items.isEmpty && status != null) {
      final isLoading =
          status.contains('yükleniyor') || status.contains('alınıyor');
      final isEmpty = status.contains('bulunamadı');
      return Padding(
        padding: const EdgeInsets.only(top: 2, bottom: 4),
        child: Row(
          children: [
            composeItem(),
            const SizedBox(width: 10),
            Expanded(
              child: InlineState(
                icon: isLoading
                    ? Icons.my_location_outlined
                    : isEmpty
                    ? Icons.people_outline_rounded
                    : Icons.location_off_outlined,
                title: isLoading
                    ? 'Yakındaki kişiler yükleniyor'
                    : isEmpty
                    ? 'Yakında görünür kimse bulunamadı'
                    : 'Konumuna ulaşılamadı',
                description: isLoading
                    ? 'Bölgendeki görünür profiller kontrol ediliyor.'
                    : isEmpty
                    ? 'Şehir akışındaki paylaşımlara göz atabilirsin.'
                    : 'Yakındaki kişileri göstermek için yeniden dene.',
                actionLabel: isLoading || retry == null ? null : 'Tekrar Dene',
                onAction: isLoading ? null : retry,
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: 88 + 15 * (MediaQuery.textScalerOf(context).scale(1) - 1),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          if (i == 0) return composeItem();
          final (p, distance) = items[i - 1];
          final cleanDist = distance.replaceAll('⌖ ', '').trim();
          return InkWell(
            borderRadius: AppShape.control,
            onTap: () => openPage(context, '/profile', p.id),
            child: SizedBox(
              width: 68,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Avatar(p, size: 58),
                  const SizedBox(height: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceBlue,
                      borderRadius: BorderRadius.circular(AppShape.pill),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.location_on_rounded,
                          size: 10,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 2),
                        Flexible(
                          child: Text(
                            cleanDist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: AppColors.navy,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FeedControls extends StatelessWidget {
  const _FeedControls(this.store);
  final AppStore store;

  static const _entries = [
    ('Akış', Icons.format_list_bulleted_rounded, 'Yeni'),
    ('Takip', Icons.people_outline_rounded, 'Takip'),
    ('Yakın', Icons.location_on_rounded, 'En yakın'),
    ('Popüler', Icons.local_fire_department_rounded, 'Popüler'),
  ];

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      // Phones (<= 430 dp wide screens) always get the social tabs on their own full-width row and the city picker
      // below, right aligned: nothing is clipped or covered. Only genuinely wide layouts keep them on one line.
      final wide = width >= 560;
      final bigText = MediaQuery.textScalerOf(context).scale(1) > 1.3;
      final iconless = width < 340 || bigText;
      Widget tab(int idx) {
        final entry = _entries[idx];
        return _FeedTab(
          entry.$1,
          entry.$2,
          showIcon: !iconless,
          selected: store.filter.sort == entry.$3,
          onTap: () => store.applyFilter(store.filter.copy()..sort = entry.$3),
        );
      }

      final tabs = wide
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < _entries.length; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  tab(i),
                ],
              ],
            )
          : bigText
          // Very large text: two even rows of two instead of squeezing a word.
          ? Column(
              children: [
                Row(
                  children: [
                    Expanded(child: tab(0)),
                    const SizedBox(width: 6),
                    Expanded(child: tab(1)),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(child: tab(2)),
                    const SizedBox(width: 6),
                    Expanded(child: tab(3)),
                  ],
                ),
              ],
            )
          : Row(
              children: [
                for (var i = 0; i < _entries.length; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(child: tab(i)),
                ],
              ],
            );
      final city = ConstrainedBox(
        constraints: BoxConstraints(maxWidth: wide ? 160 : width),
        child: TextButton(
          key: const Key('feed-city'),
          onPressed: () async {
            final selected = await chooseCity(context, store.city);
            if (selected != null && context.mounted) {
              await socialAction(context, () => store.setCity(selected));
            }
          },
          style: TextButton.styleFrom(
            foregroundColor: AppColors.navy,
            backgroundColor: Colors.white,
            minimumSize: const Size(0, 36),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFFE9D5FF)),
            ),
            textStyle: AppTypography.metadata.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 12.5,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.location_on_rounded,
                size: 16,
                color: AppColors.primary,
              ),
              const SizedBox(width: 4),
              Flexible(child: Text(store.city, textAlign: TextAlign.center)),
              const SizedBox(width: 2),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 16,
                color: AppColors.muted,
              ),
            ],
          ),
        ),
      );
      return wide
          ? Row(
              children: [
                Expanded(child: tabs),
                const SizedBox(width: Space.sm),
                city,
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                tabs,
                const SizedBox(height: Space.sm),
                Align(alignment: Alignment.centerRight, child: city),
              ],
            );
    },
  );
}

class _FeedTab extends StatelessWidget {
  const _FeedTab(
    this.label,
    this.icon, {
    required this.selected,
    required this.onTap,
    this.showIcon = true,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final bool showIcon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(12),
    onTap: onTap,
    child: Container(
      constraints: const BoxConstraints(minHeight: 40),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: selected
          ? BoxDecoration(
              gradient: AppShape.activeTabGradient,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: .22),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            )
          : BoxDecoration(
              color: AppColors.surfaceBlue,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFD6E4F7)),
            ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showIcon) ...[
              Icon(
                icon,
                size: 15,
                color: selected ? Colors.white : AppColors.primary,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
                color: selected ? Colors.white : AppColors.navy,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class FeaturedEncounterCarousel extends StatefulWidget {
  const FeaturedEncounterCarousel({super.key, this.published});
  final List<Post>? published;
  @override
  State<FeaturedEncounterCarousel> createState() =>
      FeaturedEncounterCarouselState();
}

class FeaturedEncounterCarouselState extends State<FeaturedEncounterCarousel> {
  int index = 0;
  final heights = <String, double>{};
  @override
  Widget build(BuildContext context) {
    final stories = widget.published;
    final list = stories == null
        ? StoreScope.of(context).featured
        : const <Encounter>[];
    final count = stories?.length ?? list.length;
    if (count == 0) return const SizedBox.shrink();
    index = index.clamp(0, count - 1);
    final selected = stories == null
        ? 'encounter-${list[index].id}'
        : 'post-${stories[index].id}';
    final initialHeight = stories != null && stories[index].images.isNotEmpty
        ? 282.0
        : 124.0;
    return Column(
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.topCenter,
          child: SizedBox(
            height: heights[selected] ?? initialHeight,
            child: PageView.builder(
              onPageChanged: (v) => setState(() => index = v),
              itemCount: count,
              itemBuilder: (_, i) {
                final id = stories == null
                    ? 'encounter-${list[i].id}'
                    : 'post-${stories[i].id}';
                return OverflowBox(
                  minHeight: 0,
                  maxHeight: double.infinity,
                  alignment: Alignment.topCenter,
                  child: _MeasuredHeight(
                    key: ValueKey(id),
                    onHeight: (height) {
                      if (mounted && heights[id] != height) {
                        setState(() => heights[id] = height);
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(right: 3, bottom: 4),
                      child: stories == null
                          ? EncounterCard(list[i])
                          : PublishedEncounterCard(stories[i], compact: true),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        if (count > 1)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                count,
                (i) => Container(
                  width: i == index ? 18 : 6,
                  height: 5,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppShape.pill),
                    color: i == index
                        ? AppColors.primaryBlue
                        : const Color(0xFFD5E2F2),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _MeasuredHeight extends SingleChildRenderObjectWidget {
  const _MeasuredHeight({
    super.key,
    required this.onHeight,
    required super.child,
  });
  final ValueChanged<double> onHeight;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _HeightReporter(onHeight);
  @override
  void updateRenderObject(
    BuildContext context,
    covariant _HeightReporter renderObject,
  ) {
    renderObject.onHeight = onHeight;
  }
}

class _HeightReporter extends RenderProxyBox {
  _HeightReporter(this.onHeight);
  ValueChanged<double> onHeight;
  double? previous;
  @override
  void performLayout() {
    super.performLayout();
    if (size.height != previous) {
      previous = size.height;
      final height = size.height;
      WidgetsBinding.instance.addPostFrameCallback((_) => onHeight(height));
    }
  }
}
