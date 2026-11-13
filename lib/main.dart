import 'core/polling.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/theme.dart';
import 'data/account_api.dart';
import 'data/app_store.dart';
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
import 'screens/messages.dart';
import 'screens/direct_chat.dart';
import 'screens/live_notifications.dart';
import 'screens/notifications.dart';
import 'screens/settings.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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

  @override
  void initState() {
    super.initState();
    _signedIn = store.authenticated;
    store.push?.onOpen = (id) => unawaited(openPush(id));
    store.push?.onForeground = (id) {
      unawaited(store.refreshUnread());
      _messenger.currentState?.showSnackBar(
        SnackBar(
          content: const Text('Yeni bir SenMiydin? bildirimin var.'),
          action: SnackBarAction(
            label: 'Gör',
            onPressed: () => unawaited(openPush(id)),
          ),
        ),
      );
    };
    if (store.connected) store.addListener(_sessionChanged);
  }

  void _sessionChanged() {
    final ended = _signedIn && !store.authenticated;
    _signedIn = store.authenticated;
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
    child: MaterialApp(
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
      locale: const Locale('tr', 'TR'),
      supportedLocales: const [Locale('tr', 'TR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
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
      '/map' => const AppPage(title: 'Harita', child: MapContent()),
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
      '/comments' => CommentsPage(arg as String),
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
      '/messages' => const AppPage(
        title: 'Mesajlar',
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
      _ => const AppPage(
        title: 'Sayfa Bulunamadı',
        child: EmptyState(
          'Bu yol henüz bir hikâyeye çıkmıyor.',
          'Geri dönerek keşfetmeye devam edebilirsin.',
        ),
      ),
    };
    return MaterialPageRoute<dynamic>(settings: settings, builder: (_) => page);
  }
}
