import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../core/navigation.dart';
import '../data/app_store.dart';
import '../data/communication_api.dart';
import '../data/account_api.dart';
import '../data/models.dart';
import '../widgets/account_action.dart';
import '../widgets/common.dart';
import '../widgets/social.dart';
import '../widgets/social_page.dart';

class PostDetailPage extends StatelessWidget {
  const PostDetailPage(this.id, {super.key});
  final String id;
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
              onTap: () => openPage(context, '/comments', id),
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
              onPressed: () => openPage(context, '/comments', id),
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

class CommentsPage extends StatefulWidget {
  const CommentsPage(this.id, {super.key});
  final String id;
  @override
  State<CommentsPage> createState() => _CommentsPageState();
}

class _CommentsPageState extends State<CommentsPage>
    with AccountAction<CommentsPage> {
  final text = TextEditingController(), scroll = ScrollController();
  final focus = FocusNode();

  /// The top-level comment being answered (replies never answer replies).
  Comment? replyingTo;

  /// Fully loaded reply lists, by top-level comment id (the list itself only embeds the first few).
  final expanded = <String, List<Comment>>{};

  @override
  void dispose() {
    text.dispose();
    scroll.dispose();
    focus.dispose();
    super.dispose();
  }

  void startReply(Comment comment) {
    final store = StoreScope.of(context);
    final person = comment.authorId.isEmpty
        ? null
        : store.person(comment.authorId);
    setState(() => replyingTo = comment);
    // The composer starts with @username, only to give the conversation its context.
    text.text = person == null ? '' : '@${person.handle} ';
    text.selection = TextSelection.collapsed(offset: text.text.length);
    focus.requestFocus();
  }

  void cancelReply() {
    setState(() => replyingTo = null);
    text.clear();
  }

  Future<void> loadAllReplies(Post post, String commentId) async {
    final store = StoreScope.of(context);
    final all = <Comment>[];
    int? page = 1;
    while (page != null) {
      final result = await store.loadReplies(post.id, commentId, page);
      all.addAll(result.items);
      page = result.nextPage;
    }
    if (mounted) setState(() => expanded[commentId] = all);
  }

  void send(Post post) {
    final store = StoreScope.of(context);
    if (text.text.trim().isEmpty) {
      return;
    }
    if (post.remote) {
      final parent = replyingTo;
      runAccountAction(() async {
        await store.writeComment(post, text.text, parent: parent);
        if (!mounted) return;
        text.clear();
        setState(() => replyingTo = null);
        // Show the whole conversation, including the new reply, in order.
        if (parent?.id != null) await loadAllReplies(post, parent!.id!);
      });
      return;
    }
    store.comment(post, text.text);
    text.clear();
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scroll.hasClients) {
        scroll.animateTo(
          scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) =>
      PostRequest(widget.id, builder: content, title: 'Yorumlar');

  Widget content(BuildContext context, Post post) {
    if (!post.interactionsEnabled) {
      return const AppPage(
        title: 'Yorumlar',
        child: EmptyState('Yorumlar yayın sonrası açılır.', ''),
      );
    }
    final store = StoreScope.of(context);
    return AppPage(
      title: 'Yorumlar (${post.displayedCommentCount})',
      child: Column(
        children: [
          Expanded(
            child: post.remote
                ? PagedContent<Comment>(
                    key: ValueKey(store.commentsVersion),
                    fetch: (page) => store.loadComments(post.id, page),
                    id: (comment) => comment.id!,
                    visible: (comment) =>
                        !store.blocked.contains(comment.authorId),
                    builder: (context, comments, footer, refresh) =>
                        RefreshIndicator(
                          onRefresh: refresh,
                          child: ListView(
                            padding: Space.page,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(Space.md),
                                decoration: AppShape.card(
                                  color: AppColors.pale,
                                ),
                                child: Text(post.text),
                              ),
                              const SizedBox(height: Space.xl),
                              if (comments.isEmpty && footer == null)
                                const EmptyState(
                                  'İlk merhaba senden gelsin.',
                                  'Henüz yorum yapılmamış.',
                                ),
                              for (final comment in comments)
                                commentThread(context, store, post, comment),
                              ?footer,
                            ],
                          ),
                        ),
                  )
                : ListView(
                    controller: scroll,
                    padding: Space.page,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(Space.md),
                        decoration: AppShape.card(color: AppColors.pale),
                        child: Text(post.text),
                      ),
                      const SizedBox(height: Space.xl),
                      if (post.comments.isEmpty)
                        const EmptyState(
                          'İlk merhaba senden gelsin.',
                          'Henüz yorum yapılmamış.',
                        ),
                      for (final comment in post.comments)
                        commentRow(context, store, post, comment),
                    ],
                  ),
          ),
          if (!post.commentsEnabled)
            const InfoNote('Bu paylaşım yorumlara kapalı.')
          else
            Container(
              padding: const EdgeInsets.all(Space.md),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.line)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (replyingTo != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        key: const Key('replying-banner'),
                        children: [
                          const Icon(
                            Icons.subdirectory_arrow_right_rounded,
                            size: 16,
                            color: AppColors.brandPurple,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Yanıtlanıyor: ${replyTargetName(store, replyingTo!)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.metadata.copyWith(
                                color: AppColors.brandPurple,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          IconButton(
                            key: const Key('cancel-reply'),
                            tooltip: 'Yanıtı iptal et',
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: busy ? null : cancelReply,
                          ),
                        ],
                      ),
                    ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Avatar(store.me, size: 38),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          key: const Key('comment-field'),
                          controller: text,
                          focusNode: focus,
                          enabled: !busy,
                          minLines: 1,
                          maxLines: 4,
                          maxLength: 500,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            hintText: replyingTo == null
                                ? 'Bir yorum yaz…'
                                : 'Yanıtını yaz…',
                            counterText: '',
                          ),
                          onSubmitted: (_) => send(post),
                        ),
                      ),
                      IconButton(
                        key: const Key('send-comment'),
                        tooltip: replyingTo == null
                            ? 'Yorumu gönder'
                            : 'Yanıtı gönder',
                        onPressed: busy || text.text.trim().isEmpty
                            ? null
                            : () => send(post),
                        icon: const Icon(
                          Icons.send_rounded,
                          color: AppColors.blue,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String replyTargetName(AppStore store, Comment comment) {
    final person = comment.authorId.isEmpty
        ? null
        : store.person(comment.authorId);
    return person == null ? 'Anonim yorum' : '@${person.handle}';
  }

  /// A top-level comment with its replies (oldest first, one level only).
  Widget commentThread(
    BuildContext context,
    AppStore store,
    Post post,
    Comment comment,
  ) {
    final replies = expanded[comment.id] ?? comment.replies;
    final hidden = comment.replyCount - replies.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        commentRow(context, store, post, comment, padBottom: replies.isEmpty),
        if (replies.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 44, bottom: Space.lg),
            child: Column(
              key: ValueKey('replies-${comment.id}'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final reply in replies)
                  commentRow(context, store, post, reply, reply: true),
                if (hidden > 0 && expanded[comment.id] == null)
                  TextButton(
                    key: ValueKey('more-replies-${comment.id}'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      minimumSize: const Size(0, 36),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: busy
                        ? null
                        : () => runAccountAction(
                            () => loadAllReplies(post, comment.id!),
                          ),
                    child: Text('$hidden yanıt daha'),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget commentRow(
    BuildContext context,
    AppStore store,
    Post post,
    Comment comment, {
    bool reply = false,
    bool padBottom = true,
  }) {
    final person = comment.authorId.isEmpty
        ? null
        : store.person(comment.authorId);
    return Padding(
      key: ValueKey('comment-${comment.id}'),
      padding: EdgeInsets.only(bottom: padBottom || reply ? Space.lg : 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (reply)
            const Padding(
              padding: EdgeInsets.only(top: 6, right: 4),
              child: Icon(
                Icons.subdirectory_arrow_right_rounded,
                size: 16,
                color: AppColors.textMuted,
              ),
            ),
          Avatar(
            person,
            size: reply ? 30 : 36,
            onTap: person == null
                ? null
                : () => openPage(context, '/profile', person.id),
          ),
          SizedBox(width: reply ? Space.sm : Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        person?.name ?? 'Anonim',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    Text(
                      comment.time,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (comment.mine)
                      IconButton(
                        tooltip: reply ? 'Yanıtı sil' : 'Yorumu sil',
                        icon: const Icon(Icons.delete_outline, size: 18),
                        onPressed: busy
                            ? null
                            : () => runAccountAction(() async {
                                await store.removeComment(post, comment);
                                if (comment.parentId != null) {
                                  expanded.remove(comment.parentId);
                                }
                              }),
                      )
                    else if (comment.id != null && post.remote)
                      IconButton(
                        tooltip: reply
                            ? 'Yanıtı şikâyet et'
                            : 'Yorumu şikâyet et',
                        icon: const Icon(Icons.flag_outlined, size: 18),
                        onPressed: () => openPage(
                          context,
                          '/report',
                          ReportTarget(
                            'comment',
                            int.parse(comment.id!),
                            reply ? 'Yanıt' : 'Yorum',
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(comment.text),
                if (!reply &&
                    post.remote &&
                    post.commentsEnabled &&
                    comment.id != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      key: ValueKey('reply-${comment.id}'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        minimumSize: const Size(0, 34),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        textStyle: AppTypography.metadata.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      onPressed: busy ? null : () => startReply(comment),
                      icon: const Icon(
                        Icons.subdirectory_arrow_right_rounded,
                        size: 16,
                      ),
                      label: const Text('Yanıtla'),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SavedPage extends StatelessWidget {
  const SavedPage({super.key});
  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    if (store.connected) {
      return AppPage(
        title: 'Kaydedilenler',
        child: PagedContent<Post>(
          key: ValueKey(store.savedVersion),
          fetch: store.loadSaved,
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
                  const EmptyState(
                    'Güzel anıları burada biriktir.',
                    'Kaydet simgesine dokunduğun paylaşımlar burada görünecek.',
                    icon: Icons.bookmark_border,
                  ),
                for (final post in saved)
                  PostCard(post, key: ValueKey(post.id)),
                ?footer,
              ],
            ),
          ),
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
