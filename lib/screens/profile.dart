import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../core/navigation.dart';
import '../data/app_store.dart';
import '../data/communication_api.dart';
import '../data/account_api.dart';
import '../data/models.dart';
import '../data/mock_data.dart';
import '../widgets/common.dart';
import '../widgets/social.dart';
import '../widgets/social_page.dart';
import 'encounters.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage(this.id, {super.key});
  final String id;
  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final p = store.person(id);
    final own = id == store.me.id;
    final isBlocked = store.blocked.contains(id);
    return AppPage(
      compactHeader: true,
      title: own ? 'Profilim' : 'Profil',
      actions: [
        if (own)
          IconButton(
            tooltip: 'Ayarlar',
            onPressed: () => openPage(context, '/settings'),
            icon: const Icon(Icons.settings_outlined),
          )
        else
          PopupMenuButton<String>(
            tooltip: 'Profil seçenekleri',
            onSelected: (v) async {
              if (v == 'report') {
                openPage(
                  context,
                  '/report',
                  p.remote
                      ? ReportTarget(
                          'user',
                          accountId(p.id),
                          'Kullanıcı @${p.handle}',
                        )
                      : 'Kullanıcı @${p.handle}',
                );
              } else if (v == 'block') {
                if (await confirmAction(
                  context,
                  title: 'Kullanıcı engellensin mi?',
                  message:
                      'Bu kişi sana mesaj gönderemez; paylaşımlarını akışında görmezsin.',
                  action: 'Engelle',
                )) {
                  if (!context.mounted) return;
                  try {
                    await store.setRemoteBlock(p.id, true);
                    if (p.remote && context.mounted) {
                      Navigator.maybePop(context);
                    }
                  } on ApiFailure catch (error) {
                    if (context.mounted) toast(context, error.detail);
                  }
                }
              } else {
                try {
                  await store.setRemoteBlock(p.id, false);
                } on ApiFailure catch (error) {
                  if (context.mounted) toast(context, error.detail);
                }
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'report',
                child: Text('Şikâyet Et'),
              ),
              PopupMenuItem(
                value: isBlocked ? 'unblock' : 'block',
                child: Text(isBlocked ? 'Engeli Kaldır' : 'Engelle'),
              ),
            ],
          ),
      ],
      child: ProfileContent(personId: id),
    );
  }
}

class ProfileContent extends StatefulWidget {
  const ProfileContent({super.key, required this.personId});
  final String personId;
  @override
  State<ProfileContent> createState() => _ProfileContentState();
}

class _ProfileContentState extends State<ProfileContent> {
  String tab = 'Paylaşımlar';
  int refreshVersion = 0;
  Object? profileKey;
  Future<Person>? profileRequest;

  Widget _buildStatItem({
    required String count,
    required String label,
    required VoidCallback onTap,
  }) => Expanded(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              count,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: AppColors.navy,
              ),
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildProfileTab(String title, IconData icon) {
    final active = tab == title;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => tab = title),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 16,
                    color: active ? AppColors.primary : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                          color: active ? AppColors.primary : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              height: 2.5,
              decoration: BoxDecoration(
                color: active ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final person = store.person(widget.personId);
    if (!person.remote) return profileBody(context, store, person);
    final key = (
      person.handle,
      store.postsVersion,
      store.followsVersion,
      store.encounterVersion,
    );
    if (profileKey != key) {
      profileKey = key;
      profileRequest = store.loadPublicProfile(person.handle);
    }
    return FutureBuilder(
      future: profileRequest,
      builder: (context, snapshot) {
        final error = snapshot.error;
        if (error is ApiFailure) {
          return Center(
            child: TextButton(
              onPressed: () => setState(() => profileKey = null),
              child: Text('${error.detail} Tekrar dene.'),
            ),
          );
        }
        return profileBody(
          context,
          store,
          // Account updates replace the cached Person while this request may still hold its previous instance.
          store.person(widget.personId),
          loading: snapshot.connectionState != ConnectionState.done,
        );
      },
    );
  }

  Widget profileBody(
    BuildContext context,
    AppStore store,
    Person p, {
    bool loading = false,
  }) {
    final own = p.id == store.me.id;
    final posts = store.connected
        ? <Post>[]
        : store.posts
              .where((post) => post.authorId == p.id && !post.anonymous)
              .toList();
    final encounters = store.encounters
        .where(
          (e) =>
              (e.fromId == p.id || e.toId == p.id) &&
              e.status == EncounterStatus.approved,
        )
        .toList();
    final isBlocked = store.blocked.contains(p.id);
    final following = p.remote
        ? p.isFollowing
        : !store.connected && store.following.contains(p.id);
    final cover = profileImage(p.remote ? p.cover : demoPhotos[0]);
    const coverPlaceholder = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(18)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFE89A7B),
            Color(0xFFA676C8),
            Color(0xFF7F71BF),
          ],
        ),
      ),
      child: SizedBox(width: double.infinity, height: 135),
    );
    return RefreshIndicator(
      onRefresh: () => socialAction(context, () async {
        if (p.remote) {
          final fresh = await store.loadPublicProfile(p.handle);
          if (mounted) {
            setState(() {
              profileRequest = Future.value(fresh);
              refreshVersion++;
            });
          }
        } else {
          store.refresh();
        }
      }),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        key: PageStorageKey('profile-${p.id}'),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          SizedBox(
            height: 180,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 135,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: cover == null
                        ? coverPlaceholder
                        : Image(
                            image: cover,
                            errorBuilder: (_, _, _) => coverPlaceholder,
                            width: double.infinity,
                            height: 135,
                            fit: BoxFit.cover,
                          ),
                  ),
                ),
                Positioned(
                  left: 14,
                  top: 85,
                  child: Container(
                    padding: const EdgeInsets.all(3.5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(
                        color: const Color(0xFFD6E4F7),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: .18),
                          blurRadius: 14,
                          spreadRadius: 1,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Avatar(p, size: 80),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            p.name,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.navy,
              height: 1.2,
              letterSpacing: -.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '@${p.handle}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          if (p.bio.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              p.bio,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.navy,
                height: 1.4,
              ),
            ),
          ],
          Container(
            margin: const EdgeInsets.only(top: 16, bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.line),
              boxShadow: [
                BoxShadow(
                  color: AppColors.navy.withValues(alpha: .03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                _buildStatItem(
                  count: p.remote
                      ? (loading ? '…' : '${p.postCount}')
                      : '${posts.length}',
                  label: 'Paylaşım',
                  onTap: () => setState(() => tab = 'Paylaşımlar'),
                ),
                Container(width: 1, height: 28, color: AppColors.line),
                _buildStatItem(
                  count: p.remote && loading
                      ? '…'
                      : '${p.remote ? p.encounterCount : encounters.length}',
                  label: 'Karşılaşma',
                  onTap: () => own
                      ? openPage(context, '/encounters')
                      : setState(() => tab = 'Karşılaşmalar'),
                ),
                Container(width: 1, height: 28, color: AppColors.line),
                _buildStatItem(
                  count: p.remote
                      ? (loading ? '…' : '${p.followersCount}')
                      : store.connected
                          ? '0'
                          : '${1264 + (following ? 1 : 0)}',
                  label: 'Takipçi',
                  onTap: () => openPage(
                    context,
                    '/people',
                    p.remote ? ('Takipçi', p.handle) : 'Takipçi',
                  ),
                ),
                Container(width: 1, height: 28, color: AppColors.line),
                _buildStatItem(
                  count: p.remote
                      ? (loading ? '…' : '${p.followingCount}')
                      : store.connected
                          ? '0'
                          : own
                              ? '${store.following.length}'
                              : '287',
                  label: 'Takip',
                  onTap: () => openPage(
                    context,
                    '/people',
                    p.remote ? ('Takip', p.handle) : 'Takip',
                  ),
                ),
              ],
            ),
          ),
          if (!own) ...[
            if (isBlocked)
              InfoNote(
                '@${p.handle} engellendi. İletişim kurmak için profil menüsünden engeli kaldırabilirsin.',
                icon: Icons.block,
              )
            else
              Row(
                children: [
                  Expanded(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: p.remote
                            ? () => socialAction(
                                context,
                                () => store.toggleFollow(p),
                              )
                            : store.connected
                                ? null
                                : () => store.follow(p.id),
                        borderRadius: BorderRadius.circular(24),
                        child: Ink(
                          height: 46,
                          decoration: BoxDecoration(
                            gradient: AppShape.blueGradient,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary
                                    .withValues(alpha: .24),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                following
                                    ? Icons.check_rounded
                                    : Icons.person_add_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    following ? 'Takip Ediliyor' : 'Takip Et',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => openPage(context, '/chat', p.id),
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          height: 46,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceBlue,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: const Color(0xFFD6E4F7),
                              width: 1.2,
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.chat_bubble_outline_rounded,
                                color: AppColors.navy,
                                size: 18,
                              ),
                              SizedBox(width: 8),
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    'Mesaj',
                                    style: TextStyle(
                                      color: AppColors.navy,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
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
            const SizedBox(height: 16),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => openPage(context, '/edit-profile'),
                      borderRadius: BorderRadius.circular(24),
                      child: Ink(
                        height: 46,
                        decoration: BoxDecoration(
                          gradient: AppShape.blueGradient,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary
                                  .withValues(alpha: .24),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.edit_outlined,
                              color: Colors.white,
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  'Profili Düzenle',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => openPage(context, '/settings'),
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        height: 46,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceBlue,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: const Color(0xFFD6E4F7),
                            width: 1.2,
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.settings_outlined,
                              color: AppColors.navy,
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  'Ayarlar',
                                  style: TextStyle(
                                    color: AppColors.navy,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
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
            const SizedBox(height: 16),
          ],
          Stack(
            alignment: Alignment.bottomCenter,
            children: [
              Container(height: 1, color: AppColors.line),
              Row(
                children: [
                  _buildProfileTab(
                    'Paylaşımlar',
                    Icons.view_agenda_outlined,
                  ),
                  _buildProfileTab(
                    'Karşılaşmalar',
                    Icons.auto_awesome_rounded,
                  ),
                  _buildProfileTab(
                    'Medya',
                    Icons.photo_library_outlined,
                  ),
                  if (own)
                    _buildProfileTab(
                      'Kaydedilenler',
                      Icons.bookmark_outline_rounded,
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (isBlocked && !own)
            const EmptyState(
              'Bu profil engellendi.',
              'Paylaşımlar gizlendi.',
              icon: Icons.block,
            )
          else if (tab == 'Karşılaşmalar' && p.remote)
            PublishedEncountersList(username: p.handle, embedded: true)
          else if (tab == 'Karşılaşmalar') ...[
            if (encounters.isEmpty)
              const EmptyState(
                'Henüz doğrulanmış karşılaşma yok.',
                'Yeni hikâyeler burada birikecek.',
                icon: Icons.auto_awesome_rounded,
              ),
            ...encounters.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: Space.md),
                child: EncounterCard(e),
              ),
            ),
          ] else if (tab == 'Medya') ...[
            if (p.remote)
              PagedContent<Post>(
                key: ValueKey((
                  p.handle,
                  'Medya',
                  store.postsVersion,
                  refreshVersion,
                )),
                fetch: (page) => store.loadProfilePosts(p.handle, page),
                id: (post) => post.id,
                visible: (post) =>
                    !store.blocked.contains(post.authorId) &&
                    post.images.isNotEmpty,
                builder: (context, items, footer, _) => Column(
                  children: [
                    if (items.isEmpty && footer == null)
                      const EmptyState(
                        'Henüz bir fotoğraf yok.',
                        'Paylaştığın fotoğraflar burada listelenir.',
                        icon: Icons.photo_library_outlined,
                      ),
                    for (final post in items)
                      PostCard(post, key: ValueKey(post.id)),
                    ?footer,
                  ],
                ),
              )
            else ...[
              if (posts.where((x) => x.images.isNotEmpty).isEmpty)
                const EmptyState(
                  'Henüz bir fotoğraf yok.',
                  'Paylaştığın fotoğraflar burada listelenir.',
                  icon: Icons.photo_library_outlined,
                ),
              ...posts
                  .where((x) => x.images.isNotEmpty)
                  .map((p) => PostCard(p)),
            ],
          ] else if (p.remote)
            PagedContent<Post>(
              key: ValueKey((
                p.handle,
                tab,
                store.postsVersion,
                store.savedVersion,
                refreshVersion,
              )),
              fetch: tab == 'Kaydedilenler'
                  ? store.loadSaved
                  : (page) => store.loadProfilePosts(p.handle, page),
              id: (post) => post.id,
              visible: (post) => !store.blocked.contains(post.authorId),
              builder: (context, items, footer, _) => Column(
                children: [
                  if (items.isEmpty && footer == null)
                    const EmptyState(
                      'Henüz bir paylaşım yok.',
                      'İlk hikâyene yer aç.',
                    ),
                  for (final post in items)
                    PostCard(post, key: ValueKey(post.id)),
                  ?footer,
                ],
              ),
            )
          else ...[
            if ((tab == 'Kaydedilenler'
                    ? store.posts.where((p) => p.saved)
                    : posts)
                .isEmpty)
              const EmptyState(
                'Henüz bir paylaşım yok.',
                'İlk hikâyene yer aç.',
              ),
            ...(tab == 'Kaydedilenler'
                    ? store.posts.where(
                        (p) => p.saved && !store.blocked.contains(p.authorId),
                      )
                    : posts)
                .map((p) => PostCard(p)),
          ],
        ],
      ),
    );
  }
}

class PeoplePage extends StatelessWidget {
  const PeoplePage(this.title, {super.key, this.username});
  final String title;
  final String? username;
  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final account = username;
    if (store.connected) {
      return AppPage(
        title: title,
        child: account == null
            ? const EmptyState(
                'Henüz kimse yok.',
                'Yeni insanları keşfetmeye başlayabilirsin.',
              )
            : PagedContent<Person>(
                fetch: (page) => store.loadConnections(
                  account,
                  title == 'Takipçi' ? 'followers' : 'following',
                  page,
                ),
                id: (person) => person.id,
                visible: (person) => !store.blocked.contains(person.id),
                builder: (context, people, footer, refresh) => RefreshIndicator(
                  onRefresh: refresh,
                  child: ListView(
                    padding: Space.page,
                    children: [
                      if (people.isEmpty && footer == null)
                        const EmptyState(
                          'Henüz kimse yok.',
                          'Yeni insanları keşfetmeye başlayabilirsin.',
                        ),
                      for (final person in people)
                        UserRow(
                          person,
                          onTap: () => openPage(context, '/profile', person.id),
                        ),
                      ?footer,
                    ],
                  ),
                ),
              ),
      );
    }
    final people = store.people
        .where(
          (p) =>
              p.id != store.me.id &&
              !store.blocked.contains(p.id) &&
              (title != 'Takip' || store.following.contains(p.id)),
        )
        .toList();
    return AppPage(
      title: title,
      child: people.isEmpty
          ? const EmptyState(
              'Henüz kimse yok.',
              'Yeni insanları keşfetmeye başlayabilirsin.',
            )
          : ListView.builder(
              padding: Space.page,
              itemCount: people.length,
              itemBuilder: (_, i) => UserRow(
                people[i],
                onTap: () => openPage(context, '/profile', people[i].id),
              ),
            ),
    );
  }
}
