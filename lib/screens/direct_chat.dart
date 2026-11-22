import '../core/polling.dart';

import 'dart:async';

import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart' show SystemChannels;

import '../widgets/translated_text.dart';

import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import 'package:geolocator/geolocator.dart' show LocationPermission;
import 'package:latlong2/latlong.dart';

import '../core/app_locale.dart';
import '../core/chat_theme.dart';
import '../core/navigation.dart';
import '../core/theme.dart';
import '../data/account_api.dart';
import '../data/app_store.dart';
import '../data/communication_api.dart';
import '../data/gifts.dart';
import '../data/voice_service.dart';
import '../data/social_api.dart';
import '../data/location_service.dart';
import '../data/models.dart';
import '../widgets/account_action.dart';
import '../widgets/chat_composer.dart';
import '../widgets/chat_theme_sheet.dart';
import '../widgets/common.dart';
import '../widgets/emoji_panel.dart';
import '../widgets/gift_ui.dart';
import '../widgets/media_viewer.dart';
import '../widgets/social_page.dart';
import '../widgets/voice_ui.dart';

class DirectConversationList extends StatelessWidget {
  const DirectConversationList(this.requests, this.query, {super.key});
  final bool requests;
  final String query;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final text = context.l10n;
    return PagedContent<DirectConversation>(
      key: ValueKey((requests, query, store.communicationVersion)),
      fetch: (page) =>
          store.communication!.conversations(page, requests, query),
      id: (item) => item.id.toString(),
      builder: (context, items, footer, refresh) => RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: Space.xl),
          children: [
            if (items.isEmpty && footer == null)
              EmptyState(
                text.messagesEmptyTitle,
                text.messagesEmptyBody,
                icon: Icons.chat_bubble_outline,
              ),
            for (final chat in items)
              ConversationTile(
                key: ValueKey(('conversation', chat.id)),
                peer: chat.peer,
                online: chat.recentlyActive,
                unread: chat.unread,
                last: chat.last,
                note: requests
                    ? (chat.outgoing
                          ? text.messagesRequestPending
                          : text.messagesRequestIncoming)
                    : null,
                onTap: () =>
                    openPage(context, '/conversation', chat.id.toString()),
              ),
            ?footer,
          ],
        ),
      ),
    );
  }
}

/// One conversation row: avatar, name, last message (with a photo / location glyph), time and unread badge.
/// Online dots are only ever shown from real recent activity; there is no invented presence.
class ConversationTile extends StatelessWidget {
  const ConversationTile({
    super.key,
    required this.peer,
    required this.unread,
    required this.last,
    required this.onTap,
    this.online = false,
    this.note,
  });
  final Person peer;
  final int unread;
  final DirectMessage? last;
  final VoidCallback onTap;
  final bool online;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final text = context.l10n;
    final unreadRow = unread > 0;
    final line = last == null ? text.messagesSayHi : last!.preview;
    // A request row says so in the same line ("Gelen istek · mesaj"), as one readable string.
    final preview = note == null ? line : '$note · $line';
    final glyph = switch (last?.type) {
      'image' => Icons.image_outlined,
      'location' => Icons.location_on_outlined,
      'voice' => Icons.mic_none_rounded,
      'gift' => Icons.card_giftcard_rounded,
      _ => null,
    };
    return Material(
      color: unreadRow ? const Color(0xFFF3F6FF) : Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 76),
          padding: const EdgeInsets.symmetric(
            horizontal: Space.lg,
            vertical: 11,
          ),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFEEF3F9))),
          ),
          child: Row(
            children: [
              Avatar(peer, size: 54, online: online),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            peer.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: unreadRow
                                  ? FontWeight.w800
                                  : FontWeight.w700,
                              fontSize: 15.5,
                              color: AppColors.navy,
                            ),
                          ),
                        ),
                        if (last case final message?)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Text(
                              socialTime(message.date.toIso8601String()),
                              style: TextStyle(
                                color: unreadRow
                                    ? AppColors.blue
                                    : AppColors.muted,
                                fontSize: 12,
                                fontWeight: unreadRow
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (glyph != null)
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Icon(
                              glyph,
                              size: 16,
                              color: unreadRow
                                  ? AppColors.navy
                                  : AppColors.muted,
                            ),
                          ),
                        Expanded(
                          child: Text(
                            preview,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: unreadRow
                                  ? AppColors.navy
                                  : AppColors.muted,
                              fontWeight: unreadRow
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              fontSize: 13.5,
                            ),
                          ),
                        ),
                        if (unreadRow)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Badge(
                              label: Text('$unread'),
                              backgroundColor: AppColors.action,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
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
  final inputFocus = FocusNode();
  late final recorder = VoiceRecordingController();
  late final playback = VoicePlayback();
  bool emojiOpen = false;
  String? voiceKey;
  List<GiftItem>? giftCache;
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
    store!.chatTheme.addListener(onThemeChanged);
    unawaited(store!.chatTheme.ensureLoaded(store!.me.id.toString()));

    scroll.addListener(loadAtTop);
    // Opening the keyboard (focusing the input) closes the emoji panel so the two never share the screen.
    inputFocus.addListener(() {
      if (inputFocus.hasFocus && emojiOpen && mounted) {
        setState(() => emojiOpen = false);
      }
    });
    recorder.addListener(() {
      if (mounted) setState(() {});
    });
    timer = RoutePolling(
      interval: const Duration(seconds: 4),
      maxBackoff: const Duration(seconds: 16),
      fetch: sync,
    );
    timer!.attach(context);
  }

  void onThemeChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    store?.chatTheme.removeListener(onThemeChanged);
    timer?.dispose();
    scroll.dispose();
    text.dispose();
    inputFocus.dispose();
    // Leaving the conversation stops any playback, deletes the downloaded voice files and drops an unsent recording.
    playback.dispose();
    recorder.dispose();
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

  Future<void> chooseImage([ImageSource source = ImageSource.gallery]) async {
    try {
      final chosen = await picker.pickImage(
        source: source,
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

  Future<void> attach() async {
    closeEmoji();
    final choice = await showChatAttachmentSheet(context);
    if (!mounted || choice == null) return;
    switch (choice) {
      case ChatAttachment.photo:
        await chooseImage();
      case ChatAttachment.camera:
        await chooseImage(ImageSource.camera);
      case ChatAttachment.location:
        await chooseLocation();
      case ChatAttachment.gift:
        await chooseGift();
    }
  }

  // ------------------------------------------------------------------------------------------------ gifts

  Future<void> chooseGift() async {
    final current = chat;
    if (current == null || !current.canSend || busy) return;
    final gift = await showGiftSheet(
      context,
      () async => giftCache ??= await api.gifts(),
    );
    if (!mounted || gift == null) return;
    sendGift(gift);
  }

  void sendGift(GiftItem gift) {
    final current = chat;
    if (current == null || !current.canSend || busy) return;
    final key = const Uuid().v4();
    runAccountAction(() async {
      try {
        final (next, message) = await api.send(
          current.peer,
          '',
          key,
          null,
          gift: gift.slug,
        );
        if (!mounted) return;
        setState(() {
          chat = next;
          messages[message.id] = message;
          sendError = null;
        });
        store!.communicationChanged();
        unawaited(store!.noteMeaningfulAction());
        if (scroll.hasClients) scroll.jumpTo(0);
      } on ApiFailure catch (failure) {
        if (mounted) setState(() => sendError = failure.detail);
      }
    });
  }

  // ------------------------------------------------------------------------------------------------ voice

  Future<void> startVoice() async {
    final current = chat;
    if (current == null ||
        !current.canSend ||
        busy ||
        recorder.phase != VoiceRecordingPhase.idle) {
      return;
    }
    closeEmoji();
    if (VoiceServices.denied) {
      toast(
        context,
        tr(
          'Mikrofon izni kapalı. Sesli mesaj için Ayarlar\'dan mikrofona izin verebilirsin.',
        ),
      );
      return;
    }
    if (!VoiceServices.explained) {
      final agreed = await showMicrophoneExplanation(context);
      if (!mounted || !agreed) return;
      VoiceServices.explained = true;
    }
    final granted = await recorder.requestPermission();
    if (!mounted) return;
    if (!granted) {
      // One explanation, one system prompt: a refusal is remembered for this session, never asked in a loop.
      VoiceServices.denied = true;
      toast(
        context,
        tr(
          'Mikrofon izni verilmedi. Sesli mesaj için Ayarlar\'dan izin verebilirsin.',
        ),
      );
      return;
    }
    if (!await recorder.start() && mounted) {
      toast(context, tr('Kayıt başlatılamadı. Tekrar dene.'));
    }
  }

  Future<void> stopVoice() async {
    final kept = await recorder.stop();
    if (!kept && mounted) {
      toast(context, tr('Kayıt çok kısaydı, gönderilmedi.'));
    }
  }

  void sendVoice() {
    final current = chat;
    final path = recorder.path;
    if (current == null ||
        !current.canSend ||
        busy ||
        path == null ||
        !recorder.hasPreview) {
      return;
    }
    final key = voiceKey ??= const Uuid().v4();
    runAccountAction(() async {
      try {
        await playback.stopAll();
        final (next, message) = await api.send(
          current.peer,
          '',
          key,
          null,
          voice: XFile(path),
        );
        if (!mounted) return;
        await recorder.finish();
        setState(() {
          chat = next;
          messages[message.id] = message;
          voiceKey = null;
          sendError = null;
        });
        store!.communicationChanged();
        unawaited(store!.noteMeaningfulAction());
        if (scroll.hasClients) scroll.jumpTo(0);
      } on ApiFailure catch (failure) {
        // The recording stays in the preview so the same request can be retried.
        if (mounted) setState(() => sendError = failure.detail);
      }
    });
  }

  Future<void> toggleVoice(DirectMessage message) => playback.toggle(
    message.id,
    () => VoiceServices.download(
      message.audio,
      StoreScope.of(context).mediaHeaders(message.audio),
    ),
  );

  // ------------------------------------------------------------------------------------------------ emoji panel

  void closeEmoji() {
    if (emojiOpen) setState(() => emojiOpen = false);
  }

  /// A tap on the conversation (or the empty area): closes the panel and the keyboard.
  void dismissPanels() {
    closeEmoji();
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void toggleEmoji() {
    if (emojiOpen) {
      // Back to the system keyboard (its own emoji keyboard stays available there).
      setState(() => emojiOpen = false);
      inputFocus.requestFocus();
      return;
    }
    // Hide the keyboard first so the panel and the keyboard never take space together.
    FocusManager.instance.primaryFocus?.unfocus();
    SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    setState(() => emojiOpen = true);
  }

  void onEmoji(String emoji) {
    insertAtCursor(text, emoji);
    setState(() {
      attempt = null;
      sendError = null;
    });
  }

  void onEmojiBackspace() {
    deleteBeforeCursor(text);
    setState(() {
      attempt = null;
      sendError = null;
    });
  }

  /// A private, approximate location message: the device point (or a picked one) goes to the server, which snaps it.
  Future<void> chooseLocation() async {
    final source = await showChatLocationSourceSheet(context);
    if (!mounted || source == null) return;
    LatLng? point;
    if (source == ChatLocationSource.map) {
      point = await Navigator.of(context).push<LatLng>(
        MaterialPageRoute(builder: (_) => const PickLocationPage()),
      );
    } else {
      point = await deviceLocation();
    }
    if (!mounted || point == null) return;
    sendLocation(point);
  }

  Future<LatLng?> deviceLocation() async {
    const device = LocationDevice();
    try {
      if (!await device.enabled()) {
        if (mounted) toast(context, DeviceLocationState.disabled.message);
        return null;
      }
      var permission = await device.permission();
      if (permission == LocationPermission.denied) {
        permission = await device.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) toast(context, DeviceLocationState.denied.message);
        return null;
      }
      // The first GPS fix can take several seconds: say so instead of staying silent.
      if (mounted) toast(context, tr('Konum alınıyor…'));
      final position = await device.current();
      return LatLng(position.latitude, position.longitude);
    } catch (_) {
      if (mounted) toast(context, DeviceLocationState.unavailable.message);
      return null;
    }
  }

  void sendLocation(LatLng point) {
    final current = chat;
    if (current == null || !current.canSend || busy) return;
    final key = const Uuid().v4();
    runAccountAction(() async {
      try {
        final (next, message) = await api.send(
          current.peer,
          '',
          key,
          null,
          location: (
            latitude: point.latitude,
            longitude: point.longitude,
            label: null,
          ),
        );
        if (!mounted) return;
        setState(() {
          chat = next;
          messages[message.id] = message;
          sendError = null;
        });
        store!.communicationChanged();
        unawaited(store!.noteMeaningfulAction());
        if (scroll.hasClients) scroll.jumpTo(0);
      } on ApiFailure catch (failure) {
        if (mounted) setState(() => sendError = failure.detail);
      }
    });
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
        unawaited(store!.noteMeaningfulAction());
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
            title: tr('Kullanıcı engellensin mi?'),
            message: tr('Bu kişiyle mesajlaşma durdurulacak.'),
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
    return PopScope(
      // Android back first closes the emoji panel / drops a recording; only then does it leave the conversation.
      canPop: !emojiOpen && recorder.phase == VoiceRecordingPhase.idle,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (emojiOpen) {
          closeEmoji();
        } else if (recorder.phase != VoiceRecordingPhase.idle) {
          unawaited(recorder.discard());
        }
      },
      child: Scaffold(
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
                tooltip: tr('Sohbet seçenekleri'),
                onSelected: (value) => value == 'theme'
                    ? showChatThemeSheet(context)
                    : option(value, current),
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    key: Key('chat-theme-menu'),
                    value: 'theme',
                    child: Text('Sohbet Teması'),
                  ),
                  const PopupMenuItem(
                    value: 'report',
                    child: Text('Şikâyet Et'),
                  ),
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
        body: ChatBackdropView(
          theme: store!.chatTheme.theme,
          child: SafeArea(
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
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
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
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onTap: dismissPanels,
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
                                    final day = DateUtils.dateOnly(
                                      message.date,
                                    );
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
                                            child: ChatDayPill(
                                              DateUtils.isSameDay(
                                                    day,
                                                    DateTime.now(),
                                                  )
                                                  ? 'BUGÜN'
                                                  : MaterialLocalizations.of(
                                                      context,
                                                    ).formatMediumDate(day),
                                            ),
                                          ),
                                        _DirectBubble(
                                          theme: store!.chatTheme.theme,
                                          message,
                                          onAction: () =>
                                              messageAction(current, message),
                                          playback: playback,
                                          onPlay: () => toggleVoice(message),
                                          peerName: current.peer.name,
                                        ),
                                      ],
                                    );
                                  },
                                ),
                        ),
                      ),
                      if (sendError != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: InfoNote(sendError!),
                        ),
                      if (current.canSend) ...[
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            12,
                            8,
                            12,
                            emojiOpen ? 6 : 12,
                          ),
                          child: Column(
                            children: [
                              if (image != null &&
                                  recorder.phase == VoiceRecordingPhase.idle)
                                PendingPhoto(
                                  file: image!,
                                  label: tr('Fotoğraf eklendi'),
                                  removeTooltip: tr('Fotoğrafı kaldır'),
                                  onRemove: busy
                                      ? null
                                      : () => setState(() {
                                          image = null;
                                          attempt = null;
                                        }),
                                ),
                              if (recorder.phase != VoiceRecordingPhase.idle)
                                VoiceDraftBar(
                                  recorder: recorder,
                                  playback: playback,
                                  onSend: sendVoice,
                                  onStop: stopVoice,
                                  busy: busy,
                                )
                              else
                                ChatComposerBar(
                                  controller: text,
                                  focusNode: inputFocus,
                                  emojiOpen: emojiOpen,
                                  busy: busy,
                                  canSend:
                                      text.text.trim().isNotEmpty ||
                                      image != null,
                                  onAttach: attach,
                                  onEmoji: toggleEmoji,
                                  onSend: send,
                                  onMic: startVoice,
                                  onChanged: () => setState(() {
                                    attempt = null;
                                    sendError = null;
                                  }),
                                ),
                            ],
                          ),
                        ),
                        if (emojiOpen &&
                            recorder.phase == VoiceRecordingPhase.idle)
                          EmojiPanel(
                            onEmoji: onEmoji,
                            onBackspace: onEmojiBackspace,
                          ),
                      ] else if (current.status != 'pending')
                        const Padding(
                          padding: Space.page,
                          child: InfoNote(
                            'Bu kişiye şu anda mesaj gönderemezsin.',
                          ),
                        ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Future<void> messageAction(
    DirectConversation current,
    DirectMessage message,
  ) async {
    final chosen = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const Key('message-delete-me'),
              leading: const Icon(Icons.delete_outline),
              title: Text(tr('Benim için sil')),
              onTap: () => Navigator.pop(context, 'me'),
            ),
            if (message.mine)
              ListTile(
                key: const Key('message-delete-everyone'),
                leading: const Icon(
                  Icons.undo_rounded,
                  color: Color(0xFFD92D20),
                ),
                title: Text(
                  tr('Herkesten sil'),
                  style: const TextStyle(color: Color(0xFFD92D20)),
                ),
                subtitle: Text(tr('Karşı taraf bu mesajı artık görmez.')),
                onTap: () => Navigator.pop(context, 'everyone'),
              )
            else
              ListTile(
                key: const Key('message-report'),
                leading: const Icon(Icons.flag_outlined),
                title: Text(tr('Mesajı Şikâyet Et')),
                onTap: () => Navigator.pop(context, 'report'),
              ),
          ],
        ),
      ),
    );
    if (chosen == null || !mounted) return;
    if (chosen == 'report') {
      await openPage(
        context,
        '/report',
        ReportTarget('message', message.id, 'Mesaj'),
      );
      return;
    }
    runAccountAction(() async {
      await api.deleteMessage(
        current.id!,
        message.id,
        everyone: chosen == 'everyone',
      );
      if (!mounted) return;
      setState(() => messages.remove(message.id));
      store!.communicationChanged();
    });
  }
}

class _DirectBubble extends StatelessWidget {
  const _DirectBubble(
    this.message, {
    required this.onAction,
    required this.playback,
    required this.onPlay,
    required this.peerName,
    required this.theme,
  });
  final DirectMessage message;
  final VoidCallback onAction, onPlay;
  final VoicePlayback playback;
  final String peerName;
  final ChatTheme theme;

  @override
  Widget build(BuildContext context) {
    final m = message;
    final color = theme.textFor(mine: m.mine);
    return Align(
      alignment: m.mine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onAction,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * .76,
          ),
          child: Padding(
            padding: const EdgeInsets.only(bottom: Space.md),
            child: ChatBubbleSurface(
              mine: m.mine,
              theme: theme,
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
                  if (m.isLocation) _LocationCard(m, color: color),
                  if (m.isVoice)
                    VoiceBubbleBody(
                      messageId: m.id,
                      duration: Duration(milliseconds: m.durationMs),
                      color: color,
                      playback: playback,
                      onToggle: onPlay,
                    ),
                  if (m.isGift)
                    GiftBubbleBody(
                      gift: m.gift!,
                      mine: m.mine,
                      senderName: peerName,
                      color: color,
                    ),
                  // A message type this version does not know shows a neutral line instead of an empty bubble.
                  if (!m.isVoice &&
                      !m.isGift &&
                      !m.isLocation &&
                      m.image.isEmpty &&
                      m.body.isEmpty)
                    Text(
                      tr('Bu mesaj türü bu sürümde gösterilemiyor.'),
                      style: TextStyle(color: color, fontSize: 14),
                    ),
                  if (m.body.isNotEmpty)
                    Text(
                      m.body,
                      style: TextStyle(
                        color: color,
                        fontSize: 15,
                        height: 1.45,
                      ),
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
        ),
      ),
    );
  }
}

/// Location message bubble: pin, "Konum", approximate area and "Haritada Aç" (opens the app map on that point).
class _LocationCard extends StatelessWidget {
  const _LocationCard(this.message, {required this.color});
  final DirectMessage message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final text = context.l10n;
    final label = (message.placeLabel ?? '').trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.location_on_rounded, color: color, size: 22),
              const SizedBox(width: 6),
              Text(
                text.chatLocationTitle,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2, left: 28),
            child: Text(
              label.isEmpty
                  ? text.chatLocationApprox
                  : '${text.chatLocationApprox} · $label',
              style: TextStyle(
                color: color.withValues(alpha: .85),
                fontSize: 12.5,
              ),
            ),
          ),
          const SizedBox(height: 6),
          TextButton.icon(
            key: const Key('open-location-on-map'),
            style: TextButton.styleFrom(
              foregroundColor: color,
              backgroundColor: color.withValues(alpha: .14),
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () {
              StoreScope.of(context).mapFocus = LatLng(
                message.latitude!,
                message.longitude!,
              );
              openPage(context, '/map');
            },
            icon: const Icon(Icons.map_outlined, size: 18),
            label: Text(text.chatOpenOnMap),
          ),
        ],
      ),
    );
  }
}
