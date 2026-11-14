import 'package:flutter/material.dart' hide Text;
import 'translated_text.dart';

import '../core/navigation.dart';
import '../core/theme.dart';
import '../data/app_store.dart';
import '../data/communication_api.dart';
import '../data/models.dart';
import 'account_action.dart';
import 'common.dart';
import 'social_page.dart';
import '../core/app_locale.dart';

/// Opens the comments of [post] as a bottom sheet over the current screen (Home, profile, search, saved, detail…).
/// The screen underneath keeps its scroll position and updates its comment count live.
Future<void> showCommentsSheet(BuildContext context, Post post) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => CommentsSheet(post: post),
    );

/// The draggable shell: starts at 78 % of the screen, grows to 95 %, closes when dragged down, and lifts above the keyboard.
class CommentsSheet extends StatefulWidget {
  const CommentsSheet({super.key, required this.post});
  final Post post;

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  bool closing = false;

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 120),
      padding: EdgeInsets.only(bottom: inset),
      child: NotificationListener<DraggableScrollableNotification>(
        onNotification: (notification) {
          if (!closing && notification.extent <= notification.minExtent + .01) {
            closing = true;
            Navigator.maybePop(context);
          }
          return false;
        },
        child: DraggableScrollableSheet(
          initialChildSize: .78,
          minChildSize: .35,
          maxChildSize: .95,
          snap: true,
          snapSizes: const [.78],
          builder: (context, controller) =>
              CommentsPanel(post: widget.post, controller: controller),
        ),
      ),
    );
  }
}

class _PanelHeader extends SliverPersistentHeaderDelegate {
  _PanelHeader({required this.post, required this.scale, required this.close});
  final Post post;
  final double scale;
  final VoidCallback close;

  @override
  double get maxExtent =>
      20 + 46 * scale + (post.text.trim().isEmpty ? 0 : 22 * scale);
  @override
  double get minExtent => maxExtent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => Material(
    color: Colors.white,
    child: ClipRect(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Decorative drag handle: no semantics noise.
          ExcludeSemantics(
            child: Center(
              child: Container(
                margin: const EdgeInsets.only(top: 8, bottom: 6),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: Space.lg, right: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Yorumlar (${post.displayedCommentCount})',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.section,
                  ),
                ),
                IconButton(
                  key: const Key('comments-close'),
                  tooltip: tr('Kapat'),
                  icon: const Icon(Icons.close_rounded),
                  onPressed: close,
                ),
              ],
            ),
          ),
          if (post.text.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.lg),
              child: Text(
                post.text.trim().replaceAll(RegExp(r'\s+'), ' '),
                key: const Key('comments-context'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.metadata,
              ),
            ),
        ],
      ),
    ),
  );

  @override
  bool shouldRebuild(covariant _PanelHeader old) =>
      old.post.displayedCommentCount != post.displayedCommentCount ||
      old.post.text != post.text ||
      old.scale != scale;
}

/// The reusable comments surface: header, scrolling thread list (with replies, likes, report, delete) and a docked composer.
class CommentsPanel extends StatefulWidget {
  const CommentsPanel({super.key, required this.post, this.controller});
  final Post post;
  final ScrollController? controller;

  @override
  State<CommentsPanel> createState() => _CommentsPanelState();
}

class _CommentsPanelState extends State<CommentsPanel>
    with AccountAction<CommentsPanel> {
  final text = TextEditingController();
  final focus = FocusNode();
  ScrollController? ownScroll;
  ScrollController get scroll =>
      widget.controller ?? (ownScroll ??= ScrollController());

  /// The top-level comment being answered (replies never answer replies).
  Comment? replyingTo;

  /// Fully loaded reply lists, by top-level comment id (the list itself only embeds the first few).
  final expanded = <String, List<Comment>>{};

  @override
  void dispose() {
    text.dispose();
    focus.dispose();
    ownScroll?.dispose();
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

  void close() => Navigator.maybePop(context);

  SliverPersistentHeader header(Post post) => SliverPersistentHeader(
    pinned: true,
    delegate: _PanelHeader(
      post: post,
      scale: MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0),
      close: close,
    ),
  );

  Widget body(
    BuildContext context,
    AppStore store,
    Post post,
    List<Comment> comments,
    Widget? footer,
  ) {
    final empty = comments.isEmpty && footer == null;
    return CustomScrollView(
      key: const Key('comments-scroll'),
      controller: scroll,
      slivers: [
        header(post),
        if (empty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                Space.lg,
                Space.lg,
                Space.lg,
                Space.md,
              ),
              child: Column(
                children: [
                  Text(
                    'İlk merhaba senden gelsin.',
                    key: Key('comments-empty'),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Henüz yorum yapılmamış.',
                    textAlign: TextAlign.center,
                    style: AppTypography.metadata,
                  ),
                ],
              ),
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            Space.lg,
            Space.sm,
            Space.lg,
            Space.md,
          ),
          sliver: SliverList.list(
            children: [
              for (final comment in comments)
                post.remote
                    ? commentThread(context, store, post, comment)
                    : commentRow(context, store, post, comment),
              ?footer,
            ],
          ),
        ),
      ],
    );
  }

  Widget composer(BuildContext context, AppStore store, Post post) {
    if (!post.commentsEnabled) {
      return const SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(Space.md, 4, Space.md, Space.md),
          child: InfoNote('Bu paylaşım yorumlara kapalı.'),
        ),
      );
    }
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.md,
            Space.sm,
            Space.md,
            Space.sm,
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
                        tooltip: tr('Yanıtı iptal et'),
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
                    icon: const Icon(Icons.send_rounded, color: AppColors.blue),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final post = widget.post;
    return Material(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: !post.interactionsEnabled
          ? CustomScrollView(
              controller: scroll,
              slivers: [
                header(post),
                const SliverToBoxAdapter(
                  child: EmptyState('Yorumlar yayın sonrası açılır.', ''),
                ),
              ],
            )
          : Column(
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
                              body(context, store, post, comments, footer),
                        )
                      : body(context, store, post, post.comments, null),
                ),
                composer(context, store, post),
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
                if (post.remote && comment.id != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Outline heart + count; the same icon and colours as the post like.
                        TextButton.icon(
                          key: ValueKey('like-comment-${comment.id}'),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            minimumSize: const Size(0, 34),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            foregroundColor: comment.liked
                                ? AppColors.encounterPink
                                : const Color(0xFF334766),
                            textStyle: AppTypography.metadata.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          onPressed: () => socialAction(
                            context,
                            () => store.toggleCommentLike(post, comment),
                          ),
                          icon: Icon(
                            comment.liked
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            size: 17,
                            semanticLabel: comment.liked
                                ? 'Beğeniyi geri al'
                                : 'Beğen',
                          ),
                          label: Text('${comment.likes}'),
                        ),
                        if (!reply && post.commentsEnabled) ...[
                          const SizedBox(width: 10),
                          TextButton.icon(
                            key: ValueKey('reply-${comment.id}'),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 2,
                              ),
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
                        ],
                      ],
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
