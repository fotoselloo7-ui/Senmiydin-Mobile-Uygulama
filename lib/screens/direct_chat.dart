import '../core/polling.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../core/navigation.dart';
import '../core/theme.dart';
import '../data/account_api.dart';
import '../data/app_store.dart';
import '../data/communication_api.dart';
import '../data/social_api.dart';
import '../widgets/account_action.dart';
import '../widgets/common.dart';
import '../widgets/media_viewer.dart';
import '../widgets/social_page.dart';

class DirectConversationList extends StatelessWidget {
  const DirectConversationList(this.requests, this.query, {super.key});
  final bool requests;
  final String query;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return PagedContent<DirectConversation>(
      key: ValueKey((requests, query, store.communicationVersion)),
      fetch: (page) =>
          store.communication!.conversations(page, requests, query),
      id: (item) => item.id.toString(),
      builder: (context, items, footer, refresh) => RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            if (items.isEmpty && footer == null)
              const EmptyState(
                'Bir merhaba ile başlar.',
                'Yeni sohbetler ve mesaj istekleri burada görünecek.',
                icon: Icons.chat_bubble_outline,
              ),
            for (final chat in items) ...[
              ListTile(
                contentPadding: const EdgeInsets.symmetric(vertical: Space.sm),
                leading: Avatar(
                  chat.peer,
                  size: 53,
                  online: chat.recentlyActive,
                ),
                title: Text(
                  chat.peer.name,
                  style: TextStyle(
                    fontWeight: chat.unread > 0
                        ? FontWeight.w700
                        : FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  [
                    if (requests)
                      chat.outgoing ? 'Onay bekliyor' : 'Gelen istek',
                    chat.last?.preview ?? 'Bir merhaba gönder.',
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (chat.last case final last?)
                      Text(
                        socialTime(last.date.toIso8601String()),
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    if (chat.unread > 0) ...[
                      const SizedBox(height: 4),
                      Badge(
                        label: Text('${chat.unread}'),
                        backgroundColor: AppColors.action,
                      ),
                    ],
                  ],
                ),
                onTap: () =>
                    openPage(context, '/conversation', chat.id.toString()),
              ),
              const Divider(height: 1),
            ],
            ?footer,
          ],
        ),
      ),
    );
  }
}

class DirectChatPage extends StatefulWidget {
  const DirectChatPage(
    this.id, {
    super.key,
    this.byPeer = false,
    this.initialText,
  });
  final String id;
  final bool byPeer;
  final String? initialText;

  @override
  State<DirectChatPage> createState() => _DirectChatPageState();
}

class _DirectChatPageState extends State<DirectChatPage>
    with AccountAction<DirectChatPage> {
  late final text = TextEditingController(text: widget.initialText);
  final scroll = ScrollController();
  final messages = <int, DirectMessage>{};
  final picker = ImagePicker();
  DirectConversation? chat;
  XFile? image;
  RoutePolling? timer;
  AppStore? store;
  String? error, sendError, attempt;
  int readThrough = 0;
  bool loading = false, loadingOlder = false, hasOlder = false;

  CommunicationApi get api => store!.communication!;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (store != null) {
      timer?.attach(context);
      return;
    }
    store = StoreScope.of(context);

    scroll.addListener(loadAtTop);
    timer = RoutePolling(interval: const Duration(seconds: 4), fetch: sync);
    timer!.attach(context);
  }

  @override
  void dispose() {
    timer?.dispose();
    scroll.dispose();
    text.dispose();
    super.dispose();
  }

  Future<bool> sync({bool older = false}) async {
    if (loading || loadingOlder || busy || (older && !hasOlder)) return true;
    final initial = chat == null;
    if (older) {
      setState(() => loadingOlder = true);
    } else {
      loading = true;
    }
    try {
      final previousId = chat?.id;
      final next = older
          ? chat!
          : await api.conversation(
              previousId?.toString() ?? widget.id,
              byPeer: previousId == null && widget.byPeer,
            );
      final id = next.id;
      if (id == null) {
        if (mounted) {
          setState(() {
            chat = next;
            error = null;
          });
        }
        return true;
      }
      final firstPage = messages.isEmpty;
      final page = await api.messages(
        id,
        before: older ? messages.keys.reduce((a, b) => a < b ? a : b) : null,
      );
      final received = page.items
          .where((message) => !message.mine && !message.read)
          .fold(
            0,
            (latest, message) => message.id > latest ? message.id : latest,
          );
      if (mounted) {
        setState(() {
          chat = next;
          error = null;
          final newestCached = messages.keys.fold(
            0,
            (newest, id) => id > newest ? id : newest,
          );
          final historyGap =
              !older &&
              page.more &&
              newestCached > 0 &&
              page.items.every((message) => message.id > newestCached);
          if (historyGap) messages.clear();
          if (!older) {
            final returned = page.items.map((message) => message.id).toSet();
            final oldestReturned = page.items.fold<int?>(
              null,
              (oldest, message) =>
                  oldest == null || message.id < oldest ? message.id : oldest,
            );
            messages.removeWhere(
              (id, _) =>
                  !returned.contains(id) &&
                  (!page.more ||
                      (oldestReturned != null && id >= oldestReturned)),
            );
          }
          for (final message in page.items) {
            messages[message.id] = message;
          }
          if (older || firstPage || historyGap || !page.more) {
            hasOlder = page.more;
          }
        });
      }
      if (received > readThrough &&
          mounted &&
          ModalRoute.of(context)?.isCurrent == true &&
          timer?.poller.active == true) {
        await api.readMessages(id, received);
        readThrough = received;
        if (mounted) unawaited(store!.refreshUnread());
      }
      return true;
    } on ApiFailure catch (failure) {
      if (mounted &&
          (initial || failure.status == 404 || failure.status == 403)) {
        setState(
          () => error = failure.status == 404
              ? 'Bu sohbet şu anda kullanılamıyor.'
              : failure.detail,
        );
      } else if (mounted && older) {
        toast(context, failure.detail);
      }
      return false;
    } finally {
      loading = false;
      if (mounted && older) setState(() => loadingOlder = false);
    }
  }

  void loadAtTop() {
    if (scroll.position.extentAfter < 150) unawaited(sync(older: true));
  }

  Future<void> chooseImage() async {
    try {
      final chosen = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 88,
      );
      if (mounted && chosen != null) {
        setState(() {
          image = chosen;
          attempt = null;
        });
      }
    } catch (_) {
      if (mounted) toast(context, 'Fotoğraf seçilemedi. Tekrar dene.');
    }
  }

  void send() {
    final current = chat;
    final body = text.text.trim();
    if (current == null ||
        !current.canSend ||
        (body.isEmpty && image == null) ||
        busy) {
      return;
    }
    final key = attempt ??= const Uuid().v4();
    runAccountAction(() async {
      try {
        final (next, message) = await api.send(current.peer, body, key, image);
        if (!mounted) return;
        text.clear();
        setState(() {
          chat = next;
          messages[message.id] = message;
          attempt = null;
          image = null;
          sendError = null;
        });
        store!.communicationChanged();
        if (scroll.hasClients) scroll.jumpTo(0);
      } on ApiFailure catch (failure) {
        if (mounted) setState(() => sendError = failure.detail);
      }
    });
  }

  void respond(bool accept) => runAccountAction(() async {
    final result = await api.respond(chat!.id!, accept);
    if (!mounted) return;
    setState(() => chat = result);
    store!.communicationChanged();
    if (!accept) Navigator.pop(context);
  });

  Future<void> option(String value, DirectConversation current) async {
    if (value == 'report') {
      await openPage(
        context,
        '/report',
        ReportTarget(
          'user',
          accountId(current.peer.id),
          '@${current.peer.handle}',
        ),
      );
    } else if (value == 'block') {
      if (!await confirmAction(
            context,
            title: 'Kullanıcı engellensin mi?',
            message: 'Bu kişiyle mesajlaşma durdurulacak.',
            action: 'Engelle',
          ) ||
          !mounted) {
        return;
      }
      runAccountAction(() async {
        await store!.setRemoteBlock(current.peer.id, true);
        if (mounted) Navigator.pop(context);
      });
    } else {
      runAccountAction(() async {
        await api.hide(current.id!);
        if (!mounted) return;
        store!.communicationChanged();
        Navigator.pop(context);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = chat;
    final sorted = messages.values.toList()
      ..sort((a, b) => b.id.compareTo(a.id));
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: current == null
            ? const Text('Sohbet')
            : InkWell(
                onTap: () => openPage(context, '/profile', current.peer.id),
                child: Row(
                  children: [
                    Avatar(current.peer, size: 36),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            current.peer.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            current.recentlyActive
                                ? 'Yakın zamanda aktif'
                                : '@${current.peer.handle}',
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
        actions: [
          if (current != null && error == null)
            PopupMenuButton<String>(
              tooltip: 'Sohbet seçenekleri',
              onSelected: (value) => option(value, current),
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'report', child: Text('Şikâyet Et')),
                const PopupMenuItem(value: 'block', child: Text('Engelle')),
                if (current.id != null)
                  const PopupMenuItem(
                    value: 'hide',
                    child: Text('Sohbeti Gizle'),
                  ),
              ],
            ),
        ],
      ),
      body: SafeArea(
        child: error != null
            ? SingleChildScrollView(
                child: EmptyState(
                  error!,
                  '',
                  action: SecondaryButton('Tekrar Dene', onPressed: sync),
                ),
              )
            : current == null
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  if (current.status == 'pending')
                    Container(
                      color: AppColors.pale,
                      padding: Space.page,
                      child: Column(
                        children: [
                          Text(
                            current.outgoing
                                ? 'Mesaj isteğin onay bekliyor.'
                                : 'Bu kişi seninle sohbet etmek istiyor.',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          if (!current.outgoing) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: SecondaryButton(
                                    'Reddet',
                                    onPressed: busy
                                        ? null
                                        : () => respond(false),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: PrimaryButton(
                                    'Kabul Et',
                                    icon: Icons.check,
                                    onPressed: busy
                                        ? null
                                        : () => respond(true),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  Expanded(
                    child: sorted.isEmpty
                        ? const SingleChildScrollView(
                            child: EmptyState(
                              'İlk merhabayı sen söyle.',
                              'Güzel bir sohbet burada başlayabilir.',
                              icon: Icons.waving_hand_outlined,
                            ),
                          )
                        : ListView.builder(
                            reverse: true,
                            controller: scroll,
                            padding: Space.page,
                            itemCount: sorted.length + (hasOlder ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == sorted.length) {
                                return Center(
                                  child: TextButton(
                                    onPressed: loadingOlder
                                        ? null
                                        : () => sync(older: true),
                                    child: Text(
                                      loadingOlder
                                          ? 'Yükleniyor…'
                                          : 'Önceki mesajları yükle',
                                    ),
                                  ),
                                );
                              }
                              final message = sorted[index];
                              final day = DateUtils.dateOnly(message.date);
                              final dayStart =
                                  index + 1 == sorted.length ||
                                  !DateUtils.isSameDay(
                                    day,
                                    sorted[index + 1].date,
                                  );
                              return Column(
                                children: [
                                  if (dayStart)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: Space.md,
                                      ),
                                      child: Text(
                                        DateUtils.isSameDay(day, DateTime.now())
                                            ? 'BUGÜN'
                                            : MaterialLocalizations.of(context)
                                                  .formatMediumDate(day),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.muted,
                                          letterSpacing: 1.5,
                                        ),
                                      ),
                                    ),
                                  _DirectBubble(
                                    message,
                                    onAction: () =>
                                        messageAction(current, message),
                                  ),
                                ],
                              );
                            },
                          ),
                  ),
                  if (sendError != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: InfoNote(sendError!),
                    ),
                  if (current.canSend)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                      child: Column(
                        children: [
                          if (image != null)
                            ListTile(
                              dense: true,
                              leading: const Icon(Icons.image_outlined),
                              title: const Text('Fotoğraf eklendi'),
                              trailing: IconButton(
                                tooltip: 'Fotoğrafı kaldır',
                                onPressed: busy
                                    ? null
                                    : () => setState(() {
                                        image = null;
                                        attempt = null;
                                      }),
                                icon: const Icon(Icons.close),
                              ),
                            ),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              IconButton(
                                tooltip: 'Fotoğraf ekle',
                                icon: const Icon(Icons.image_outlined),
                                onPressed: busy ? null : chooseImage,
                              ),
                              Expanded(
                                child: TextField(
                                  key: const Key('chat-input'),
                                  controller: text,
                                  enabled: !busy,
                                  minLines: 1,
                                  maxLines: 5,
                                  maxLength: 2000,
                                  onChanged: (_) => setState(() {
                                    attempt = null;
                                    sendError = null;
                                  }),
                                  decoration: const InputDecoration(
                                    hintText: 'Bir mesaj yaz…',
                                    counterText: '',
                                  ),
                                  onSubmitted: (_) => send(),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton.filled(
                                tooltip: 'Mesajı gönder',
                                onPressed:
                                    busy ||
                                        (text.text.trim().isEmpty &&
                                            image == null)
                                    ? null
                                    : send,
                                icon: busy
                                    ? const SizedBox.square(
                                        dimension: 17,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.send_rounded),
                              ),
                            ],
                          ),
                        ],
                      ),
                    )
                  else if (current.status != 'pending')
                    const Padding(
                      padding: Space.page,
                      child: InfoNote('Bu kişiye şu anda mesaj gönderemezsin.'),
                    ),
                ],
              ),
      ),
    );
  }

  Future<void> messageAction(
    DirectConversation current,
    DirectMessage message,
  ) async {
    final chosen = await showModalBottomSheet<bool>(
      context: context,
      builder: (context) => SafeArea(
        child: ListTile(
          leading: Icon(
            message.mine ? Icons.delete_outline : Icons.flag_outlined,
          ),
          title: Text(message.mine ? 'Benim için sil' : 'Mesajı Şikâyet Et'),
          onTap: () => Navigator.pop(context, true),
        ),
      ),
    );
    if (chosen != true || !mounted) return;
    if (!message.mine) {
      await openPage(
        context,
        '/report',
        ReportTarget('message', message.id, 'Mesaj'),
      );
    } else {
      runAccountAction(() async {
        await api.deleteMessage(current.id!, message.id);
        if (!mounted) return;
        setState(() => messages.remove(message.id));
        store!.communicationChanged();
      });
    }
  }
}

class _DirectBubble extends StatelessWidget {
  const _DirectBubble(this.message, {required this.onAction});
  final DirectMessage message;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final m = message;
    final color = m.mine ? Colors.white : AppColors.navy;
    return Align(
      alignment: m.mine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onAction,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * .76,
          ),
          margin: const EdgeInsets.only(bottom: Space.md),
          padding: const EdgeInsets.fromLTRB(14, 11, 14, 8),
          decoration: BoxDecoration(
            gradient: m.mine ? AppShape.blueGradient : null,
            color: m.mine ? null : AppColors.surfaceBlue,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(m.mine ? 16 : 4),
              bottomRight: Radius.circular(m.mine ? 4 : 16),
            ),
            border: m.mine ? null : Border.all(color: const Color(0xFFD6E4F7)),
            boxShadow: m.mine
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: .20),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (m.image.isNotEmpty)
                GestureDetector(
                  onTap: () => showMediaViewer(context, [m.image]),
                  child: ClipRRect(
                    borderRadius: AppShape.rounded,
                    child: Image.network(
                      m.image,
                      headers: StoreScope.of(context).mediaHeaders(m.image),
                      width: 210,
                      height: 170,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Text(
                        'Fotoğraf yüklenemedi.',
                        style: TextStyle(color: color),
                      ),
                    ),
                  ),
                ),
              if (m.body.isNotEmpty)
                Text(
                  m.body,
                  style: TextStyle(color: color, fontSize: 15, height: 1.45),
                ),
              const SizedBox(height: 5),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    MaterialLocalizations.of(context)
                        .formatTimeOfDay(TimeOfDay.fromDateTime(m.date)),
                    style: TextStyle(
                      color: color.withValues(alpha: .8),
                      fontSize: 11,
                    ),
                  ),
                  if (m.mine) ...[
                    const SizedBox(width: 4),
                    Tooltip(
                      message: m.read ? 'Okundu' : 'Gönderildi',
                      child: Icon(
                        m.read ? Icons.done_all : Icons.done,
                        size: 14,
                        color: color,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
