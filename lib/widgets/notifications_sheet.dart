import 'dart:async';

import 'package:flutter/material.dart' hide Text;
import 'translated_text.dart';

import '../core/app_locale.dart';
import '../core/theme.dart';
import '../data/app_store.dart';
import '../data/communication_api.dart';
import '../data/models.dart';
import '../screens/live_notifications.dart';
import 'common.dart';

/// Number of notifications the quick panel previews before "Tümünü Gör".
const notificationPreviewCount = 10;

/// Opens the notification quick panel over the current screen (the Home bell). The full list stays one tap away.
Future<void> showNotificationsSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => const NotificationsSheet(),
    );

/// Draggable shell: opens at 70 %, grows to 95 %, closes when dragged down.
class NotificationsSheet extends StatefulWidget {
  const NotificationsSheet({super.key});
  @override
  State<NotificationsSheet> createState() => _NotificationsSheetState();
}

class _NotificationsSheetState extends State<NotificationsSheet> {
  bool closing = false;

  @override
  Widget build(BuildContext context) =>
      NotificationListener<DraggableScrollableNotification>(
        onNotification: (notification) {
          if (!closing && notification.extent <= notification.minExtent + .01) {
            closing = true;
            Navigator.maybePop(context);
          }
          return false;
        },
        child: DraggableScrollableSheet(
          initialChildSize: .7,
          minChildSize: .35,
          maxChildSize: .95,
          snap: true,
          snapSizes: const [.7],
          builder: (context, controller) =>
              NotificationsPanel(controller: controller),
        ),
      );
}

/// Reusable panel: sticky header (title, unread count, "Tümünü okundu"), grouped list and a "Tümünü Gör" footer.
class NotificationsPanel extends StatefulWidget {
  const NotificationsPanel({super.key, this.controller});
  final ScrollController? controller;
  @override
  State<NotificationsPanel> createState() => _NotificationsPanelState();
}

class _NotificationsPanelState extends State<NotificationsPanel> {
  List<InboxNotification>? items;
  bool failed = false;
  bool marking = false;
  int loadToken = 0;
  int seenVersion = -1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final store = StoreScope.of(context);
    if (store.connected && seenVersion != store.communicationVersion) {
      seenVersion = store.communicationVersion;
      unawaited(load(store));
    }
  }

  Future<void> load(AppStore store) async {
    final token = ++loadToken;
    try {
      final page = await store.communication!.inbox(1, false);
      if (!mounted || token != loadToken) return;
      setState(() {
        items = page.items.take(notificationPreviewCount).toList();
        failed = false;
      });
    } catch (_) {
      if (!mounted || token != loadToken) return;
      setState(() => failed = true);
    }
  }

  Future<void> markAll(AppStore store) async {
    if (marking) return;
    setState(() => marking = true);
    try {
      if (store.connected) {
        await store.communication!.readNotification();
        store.communicationChanged();
      } else {
        store.readAll();
      }
    } catch (_) {
      // The list below stays as it was; the next refresh shows the real state.
    } finally {
      if (mounted) setState(() => marking = false);
    }
  }

  Future<void> open(AppStore store, InboxNotification item) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    if (!item.read) {
      try {
        await store.communication!.readNotification(item.id);
        store.communicationChanged();
      } catch (_) {
        // Reading state is best effort; routing still works.
      }
    }
    if (!mounted) return;
    navigator.pop();
    unawaited(routeInboxNotification(navigator, item));
  }

  void seeAll() {
    final navigator = Navigator.of(context, rootNavigator: true);
    navigator.pop();
    unawaited(navigator.pushNamed('/notifications'));
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final text = context.l10n;
    final connected = store.connected;
    final unread = connected
        ? store.unreadNotifications
        : store.unreadNotices;
    final rows = <Widget>[];
    if (connected) {
      final list = items;
      if (list == null && !failed) {
        rows.add(const Padding(
          padding: EdgeInsets.all(Space.xl),
          child: Center(child: CircularProgressIndicator()),
        ));
      } else if (failed && (list == null || list.isEmpty)) {
        rows.add(
          InlineState(
            title: text.notificationsLoadError,
            actionLabel: text.retry,
            onAction: () => unawaited(load(store)),
          ),
        );
      } else if (list!.isEmpty) {
        rows.add(EmptyState(
          text.notificationsEmptyTitle,
          text.notificationsEmptyBody,
          icon: Icons.notifications_none,
        ));
      } else {
        for (final group in groupNotifications(list)) {
          rows.add(NotificationGroupHeader(group.label(text)));
          for (final item in group.items) {
            rows.add(
              NotificationTile(
                key: ValueKey(('notification', item.id)),
                item: item,
                onTap: () => unawaited(open(store, item)),
              ),
            );
          }
        }
      }
    } else {
      final notices = store.notices.take(notificationPreviewCount).toList();
      if (notices.isEmpty) {
        rows.add(EmptyState(
          text.notificationsEmptyTitle,
          text.notificationsEmptyBody,
          icon: Icons.notifications_none,
        ));
      }
      for (final notice in notices) {
        rows.add(_OfflineNoticeTile(notice));
      }
    }

    return Material(
      color: Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
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
            padding: const EdgeInsets.fromLTRB(Space.lg, 2, 8, 4),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        text.notificationsTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.section,
                      ),
                      Text(
                        unread > 0
                            ? text.notificationsUnreadCount(unread)
                            : text.notificationsAllRead,
                        key: const Key('notifications-unread-count'),
                        style: AppTypography.metadata,
                      ),
                    ],
                  ),
                ),
                TextButton(
                  key: const Key('notifications-mark-all'),
                  onPressed: marking || unread == 0
                      ? null
                      : () => unawaited(markAll(store)),
                  child: Text(text.notificationsMarkAll),
                ),
                IconButton(
                  key: const Key('notifications-close'),
                  tooltip: text.close,
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.maybePop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.line),
          Expanded(
            child: ListView(
              key: const Key('notifications-scroll'),
              controller: widget.controller,
              padding: EdgeInsets.zero,
              children: [
                ...rows,
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Space.lg,
                    Space.md,
                    Space.lg,
                    Space.lg,
                  ),
                  child: SecondaryButton(
                    text.notificationsSeeAll,
                    key: const Key('notifications-see-all'),
                    onPressed: seeAll,
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

// ---------------------------------------------------------------- grouping

enum NotificationGroupKind { today, yesterday, earlier }

class NotificationGroup {
  NotificationGroup(this.kind);
  final NotificationGroupKind kind;
  final List<InboxNotification> items = [];

  String label(AppLocalizations text) => switch (kind) {
    NotificationGroupKind.today => text.notificationsGroupToday,
    NotificationGroupKind.yesterday => text.notificationsGroupYesterday,
    NotificationGroupKind.earlier => text.notificationsGroupEarlier,
  };
}

NotificationGroupKind notificationGroupOf(DateTime time, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(time.year, time.month, time.day);
  final diff = today.difference(day).inDays;
  if (diff <= 0) return NotificationGroupKind.today;
  if (diff == 1) return NotificationGroupKind.yesterday;
  return NotificationGroupKind.earlier;
}

/// Newest-first notifications grouped into Bugün / Dün / Daha Önce (empty groups are skipped).
List<NotificationGroup> groupNotifications(
  List<InboxNotification> items, {
  DateTime? now,
}) {
  final clock = now ?? DateTime.now();
  final groups = <NotificationGroupKind, NotificationGroup>{};
  for (final item in items) {
    final kind = notificationGroupOf(item.createdAt, clock);
    groups.putIfAbsent(kind, () => NotificationGroup(kind)).items.add(item);
  }
  return [
    for (final kind in NotificationGroupKind.values)
      if (groups[kind] != null) groups[kind]!,
  ];
}

class NotificationGroupHeader extends StatelessWidget {
  const NotificationGroupHeader(this.label, {super.key});
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(Space.lg, Space.md, Space.lg, 6),
    child: Semantics(
      header: true,
      child: Text(
        label,
        style: AppTypography.metadata.copyWith(
          fontWeight: FontWeight.w800,
          color: AppColors.muted,
          letterSpacing: .2,
        ),
      ),
    ),
  );
}

// -------------------------------------------------------------------- rows

IconData notificationIcon(String type) => switch (type) {
  'like' || 'comment_like' => Icons.favorite_rounded,
  'comment' || 'comment_reply' => Icons.chat_bubble_rounded,
  'follow' => Icons.person_add_alt_1_rounded,
  'message' || 'message_request' => Icons.mail_rounded,
  'encounter_request' ||
  'encounter_accepted' ||
  'encounter_rejected' ||
  'encounter_story' ||
  'encounter_story_approval' ||
  'encounter_story_published' => Icons.favorite_rounded,
  'location_match' || 'nearby_activity' => Icons.location_on_rounded,
  'map_note_nearby' || 'map_note_reply' => Icons.mail_outline_rounded,
  'system' => Icons.campaign_rounded,
  _ => Icons.notifications_rounded,
};

Color notificationColor(String type) => switch (type) {
  'like' || 'comment_like' => AppColors.encounterPink,
  'map_note_nearby' || 'map_note_reply' => AppColors.brandPurple,
  'location_match' || 'nearby_activity' => AppColors.primary,
  _ => AppColors.blue,
};

/// One clean list row (no per-row card box): avatar or category icon, text, optional second line, time, unread dot.
class NotificationTile extends StatelessWidget {
  const NotificationTile({super.key, required this.item, required this.onTap});
  final InboxNotification item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = context.l10n;
    final subtitle = item.available
        ? item.subtitle
        : text.notificationsContentUnavailable;
    return Semantics(
      label: item.read
          ? text.notificationsReadSemantics
          : text.notificationsUnreadSemantics,
      child: Material(
        color: item.read ? Colors.white : const Color(0xFFF1F5FF),
        child: InkWell(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 64),
            padding: const EdgeInsets.symmetric(
              horizontal: Space.lg,
              vertical: 10,
            ),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFEEF3F9))),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                NotificationAvatar(item.type, item.actor),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.text,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.3,
                          fontWeight: item.read
                              ? FontWeight.w600
                              : FontWeight.w800,
                          color: AppColors.navy,
                        ),
                      ),
                      if (subtitle != null && subtitle.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            subtitle,
                            style: AppTypography.metadata.copyWith(height: 1.3),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          item.time,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!item.read)
                  const Padding(
                    padding: EdgeInsets.only(left: 8, top: 6),
                    child: Icon(Icons.circle, size: 8, color: AppColors.blue),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Actor avatar with a small category badge, or just the category icon when the notification carries no identity.
class NotificationAvatar extends StatelessWidget {
  const NotificationAvatar(this.type, this.actor, {super.key});
  final String type;
  final Person? actor;

  @override
  Widget build(BuildContext context) {
    final icon = notificationIcon(type);
    final color = notificationColor(type);
    if (actor == null) {
      return CircleAvatar(
        radius: 22,
        backgroundColor: color.withValues(alpha: .12),
        child: Icon(icon, color: color, size: 22),
      );
    }
    return SizedBox(
      width: 46,
      height: 46,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Avatar(actor, size: 44),
          Positioned(
            right: -3,
            bottom: -3,
            child: CircleAvatar(
              radius: 10,
              backgroundColor: Colors.white,
              child: Icon(icon, color: color, size: 13),
            ),
          ),
        ],
      ),
    );
  }
}

/// Offline demo notices (no server): same visual language, no date groups.
class _OfflineNoticeTile extends StatelessWidget {
  const _OfflineNoticeTile(this.notice);
  final AppNotice notice;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return Material(
      color: notice.read ? Colors.white : const Color(0xFFF1F5FF),
      child: InkWell(
        onTap: () {
          store.markRead(notice);
          final navigator = Navigator.of(context, rootNavigator: true)..pop();
          navigator.pushNamed('/notifications');
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Space.lg,
            vertical: 12,
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.blue.withValues(alpha: .12),
                child: const Icon(
                  Icons.notifications_rounded,
                  color: AppColors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  notice.text,
                  style: TextStyle(
                    fontWeight: notice.read ? FontWeight.w600 : FontWeight.w800,
                    color: AppColors.navy,
                  ),
                ),
              ),
              if (!notice.read)
                const Icon(Icons.circle, size: 8, color: AppColors.blue),
            ],
          ),
        ),
      ),
    );
  }
}
