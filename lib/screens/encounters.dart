import 'package:flutter/material.dart' hide Text;
import '../widgets/translated_text.dart';

import '../core/navigation.dart';
import '../core/theme.dart';
import '../data/account_api.dart';
import '../data/app_store.dart';
import '../data/encounter_api.dart';
import '../data/models.dart';
import '../widgets/account_action.dart';
import '../widgets/common.dart';
import '../widgets/social.dart';
import '../widgets/social_page.dart';
import '../core/app_locale.dart';

class LiveEncountersPage extends StatefulWidget {
  const LiveEncountersPage({
    super.key,
    required this.featured,
    required this.initial,
  });
  final bool featured;
  final EncounterStatus initial;

  @override
  State<LiveEncountersPage> createState() => _LiveEncountersPageState();
}

class _LiveEncountersPageState extends State<LiveEncountersPage> {
  late EncounterStatus status = widget.initial;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return AppPage(
      title: widget.featured ? 'Öne Çıkan Karşılaşmalar' : 'Karşılaşmalarım',
      child: widget.featured
          ? PublishedEncountersList(
              key: ValueKey((store.city, store.encounterVersion)),
            )
          : Column(
              children: [
                Padding(
                  padding: Space.page,
                  child: ChoicePills(
                    options: EncounterStatus.values
                        .map((value) => value.label)
                        .toList(),
                    value: status.label,
                    onChanged: (value) => setState(
                      () => status = EncounterStatus.values.firstWhere(
                        (item) => item.label == value,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: PagedContent<EncounterEntry>(
                    key: ValueKey((status, store.encounterVersion)),
                    fetch: (page) => store.loadEncounters(
                      page,
                      status: switch (status) {
                        EncounterStatus.pending => 'pending',
                        EncounterStatus.approved => 'accepted',
                        EncounterStatus.rejected => 'closed',
                      },
                    ),
                    id: (entry) => entry.id,
                    visible: (entry) => !store.blocked.contains(entry.other.id),
                    builder: (context, entries, footer, refresh) =>
                        RefreshIndicator(
                          onRefresh: refresh,
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: Space.page,
                            children: [
                              if (entries.isEmpty && footer == null)
                                const EmptyState(
                                  'Burada henüz bir karşılaşma yok.',
                                  'Yeni karşılaşmalar burada görünecek.',
                                ),
                              for (final entry in entries)
                                EncounterInboxRow(entry),
                              ?footer,
                            ],
                          ),
                        ),
                  ),
                ),
              ],
            ),
    );
  }
}

class PublishedEncountersList extends StatelessWidget {
  const PublishedEncountersList({
    super.key,
    this.username,
    this.embedded = false,
  });
  final String? username;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return PagedContent<Post>(
      key: ValueKey((username, store.city, store.encounterVersion)),
      fetch: (page) => store.loadFeaturedEncounters(page, username: username),
      id: (post) => post.id,
      visible: (post) => post.storyParticipants.every(
        (person) => !store.blocked.contains(person.id),
      ),
      builder: (context, posts, footer, refresh) {
        final content = [
          if (posts.isEmpty && footer == null)
            const EmptyState(
              'Henüz yayınlanmış bir karşılaşma yok.',
              'Ortak hikâyeler burada görünecek.',
            ),
          for (final post in posts)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.md),
              child: PublishedEncounterCard(post),
            ),
          ?footer,
        ];
        return embedded
            ? Column(children: content)
            : RefreshIndicator(
                onRefresh: refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: Space.page,
                  children: content,
                ),
              );
      },
    );
  }
}

class EncounterInboxRow extends StatelessWidget {
  const EncounterInboxRow(this.entry, {super.key});
  final EncounterEntry entry;

  @override
  Widget build(BuildContext context) {
    final direction = entry.outgoing ? 'Gönderilen' : 'Gelen';
    final caption = entry.needsReview
        ? 'Ortak hikâye yayın onayı bekliyor'
        : switch ((entry.story?.mine, entry.story?.storyStatus)) {
            (true, 'published') => 'Ortak hikâye yayınlandı',
            (true, 'rejected') => 'Ortak hikâyenin yayın onayı reddedildi',
            _ => '$direction · ${entry.statusLabel}',
          };
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.sm),
      child: Container(
        decoration: AppShape.card(color: AppColors.pale),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: AppShape.rounded,
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            leading: Avatar(entry.other, size: 43),
            title: Text(
              entry.other.name,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '@${entry.other.handle} · $caption',
                  style: const TextStyle(fontSize: 12),
                ),
                if (entry.source?.text.trim().isNotEmpty == true)
                  Text(
                    entry.source!.text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                Text(
                  entry.time,
                  style: const TextStyle(color: AppColors.muted, fontSize: 11),
                ),
              ],
            ),
            trailing: const Icon(Icons.chevron_right, color: AppColors.blue),
            onTap: () => openPage(context, '/encounter', entry.id),
          ),
        ),
      ),
    );
  }
}

class LiveEncounterPage extends StatefulWidget {
  const LiveEncounterPage(this.id, {super.key});
  final String id;

  @override
  State<LiveEncounterPage> createState() => _LiveEncounterPageState();
}

class _LiveEncounterPageState extends State<LiveEncounterPage>
    with AccountAction<LiveEncounterPage> {
  Future<EncounterEntry>? request;

  void reload(AppStore store) {
    setState(() {
      request = store.loadEncounter(widget.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    request ??= store.loadEncounter(widget.id);
    return AppPage(
      title: tr('Karşılaşma Etiketi'),
      child: FutureBuilder(
        future: request,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData) {
            final error = snapshot.error;
            return EmptyState(
              error is ApiFailure ? error.detail : 'Karşılaşma yüklenemedi.',
              'Biraz sonra tekrar deneyebilirsin.',
              action: SecondaryButton(
                'Tekrar Dene',
                onPressed: () => reload(store),
              ),
            );
          }
          return details(store, snapshot.data!);
        },
      ),
    );
  }

  Widget details(AppStore store, EncounterEntry entry) {
    final pending = entry.status == 'pending';
    final story = entry.story;
    final source = entry.source;
    final title = pending && !entry.outgoing
        ? '${entry.requester.name} seni bir karşılaşmada etiketledi!'
        : entry.statusLabel;

    void respond(String action) {
      runAccountAction(() async {
        final updated = await store.respondEncounter(entry.id, action);
        if (mounted) {
          setState(() {
            request = Future.value(updated);
          });
        }
      });
    }

    void review(String action) {
      runAccountAction(() async {
        final updated = await store.reviewEncounterStory(entry, action);
        if (mounted) {
          setState(() {
            request = Future.value(updated);
          });
        }
      });
    }

    Future<void> compose({bool edit = false}) async {
      await openPage(
        context,
        edit ? '/encounter-story-edit' : '/encounter-story',
        entry,
      );
      if (mounted) reload(store);
    }

    return ListView(
      padding: Space.page,
      children: [
        Center(
          child: EncounterAvatars([entry.requester, entry.target], size: 68),
        ),
        const SizedBox(height: Space.lg),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: Space.sm),
        Text(
          '@${entry.other.handle} · ${entry.outgoing ? 'Gönderilen' : 'Gelen'} · ${entry.time}',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: Space.lg),
        if (source != null) ...[
          InfoNote(source.text.isEmpty ? source.city : source.text),
          if (source.images.isNotEmpty) ...[
            const SizedBox(height: Space.md),
            ImageCarousel(source.images),
          ],
          TextButton(
            onPressed: () => openPage(context, '/post', source.id),
            child: const Text('Paylaşımı Gör'),
          ),
        ],
        const SizedBox(height: Space.md),
        if (pending && !entry.outgoing) ...[
          PrimaryButton(
            'Karşılaşmayı Onayla',
            key: const Key('approve-encounter'),
            icon: Icons.check_rounded,
            onPressed: busy ? null : () => respond('accept'),
          ),
          const SizedBox(height: Space.sm),
          SecondaryButton(
            'Reddet',
            icon: Icons.close,
            onPressed: busy ? null : () => respond('reject'),
          ),
        ] else if (pending)
          SecondaryButton(
            'İsteği İptal Et',
            icon: Icons.close,
            onPressed: busy ? null : () => respond('cancel'),
          )
        else if (entry.status == 'accepted') ...[
          SecondaryButton(
            'Mesaj Gönder',
            icon: Icons.chat_bubble_outline,
            onPressed: () => openPage(context, '/chat', entry.other.id),
          ),
          const SizedBox(height: Space.sm),
          if (story == null)
            PrimaryButton(
              'Karşılaşmayı Paylaş',
              onPressed: busy ? null : () => compose(),
            )
          else ...[
            const SectionHeader('Ortak Hikâye', icon: Icons.favorite_border),
            PostCard(
              story,
              preview: story.storyStatus != 'published',
              detail: true,
            ),
            if (story.storyStatus == 'published')
              PrimaryButton(
                'Yayınlanan Hikâyeyi Gör',
                onPressed: () => openPage(context, '/post', story.id),
              )
            else if (entry.needsReview) ...[
              const InfoNote(
                'Bu karşılaşma hikâyesini yayınlamayı onaylıyor musun?',
              ),
              const SizedBox(height: Space.sm),
              PrimaryButton(
                'Yayınlamayı Onayla',
                icon: Icons.check_rounded,
                onPressed: busy ? null : () => review('approve'),
              ),
              const SizedBox(height: Space.sm),
              SecondaryButton(
                'Reddet',
                icon: Icons.close,
                onPressed: busy ? null : () => review('reject'),
              ),
            ] else ...[
              InfoNote(
                story.storyStatus == 'rejected'
                    ? 'Yayın onayı reddedildi.'
                    : 'Yayın için karşı tarafın onayı bekleniyor.',
              ),
              if (story.mine) ...[
                const SizedBox(height: Space.sm),
                SecondaryButton(
                  'Hikâyeyi Düzenle',
                  icon: Icons.edit_outlined,
                  onPressed: busy ? null : () => compose(edit: true),
                ),
              ],
            ],
          ],
        ],
      ],
    );
  }
}
