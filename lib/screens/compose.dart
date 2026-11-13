import '../data/post_context.dart';
import '../widgets/post_context.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../core/theme.dart';
import '../core/navigation.dart';
import '../data/app_store.dart';
import '../data/encounter_api.dart';
import 'encounters.dart';
import '../data/account_api.dart';
import '../widgets/account_action.dart';
import '../data/models.dart';
import '../data/mock_data.dart';
import '../widgets/common.dart';
import '../widgets/social.dart';

class ComposePage extends StatefulWidget {
  const ComposePage({
    super.key,
    this.media,
    this.storyFor,
    this.reviseStory = false,
  });
  final String? media;
  final EncounterEntry? storyFor;
  final bool reviseStory;
  @override
  State<ComposePage> createState() => _ComposePageState();
}

class _ComposePageState extends State<ComposePage>
    with AccountAction<ComposePage> {
  final placeKey = GlobalKey();
  final text = TextEditingController();
  final storyTitle = TextEditingController();
  bool get composingStory => widget.storyFor != null;
  bool get canPublish => composingStory
      ? storyTitle.text.trim().isNotEmpty && text.text.trim().isNotEmpty
      : text.text.trim().isNotEmpty || images.isNotEmpty;
  final picker = ImagePicker();
  final requestId = const Uuid().v4();
  bool publishing = false;
  bool attachLocation = false;
  PostPlaceSelection? place;
  DateTime? occurredAt;
  final travelDraft = TravelDraft();
  PostKind kind = PostKind.memory;
  final List<String> images = [];
  String? taggedId, city;
  bool anonymous = false, cityWide = true, submitted = false;
  @override
  void initState() {
    super.initState();
    if (composingStory) {
      kind = PostKind.encounter;
      if (widget.reviseStory) {
        storyTitle.text = widget.storyFor?.story?.storyTitle ?? '';
        text.text = widget.storyFor?.story?.text ?? '';
      }
    }
    if (widget.media == 'photo' || widget.media == 'camera') {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => widget.media == 'camera' ? camera() : pickPhotos(),
      );
    } else if (widget.media == 'location') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final target = placeKey.currentContext;
        if (mounted && target != null) {
          Scrollable.ensureVisible(target, alignment: .1);
        }
      });
    }
  }

  @override
  void dispose() {
    text.dispose();
    storyTitle.dispose();
    super.dispose();
  }

  bool get dirty =>
      text.text.trim().isNotEmpty ||
      images.isNotEmpty ||
      taggedId != null ||
      storyTitle.text.trim().isNotEmpty ||
      place != null ||
      occurredAt != null ||
      travelDraft.enabled;
  Future<void> pickPhotos() async {
    if (StoreScope.of(context).connected) {
      await selectMedia();
      return;
    }
    final selected = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => DemoPhotoPicker(initial: images),
    );
    if (selected != null && mounted) {
      setState(
        () => images
          ..clear()
          ..addAll(selected),
      );
    }
  }

  Future<void> camera() async {
    if (StoreScope.of(context).connected) {
      await selectMedia(camera: true);
      return;
    }
    final photo = await openPage<String>(context, '/camera');
    if (photo != null && mounted && !images.contains(photo)) {
      setState(() => images.add(photo));
    }
  }

  Future<void> selectMedia({bool camera = false}) async {
    if (images.length >= 10) {
      toast(context, 'En fazla 10 fotoğraf ekleyebilirsin.');
      return;
    }
    await runAccountAction(() async {
      try {
        final List<XFile> selected;
        if (camera) {
          final image = await picker.pickImage(
            source: ImageSource.camera,
            maxWidth: 1600,
            maxHeight: 1600,
            imageQuality: 82,
          );
          selected = image == null ? [] : [image];
        } else {
          selected = await picker.pickMultiImage(
            maxWidth: 1600,
            maxHeight: 1600,
            imageQuality: 82,
            limit: 10 - images.length,
          );
        }
        if (!mounted) return;
        setState(() {
          for (final image in selected) {
            if (images.length == 10) break;
            if (!images.contains(image.path)) images.add(image.path);
          }
        });
      } on PlatformException {
        throw ApiFailure(
          camera ? 'Kamera açılamadı.' : 'Fotoğraflar seçilemedi.',
        );
      }
    });
  }

  Post draft(AppStore store) => Post(
    id: 'preview',
    authorId: store.me.id,
    text: text.text.trim(),
    kind: kind,
    images: List.of(images),
    anonymous: anonymous,
    city: city ?? store.city,
    time: 'Az önce',
    taggedId: taggedId,
    occurredAt: occurredAt,
    travel:
        kind == PostKind.journey &&
            travelDraft.enabled &&
            travelDraft.destination != null
        ? TravelDetails(
            transport: travelDraft.transport,
            origin: CatalogItem(0, travelDraft.origin ?? city ?? store.city),
            destination: CatalogItem(0, travelDraft.destination!),
            departureAt: travelDraft.departureAt,
            operatorName: travelDraft.operatorName,
            serviceCode: travelDraft.serviceCode,
            vehicleIdentifier: travelDraft.vehicleIdentifier,
            isPublic: travelDraft.isPublic,
          )
        : null,
    cityWide: cityWide,
    remote: store.connected,
    storyTitle: composingStory ? storyTitle.text.trim() : null,
  );
  void publish() {
    if (!canPublish) {
      toast(context, 'Bir şeyler yaz veya bir fotoğraf ekle.');
      return;
    }
    final store = StoreScope.of(context);
    if (store.connected) {
      runAccountAction(() async {
        setState(() => publishing = true);
        try {
          final entry = widget.storyFor;
          Post? post;
          if (entry != null && widget.reviseStory) {
            await store.reviseEncounterStory(entry, storyTitle.text, text.text);
          } else {
            post = await store.publishPost(
              body: text.text,
              kind: kind,
              media: images.map(XFile.new).toList(),
              anonymous: anonymous,
              cityWide: cityWide,
              location: entry?.source?.city ?? city ?? store.city,
              requestId: requestId,
              attachLocation: place == null && attachLocation,
              place: place,
              occurredAt: occurredAt,
              travel: kind == PostKind.journey
                  ? await travelDraft.resolve(store.cityId, city ?? store.city)
                  : null,
              targetId: kind == PostKind.encounter && !anonymous
                  ? taggedId
                  : null,
              encounterId: entry?.encounterId,
              storyTitle: entry != null ? storyTitle.text : null,
            );
          }
          if (!mounted) return;
          submitted = true;
          if (post?.encounterRequestId case final id?) {
            Navigator.pushReplacementNamed(
              context,
              '/encounter',
              arguments: id,
            );
          } else {
            Navigator.pop(context);
            toast(
              context,
              entry != null
                  ? 'Hikâye yayın onayına gönderildi.'
                  : cityWide
                  ? 'Paylaşımın şehir akışına eklendi.'
                  : 'Paylaşım profilinde kaydedildi.',
            );
          }
        } finally {
          if (mounted) setState(() => publishing = false);
        }
      });
      return;
    }
    final post = store.publish(
      text: text.text,
      kind: kind,
      images: images,
      anonymous: anonymous,
      cityWide: cityWide,
      taggedId: kind == PostKind.encounter ? taggedId : null,
      location: city ?? store.city,
    );
    submitted = true;
    if (kind == PostKind.encounter && taggedId != null && !anonymous) {
      final e = store.encounters.firstWhere((e) => e.postId == post.id);
      Navigator.pushReplacementNamed(context, '/encounter', arguments: e.id);
    } else {
      Navigator.pop(context);
      toast(context, 'Paylaşımın şehir akışına eklendi.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return PopScope(
      canPop: (!busy && !dirty) || submitted,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || busy) {
          return;
        }
        if (await confirmAction(
              context,
              title: 'Paylaşımdan çıkılsın mı?',
              message: 'Bu ekrandaki taslağın silinecek.',
              action: 'Çık',
            ) &&
            context.mounted) {
          setState(() => submitted = true);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              Navigator.pop(context);
            }
          });
        }
      },
      child: AppPage(
        title: composingStory
            ? 'Ortak Karşılaşma Hikâyesi'
            : 'Bir anını paylaş',
        child: AbsorbPointer(
          absorbing: busy,
          child: ListView(
            padding: Space.page,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              if (composingStory)
                const InfoNote(
                  'Hikâyen, diğer katılımcı yayınlamayı onayladığında akışta görünür.',
                )
              else
                const Text(
                  'Gördüğün, tanıştığın, hissettiğin bir anı SenMiydin? topluluğuyla paylaş.',
                  style: TextStyle(color: AppColors.muted, fontSize: 13),
                ),
              const SizedBox(height: Space.md),
              if (composingStory)
                TextField(
                  key: const Key('encounter-story-title'),
                  controller: storyTitle,
                  maxLength: 100,
                  decoration: const InputDecoration(labelText: 'Başlık'),
                  onChanged: (_) => setState(() {}),
                ),
              TextField(
                key: const Key('post-text'),
                controller: text,
                maxLength: 1000,
                minLines: 5,
                maxLines: 8,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: composingStory
                      ? 'Açıklama'
                      : 'Bugün kiminle karşılaştın?',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: Space.md),
              if (images.isNotEmpty) ...[
                SizedBox(
                  height: 132,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: images.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (_, i) => SizedBox(
                      width: 115,
                      child: Column(
                        children: [
                          Expanded(
                            child: Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: AppShape.rounded,
                                  child: socialMediaImage(
                                    store,
                                    images[i],
                                    width: 115,
                                    height: 98,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  top: 3,
                                  right: 3,
                                  child: InkWell(
                                    onTap: () =>
                                        setState(() => images.removeAt(i)),
                                    child: const CircleAvatar(
                                      radius: 12,
                                      backgroundColor: Colors.white,
                                      child: Icon(
                                        Icons.close,
                                        size: 16,
                                        color: AppColors.navy,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              InkWell(
                                onTap: i == 0
                                    ? null
                                    : () => setState(() {
                                        final image = images.removeAt(i);
                                        images.insert(i - 1, image);
                                      }),
                                child: const Padding(
                                  padding: EdgeInsets.all(6),
                                  child: Icon(Icons.arrow_back, size: 16),
                                ),
                              ),
                              Text(
                                '${i + 1}/${images.length}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              InkWell(
                                onTap: i == images.length - 1
                                    ? null
                                    : () => setState(() {
                                        final image = images.removeAt(i);
                                        images.insert(i + 1, image);
                                      }),
                                child: const Padding(
                                  padding: EdgeInsets.all(6),
                                  child: Icon(Icons.arrow_forward, size: 16),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: Space.md),
              ],
              if (widget.reviseStory &&
                  widget.storyFor!.story!.images.isNotEmpty)
                ImageCarousel(widget.storyFor!.story!.images),
              if (!widget.reviseStory)
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    ActionChip(
                      avatar: const Icon(
                        Icons.image_outlined,
                        color: AppColors.blue,
                        size: 19,
                      ),
                      label: const Text('Fotoğraf Ekle'),
                      onPressed: busy ? null : pickPhotos,
                    ),
                    ActionChip(
                      avatar: const Icon(
                        Icons.camera_alt_outlined,
                        color: AppColors.blue,
                        size: 19,
                      ),
                      label: const Text('Kamera'),
                      onPressed: busy ? null : camera,
                    ),
                    if (!composingStory)
                      ActionChip(
                        avatar: const Icon(
                          Icons.location_on_outlined,
                          color: AppColors.blue,
                          size: 19,
                        ),
                        label: const Text('Konum Ekle'),
                        onPressed: () async {
                          final c = await chooseCity(
                            context,
                            city ?? store.city,
                          );
                          if (c != null) {
                            setState(() {
                              city = c;
                              place = null;
                              attachLocation = false;
                            });
                          }
                        },
                      ),
                  ],
                ),
              const SizedBox(height: Space.md),
              if (!composingStory) ...[
                const SectionHeader(
                  'Paylaşım türü',
                  icon: Icons.layers_outlined,
                ),
                ChoicePills(
                  options: PostKind.values.map((k) => k.label).toList(),
                  value: kind.label,
                  onChanged: (v) => setState(() {
                    kind = PostKind.values.firstWhere((k) => k.label == v);
                    if (kind != PostKind.encounter) {
                      taggedId = null;
                    }
                  }),
                ),
                const SizedBox(height: Space.md),
                if (kind == PostKind.encounter) ...[
                  SettingsRow(
                    taggedId == null
                        ? 'Karşılaştığım kişiyi etiketle'
                        : store.person(taggedId!).name,
                    Icons.person_outline,
                    subtitle: store.connected && !cityWide
                        ? 'Etiketlemek için şehir görünürlüğünü aç.'
                        : anonymous
                        ? 'Etiketlemek için anonim paylaşımı kapat.'
                        : taggedId == null
                        ? '@kullanıcıadı ile ara'
                        : '@${store.person(taggedId!).handle}',
                    onTap: store.connected && !cityWide
                        ? null
                        : anonymous
                        ? () => toast(
                            context,
                            'Anonim paylaşımlarda kişi etiketlenmez.',
                          )
                        : () async {
                            final id = await openPage<String>(context, '/tag');
                            if (id != null && mounted) {
                              setState(() => taggedId = id);
                            }
                          },
                    trailing: taggedId == null
                        ? null
                        : IconButton(
                            tooltip: 'Etiketi kaldır',
                            onPressed: () => setState(() => taggedId = null),
                            icon: const Icon(Icons.close),
                          ),
                  ),
                  if (taggedId == null)
                    const Padding(
                      padding: EdgeInsets.only(bottom: Space.md),
                      child: InfoNote(
                        'Etiketlemeden de bir karşılaşma paylaşabilirsin. Doğrulama için diğer kişinin onayı gerekir.',
                      ),
                    ),
                ],
                SettingsRow(
                  'Konum',
                  Icons.location_on_outlined,
                  subtitle: city ?? store.city,
                  onTap: () async {
                    final c = await chooseCity(context, city ?? store.city);
                    if (c != null) {
                      setState(() => city = c);
                    }
                  },
                ),
                if (store.connected && cityWide)
                  PostPlaceField(
                    key: placeKey,
                    value: place,
                    city: city ?? store.city,
                    onChanged: (selected) => setState(() {
                      place = selected;
                      if (selected?.recordedAt != null) {
                        occurredAt = selected!.recordedAt;
                      }
                      attachLocation = false;
                      if (selected?.city != null) city = selected!.city;
                    }),
                  ),
                if (kind == PostKind.encounter ||
                    kind == PostKind.journey ||
                    place != null)
                  OccurredTimeField(
                    value: occurredAt,
                    onChanged: (value) => setState(() => occurredAt = value),
                  ),
                if (kind == PostKind.journey)
                  TravelFields(
                    draft: travelDraft,
                    city: city ?? store.city,
                    onChanged: () {
                      if (mounted) setState(() {});
                    },
                  ),
                PreferenceRow(
                  'Şehir genelinde görünür',
                  cityWide,
                  (v) => setState(() {
                    cityWide = v;
                    if (store.connected && !v) taggedId = null;
                  }),
                  subtitle: cityWide
                      ? 'Paylaşımın şehrindeki herkese önerilebilir.'
                      : store.connected
                      ? 'Paylaşımını yalnızca kendi profilinde görürsün.'
                      : 'Paylaşımın yakın çevredeki keşifte yer alır.',
                ),
                if (store.connected && cityWide && place == null)
                  PreferenceRow(
                    'Yaklaşık konumu ekle',
                    attachLocation && store.location?.synced == true,
                    busy
                        ? null
                        : (value) async {
                            if (value && store.location?.synced != true) {
                              await store.location?.activateFromUi();
                            }
                            if (mounted) {
                              setState(
                                () => attachLocation =
                                    value && store.location?.synced == true,
                              );
                            }
                          },
                    subtitle: 'Haritada yakın bir bölge işaretlenir.',
                  ),
                PreferenceRow(
                  'Anonim paylaş',
                  anonymous,
                  (v) => setState(() {
                    anonymous = v;
                    if (v) {
                      taggedId = null;
                    }
                  }),
                  subtitle: 'Adın ve profilin bu paylaşımda görünmez.',
                ),
              ],
              const SizedBox(height: Space.md),
              if (!widget.reviseStory)
                SecondaryButton(
                  'Paylaşım Önizlemesi',
                  icon: Icons.visibility_outlined,
                  onPressed: () {
                    if (text.text.trim().isEmpty && images.isEmpty) {
                      toast(context, 'Önizleme için metin veya fotoğraf ekle.');
                      return;
                    }
                    showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      builder: (ctx) => SafeArea(
                        child: SingleChildScrollView(
                          padding: Space.page,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Paylaşım Önizlemesi',
                                style: Theme.of(ctx).textTheme.titleLarge,
                              ),
                              const SizedBox(height: Space.lg),
                              PostCard(draft(store), preview: true),
                              SecondaryButton(
                                'Düzenlemeye Dön',
                                onPressed: () => Navigator.pop(ctx),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              const SizedBox(height: Space.md),
              PrimaryButton(
                publishing
                    ? (images.isEmpty
                          ? 'Paylaşılıyor…'
                          : 'Fotoğraflar yükleniyor…')
                    : composingStory
                    ? 'Yayın Onayına Gönder'
                    : 'Paylaş',
                key: const Key('publish-post'),
                icon: Icons.near_me_outlined,
                onPressed: busy || !canPublish ? null : publish,
              ),
              const SizedBox(height: Space.xl),
            ],
          ),
        ),
      ),
    );
  }
}

class DemoPhotoPicker extends StatefulWidget {
  const DemoPhotoPicker({super.key, required this.initial});
  final List<String> initial;
  @override
  State<DemoPhotoPicker> createState() => _DemoPhotoPickerState();
}

class _DemoPhotoPickerState extends State<DemoPhotoPicker> {
  late final List<String> selected = List.of(widget.initial);
  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: Space.page,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Fotoğraflarını seç',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          const Text(
            'Örnek albüm · Birden fazla fotoğraf seçebilirsin.',
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const SizedBox(height: Space.lg),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              mainAxisExtent: 125,
            ),
            itemCount: demoPhotos.length,
            itemBuilder: (_, i) {
              final active = selected.contains(demoPhotos[i]);
              return InkWell(
                onTap: () => setState(
                  () => active
                      ? selected.remove(demoPhotos[i])
                      : selected.add(demoPhotos[i]),
                ),
                child: ClipRRect(
                  borderRadius: AppShape.rounded,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(demoPhotos[i], fit: BoxFit.cover),
                      if (active)
                        Container(color: AppColors.blue.withValues(alpha: .18)),
                      Positioned(
                        right: 8,
                        top: 8,
                        child: CircleAvatar(
                          radius: 13,
                          backgroundColor: active
                              ? AppColors.blue
                              : Colors.white,
                          child: active
                              ? Text(
                                  '${selected.indexOf(demoPhotos[i]) + 1}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                                )
                              : const Icon(
                                  Icons.add,
                                  size: 18,
                                  color: AppColors.blue,
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: Space.lg),
          PrimaryButton(
            '${selected.length} Fotoğrafı Kullan',
            icon: Icons.check,
            onPressed: () => Navigator.pop(context, selected),
          ),
        ],
      ),
    ),
  );
}

class DemoCameraPage extends StatelessWidget {
  const DemoCameraPage({super.key});
  @override
  Widget build(BuildContext context) => AppPage(
    title: 'Kamera',
    bottom: PrimaryButton(
      'Fotoğraf Çek',
      icon: Icons.camera_alt_outlined,
      onPressed: () => Navigator.pop(context, demoPhotos[1]),
    ),
    child: Padding(
      padding: Space.page,
      child: Column(
        children: [
          const InfoNote('Örnek fotoğraflarla paylaşımını hazırlayabilirsin.'),
          const SizedBox(height: Space.lg),
          Expanded(
            child: ClipRRect(
              borderRadius: AppShape.rounded,
              child: Image.asset(
                demoPhotos[1],
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: Space.lg),
        ],
      ),
    ),
  );
}

class EncounterPage extends StatelessWidget {
  const EncounterPage(this.id, {super.key});
  final String id;
  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    if (store.connected) return LiveEncounterPage(id);
    final e = store.encounters.firstWhere((e) => e.id == id);
    final from = store.person(e.fromId),
        to = store.person(e.toId),
        post = store.post(e.postId);
    final pending = e.status == EncounterStatus.pending;
    return AppPage(
      title: pending ? 'Karşılaşma Etiketi' : 'Karşılaşmanız',
      child: ListView(
        padding: Space.page,
        children: [
          if (pending) ...[
            InfoNote(
              'Örnek karşılaşma · ${to.name} olarak gelen karşılaşma isteğini görüyorsun. Onay verdikten sonra kendi hesabına dönersin.',
            ),
            const SizedBox(height: Space.xl),
          ],
          Center(
            child: SizedBox(
              width: 205,
              height: 110,
              child: Stack(
                children: [
                  Positioned(left: 0, child: Avatar(from, size: 103)),
                  Positioned(right: 0, child: Avatar(to, size: 103)),
                  const Positioned(
                    bottom: 0,
                    left: 82,
                    child: CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.red,
                      child: Icon(
                        Icons.favorite,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Space.xl),
          Text(
            pending
                ? '${from.name} seni bir\nkarşılaşmada etiketledi!'
                : e.status == EncounterStatus.approved
                ? 'Birbirinizi buldunuz! 💙'
                : 'Bu karşılaşma reddedildi.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: Space.lg),
          Container(
            padding: const EdgeInsets.all(Space.lg),
            decoration: AppShape.card(color: AppColors.pale),
            child: Text(
              '“${post.text}”',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 17,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: Space.md),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 18),
              const SizedBox(width: 8),
              Text(
                store.connected
                    ? post.city
                    : '${post.city} · Yaklaşık ${post.distance.toStringAsFixed(1).replaceAll('.', ',')} km',
              ),
            ],
          ),
          const SizedBox(height: Space.sm),
          Row(
            children: [
              const Icon(Icons.schedule, size: 18),
              const SizedBox(width: 8),
              Text(post.time),
            ],
          ),
          const SizedBox(height: Space.lg),
          if (post.images.isNotEmpty) ImageCarousel(post.images, height: 180),
          const SizedBox(height: Space.xl),
          if (pending) ...[
            PrimaryButton(
              'Karşılaşmayı Onayla',
              key: const Key('approve-encounter'),
              icon: Icons.check,
              onPressed: () {
                store.resolveEncounter(e, true);
                Navigator.pushReplacementNamed(
                  context,
                  '/encounters',
                  arguments: EncounterStatus.approved,
                );
              },
            ),
            const SizedBox(height: Space.md),
            SecondaryButton(
              'Reddet',
              icon: Icons.close,
              onPressed: () {
                store.resolveEncounter(e, false);
                Navigator.pushReplacementNamed(
                  context,
                  '/encounters',
                  arguments: EncounterStatus.rejected,
                );
              },
            ),
          ] else ...[
            if (e.status == EncounterStatus.approved) ...[
              PrimaryButton(
                'Sohbet Başlat',
                icon: Icons.chat_bubble_outline_rounded,
                onPressed: () => openPage(
                  context,
                  '/chat',
                  e.fromId == store.me.id ? e.toId : e.fromId,
                ),
              ),
              const SizedBox(height: Space.md),
            ],
            SecondaryButton(
              'Ana Sayfaya Dön',
              icon: Icons.home_outlined,
              onPressed: () => home(context),
            ),
          ],
          const SizedBox(height: Space.xl),
        ],
      ),
    );
  }
}

class EncountersPage extends StatefulWidget {
  const EncountersPage({
    super.key,
    this.initial = EncounterStatus.pending,
    this.featured = false,
  });
  final EncounterStatus initial;
  final bool featured;
  @override
  State<EncountersPage> createState() => _EncountersPageState();
}

class _EncountersPageState extends State<EncountersPage> {
  late EncounterStatus status = widget.initial;
  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    if (store.connected) {
      return LiveEncountersPage(
        featured: widget.featured,
        initial: widget.initial,
      );
    }
    final items = widget.featured
        ? store.featured
        : store.encounters
              .where(
                (e) =>
                    (e.fromId == store.me.id || e.toId == store.me.id) &&
                    e.status == status &&
                    !store.blocked.contains(e.fromId) &&
                    !store.blocked.contains(e.toId),
              )
              .toList();
    return AppPage(
      title: widget.featured ? 'Öne Çıkan Karşılaşmalar' : 'Karşılaşmalarım',
      child: Column(
        children: [
          Padding(
            padding: Space.page,
            child: widget.featured
                ? const InfoNote(
                    'Birbirini doğrulayan insanların ortak hikâyeleri. Güzel tesadüfler burada hayat buluyor.',
                  )
                : ChoicePills(
                    options: EncounterStatus.values
                        .map((s) => s.label)
                        .toList(),
                    value: status.label,
                    onChanged: (v) => setState(
                      () => status = EncounterStatus.values.firstWhere(
                        (s) => s.label == v,
                      ),
                    ),
                  ),
          ),
          Expanded(
            child: items.isEmpty
                ? const SingleChildScrollView(
                    child: EmptyState(
                      'Hikâyen henüz başlamadı.',
                      'Karşılaşmalarını paylaş ve yarım kalan bir merhabayı tamamla.',
                      icon: Icons.favorite_border,
                    ),
                  )
                : ListView.separated(
                    padding: Space.page,
                    itemCount: items.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: Space.md),
                    itemBuilder: (_, i) => EncounterCard(items[i]),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SecondaryButton(
              'Ana Sayfaya Dön',
              icon: Icons.home_outlined,
              onPressed: () => home(context),
            ),
          ),
        ],
      ),
    );
  }
}
