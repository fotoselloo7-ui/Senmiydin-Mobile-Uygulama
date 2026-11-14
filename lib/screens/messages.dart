import 'package:flutter/material.dart' hide Text;

import '../widgets/translated_text.dart';

import '../core/app_locale.dart';
import '../core/theme.dart';
import '../core/navigation.dart';
import '../data/app_store.dart';
import '../data/models.dart';
import '../widgets/common.dart';
import 'direct_chat.dart';

class MessagesContent extends StatefulWidget {
  const MessagesContent({super.key});
  @override
  State<MessagesContent> createState() => _MessagesContentState();
}

class _MessagesContentState extends State<MessagesContent> {
  // 0 = chats, 1 = requests.
  int tabIndex = 0;
  String query = '';
  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final text = context.l10n;
    final requestsTab = tabIndex == 1;
    final chats = store.conversations
        .where(
          (c) =>
              !store.blocked.contains(c.personId) &&
              c.request == requestsTab &&
              store
                  .person(c.personId)
                  .name
                  .toLowerCase()
                  .contains(query.toLowerCase()),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: Space.page,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      text.messagesTitle,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                  IconButton(
                    tooltip: text.messagesNew,
                    onPressed: () => openPage(
                      context,
                      store.connected ? '/message-recipient' : '/search',
                    ),
                    icon: const Icon(Icons.edit_square, color: AppColors.blue),
                  ),
                ],
              ),
              const SizedBox(height: Space.md),
              TextField(
                key: const Key('messages-search'),
                onChanged: (v) => setState(() => query = v),
                decoration: InputDecoration(
                  hintText: text.messagesSearchHint,
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                ),
              ),
              const SizedBox(height: Space.md),
              _MessageTabs(
                labels: [text.messagesTabChats, text.messagesTabRequests],
                selected: tabIndex,
                onChanged: (v) => setState(() => tabIndex = v),
              ),
            ],
          ),
        ),
        Expanded(
          child: store.connected
              ? DirectConversationList(requestsTab, query)
              : chats.isEmpty
              ? SingleChildScrollView(
                  child: EmptyState(
                    text.messagesEmptyTitle,
                    text.messagesEmptyBody,
                    icon: Icons.chat_bubble_outline,
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: chats.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, i) => MessageRow(chats[i]),
                ),
        ),
      ],
    );
  }
}

class MessageRow extends StatelessWidget {
  const MessageRow(this.conversation, {super.key});
  final Conversation conversation;
  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context),
        c = conversation,
        p = store.person(c.personId);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: Space.sm),
      leading: Avatar(p, size: 53),
      title: Row(
        children: [
          Expanded(
            child: Text(
              p.name,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          Text(
            c.messages.isEmpty ? '' : c.messages.last.time,
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ],
      ),
      subtitle: Text(
        c.messages.isEmpty ? 'Bir merhaba gönder.' : c.messages.last.text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: c.unread > 0 ? AppColors.navy : AppColors.muted,
          fontWeight: c.unread > 0 ? FontWeight.w700 : FontWeight.w400,
          fontSize: 13,
        ),
      ),
      trailing: c.unread == 0
          ? null
          : CircleAvatar(
              radius: 11,
              backgroundColor: AppColors.action,
              child: Text(
                '${c.unread}',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
      onTap: () {
        c.unread = 0;
        store.refresh();
        openPage(context, '/chat', p.id);
      },
    );
  }
}

class ChatPage extends StatefulWidget {
  const ChatPage(this.id, {super.key});
  final String id;
  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final text = TextEditingController(), scroll = ScrollController();
  bool ready = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!ready) {
      final c = StoreScope.of(context).conversation(widget.id);
      c.unread = 0;
      ready = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => goToEnd());
    }
  }

  @override
  void dispose() {
    text.dispose();
    scroll.dispose();
    super.dispose();
  }

  void goToEnd() {
    if (scroll.hasClients) {
      scroll.animateTo(
        scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    }
  }

  void send() {
    final store = StoreScope.of(context);
    if (text.text.trim().isEmpty) {
      return;
    }
    store.send(widget.id, text.text);
    text.clear();
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) => goToEnd());
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context),
        p = store.person(widget.id),
        chat = store.conversation(widget.id),
        blocked = store.blocked.contains(p.id);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: InkWell(
          onTap: () => openPage(context, '/profile', p.id),
          child: Row(
            children: [
              Avatar(p, size: 36),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const Text(
                      'Güzel bir sohbete yer aç.',
                      style: TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: tr('Sohbet seçenekleri'),
            onSelected: (v) async {
              if (v == 'report') {
                openPage(context, '/report', 'Sohbet @${p.handle}');
              } else if (blocked) {
                store.unblock(p.id);
              } else if (await confirmAction(
                context,
                title: tr('Kullanıcı engellensin mi?'),
                message: tr('Bu kişiyle mesajlaşma durdurulacak.'),
                action: 'Engelle',
              )) {
                store.block(p.id);
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'report', child: Text('Şikâyet Et')),
              PopupMenuItem(
                value: 'block',
                child: Text(blocked ? 'Engeli Kaldır' : 'Engelle'),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (chat.request)
              Container(
                color: AppColors.pale,
                padding: Space.page,
                child: Column(
                  children: [
                    const Text(
                      'Bu kişi seninle sohbet etmek istiyor.',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: SecondaryButton(
                            'Reddet',
                            onPressed: () {
                              store.conversations.remove(chat);
                              store.refresh();
                              Navigator.pop(context);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: PrimaryButton(
                            'Kabul Et',
                            icon: Icons.check,
                            onPressed: () {
                              chat.request = false;
                              store.refresh();
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            Expanded(
              child: ListView(
                controller: scroll,
                padding: Space.page,
                children: [
                  const Center(
                    child: Text(
                      'BUGÜN',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: Space.xl),
                  if (chat.messages.isEmpty)
                    const EmptyState(
                      'İlk merhabayı sen söyle.',
                      'Güzel bir sohbet burada başlayabilir.',
                      icon: Icons.waving_hand_outlined,
                    ),
                  ...chat.messages.map(
                    (m) => Align(
                      alignment: m.mine
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.sizeOf(context).width * .76,
                        ),
                        margin: const EdgeInsets.only(bottom: Space.md),
                        padding: const EdgeInsets.fromLTRB(14, 11, 14, 8),
                        decoration: BoxDecoration(
                          color: m.mine ? AppColors.blue : AppColors.pale,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft: Radius.circular(m.mine ? 16 : 4),
                            bottomRight: Radius.circular(m.mine ? 4 : 16),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              m.text,
                              style: TextStyle(
                                color: m.mine ? Colors.white : AppColors.navy,
                                fontSize: 14,
                                height: 1.45,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  m.time,
                                  style: TextStyle(
                                    color: m.mine
                                        ? Colors.white70
                                        : AppColors.muted,
                                    fontSize: 11,
                                  ),
                                ),
                                if (m.mine) ...[
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.done_all,
                                    color: Colors.white70,
                                    size: 14,
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (blocked)
              const Padding(
                padding: Space.page,
                child: InfoNote(
                  'Bu kullanıcı engellendi. Mesaj göndermek için engeli kaldır.',
                ),
              )
            else if (!chat.request)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        key: const Key('chat-input'),
                        controller: text,
                        minLines: 1,
                        maxLines: 5,
                        maxLength: 2000,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: tr('Bir mesaj yaz…'),
                          counterText: '',
                        ),
                        onSubmitted: (_) => send(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      tooltip: tr('Mesajı gönder'),
                      onPressed: text.text.trim().isEmpty ? null : send,
                      icon: const Icon(Icons.send_rounded),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class SharePage extends StatelessWidget {
  const SharePage(this.postId, {super.key});
  final String postId;
  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return AppPage(
      title: tr('Mesajla Gönder'),
      child: ListView(
        padding: Space.page,
        children: [
          const InfoNote('Paylaşımı göndermek istediğin kişiyi seç.'),
          const SizedBox(height: 12),
          ...store.people
              .where(
                (p) => p.id != store.me.id && !store.blocked.contains(p.id),
              )
              .map(
                (p) => UserRow(
                  p,
                  trailing: const Icon(
                    Icons.send_outlined,
                    color: AppColors.blue,
                  ),
                  onTap: () {
                    store.send(
                      p.id,
                      trf('Bu paylaşımı seninle paylaşmak istedim:\n\n{0}', [store.post(postId).text]),
                    );
                    Navigator.pushReplacementNamed(
                      context,
                      '/chat',
                      arguments: p.id,
                    );
                  },
                ),
              ),
        ],
      ),
    );
  }
}

/// Two equal tabs ("Sohbetler" / "İstekler") in one soft container: a clear, balanced split instead of loose pills.
class _MessageTabs extends StatelessWidget {
  const _MessageTabs({
    required this.labels,
    required this.selected,
    required this.onChanged,
  });
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: AppColors.surfaceBlue,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFD6E4F7)),
    ),
    child: Row(
      children: [
        for (final (i, label) in labels.indexed)
          Expanded(
            child: Semantics(
              button: true,
              selected: i == selected,
              child: InkWell(
                key: ValueKey('messages-tab-$i'),
                borderRadius: BorderRadius.circular(11),
                onTap: () => onChanged(i),
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: i == selected
                        ? AppColors.action
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                      color: i == selected ? Colors.white : AppColors.navy,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
