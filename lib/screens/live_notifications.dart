import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../data/app_store.dart';
import '../data/communication_api.dart';
import '../widgets/account_action.dart';
import '../widgets/common.dart';
import '../widgets/social_page.dart';

Future<void> routeInboxNotification(
  NavigatorState navigator,
  InboxNotification item,
) async {
  if (!item.available) {
    ScaffoldMessenger.of(navigator.context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Bu içerik artık kullanılamıyor.')),
      );
    return;
  }
  if (item.announcementBody case final body?) {
    await showDialog<void>(
      context: navigator.context,
      builder: (context) => AlertDialog(
        title: Text(item.text),
        content: SingleChildScrollView(child: Text(body)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
    return;
  }
  final entity = item.entity?.toString();
  switch (item.route) {
    case '/post' ||
            '/comments' ||
            '/conversation' ||
            '/encounter' ||
            '/map-note'
        when entity != null:
      await navigator.pushNamed(item.route, arguments: entity);
    case '/profile' when item.actor != null:
      await navigator.pushNamed('/profile', arguments: item.actor!.id);
    case '/notifications':
      await navigator.pushNamed('/notifications');
  }
}

class LiveNotificationsPage extends StatefulWidget {
  const LiveNotificationsPage({super.key});

  @override
  State<LiveNotificationsPage> createState() => _LiveNotificationsPageState();
}

class _LiveNotificationsPageState extends State<LiveNotificationsPage>
    with AccountAction<LiveNotificationsPage> {
  bool unread = false;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return AppPage(
      title: 'Bildirimler',
      actions: [
        IconButton(
          tooltip: 'Tümünü okundu işaretle',
          onPressed: busy
              ? null
              : () => runAccountAction(() async {
                  await store.communication!.readNotification();
                  store.communicationChanged();
                }),
          icon: const Icon(Icons.done_all, color: AppColors.blue),
        ),
      ],
      child: Column(
        children: [
          Padding(
            padding: Space.page,
            child: ChoicePills(
              options: const ['Tümü', 'Okunmamış'],
              value: unread ? 'Okunmamış' : 'Tümü',
              onChanged: (value) =>
                  setState(() => unread = value == 'Okunmamış'),
            ),
          ),
          Expanded(
            child: PagedContent<InboxNotification>(
              key: ValueKey((unread, store.communicationVersion)),
              fetch: (page) => store.communication!.inbox(page, unread),
              id: (item) => item.id.toString(),
              builder: (context, items, footer, refresh) => RefreshIndicator(
                onRefresh: refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: Space.lg),
                  children: [
                    if (items.isEmpty && footer == null)
                      const EmptyState(
                        'Her şey güncel.',
                        'Yeni etkileşimlerin burada görünecek.',
                        icon: Icons.notifications_none,
                      ),
                    for (final item in items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: Space.sm),
                        child: Container(
                          decoration: AppShape.card(
                            color: item.read ? Colors.white : AppColors.pale,
                          ),
                          child: Material(
                            type: MaterialType.transparency,
                            borderRadius: AppShape.rounded,
                            clipBehavior: Clip.antiAlias,
                            child: Semantics(
                              label: item.read
                                  ? 'Okundu'
                                  : 'Okunmamış bildirim',
                              child: ListTile(
                                key: ValueKey(('notification', item.id)),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                leading: _NoticeAvatar(item),
                                title: Text(
                                  item.text,
                                  style: TextStyle(
                                    fontWeight: item.read
                                        ? FontWeight.w500
                                        : FontWeight.w700,
                                  ),
                                ),
                                subtitle: Text(
                                  item.available
                                      ? [?item.subtitle, item.time].join(' · ')
                                      : '${item.time} · İçerik kullanılamıyor',
                                  style: const TextStyle(
                                    color: AppColors.muted,
                                  ),
                                ),
                                trailing: item.read
                                    ? null
                                    : const Icon(
                                        Icons.circle,
                                        size: 7,
                                        color: AppColors.blue,
                                      ),
                                onTap: busy
                                    ? null
                                    : () => runAccountAction(() async {
                                        if (!item.read) {
                                          await store.communication!
                                              .readNotification(item.id);
                                          store.communicationChanged();
                                        }
                                        if (context.mounted &&
                                            (!item.available ||
                                                item.route !=
                                                    '/notifications' ||
                                                item.announcementBody !=
                                                    null)) {
                                          unawaited(
                                            routeInboxNotification(
                                              Navigator.of(context),
                                              item,
                                            ),
                                          );
                                        }
                                      }),
                              ),
                            ),
                          ),
                        ),
                      ),
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

class _NoticeAvatar extends StatelessWidget {
  const _NoticeAvatar(this.item);
  final InboxNotification item;

  @override
  Widget build(BuildContext context) {
    final icon = switch (item.type) {
      'like' => Icons.favorite_border,
      'comment' || 'comment_reply' => Icons.chat_bubble_outline,
      'follow' => Icons.person_add_outlined,
      'message' || 'message_request' => Icons.mail_outline,
      'location_match' || 'nearby_activity' => Icons.location_on_outlined,
      'map_note_nearby' || 'map_note_reply' => Icons.mail_outline_rounded,
      'system' => Icons.campaign_outlined,
      _ => Icons.favorite_border,
    };
    if (item.actor == null) {
      return CircleAvatar(
        backgroundColor: Colors.white,
        child: Icon(icon, color: AppColors.blue),
      );
    }
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Avatar(item.actor, size: 43),
        Positioned(
          right: -3,
          bottom: -3,
          child: CircleAvatar(
            radius: 10,
            backgroundColor: Colors.white,
            child: Icon(icon, color: AppColors.blue, size: 13),
          ),
        ),
      ],
    );
  }
}
