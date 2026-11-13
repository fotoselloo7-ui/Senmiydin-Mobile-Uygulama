import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../core/navigation.dart';
import '../data/app_store.dart';
import '../data/models.dart';
import '../widgets/common.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});
  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  String filter = 'Tümü';
  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context),
        notices = store.notices
            .where(
              (n) =>
                  (filter != 'Okunmamış' || !n.read) &&
                  (n.personId == null || !store.blocked.contains(n.personId)),
            )
            .toList();
    return AppPage(
      title: 'Bildirimler',
      actions: [
        IconButton(
          tooltip: 'Tümünü okundu işaretle',
          onPressed: store.readAll,
          icon: const Icon(Icons.done_all, color: AppColors.blue),
        ),
      ],
      child: Column(
        children: [
          Padding(
            padding: Space.page,
            child: ChoicePills(
              options: const ['Tümü', 'Okunmamış'],
              value: filter,
              onChanged: (v) => setState(() => filter = v),
            ),
          ),
          Expanded(
            child: notices.isEmpty
                ? const SingleChildScrollView(
                    child: EmptyState(
                      'Her şey güncel.',
                      'Yeni etkileşimlerin burada görünecek.',
                      icon: Icons.notifications_none,
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: Space.lg),
                    itemCount: notices.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: Space.sm),
                    itemBuilder: (_, i) => NotificationRow(notices[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

class NotificationRow extends StatelessWidget {
  const NotificationRow(this.notice, {super.key});
  final AppNotice notice;
  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context), n = notice;
    final icon = switch (n.kind) {
      NoticeKind.like => Icons.favorite_border,
      NoticeKind.comment => Icons.chat_bubble_outline,
      NoticeKind.follow => Icons.person_add_outlined,
      NoticeKind.message => Icons.mail_outline,
      NoticeKind.tag => Icons.alternate_email,
      NoticeKind.request => Icons.favorite_border,
      NoticeKind.approved => Icons.verified_outlined,
      NoticeKind.nearby => Icons.location_on_outlined,
      NoticeKind.system => Icons.campaign_outlined,
    };
    return Container(
      decoration: AppShape.card(color: n.read ? Colors.white : AppColors.pale),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppShape.rounded,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          leading: n.personId == null
              ? CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Icon(icon, color: AppColors.blue),
                )
              : Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Avatar(store.person(n.personId!), size: 43),
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
                ),
          title: Text(
            n.text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: n.read ? FontWeight.w500 : FontWeight.w800,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(
              n.time,
              style: const TextStyle(color: AppColors.muted, fontSize: 11),
            ),
          ),
          trailing: n.read
              ? null
              : const CircleAvatar(radius: 3, backgroundColor: AppColors.blue),
          onTap: () {
            store.markRead(n);
            if (n.encounterId != null) {
              openPage(context, '/encounter', n.encounterId);
            } else if (n.kind == NoticeKind.message) {
              openPage(context, '/chat', n.personId);
            } else if (n.postId != null) {
              openPage(
                context,
                n.kind == NoticeKind.comment ? '/comments' : '/post',
                n.postId,
              );
            } else if (n.personId != null) {
              openPage(context, '/profile', n.personId);
            } else if (n.kind == NoticeKind.nearby) {
              openPage(context, '/map');
            } else {
              openPage(context, '/legal', 'Topluluk Kuralları');
            }
          },
        ),
      ),
    );
  }
}
