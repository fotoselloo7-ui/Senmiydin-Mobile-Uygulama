import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../core/navigation.dart';
import '../data/account_api.dart';
import '../data/app_store.dart';
import '../data/models.dart';
import '../data/location_api.dart';
import '../widgets/common.dart';
import '../widgets/location_ui.dart';
import 'live_map.dart';
import '../widgets/social.dart';
import '../widgets/social_page.dart';

String searchKey(String value) => turkishSearchKey(value);

class FilterPage extends StatefulWidget {
  const FilterPage({super.key});
  @override
  State<FilterPage> createState() => _FilterPageState();
}

class _FilterPageState extends State<FilterPage> {
  FeedFilter? draft;
  Future<List<CatalogItem>>? interests;
  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    draft ??= store.filter.copy();
    interests ??= store.loadInterests();
    final f = draft!;
    return AppPage(
      title: 'Filtreler',
      actions: [
        TextButton(
          onPressed: () => setState(() => draft = FeedFilter()),
          child: const Text('Sıfırla', style: TextStyle(fontSize: 12)),
        ),
      ],
      bottom: Row(
        children: [
          Expanded(
            child: SecondaryButton(
              'Temizle',
              icon: Icons.refresh,
              onPressed: () => setState(() => draft = FeedFilter()),
            ),
          ),
          const SizedBox(width: Space.md),
          Expanded(
            flex: 2,
            child: PrimaryButton(
              'Uygula',
              icon: Icons.check,
              onPressed: () {
                store.applyFilter(f);
                Navigator.pop(context);
              },
            ),
          ),
        ],
      ),
      child: ListView(
        padding: Space.page,
        children: [
          const InfoBanner(
            'Paylaşımları dilediğin gibi filtrele!',
            'Sana en uygun içerikleri keşfet.',
            icon: Icons.filter_alt_outlined,
          ),
          const SizedBox(height: Space.md),
          const SectionHeader('Konum', icon: Icons.location_on_outlined),
          ChoicePills(
            options: const ['Tüm şehir', '5 km', '10 km', '25 km'],
            value: f.range,
            onChanged: (v) {
              setState(() => f.range = v);
              if (store.connected &&
                  v != 'Tüm şehir' &&
                  store.location?.synced != true) {
                unawaited(store.location?.activateFromUi());
              }
            },
          ),
          const Divider(height: 26),
          const SectionHeader('Sıralama', icon: Icons.swap_vert),
          ChoicePills(
            options: const ['En yakın', 'Yeni', 'Popüler'],
            value: f.sort,
            onChanged: (v) => setState(() => f.sort = v),
          ),
          const Divider(height: 26),
          const SectionHeader('İçerik', icon: Icons.layers_outlined),
          ChoicePills(
            options: const [
              'Tüm paylaşımlar',
              'Karşılaşmalar',
              'Etiketli',
              'Anı',
              'İtiraf',
              'Düşünce',
              'Yolculuk',
            ],
            value: f.content,
            onChanged: (v) {
              setState(() => f.content = v);
            },
          ),
          const Divider(height: 26),
          const SectionHeader('Medya', icon: Icons.image_outlined),
          ChoicePills(
            options: const ['Tümü', 'Fotoğraflı', 'Yazılı'],
            value: f.media,
            onChanged: (v) => setState(() => f.media = v),
          ),
          const Divider(height: 26),
          const SectionHeader('İlgi Alanları', icon: Icons.favorite_border),
          FutureBuilder(
            future: interests,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return TextButton(
                  onPressed: () =>
                      setState(() => interests = store.loadInterests()),
                  child: const Text('İlgi alanları yüklenemedi. Tekrar dene.'),
                );
              }
              if (!snapshot.hasData) {
                return const LoadingState();
              }
              return Wrap(
                spacing: 8,
                children: [
                  for (final item in snapshot.data!)
                    InterestChip(
                      item.name,
                      selected: f.interests.contains(item.name),
                      onTap: () => setState(
                        () => f.interests.contains(item.name)
                            ? f.interests.remove(item.name)
                            : f.interests.add(item.name),
                      ),
                    ),
                ],
              );
            },
          ),
          const Divider(height: 26),
          PreferenceRow('Sadece yakınımdakileri göster', f.nearbyOnly, (v) {
            setState(() => f.nearbyOnly = v);
            if (v && store.connected && store.location?.synced != true) {
              unawaited(store.location?.activateFromUi());
            }
          }),
          PreferenceRow(
            'Fotoğraflı paylaşımlar öncelikli',
            f.photoFirst,
            (v) => setState(() => f.photoFirst = v),
          ),
          PreferenceRow(
            'Karşılaşma hikâyelerini öne çıkar',
            f.encounterFirst,
            (v) => setState(() => f.encounterFirst = v),
          ),
        ],
      ),
    );
  }
}

class SearchPage extends StatefulWidget {
  const SearchPage({
    super.key,
    this.tag = false,
    this.messageRecipient = false,
    this.sharedPost,
  });
  final bool tag, messageRecipient;
  final String? sharedPost;
  bool get peoplePicker => tag || messageRecipient;
  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final controller = TextEditingController();
  String tab = 'İnsanlar';
  Future<List<CatalogItem>>? cities;
  Timer? debounce;
  String submittedQuery = '';

  void searchChanged(bool connected) {
    debounce?.cancel();
    setState(() {
      if (!connected || controller.text.isEmpty) submittedQuery = '';
    });
    if (connected && controller.text.isNotEmpty) {
      debounce = Timer(const Duration(milliseconds: 320), () {
        setState(
          () => submittedQuery = controller.text.trim().replaceFirst(
            RegExp(r'^@'),
            '',
          ),
        );
      });
    }
  }

  @override
  void dispose() {
    debounce?.cancel();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context), query = searchKey(controller.text);
    if (tab == 'Şehirler') cities ??= store.loadCities();
    final people = store.people
        .where(
          (p) =>
              !store.blocked.contains(p.id) &&
              (!widget.peoplePicker || p.id != store.me.id) &&
              (searchKey(p.handle).contains(query) ||
                  searchKey(p.name).contains(query)),
        )
        .toList();
    final posts = store.posts
        .where(
          (p) =>
              !store.blocked.contains(p.authorId) &&
              searchKey(p.text).contains(query),
        )
        .toList();
    return AppPage(
      title: widget.tag
          ? 'Karşılaştığım Kişiyi Etiketle'
          : widget.messageRecipient
          ? 'Yeni Mesaj'
          : 'Ara',
      child: Column(
        children: [
          Padding(
            padding: Space.page,
            child: Column(
              children: [
                Semantics(
                  label: widget.tag
                      ? 'Kullanıcı adı ara'
                      : 'İnsan, kullanıcı adı veya paylaşım ara',
                  child: TextField(
                    key: Key(widget.tag ? 'tag-search' : 'global-search'),
                    controller: controller,
                    maxLength: 80,
                    onChanged: (_) => searchChanged(store.connected),
                    decoration: InputDecoration(
                      hintText: widget.tag
                          ? '@kullanıcıadı ara…'
                          : 'İnsan, @kullanıcıadı veya paylaşım ara…',
                      prefixIcon: const Icon(Icons.search),
                      counterText: '',
                      suffixIcon: controller.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Aramayı temizle',
                              onPressed: () {
                                controller.clear();
                                searchChanged(store.connected);
                              },
                              icon: const Icon(Icons.close),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: Space.md),
                if (widget.tag && MediaQuery.viewInsetsOf(context).bottom == 0)
                  const InfoNote(
                    'Etiketlediğin kişi karşılaşmayı onaylayarak bu anıyı seninle birlikte doğrulayabilir. Onaylanana kadar karşılaşma beklemede kalır.',
                  )
                else if (!widget.peoplePicker)
                  ChoicePills(
                    options: const ['İnsanlar', 'Paylaşımlar', 'Şehirler'],
                    value: tab,
                    onChanged: (v) => setState(() => tab = v),
                  ),
              ],
            ),
          ),
          Expanded(
            child: query.isEmpty
                ? EmptyState(
                    widget.tag
                        ? 'O kişiyi kullanıcı adıyla bul.'
                        : 'Bir merhaba kadar yakın.',
                    widget.tag
                        ? 'Aramaya başladığında eşleşen profiller burada görünecek.'
                        : 'Bir isim, kullanıcı adı veya hikâyede aklında kalan bir kelime yaz.',
                    icon: Icons.search_rounded,
                  )
                : store.connected && tab != 'Şehirler'
                ? remoteResults(store)
                : widget.tag || tab == 'İnsanlar'
                ? people.isEmpty
                      ? const EmptyState(
                          'Bir eşleşme bulamadık.',
                          'Kullanıcı adını kontrol edip yeniden dene.',
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(
                            horizontal: Space.lg,
                          ),
                          itemCount: people.length,
                          separatorBuilder: (_, _) => const Divider(),
                          itemBuilder: (_, i) => UserRow(
                            people[i],
                            trailing: widget.tag
                                ? const Icon(
                                    Icons.add_circle_outline,
                                    color: AppColors.blue,
                                  )
                                : null,
                            onTap: () {
                              if (widget.tag) {
                                Navigator.pop(context, people[i].id);
                              } else {
                                openPage(context, '/profile', people[i].id);
                              }
                            },
                          ),
                        )
                : tab == 'Paylaşımlar'
                ? posts.isEmpty
                      ? const EmptyState(
                          'Bu kelimeyle bir paylaşım yok.',
                          'Başka bir kelimeyle aramayı dene.',
                        )
                      : ListView.builder(
                          padding: Space.page,
                          itemCount: posts.length,
                          itemBuilder: (_, i) => PostCard(posts[i]),
                        )
                : FutureBuilder(
                    future: cities,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(
                          child: TextButton(
                            onPressed: () =>
                                setState(() => cities = store.loadCities()),
                            child: const Text(
                              'Şehirler yüklenemedi. Tekrar dene.',
                            ),
                          ),
                        );
                      }
                      if (!snapshot.hasData) {
                        return const LoadingState();
                      }
                      return ListView(
                        children: [
                          for (final city in snapshot.data!)
                            if (searchKey(city.name).contains(query))
                              ListTile(
                                leading: const Icon(
                                  Icons.location_on_outlined,
                                  color: AppColors.blue,
                                ),
                                title: Text(city.name),
                                onTap: () async {
                                  await socialAction(
                                    context,
                                    () => store.setCity(city.name),
                                  );
                                  if (context.mounted) home(context);
                                },
                              ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget remoteResults(AppStore store) {
    final text = submittedQuery;
    final query = widget.tag ? text.replaceFirst(RegExp(r'^@+'), '') : text;
    if (query.runes.length < 2) {
      return const EmptyState(
        'Aramak için en az iki karakter yaz.',
        'Ad, kullanıcı adı veya bir kelimeyle ara.',
        icon: Icons.search_rounded,
      );
    }
    if (widget.peoplePicker || tab == 'İnsanlar') {
      return PagedContent<Person>(
        key: ValueKey(text),
        fetch: (page) => store.searchPeople(text, page, encounter: widget.tag),
        id: (person) => person.id,
        visible: (person) =>
            !store.blocked.contains(person.id) &&
            (!widget.peoplePicker || person.id != store.me.id),
        builder: (context, people, footer, _) => ListView(
          padding: Space.page,
          children: [
            if (people.isEmpty && footer == null)
              const EmptyState(
                'Bir eşleşme bulamadık.',
                'Kullanıcı adını kontrol edip yeniden dene.',
              ),
            for (final person in people)
              UserRow(
                person,
                trailing: widget.tag
                    ? const Icon(
                        Icons.add_circle_outline,
                        color: AppColors.blue,
                      )
                    : null,
                onTap: () {
                  if (widget.tag) {
                    Navigator.pop(context, person.id);
                  } else if (widget.messageRecipient) {
                    final shared = widget.sharedPost;
                    openPage(
                      context,
                      '/chat',
                      shared == null
                          ? person.id
                          : (
                              person.id,
                              'Bu paylaşımı seninle paylaşmak istedim:\n\n${store.post(shared).text}',
                            ),
                    );
                  } else {
                    openPage(context, '/profile', person.id);
                  }
                },
              ),
            ?footer,
          ],
        ),
      );
    }
    return PagedContent<Post>(
      key: ValueKey((text, store.city, store.postsVersion)),
      fetch: (page) => store.searchPosts(text, page),
      id: (post) => post.id,
      visible: (post) => !store.blocked.contains(post.authorId),
      builder: (context, posts, footer, _) => ListView(
        padding: Space.page,
        children: [
          if (posts.isEmpty && footer == null)
            const EmptyState(
              'Bu kelimeyle bir paylaşım yok.',
              'Başka bir kelimeyle aramayı dene.',
            ),
          for (final post in posts) PostCard(post, key: ValueKey(post.id)),
          ?footer,
        ],
      ),
    );
  }
}

class NearbyPage extends StatelessWidget {
  const NearbyPage({super.key});
  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    if (store.connected) {
      return AppPage(
        title: 'Yakınındaki İnsanlar',
        child: NearbyResults(
          builder: (context, people, status, retry) => ListView(
            padding: Space.page,
            children: [
              const InfoNote(
                'Yalnızca konum görünürlüğünü açan profiller burada listelenir. Mesafeler yaklaşık gösterilir.',
              ),
              const SizedBox(height: Space.lg),
              if (status != null)
                EmptyState(
                  status,
                  'Şehir akışına her zaman dönebilirsin.',
                  action: SecondaryButton(
                    'Konumu Kontrol Et',
                    onPressed: retry,
                  ),
                ),
              for (final entry in people)
                UserRow(
                  entry.person,
                  subtitle:
                      '@${entry.person.handle} · ${locationDistance(entry.meters)}',
                  onTap: () => openPage(context, '/profile', entry.person.id),
                ),
            ],
          ),
        ),
      );
    }
    final people = store.nearbyPeople
        .where((p) => p.id != store.me.id)
        .toList();
    return AppPage(
      title: 'Yakınındaki İnsanlar',
      child: ListView(
        padding: Space.page,
        children: [
          const InfoNote(
            'Burada yalnızca konum görünürlüğüne izin veren profiller yer alır. Mesafeler yaklaşık olarak gösterilir.',
          ),
          const SizedBox(height: Space.lg),
          if (people.isEmpty)
            const EmptyState(
              'Yeni karşılaşmalara yer var.',
              'Bu şehirde henüz görünür bir profil bulunmuyor.',
            ),
          ...people.map(
            (p) => UserRow(
              p,
              subtitle: store.connected
                  ? '@${p.handle} · ${p.city}'
                  : '@${p.handle} · ${p.distanceLabel}',
              onTap: () => openPage(context, '/profile', p.id),
            ),
          ),
        ],
      ),
    );
  }
}

class MapContent extends StatefulWidget {
  const MapContent({super.key});
  @override
  State<MapContent> createState() => _MapContentState();
}

class _MapContentState extends State<MapContent> {
  String? selected;
  bool showPosts = false;
  final transform = TransformationController();
  @override
  void dispose() {
    transform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    if (store.connected) return const LiveMapContent();
    final people = store.nearbyPeople
        .where(
          (p) =>
              p.id != store.me.id &&
              p.distance <= store.filter.maxDistance &&
              (!store.filter.nearbyOnly || p.distance <= 5),
        )
        .take(7)
        .toList();
    final posts = store.feed.take(7).toList();
    final count = showPosts ? posts.length : people.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Şehrinde bir iz bul.',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      '${store.city} · ${store.connected ? 'Örnek konumlar' : 'Yaklaşık konumlar'}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Harita filtreleri',
                onPressed: () => openPage(context, '/filters'),
                icon: const Icon(Icons.tune, color: AppColors.blue),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ChoicePills(
            options: const ['Tüm şehir', '5 km', '10 km', '25 km'],
            value: store.filter.range,
            onChanged: (v) {
              store.applyFilter(store.filter.copy()..range = v);
              setState(() => selected = null);
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              TextButton.icon(
                onPressed: () => setState(() {
                  showPosts = false;
                  selected = null;
                }),
                icon: Icon(
                  Icons.people_outline,
                  color: !showPosts ? AppColors.blue : AppColors.muted,
                ),
                label: Text(
                  'İnsanlar',
                  style: TextStyle(
                    color: !showPosts ? AppColors.blue : AppColors.muted,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => setState(() {
                  showPosts = true;
                  selected = null;
                }),
                icon: Icon(
                  Icons.chat_bubble_outline,
                  color: showPosts ? AppColors.blue : AppColors.muted,
                ),
                label: Text(
                  'Paylaşımlar',
                  style: TextStyle(
                    color: showPosts ? AppColors.blue : AppColors.muted,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: ClipRRect(
              borderRadius: AppShape.rounded,
              child: LayoutBuilder(
                builder: (context, size) => Stack(
                  children: [
                    Positioned.fill(
                      child: InteractiveViewer(
                        transformationController: transform,
                        maxScale: 2.5,
                        minScale: 1,
                        child: SizedBox(
                          width: size.maxWidth,
                          height: size.maxHeight,
                          child: Stack(
                            children: [
                              const Positioned.fill(
                                child: CustomPaint(painter: _MapPainter()),
                              ),
                              Positioned(
                                top: size.maxHeight * .18,
                                left: size.maxWidth * .12,
                                child: const Text(
                                  'ŞEHİR MERKEZİ',
                                  style: TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 12,
                                    letterSpacing: 2,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              Positioned(
                                top: size.maxHeight * .56,
                                right: 28,
                                child: const Text(
                                  'SAHİL',
                                  style: TextStyle(
                                    color: AppColors.action,
                                    fontSize: 11,
                                    letterSpacing: 3,
                                  ),
                                ),
                              ),
                              for (int i = 0; i < count; i++)
                                Positioned(
                                  left:
                                      (size.maxWidth - 60) *
                                      [.22, .6, .4, .72, .12, .46, .8][i],
                                  top:
                                      (size.maxHeight - 100) *
                                      [.25, .38, .59, .18, .66, .12, .54][i],
                                  child: GestureDetector(
                                    onTap: () => setState(
                                      () => selected = showPosts
                                          ? posts[i].id
                                          : people[i].id,
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(30),
                                        border: Border.all(
                                          color: AppColors.blue,
                                          width: 2,
                                        ),
                                        boxShadow: AppShape.shadow,
                                      ),
                                      child: showPosts
                                          ? const Padding(
                                              padding: EdgeInsets.all(6),
                                              child: Icon(
                                                Icons.chat_bubble_rounded,
                                                color: AppColors.blue,
                                                size: 23,
                                              ),
                                            )
                                          : Avatar(people[i], size: 35),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 12,
                      right: 12,
                      child: Column(
                        children: [
                          FloatingActionButton.small(
                            heroTag: 'zoom-in',
                            tooltip: 'Yakınlaştır',
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.blue,
                            onPressed: () =>
                                transform.value = Matrix4.identity()
                                  ..scaleByDouble(1.6, 1.6, 1, 1),
                            child: const Icon(Icons.add),
                          ),
                          const SizedBox(height: 6),
                          FloatingActionButton.small(
                            heroTag: 'zoom-out',
                            tooltip: 'Haritayı sıfırla',
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.blue,
                            onPressed: () =>
                                transform.value = Matrix4.identity(),
                            child: const Icon(Icons.my_location_outlined),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: AppShape.card(),
                        child: const Text(
                          'Örnek harita',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.muted,
                          ),
                        ),
                      ),
                    ),
                    if (count == 0)
                      const Center(
                        child: EmptyState(
                          'Bu bölgede henüz bir iz yok.',
                          'Daha geniş bir mesafe seçebilirsin.',
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (selected != null &&
            (showPosts
                ? posts.any((p) => p.id == selected)
                : people.any((p) => p.id == selected)))
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: showPosts
                ? SizedBox(
                    height: 112,
                    child: ListTile(
                      leading: const Icon(
                        Icons.chat_bubble_outline,
                        color: AppColors.blue,
                      ),
                      title: Text(
                        store.post(selected!).text,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: const Text('Paylaşımı görüntüle →'),
                      onTap: () => openPage(context, '/post', selected),
                    ),
                  )
                : UserRow(
                    store.person(selected!),
                    onTap: () => openPage(context, '/profile', selected),
                  ),
          ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Text(
            'Kesin konumlar paylaşılmaz. Pinler yaklaşık bölgeleri temsil eder.',
            style: TextStyle(color: AppColors.muted, fontSize: 11),
          ),
        ),
      ],
    );
  }
}

class _MapPainter extends CustomPainter {
  const _MapPainter();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFF0F5FA),
    );
    final sea = Path()
      ..moveTo(size.width, size.height * .47)
      ..quadraticBezierTo(
        size.width * .72,
        size.height * .55,
        size.width * .62,
        size.height,
      )
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(sea, Paint()..color = const Color(0xFFCEEEFF));
    final green = Paint()..color = const Color(0xFFDCEEE4);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * .08,
          size.height * .29,
          size.width * .24,
          size.height * .17,
        ),
        const Radius.circular(20),
      ),
      green,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * .47,
          size.height * .08,
          size.width * .25,
          size.height * .15,
        ),
        const Radius.circular(20),
      ),
      green,
    );
    final road = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 11;
    for (int i = 1; i < 6; i++) {
      canvas.drawPath(
        Path()
          ..moveTo(0, size.height * i / 6)
          ..quadraticBezierTo(
            size.width * .5,
            size.height * (i / 6 - .09),
            size.width,
            size.height * (i / 6 + .04),
          ),
        road,
      );
      canvas.drawPath(
        Path()
          ..moveTo(size.width * i / 6, 0)
          ..lineTo(size.width * (i / 6 - .2), size.height),
        road,
      );
    }
    final coast = Path()
      ..moveTo(size.width * .85, 0)
      ..quadraticBezierTo(
        size.width * .85,
        size.height * .5,
        size.width * .41,
        size.height,
      );
    canvas.drawPath(
      coast,
      Paint()
        ..color = Colors.white
        ..strokeWidth = 16
        ..style = PaintingStyle.stroke,
    );
    canvas.drawPath(
      coast,
      Paint()
        ..color = const Color(0xFFE0DCBD)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
