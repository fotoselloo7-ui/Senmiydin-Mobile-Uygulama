import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../core/navigation.dart';
import '../data/app_store.dart';
import '../data/account_api.dart';
import '../data/models.dart';
import '../widgets/collections.dart';
import '../widgets/comments_sheet.dart';
import '../widgets/common.dart';
import '../widgets/social.dart';
import '../widgets/social_page.dart';

class PostDetailPage extends StatelessWidget {
  const PostDetailPage(this.id, {super.key, this.openComments = false});
  final String id;

  /// Opened from a comment notification / the legacy `/comments` route: show the post and raise the comments sheet.
  final bool openComments;
  @override
  Widget build(BuildContext context) => PostRequest(id, builder: content);

  Widget content(BuildContext context, Post post) {
    final store = StoreScope.of(context);
    final encounters = store.encounters.where((e) => e.postId == id);
    return AppPage(
      title: 'Paylaşım',
      child: ListView(
        padding: Space.page,
        children: [
          if (openComments) _OpenCommentsOnce(post),
          PostCard(post, detail: true),
          if (encounters.isNotEmpty) ...[
            const SectionHeader(
              'Bu anının karşılaşması',
              icon: Icons.favorite_border,
            ),
            EncounterCard(encounters.first),
          ],
          if (post.interactionsEnabled) ...[
            SectionHeader(
              'Yorumlar (${post.displayedCommentCount})',
              action: 'Tümünü Gör',
              onTap: () => showCommentsSheet(context, post),
            ),
            if (post.remote)
              PagedContent<Comment>(
                key: ValueKey(store.commentsVersion),
                fetch: (page) => store.loadComments(id, page),
                builder: (context, comments, footer, _) => Column(
                  children: [
                    for (final comment in comments.take(3))
                      previewComment(context, store, comment),
                    if (comments.isEmpty && footer != null) footer,
                  ],
                ),
              ),
            for (final comment in post.comments.take(3))
              previewComment(context, store, comment),
            SecondaryButton(
              post.commentsEnabled ? 'Yorum Yaz' : 'Yorumları Gör',
              icon: Icons.chat_bubble_outline,
              onPressed: () => showCommentsSheet(context, post),
            ),
          ],
        ],
      ),
    );
  }

  Widget previewComment(BuildContext context, AppStore store, Comment comment) {
    final person = comment.authorId.isEmpty
        ? null
        : store.person(comment.authorId);
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Avatar(person, size: 34),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(Space.md),
              decoration: AppShape.card(color: AppColors.pale),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    person?.name ?? 'Anonim',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(comment.text),
                  Text(
                    comment.time,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Raises the comments sheet exactly once, right after the post is on screen.
class _OpenCommentsOnce extends StatefulWidget {
  const _OpenCommentsOnce(this.post);
  final Post post;
  @override
  State<_OpenCommentsOnce> createState() => _OpenCommentsOnceState();
}

class _OpenCommentsOnceState extends State<_OpenCommentsOnce> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) showCommentsSheet(context, widget.post);
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class SavedPage extends StatefulWidget {
  const SavedPage({super.key});
  @override
  State<SavedPage> createState() => _SavedPageState();
}

class _SavedPageState extends State<SavedPage> {
  int? collectionId;
  List<SavedCollection> collections = const [];
  int loadedVersion = -1;
  bool askedOnce = false;

  Future<void> loadCollections(AppStore store) async {
    final version = store.collectionsVersion;
    try {
      final items = await store.loadCollections();
      if (!mounted) return;
      setState(() {
        collections = items;
        loadedVersion = version;
        // A collection that vanished (deleted elsewhere) falls back to Tümü.
        if (collectionId != null && !items.any((c) => c.id == collectionId)) {
          collectionId = null;
        }
      });
    } catch (_) {
      // The list below keeps working without the chip row.
      if (mounted) setState(() => loadedVersion = version);
    }
  }

  SavedCollection? get current {
    for (final collection in collections) {
      if (collection.id == collectionId) return collection;
    }
    return null;
  }

  Future<void> create(AppStore store) async {
    final name = await askCollectionName(context);
    if (name == null || !mounted) return;
    await collectionAction(context, () async {
      final created = await store.createCollection(name);
      if (mounted) setState(() => collectionId = created.id);
    });
  }

  Future<void> rename(AppStore store, SavedCollection collection) async {
    final name = await askCollectionName(
      context,
      title: 'Koleksiyonu yeniden adlandır',
      action: 'Kaydet',
      initial: collection.name,
    );
    if (name == null || !mounted) return;
    await collectionAction(
      context,
      () => store.renameCollection(collection, name),
    );
  }

  Future<void> remove(AppStore store, SavedCollection collection) async {
    final confirmed = await confirmAction(
      context,
      title: 'Koleksiyon silinsin mi?',
      message:
          '“${collection.name}” silinir; içindeki gönderiler Kaydedilenler’de kalır.',
      action: 'Sil',
    );
    if (!confirmed || !mounted) return;
    await socialAction(context, () async {
      await store.deleteCollection(collection);
      if (mounted) setState(() => collectionId = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    if (store.connected) {
      if (loadedVersion != store.collectionsVersion && !askedOnce ||
          loadedVersion != store.collectionsVersion) {
        askedOnce = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && loadedVersion != store.collectionsVersion) {
            loadCollections(store);
          }
        });
      }
      final selected = current;
      return AppPage(
        title: 'Kaydedilenler',
        child: Column(
          children: [
            const SizedBox(height: Space.sm),
            CollectionChips(
              collections: collections,
              selected: collectionId,
              onSelect: (id) => setState(() => collectionId = id),
              onCreate: () => create(store),
            ),
            if (selected != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(Space.lg, 4, Space.sm, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${selected.name} · ${selected.postsCount} gönderi',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.metadata,
                      ),
                    ),
                    IconButton(
                      key: const Key('rename-collection'),
                      tooltip: 'Yeniden adlandır',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      onPressed: () => rename(store, selected),
                    ),
                    IconButton(
                      key: const Key('delete-collection'),
                      tooltip: 'Koleksiyonu sil',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.delete_outline_rounded, size: 20),
                      onPressed: () => remove(store, selected),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: PagedContent<Post>(
                key: ValueKey((
                  collectionId,
                  store.savedVersion,
                  store.collectionsVersion,
                )),
                fetch: collectionId == null
                    ? store.loadSaved
                    : (page) => store.loadCollectionPosts(collectionId!, page),
                id: (post) => post.id,
                visible: (post) =>
                    post.saved && !store.blocked.contains(post.authorId),
                builder: (context, saved, footer, refresh) => RefreshIndicator(
                  onRefresh: refresh,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: Space.page,
                    children: [
                      if (saved.isEmpty && footer == null)
                        EmptyState(
                          collectionId == null
                              ? 'Güzel anıları burada biriktir.'
                              : 'Bu koleksiyon henüz boş.',
                          collectionId == null
                              ? 'Kaydet simgesine dokunduğun paylaşımlar burada görünecek.'
                              : 'Kaydettiğin bir paylaşımın ⋮ menüsünden “Koleksiyona Ekle” de.',
                          icon: Icons.bookmark_border,
                        ),
                      for (final post in saved)
                        PostCard(post, key: ValueKey(post.id)),
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
    final saved = store.posts
        .where((p) => p.saved && !store.blocked.contains(p.authorId))
        .toList();
    return AppPage(
      title: 'Kaydedilenler',
      child: saved.isEmpty
          ? const SingleChildScrollView(
              child: EmptyState(
                'Güzel anıları burada biriktir.',
                'Kaydet simgesine dokunduğun paylaşımlar burada görünecek.',
                icon: Icons.bookmark_border,
              ),
            )
          : ListView.builder(
              padding: Space.page,
              itemCount: saved.length,
              itemBuilder: (_, i) => PostCard(saved[i]),
            ),
    );
  }
}

class PostRequest extends StatefulWidget {
  const PostRequest(
    this.id, {
    super.key,
    required this.builder,
    this.title = 'Paylaşım',
  });
  final String id, title;
  final Widget Function(BuildContext, Post) builder;

  @override
  State<PostRequest> createState() => _PostRequestState();
}

class _PostRequestState extends State<PostRequest> {
  Future<Post>? request;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    if (!store.isRemotePost(widget.id)) {
      return widget.builder(context, store.post(widget.id));
    }
    request ??= store.loadPost(widget.id);
    return FutureBuilder(
      future: request,
      builder: (context, snapshot) {
        final error = snapshot.error;
        if (error is ApiFailure) {
          return AppPage(
            title: widget.title,
            child: Center(
              child: TextButton(
                onPressed: () => setState(() => request = null),
                child: Text(error.detail),
              ),
            ),
          );
        }
        final post = snapshot.data ?? store.cachedPost(widget.id);
        return post == null
            ? AppPage(
                title: widget.title,
                child: const Center(child: CircularProgressIndicator()),
              )
            : widget.builder(context, post);
      },
    );
  }
}
