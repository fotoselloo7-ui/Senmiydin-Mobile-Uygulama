import 'core/app_locale.dart';
import 'core/polling.dart';

import 'dart:async';

import 'package:flutter/material.dart' hide Text;

import 'widgets/translated_text.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/theme.dart';
import 'data/account_api.dart';
import 'data/app_store.dart';
import 'data/deep_links.dart';
import 'data/communication_api.dart';
import 'data/encounter_api.dart';
import 'data/models.dart';
import 'widgets/common.dart';
import 'widgets/app_availability.dart';
import 'screens/auth.dart';
import 'screens/home.dart';
import 'screens/discovery.dart';
import 'screens/compose.dart';
import 'screens/post.dart';
import 'screens/profile.dart';
import 'screens/map_notes.dart';
import 'screens/messages.dart';
import 'screens/direct_chat.dart';
import 'screens/live_notifications.dart';
import 'screens/notifications.dart';
import 'screens/settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppLocale.init();
  if (kReleaseMode) {
    ErrorWidget.builder = (_) => const ColoredBox(
      color: Colors.white,
      child: Center(
        child: Text(
          'Bir sorun oluştu. Uygulamayı yeniden açabilirsin.',
          textDirection: TextDirection.ltr,
          style: TextStyle(color: Colors.black, fontSize: 16),
        ),
      ),
    );
  }
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'Nunito Sans',
    ], await rootBundle.loadString('assets/fonts/OFL.txt'));
  });
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const SenMiydinApp());
}

class SenMiydinApp extends StatefulWidget {
  const SenMiydinApp({super.key, this.store, this.initialRoute = '/'});
  final AppStore? store;
  final String initialRoute;
  @override
  State<SenMiydinApp> createState() => _SenMiydinAppState();
}

class _SenMiydinAppState extends State<SenMiydinApp> {
  late final AppStore store = widget.store ?? AppStore(api: ApiClient());
  late bool _signedIn;
  int _sessionVersion = 0;
  var _navigator = GlobalKey<NavigatorState>();
  var _messenger = GlobalKey<ScaffoldMessengerState>();

  Future<void> openPush(int id) async {
    final user = store.account?.id;
    if (user == null) return;
    try {
      final item = await store.communication!.notification(id);
      if (store.account?.id != user) return;
      if (!item.read) await store.communication!.readNotification(id);
      if (!mounted || store.account?.id != user) return;
      store.communicationChanged();
      final navigator = _navigator.currentState;
      if (navigator != null) unawaited(routeInboxNotification(navigator, item));
    } on ApiFailure {
      // The item may have been removed or become unavailable.
    }
  }

  DeepLinks? _deepLinks;
  ShareLink? _pendingLink, _lastLink;
  DateTime? _lastLinkAt;

  /// A shared link was opened: once the person is signed in, resolve it and open the post / letter inside the app.
  void openShareLink(ShareLink link) {
    // The same link arrives twice (as a route and from app_links): open it once.
    final now = DateTime.now();
    if (link == _lastLink &&
        _lastLinkAt != null &&
        now.difference(_lastLinkAt!) < const Duration(seconds: 4)) {
      return;
    }
    _lastLink = link;
    _lastLinkAt = now;
    _pendingLink = link;
    unawaited(_openPendingLink());
  }

  Future<void> _openPendingLink() async {
    final link = _pendingLink;
    if (link == null || !store.connected || !store.authenticated) return;
    final navigator = _navigator.currentState;
    if (navigator == null) return;
    _pendingLink = null;
    final user = store.account?.id;
    try {
      final target = await store.resolveShareLink(link.publicId);
      if (!mounted || store.account?.id != user) return;
      if (target == null) {
        _messenger.currentState?.showSnackBar(
          SnackBar(content: Text(tr('Bu içerik artık kullanılamıyor.'))),
        );
        return;
      }
      final (type, id) = target;
      unawaited(
        navigator.pushNamed(
          type == 'map_note' ? '/map-note' : '/post',
          arguments: type == 'map_note' ? id : '$id',
        ),
      );
    } on ApiFailure {
      // Offline or a server error: the person can open the link again.
    }
  }

  @override
  void initState() {
    super.initState();
    _signedIn = store.authenticated;
    if (store.connected) {
      _deepLinks = DeepLinks(onLink: openShareLink);
      unawaited(_deepLinks!.start());
    }
    store.push?.onOpen = (id) => unawaited(openPush(id));
    store.push?.onForeground = (id) {
      unawaited(store.refreshUnread());
      _messenger.currentState?.showSnackBar(
        SnackBar(
          content: const Text('Yeni bir SenMiydin? bildirimin var.'),
          action: SnackBarAction(
            label: tr('Gör'),
            onPressed: () => unawaited(openPush(id)),
          ),
        ),
      );
    };
    if (store.connected) store.addListener(_sessionChanged);
  }

  void _sessionChanged() {
    final ended = _signedIn && !store.authenticated;
    final started = !_signedIn && store.authenticated;
    _signedIn = store.authenticated;
    if (started) unawaited(_openPendingLink());
    if (ended) {
      setState(() {
        _sessionVersion++;
        // Retaining a Navigator GlobalKey would also retain the authenticated route stack.
        _navigator = GlobalKey<NavigatorState>();
        _messenger = GlobalKey<ScaffoldMessengerState>();
      });
    }
  }

  @override
  void dispose() {
    unawaited(_deepLinks?.dispose());
    store.push
      ?..onOpen = null
      ..onForeground = null;
    store.removeListener(_sessionChanged);
    if (widget.store == null) {
      store.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => StoreScope(
    store: store,
    child: ValueListenableBuilder<Locale>(
      valueListenable: AppLocale.notifier,
      builder: (context, locale, _) => MaterialApp(
        key: ValueKey(_sessionVersion),
        navigatorKey: _navigator,
        navigatorObservers: [pollingRoutes],
        scaffoldMessengerKey: _messenger,
        builder: (context, child) => AppAvailability(
          store: store,
          child: child ?? const SizedBox.shrink(),
        ),
        title: 'SenMiydin?',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        locale: locale,
        supportedLocales: AppLocale.supported,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        initialRoute: _sessionVersion > 0
            ? '/login'
            : store.connected
            ? '/'
            : widget.initialRoute,
        onGenerateInitialRoutes: (route) => [
          buildRoute(RouteSettings(name: route)),
        ],
        onGenerateRoute: buildRoute,
      ),
    ),
  );

  Route<dynamic> buildRoute(RouteSettings settings) {
    final arg = settings.arguments;
    const publicRoutes = {
      '/',
      '/welcome',
      '/register',
      '/login',
      '/forgot',
      '/reset-password',
      '/social',
      '/legal',
    };
    if (store.connected &&
        !store.authenticated &&
        !publicRoutes.contains(settings.name)) {
      return MaterialPageRoute<dynamic>(
        settings: settings,
        builder: (_) => const AuthPage(),
      );
    }
    const entryRoutes = {
      '/register',
      '/login',
      '/forgot',
      '/reset-password',
      '/social',
    };
    if (store.connected &&
        store.authenticated &&
        entryRoutes.contains(settings.name)) {
      return buildRoute(RouteSettings(name: store.accountRoute));
    }
    // Android hands a tapped share link to Flutter as a route name (`/p/<id>`) as well as to app_links. It is not a real
    // page: the landing route closes itself at once and the link is opened through the one shared path below.
    final linked = parseShareLink(
      Uri(
        scheme: 'https',
        host: shareLinkHosts().first,
        path: settings.name ?? '',
      ),
    );
    if (linked != null) {
      return MaterialPageRoute<dynamic>(
        settings: settings,
        builder: (_) => _ShareLinkLanding(onReady: () => openShareLink(linked)),
      );
    }
    final Widget page = switch (settings.name) {
      '/' => const SplashPage(),
      '/welcome' => const WelcomePage(),
      '/register' => const AuthPage(register: true),
      '/login' => const AuthPage(),
      '/forgot' => const ForgotPage(),
      '/reset-password' => PasswordPage(resetEmail: arg as String? ?? ''),
      '/change-password' => const PasswordPage(),
      '/social' => SocialLoginPage(arg as String? ?? 'Google'),
      '/complete' => const CompleteProfilePage(),
      '/interests' => InterestsPage(
        setup:
            arg == true ||
            (store.connected && store.account?.onboardingStep == 1),
      ),
      '/permissions' => const PermissionsPage(),
      '/home' => const HomeShell(),
      '/map' => AppPage(title: tr('Harita'), child: MapContent()),
      '/nearby' => const NearbyPage(),
      '/search' => const SearchPage(),
      '/tag' => const SearchPage(tag: true),
      '/message-recipient' => SearchPage(
        messageRecipient: true,
        sharedPost: arg as String?,
      ),
      '/filters' => const FilterPage(),
      '/compose' => ComposePage(media: arg as String?),
      '/camera' => const DemoCameraPage(),
      '/encounter' => EncounterPage(arg as String),
      '/encounter-story' => ComposePage(storyFor: arg as EncounterEntry),
      '/encounter-story-edit' => ComposePage(
        storyFor: arg as EncounterEntry,
        reviseStory: true,
      ),
      '/encounters' => EncountersPage(
        initial: arg as EncounterStatus? ?? EncounterStatus.pending,
      ),
      '/featured' => const EncountersPage(featured: true),
      '/post' => PostDetailPage(arg as String),
      '/map-notes' => switch (arg) {
        (String group, int _) => MapNotePointPage(group),
        (String group, String label) => MapNotePointPage(group, label: label),
        _ => MapNotePointPage(arg as String),
      },
      '/map-note' => MapNoteDetailPage(int.parse('$arg')),
      '/my-letters' => const MyLettersPage(),
      '/my-letter' => MapNoteDetailPage(int.parse('$arg'), mine: true),
      '/map-note-compose' => switch (arg) {
        (LatLng center, double zoom) => MapNoteComposePage(
          center: center,
          zoom: zoom,
        ),
        _ => const MapNoteComposePage(),
      },
      // Legacy / notification route: no separate Yorumlar page any more, the post opens with its comments sheet.
      '/comments' => PostDetailPage(arg as String, openComments: true),
      '/profile' => ProfilePage(arg as String? ?? store.me.id),
      '/edit-profile' => const CompleteProfilePage(edit: true),
      '/people' => switch (arg) {
        (String title, String username) => PeoplePage(
          title,
          username: username,
        ),
        _ => PeoplePage(arg as String? ?? 'İnsanlar'),
      },
      '/saved' => const SavedPage(),
      '/notifications' =>
        store.connected
            ? const LiveNotificationsPage()
            : const NotificationsPage(),
      '/messages' => AppPage(
        title: tr('Mesajlar'),
        compactHeader: true,
        child: MessagesContent(),
      ),
      '/chat' =>
        store.connected
            ? switch (arg) {
                (String id, String text) => DirectChatPage(
                  id,
                  byPeer: true,
                  initialText: text,
                ),
                _ => DirectChatPage(arg as String, byPeer: true),
              }
            : ChatPage(arg as String),
      '/conversation' => DirectChatPage(arg as String),
      '/share' =>
        store.connected
            ? SearchPage(messageRecipient: true, sharedPost: arg as String)
            : SharePage(arg as String),
      '/settings' => const SettingsPage(),
      '/preferences' => PreferencesPage(initial: arg as String? ?? 'Gizlilik'),
      '/blocked' => const BlockedPage(),
      '/report' =>
        arg is ReportTarget
            ? ReportPage(arg.label, remoteTarget: arg)
            : ReportPage(
                arg as String? ?? 'Uygulama',
                remoteTarget: store.connected
                    ? const ReportTarget('system', 0, 'Uygulama')
                    : null,
              ),
      '/delete-account' => const DeleteAccountPage(),
      '/legal' => LegalPage(arg as String? ?? 'Bilgilendirme'),
      _ => AppPage(
        title: tr('Sayfa Bulunamadı'),
        child: EmptyState(
          'Bu yol henüz bir hikâyeye çıkmıyor.',
          'Geri dönerek keşfetmeye devam edebilirsin.',
        ),
      ),
    };
    return MaterialPageRoute<dynamic>(settings: settings, builder: (_) => page);
  }
}

/// The route a tapped share link first lands on: it shows nothing, closes itself and hands the link on.
class _ShareLinkLanding extends StatefulWidget {
  const _ShareLinkLanding({required this.onReady});
  final VoidCallback onReady;
  @override
  State<_ShareLinkLanding> createState() => _ShareLinkLandingState();
}

class _ShareLinkLandingState extends State<_ShareLinkLanding> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onReady();
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: SizedBox.expand());
}
