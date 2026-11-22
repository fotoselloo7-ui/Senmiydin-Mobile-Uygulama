import 'dart:async';

import 'package:flutter/material.dart' hide Text;

import '../widgets/translated_text.dart';

import 'package:latlong2/latlong.dart';

import '../core/app_locale.dart';
import '../core/theme.dart';
import '../data/app_store.dart';
import '../data/communication_api.dart';
import '../widgets/account_action.dart';
import '../widgets/common.dart';
import '../widgets/notifications_sheet.dart';
import '../widgets/social_page.dart';

Future<void> routeInboxNotification(
  NavigatorState navigator,
  InboxNotification item,
) async {
  if (!item.available) {
    ScaffoldMessenger.of(navigator.context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(navigator.context.l10n.notificationsUnavailable),
        ),
      );
    return;
  }
  if (item.announcementBody case final body?) {
    final store = StoreScope.of(navigator.context);
    final openMap = await showDialog<bool>(
      context: navigator.context,
      builder: (context) => AlertDialog(
        title: Text(item.text),
        content: SingleChildScrollView(child: Text(body)),
        actions: [
          // A location announcement can show its approximate target on the app's own map; never a user's position.
          if (item.hasMapTarget)
            TextButton(
              key: const Key('announcement-see-on-map'),
              onPressed: () => Navigator.pop(context, true),
              child: Text(context.l10n.seeOnMap),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.close),
          ),
        ],
      ),
    );
    if (openMap == true && navigator.mounted) {
      store.mapFocus = LatLng(item.mapLatitude!, item.mapLongitude!);
      await navigator.pushNamed('/map');
    }
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

  /// all / follow / comments / likes (the unread switch above is the server's own filter).
  String kind = 'all';

  static bool _matches(String kind, InboxNotification item) => switch (kind) {
    'follow' => item.type == 'follow',
    'comments' =>
      item.type == 'comment' ||
          item.type == 'comment_reply' ||
          item.type == 'map_note_reply',
    'likes' => item.type == 'like' || item.type == 'comment_like',
    _ => true,
  };

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final text = context.l10n;
    return AppPage(
      title: text.notificationsTitle,
      actions: [
        IconButton(
          tooltip: text.notificationsMarkAllTooltip,
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
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final (key, label, isUnread) in [
                    ('all', text.notificationsFilterAll, false),
                    ('unread', text.notificationsFilterUnread, true),
                    ('follow', tr('Takip'), false),
                    ('comments', tr('Yorumlar'), false),
                    ('likes', tr('Beğeniler'), false),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _FilterChip(
                        key: Key('notifications-filter-$key'),
                        label: label,
                        selected: isUnread ? unread : !unread && kind == key,
                        onTap: () => setState(() {
                          unread = isUnread;
                          kind = isUnread ? 'all' : key;
                        }),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            child: PagedContent<InboxNotification>(
              key: ValueKey((unread, kind, store.communicationVersion)),
              fetch: (page) => store.communication!.inbox(page, unread),
              id: (item) => item.id.toString(),
              visible: (item) => _matches(kind, item),
              builder: (context, items, footer, refresh) => RefreshIndicator(
                onRefresh: refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: Space.xl),
                  children: [
                    if (items.isEmpty && footer == null)
                      EmptyState(
                        text.notificationsEmptyTitle,
                        text.notificationsEmptyBody,
                        icon: Icons.notifications_none,
                      ),
                    for (final group in groupNotifications(items)) ...[
                      NotificationGroupHeader(group.label(text)),
                      for (final item in group.items)
                        NotificationTile(
                          key: ValueKey(('notification', item.id)),
                          item: item,
                          onTap: busy
                              ? () {}
                              : () => runAccountAction(() async {
                                  if (!item.read) {
                                    await store.communication!.readNotification(
                                      item.id,
                                    );
                                    store.communicationChanged();
                                  }
                                  if (context.mounted &&
                                      (!item.available ||
                                          item.route != '/notifications' ||
                                          item.announcementBody != null)) {
                                    unawaited(
                                      routeInboxNotification(
                                        Navigator.of(context),
                                        item,
                                      ),
                                    );
                                  }
                                }),
                        ),
                    ],
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

/// A filter chip like the examples: a soft rounded rectangle; the chosen one is a light wash of the main colour.
class _FilterChip extends StatelessWidget {
  const _FilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: Material(
      color: selected
          ? AppColors.primary.withValues(alpha: .13)
          : const Color(0xFFF1F4F9),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 40),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            label,
            maxLines: 1,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: selected ? AppColors.primary : AppColors.navy,
            ),
          ),
        ),
      ),
    ),
  );
}
