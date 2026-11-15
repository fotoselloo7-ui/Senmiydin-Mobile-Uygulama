import 'dart:async';

import 'package:flutter/material.dart' hide Text;

import '../widgets/translated_text.dart';

import '../data/social_sign_in.dart';

import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../core/brand_assets.dart';
import '../core/theme.dart';
import '../core/navigation.dart';
import '../data/account_api.dart';
import '../data/app_store.dart';
import '../widgets/account_action.dart';
import '../widgets/auth_ui.dart';
import '../widgets/common.dart';
import '../widgets/location_ui.dart';
import '../core/app_locale.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key, this.initialGazeOffset});

  /// Optional fixed gaze offset in [-1.0, 1.0] for deterministic visual QA.
  final double? initialGazeOffset;

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  String? error;

  /// The big eyeless artwork has been decoded. Nothing of the branded splash is shown before that, so the pupils
  /// never float alone on the surface while the artwork is still loading.
  bool _artReady = false;

  /// Completes when the artwork is on screen: the gaze starts then, so all of it is seen (a slow first frame never
  /// eats the animation) and the splash stays about two seconds in front of the person.
  final Completer<void> _artShown = Completer<void>();
  Timer? _artTimer;
  late final AnimationController _controller;
  late final Animation<double> _gazeAnimation;

  @override
  void initState() {
    super.initState();
    // About 1.8 s from the moment the artwork is visible: centre -> a little right -> a little left -> centre. Soft
    // and short; the account restore runs in parallel and the app opens as soon as both are done.
    // AnimationBehavior.preserve: with the system animation scale at 0 (a developer option, or battery saver) Flutter
    // would otherwise shrink this 1.4 s gaze to a few milliseconds and the eyes would never visibly move.
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
      animationBehavior: AnimationBehavior.preserve,
    );
    TweenSequenceItem<double> move(double from, double to, double ms) =>
        TweenSequenceItem(
          tween: Tween<double>(
            begin: from,
            end: to,
          ).chain(CurveTween(curve: Curves.easeInOutCubic)),
          weight: ms,
        );
    _gazeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween<double>(0.0), weight: 300),
      move(0.0, 1.0, 320),
      TweenSequenceItem(tween: ConstantTween<double>(1.0), weight: 160),
      move(1.0, -1.0, 440),
      TweenSequenceItem(tween: ConstantTween<double>(-1.0), weight: 160),
      move(-1.0, 0.0, 260),
      TweenSequenceItem(tween: ConstantTween<double>(0.0), weight: 160),
    ]).animate(_controller);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(restore());
    });
  }

  @override
  void dispose() {
    _artTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> restore() async {
    setState(() => error = null);
    // The gaze is a short, gentle brand moment (pupils only, no flashing): it always plays, whatever the system
    // animation scale is. Only the fixed-offset QA mode skips it.
    // If the artwork takes unusually long, the gaze starts after three seconds anyway.
    _artTimer = Timer(const Duration(seconds: 3), () {
      if (!_artShown.isCompleted) _artShown.complete();
    });
    final animFuture = widget.initialGazeOffset != null
        ? Future<void>.value()
        : _artShown.future.then(
            (_) => _controller.forward().orCancel.catchError((_) {}),
          );
    try {
      final results = await Future.wait<dynamic>([
        StoreScope.of(context).restoreAccount(),
        animFuture,
      ]);
      final route = results[0] as String;
      if (mounted && widget.initialGazeOffset == null) {
        Navigator.pushReplacementNamed(context, route);
      }
    } on ApiFailure catch (failure) {
      if (mounted) setState(() => error = failure.detail);
    } catch (_) {
      if (mounted) setState(() => error = 'Bir sorun oluştu. Tekrar dene.');
    }
  }

  // The gaze reaches a little further than the artwork's own rest position so the movement is clearly visible on a
  // phone, while the pupils stay inside their eye whites (the ClipOval below clips the last pixels).
  static const _reach = 1.15;

  /// Artwork rows the mark sits above the screen centre (mark centre y = 745 of 1920): the artwork is moved down by
  /// this much so the mark is on the centre, where the native splash draws it.
  static const _markShift = 215.0;

  /// Colour of the artwork's top edge, continued in the strip that the shift opens at the top.
  static const _topColor = Color(0xFF1A0245);

  /// Surface of the native splash (res/values/colors.xml launch_background); the artwork fades in over it.
  static const _nativeSurface = Color(0xFF3A027C);

  /// The logo group in assets/brand/splash_eyeless.png is drawn smaller than the original artwork (see
  /// tool/make_splash_art_small.py): every coordinate below is an original-artwork coordinate that is mapped through
  /// the same scale about the mark centre.
  static const _logoScale = 0.74;
  static const _logoCenter = Offset(560, 745);

  static Offset _map(Offset p) => _logoCenter + (p - _logoCenter) * _logoScale;

  static Offset _leftPupilCenter(double t) {
    if (t < 0) {
      final s = -t * _reach;
      return _map(
        Offset(524.0 * (1 - s) + 488.0 * s, 824.0 * (1 - s) + 826.0 * s),
      );
    }
    final s = t * _reach;
    return _map(
      Offset(524.0 * (1 - s) + 562.0 * s, 824.0 * (1 - s) + 815.0 * s),
    );
  }

  static Offset _rightPupilCenter(double t) {
    if (t < 0) {
      final s = -t * _reach;
      return _map(
        Offset(656.0 * (1 - s) + 624.0 * s, 791.0 * (1 - s) + 793.0 * s),
      );
    }
    final s = t * _reach;
    return _map(
      Offset(656.0 * (1 - s) + 688.0 * s, 791.0 * (1 - s) + 784.0 * s),
    );
  }

  static Rect _mapEllipse(double cx, double cy, double rx, double ry) {
    final c = _map(Offset(cx, cy));
    return Rect.fromCenter(
      center: c,
      width: 2 * rx * _logoScale,
      height: 2 * ry * _logoScale,
    );
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final scaffold = Scaffold(
      backgroundColor: const Color(0xFF1E0245),
      body: Stack(
        fit: StackFit.expand,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final fit = constraints.maxWidth > constraints.maxHeight
                  ? BoxFit.contain
                  : BoxFit.cover;
              return FittedBox(
                fit: fit,
                alignment: Alignment.center,
                child: ClipRect(
                  child: SizedBox(
                    width: 1080,
                    height: 1920,
                    // The artwork is moved down so the mark sits on the screen centre, exactly where the native
                    // (system) splash draws it; the strip that opens at the top continues the artwork's top colour.
                    child: Stack(
                      children: [
                        const Positioned(
                          left: 0,
                          right: 0,
                          top: 0,
                          height: _markShift + 2,
                          child: ColoredBox(color: _topColor),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          top: _markShift,
                          height: 1920,
                          child: AnimatedBuilder(
                            animation: _gazeAnimation,
                            builder: (context, _) {
                              final t =
                                  widget.initialGazeOffset ??
                                  _gazeAnimation.value;
                              final lp = _leftPupilCenter(t);
                              final rp = _rightPupilCenter(t);

                              // Left sclera ellipse: center (515.8, 831.2), rx=78.5, ry=76.6
                              final lRect = _mapEllipse(
                                515.8,
                                831.2,
                                78.5,
                                76.6,
                              );
                              // Right sclera ellipse: center (648.53, 793.66), rx=64.9, ry=65.4
                              final rRect = _mapEllipse(
                                648.53,
                                793.66,
                                64.9,
                                65.4,
                              );

                              return Stack(
                                children: [
                                  Positioned.fill(
                                    child: Image.asset(
                                      BrandAssets.splashEyeless,
                                      fit: BoxFit.fill,
                                      gaplessPlayback: true,
                                      filterQuality: FilterQuality.medium,
                                      frameBuilder:
                                          (context, child, frame, sync) {
                                            if ((sync || frame != null) &&
                                                !_artReady) {
                                              WidgetsBinding.instance
                                                  .addPostFrameCallback((_) {
                                                    if (mounted) {
                                                      setState(
                                                        () => _artReady = true,
                                                      );
                                                      if (!_artShown
                                                          .isCompleted) {
                                                        _artShown.complete();
                                                      }
                                                    }
                                                  });
                                            }
                                            return child;
                                          },
                                    ),
                                  ),
                                  Positioned.fromRect(
                                    rect: lRect,
                                    child: ClipOval(
                                      child: Stack(
                                        clipBehavior: Clip.hardEdge,
                                        children: [
                                          Positioned(
                                            key: const Key('splash-pupil-left'),
                                            left:
                                                lp.dx -
                                                lRect.left -
                                                28.0 * _logoScale,
                                            top:
                                                lp.dy -
                                                lRect.top -
                                                33.0 * _logoScale,
                                            width: 56.0 * _logoScale,
                                            height: 66.0 * _logoScale,
                                            child: Image.asset(
                                              BrandAssets.pupilLeft,
                                              fit: BoxFit.fill,
                                              gaplessPlayback: true,
                                              filterQuality: FilterQuality.high,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Positioned.fromRect(
                                    rect: rRect,
                                    child: ClipOval(
                                      child: Stack(
                                        clipBehavior: Clip.hardEdge,
                                        children: [
                                          Positioned(
                                            key: const Key(
                                              'splash-pupil-right',
                                            ),
                                            left:
                                                rp.dx -
                                                rRect.left -
                                                24.0 * _logoScale,
                                            top:
                                                rp.dy -
                                                rRect.top -
                                                29.0 * _logoScale,
                                            width: 48.0 * _logoScale,
                                            height: 58.0 * _logoScale,
                                            child: Image.asset(
                                              BrandAssets.pupilRight,
                                              fit: BoxFit.fill,
                                              gaplessPlayback: true,
                                              filterQuality: FilterQuality.high,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          if (error != null)
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.all(Space.xl),
                  child: Container(
                    padding: const EdgeInsets.all(Space.lg),
                    decoration: AppShape.card(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(error!, textAlign: TextAlign.center),
                        const SizedBox(height: Space.sm),
                        TextButton(
                          onPressed: restore,
                          child: const Text('Tekrar Dene'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    // The native splash has the same brand purple surface and mark; the artwork fades in over it so there is no jump,
    // and nothing waits for the fade (the account restore and the gaze run from the first frame).
    return ColoredBox(
      color: _nativeSurface,
      child: TweenAnimationBuilder<double>(
        // Nothing of the branded splash is shown before the artwork is decoded (even with the system animation
        // scale off, when the fade just snaps): the pupils never float alone on the dark surface.
        tween: Tween<double>(begin: 0.0, end: _artReady ? 1.0 : 0.0),
        duration: disableAnimations
            ? Duration.zero
            : const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        builder: (context, opacity, child) =>
            Opacity(opacity: opacity, child: child),
        child: scaffold,
      ),
    );
  }
}

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});
  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  int index = 0;
  final controller = PageController();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    body: AuthBackdrop(
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(24, 12, 24, 0),
                  child: Brand(size: 30),
                ),
                Expanded(
                  child: PageView(
                    onPageChanged: (v) => setState(() => index = v),
                    controller: controller,
                    children: const [
                      _WelcomeSlide(
                        _WelcomeArt.glance,
                        'Bir an. Bir bakış.\nBelki de sen.',
                        'Gerçek hayatta yolların kesiştiği insanlarla, yarım kalan hikâyene yeniden merhaba de.',
                      ),
                      _WelcomeSlide(
                        _WelcomeArt.city,
                        'Şehrinin hikâyelerine\nyakından bak.',
                        'Düşünceler, anılar ve güzel tesadüfler. Aynı şehrin insanlarını keşfet.',
                      ),
                      _WelcomeSlide(
                        _WelcomeArt.connect,
                        'Güzel karşılaşmalar\nbir merhabayla başlar.',
                        'İlgi alanlarını paylaş, yeni bağlar kur. Konumunun görünürlüğü her zaman senin kontrolünde.',
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          3,
                          (i) => AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: i == index ? 26 : 8,
                            height: 8,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              color: i == index
                                  ? AppColors.brandPurple
                                  : AppColors.borderLilac,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      AuthPrimaryButton(
                        index < 2 ? 'Devam Et' : 'Hesap Oluştur',
                        icon: index < 2
                            ? Icons.arrow_forward_rounded
                            : Icons.person_add_alt_1_rounded,
                        onPressed: () {
                          if (index < 2) {
                            controller.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOut,
                            );
                          } else {
                            openPage(context, '/register');
                          }
                        },
                      ),
                      const SizedBox(height: 10),
                      AuthSecondaryButton(
                        'Giriş Yap',
                        icon: Icons.login_rounded,
                        onPressed: () => openPage(context, '/login'),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.brandPurple,
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14.5,
                          ),
                        ),
                        onPressed: () {
                          final store = StoreScope.of(context);
                          if (store.connected && !store.authenticated) {
                            openPage(context, '/register');
                          } else {
                            if (!store.connected) store.login();
                            home(context);
                          }
                        },
                        child: const Text('Uygulamayı keşfet'),
                      ),
                      const Text(
                        'Güzel tesadüflere yer aç. 💙',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

enum _WelcomeArt { glance, city, connect }

class _WelcomeSlide extends StatelessWidget {
  const _WelcomeSlide(this.art, this.title, this.text);
  final _WelcomeArt art;
  final String title, text;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final tall = box.maxHeight > 400;
      return SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              SizedBox(height: tall ? 18 : 6),
              _WelcomeIllustration(art, size: tall ? 250 : 150),
              SizedBox(height: tall ? 26 : 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 27,
                  height: 1.18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1B1140),
                  letterSpacing: -.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 15.5,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      );
    },
  );
}

/// Soft lilac stage with rings and a few floating cards. Shapes and icons only: no people, no demo data.
class _WelcomeIllustration extends StatelessWidget {
  const _WelcomeIllustration(this.art, {required this.size});
  final _WelcomeArt art;
  final double size;

  Widget _card(
    IconData icon, {
    required double left,
    required double top,
    double angle = 0,
  }) => Positioned(
    left: left * size,
    top: top * size,
    child: Transform.rotate(
      angle: angle,
      child: Container(
        width: 46 * size / 250,
        height: 46 * size / 250,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16 * size / 250),
          boxShadow: [
            BoxShadow(
              color: AppColors.brandPurple.withValues(alpha: .16),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Icon(icon, color: AppColors.brandPurple, size: 24 * size / 250),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final centre = switch (art) {
      _WelcomeArt.glance => Icons.favorite_rounded,
      _WelcomeArt.city => Icons.location_on_rounded,
      _WelcomeArt.connect => Icons.chat_bubble_rounded,
    };
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (final f in const [1.0, .76, .52])
            Container(
              width: size * f,
              height: size * f,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surfaceLilac.withValues(
                  alpha: f == .52 ? .9 : .38,
                ),
                border: Border.all(
                  color: AppColors.borderLilac.withValues(alpha: .7),
                ),
              ),
            ),
          Container(
            width: size * .34,
            height: size * .34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF8B2FE0), Color(0xFF5E17B8)],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.brandPurple.withValues(alpha: .35),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Icon(centre, color: Colors.white, size: size * .17),
          ),
          ...switch (art) {
            _WelcomeArt.glance => [
              _card(Icons.waving_hand_rounded, left: .06, top: .2, angle: -.2),
              _card(Icons.visibility_rounded, left: .74, top: .1, angle: .15),
              _card(
                Icons.auto_awesome_rounded,
                left: .72,
                top: .72,
                angle: -.1,
              ),
            ],
            _WelcomeArt.city => [
              _card(
                Icons.mail_outline_rounded,
                left: .08,
                top: .12,
                angle: -.15,
              ),
              _card(Icons.map_outlined, left: .76, top: .24, angle: .12),
              _card(
                Icons.directions_walk_rounded,
                left: .14,
                top: .72,
                angle: .1,
              ),
            ],
            _WelcomeArt.connect => [
              _card(Icons.mic_none_rounded, left: .06, top: .24, angle: -.12),
              _card(Icons.photo_outlined, left: .76, top: .14, angle: .14),
              _card(
                Icons.card_giftcard_rounded,
                left: .7,
                top: .72,
                angle: -.1,
              ),
            ],
          },
        ],
      ),
    );
  }
}

class AuthPage extends StatefulWidget {
  const AuthPage({super.key, this.register = false, this.social});
  final bool register;
  final SocialCredential? social;
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> with AccountAction<AuthPage> {
  final form = GlobalKey<FormState>();
  final handle = TextEditingController(),
      email = TextEditingController(),
      password = TextEditingController(),
      confirm = TextEditingController();
  DateTime? birthday;

  /// The display name starts as the social account's name (or the username) and is completed in the profile step.
  String? socialName;
  String city = 'Alanya';
  bool accepted = false;
  bool askedAge = false;

  /// Inline messages: a failed attempt (red) or an information note (lilac); inline errors for the two non-text
  /// requirements of the registration.
  String? failure, notice, birthdayError, termsError;
  bool submitted = false;

  @override
  void initState() {
    super.initState();
    email.text = widget.social?.email ?? '';
    socialName = widget.social?.name;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!askedAge) {
      askedAge = true;
      // The age gate comes from the server (one config value); nothing in the UI hardcodes it.
      if (widget.register) unawaited(StoreScope.of(context).loadMinimumAge());
    }
  }

  @override
  void dispose() {
    for (final c in [handle, email, password, confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Runs an account action; a failure is shown inline in the form (and never throws into the UI).
  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      failure = null;
      notice = null;
    });
    if (busy) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => busy = true);
    try {
      await action();
    } on ApiFailure catch (error) {
      if (mounted) setState(() => failure = error.detail);
    } catch (error) {
      assert(() {
        debugPrint('Account action failed: ${error.runtimeType}');
        return true;
      }());
      if (mounted) setState(() => failure = 'Bir sorun oluştu. Tekrar dene.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void submit() {
    setState(() {
      submitted = true;
      birthdayError = null;
      termsError = null;
    });
    final valid = form.currentState!.validate();
    var complete = true;
    if (widget.register && birthday == null) {
      setState(() => birthdayError = 'Doğum tarihini seçmelisin.');
      complete = false;
    }
    if (widget.register && !accepted) {
      setState(
        () => termsError = 'Devam etmek için koşulları kabul etmelisin.',
      );
      complete = false;
    }
    if (!valid || !complete) return;
    final store = StoreScope.of(context);
    if (store.connected) {
      _run(() async {
        if (widget.register) {
          final username = handle.text.trim().replaceFirst(RegExp(r'^@'), '');
          await store.signIn(
            widget.social == null
                ? 'register'
                : 'social/${widget.social!.provider}',
            {
              ...?widget.social?.fields,
              // The sign-up form has no name field: the display name starts as the social name or the username and
              // is completed in the next (profile) step.
              'name': (socialName ?? '').trim().isEmpty
                  ? username
                  : socialName!.trim(),
              'username': username,
              'email': email.text.trim(),
              'password': password.text,
              'birth_date': birthday!.toIso8601String().split('T').first,
              'city_id': await store.cityId(city),
              'accepted_terms': accepted,
            },
          );
        } else {
          await store.signIn('login', {
            'identifier': email.text.trim(),
            'password': password.text,
          });
        }
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            store.accountRoute,
            (_) => false,
          );
        }
      });
      return;
    }
    if (widget.register) {
      final username = handle.text.trim().replaceFirst('@', '');
      store.me.name = (socialName ?? '').trim().isEmpty
          ? username
          : socialName!.trim();
      store.me.handle = username;
      store.me.city = city;
      store.city = city;
      store.refresh();
      openPage(context, '/complete');
    } else {
      store.login();
      home(context);
    }
  }

  /// Google / Apple: the sign-in runs here when the provider is configured; otherwise an honest note is shown and
  /// the e-mail form stays available. A new social identity continues in the registration form.
  void social(String provider) {
    final store = StoreScope.of(context);
    if (!(store.connected && SocialSignIn.configured(provider))) {
      setState(() {
        failure = null;
        notice = trf(
          '{0} ile giriş şu anda kullanılamıyor. E-posta ve şifrenle devam edebilirsin.',
          [provider],
        );
      });
      return;
    }
    _run(() async {
      final credential = await SocialSignIn.authenticate(provider, store.auth!);
      try {
        await store.signIn('social/${credential.provider}', credential.fields);
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            store.accountRoute,
            (_) => false,
          );
        }
      } on ApiFailure catch (error) {
        if (error.status != 412) rethrow;
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute<void>(
              builder: (_) => AuthPage(register: true, social: credential),
            ),
          );
        }
      }
    });
  }

  Future<void> pickBirthday() async {
    final now = DateTime.now();
    final age = StoreScope.of(context).minimumAge;
    final value = await showDatePicker(
      context: context,
      initialDate: birthday ?? DateTime(now.year - age - 2, now.month, now.day),
      firstDate: DateTime(1920),
      lastDate: DateTime(now.year - age, now.month, now.day),
      helpText: trf('Devam etmek için {0} yaşını doldurmalısın', [age]),
    );
    if (mounted && value != null) {
      setState(() {
        birthday = value;
        birthdayError = null;
      });
    }
  }

  String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  Widget _banner() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (failure != null) AuthNotice(failure!, error: true),
      if (notice != null) AuthNotice(notice!),
    ],
  );

  Widget _legalNote(int age) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      AgeBadge(age),
      const SizedBox(width: 10),
      Expanded(
        child: AuthRichText(
          "Devam ederek {0} ve {1}'nı kabul etmiş sayılırsın.",
          [
            AuthLink(
              'Kullanım Koşulları',
              () => showLegal(context, 'Kullanım Koşulları'),
            ),
            AuthLink(
              'Gizlilik Politikası',
              () => showLegal(context, 'Gizlilik Politikası'),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _switchRow() => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          widget.register ? 'Zaten hesabın var mı?' : 'Hesabın yok mu?',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14.5,
          ),
        ),
        TextButton(
          onPressed: busy
              ? null
              : () =>
                    openPage(context, widget.register ? '/login' : '/register'),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.brandPurple,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            textStyle: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          child: Text(widget.register ? 'Giriş Yap' : 'Kayıt Ol'),
        ),
      ],
    ),
  );

  List<Widget> _login(BuildContext context) => [
    const SizedBox(height: 18),
    const AuthTitle(
      'Tekrar karşılaşmaya hazır mısın?',
      'Hesabına giriş yap ve yarım kalan karşılaşmalarına devam et.',
    ),
    const SizedBox(height: 26),
    _banner(),
    Form(
      key: form,
      autovalidateMode: submitted
          ? AutovalidateMode.onUserInteraction
          : AutovalidateMode.disabled,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthField(
            'E-posta veya kullanıcı adı',
            Icons.mail_outline_rounded,
            controller: email,
            keyboardType: TextInputType.emailAddress,
            enabled: !busy,
            autofillHints: const [AutofillHints.username],
            validator: requiredText,
          ),
          AuthField(
            'Şifre',
            Icons.lock_outline_rounded,
            controller: password,
            obscure: true,
            enabled: !busy,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => submit(),
            autofillHints: const [AutofillHints.password],
            validator: requiredText,
          ),
        ],
      ),
    ),
    Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: busy ? null : () => openPage(context, '/forgot'),
        style: TextButton.styleFrom(
          foregroundColor: AppColors.brandPurple,
          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
        ),
        child: const Text('Şifremi unuttum?'),
      ),
    ),
    const SizedBox(height: 6),
    AuthPrimaryButton(
      busy ? 'Lütfen bekle…' : 'Giriş Yap',
      icon: Icons.person_rounded,
      busy: busy,
      onPressed: busy ? null : submit,
    ),
    const AuthDivider('veya'),
    AuthSocialButton(
      SocialProvider.google,
      'Google ile devam et',
      onPressed: busy ? null : () => social('Google'),
    ),
    const SizedBox(height: 10),
    AuthSocialButton(
      SocialProvider.apple,
      'Apple ile devam et',
      onPressed: busy ? null : () => social('Apple'),
    ),
    const SizedBox(height: 14),
    _switchRow(),
    const SizedBox(height: 10),
    _legalNote(StoreScope.of(context).minimumAge),
  ];

  List<Widget> _register(BuildContext context) {
    final age = StoreScope.of(context).minimumAge;
    return [
      const SizedBox(height: 10),
      const AuthTitle(
        'SenMiydin?’e katıl',
        'Yeni insanlarla, anılarla ve yarım kalan karşılaşmalarla yeniden bağ kur.',
      ),
      const SizedBox(height: 20),
      _banner(),
      AuthSocialButton(
        SocialProvider.google,
        'Google ile kayıt ol',
        onPressed: busy ? null : () => social('Google'),
      ),
      const SizedBox(height: 10),
      AuthSocialButton(
        SocialProvider.apple,
        'Apple ile kayıt ol',
        onPressed: busy ? null : () => social('Apple'),
      ),
      const AuthDivider('veya e-posta ile kayıt ol'),
      Form(
        key: form,
        autovalidateMode: submitted
            ? AutovalidateMode.onUserInteraction
            : AutovalidateMode.disabled,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthField(
              'E-posta',
              Icons.mail_outline_rounded,
              controller: email,
              keyboardType: TextInputType.emailAddress,
              enabled: !busy,
              autofillHints: const [AutofillHints.email],
              validator: (v) => validEmail(v ?? '')
                  ? null
                  : 'Geçerli bir e-posta adresi gir.',
            ),
            AuthField(
              'Şifre',
              Icons.lock_outline_rounded,
              controller: password,
              obscure: true,
              enabled: !busy,
              autofillHints: const [AutofillHints.newPassword],
              validator: newPasswordError,
            ),
            AuthField(
              'Şifre Tekrar',
              Icons.lock_outline_rounded,
              controller: confirm,
              obscure: true,
              enabled: !busy,
              validator: (v) =>
                  v == password.text ? null : 'Şifreler eşleşmiyor.',
            ),
            AuthField(
              'Kullanıcı Adı',
              Icons.person_outline_rounded,
              controller: handle,
              enabled: !busy,
              autofillHints: const [AutofillHints.newUsername],
              validator: (v) =>
                  RegExp(r'^[a-zA-Z0-9_\.]{3,24}$')
                      .hasMatch((v ?? '').replaceFirst('@', ''))
                  ? null
                  : '3–24 harf, rakam, nokta veya alt çizgi kullan.',
            ),
            AuthSelectField(
              label: 'Doğum Tarihi',
              icon: Icons.calendar_month_outlined,
              value: birthday == null ? null : _date(birthday!),
              errorText: birthdayError,
              onTap: busy ? null : pickBirthday,
            ),
          ],
        ),
      ),
      const SizedBox(height: 4),
      AuthPrimaryButton(
        busy ? 'Lütfen bekle…' : 'Kayıt Ol',
        icon: Icons.person_add_alt_1_rounded,
        busy: busy,
        onPressed: busy ? null : submit,
      ),
      const SizedBox(height: 16),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: Checkbox(
              value: accepted,
              activeColor: AppColors.brandPurple,
              side: const BorderSide(color: AppColors.borderStrong, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
              onChanged: busy
                  ? null
                  : (v) => setState(() {
                      accepted = v ?? false;
                      if (accepted) termsError = null;
                    }),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 5),
              child: AuthRichText(
                "{0} yaşını doldurdum; {1} ve {2}'nı okudum, kabul ediyorum.",
                [
                  '$age',
                  AuthLink(
                    'Kullanım Koşulları',
                    () => showLegal(context, 'Kullanım Koşulları'),
                  ),
                  AuthLink(
                    'Gizlilik Politikası',
                    () => showLegal(context, 'Gizlilik Politikası'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      if (termsError != null)
        Padding(
          padding: const EdgeInsets.only(top: 6, left: 36),
          child: Text(
            termsError!,
            style: const TextStyle(color: AppColors.red, fontSize: 12.5),
          ),
        ),
      const SizedBox(height: 6),
      const SizedBox(height: 10),
      _switchRow(),
    ];
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: AuthScaffold(
      children: widget.register ? _register(context) : _login(context),
    ),
  );
}

String? requiredText(String? value) =>
    (value ?? '').trim().isEmpty ? 'Bu alanı doldurmalısın.' : null;

class SetupProgress extends StatelessWidget {
  const SetupProgress({super.key, required this.step});
  final int step;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: Space.sm, bottom: Space.xl),
    child: Row(
      children: List.generate(
        5,
        (i) => Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Container(
              height: 5,
              decoration: BoxDecoration(
                color: i <= step ? AppColors.blue : AppColors.line,
                borderRadius: BorderRadius.circular(5),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class CompleteProfilePage extends StatefulWidget {
  const CompleteProfilePage({super.key, this.edit = false});
  final bool edit;
  @override
  State<CompleteProfilePage> createState() => _CompleteProfilePageState();
}

class _CompleteProfilePageState extends State<CompleteProfilePage>
    with AccountAction<CompleteProfilePage> {
  late final TextEditingController bio, occupation, name, handle;
  late String city, photo;
  late Set<String> connections;
  bool visible = true, suggest = true, initialized = false, leaving = false;
  late Object originalForm;
  Object get formValue => (
    name.text,
    handle.text,
    bio.text,
    occupation.text,
    city,
    (connections.toList()..sort()).join(','),
    visible,
    suggest,
  );
  bool get hasChanges => initialized && originalForm != formValue;
  void formChanged() {
    if (mounted && widget.edit) setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (initialized) {
      return;
    }
    initialized = true;
    final store = StoreScope.of(context);
    final me = store.me;
    bio = TextEditingController(text: me.bio);
    occupation = TextEditingController(text: me.occupation);
    name = TextEditingController(text: me.name);
    handle = TextEditingController(text: me.handle);
    city = me.city;
    photo = me.photo;
    visible = me.visible;
    connections = {...store.connections};
    suggest =
        store.account?.encounterSuggestions ??
        store.preferences['Konum temelli öneriler']!;
    originalForm = formValue;
    for (final controller in [name, handle, bio, occupation]) {
      controller.addListener(formChanged);
    }
  }

  @override
  void dispose() {
    bio.dispose();
    occupation.dispose();
    name.dispose();
    handle.dispose();
    super.dispose();
  }

  void save() {
    if (name.text.trim().isEmpty ||
        !RegExp(r'^[a-zA-Z0-9_\.]{3,24}$').hasMatch(handle.text.trim())) {
      toast(context, 'Adını ve geçerli bir kullanıcı adını gir.');
      return;
    }
    final store = StoreScope.of(context);
    if (store.connected) {
      runAccountAction(() async {
        await store.saveAccountProfile({
          'name': name.text.trim(),
          'username': handle.text.trim(),
          'bio': bio.text.trim(),
          'occupation_school': occupation.text.trim(),
          if (city != store.account!.city.name)
            'city_id': await store.cityId(city),
          'connections': [
            for (final entry in AppStore.connectionChoices.entries)
              if (connections.contains(entry.value)) entry.key,
          ],
          'nearby_visible': visible,
          'encounter_suggestions': suggest,
          if (!widget.edit) 'complete_profile': true,
        });
        if (mounted) afterSave();
      });
      return;
    }
    store.me
      ..name = name.text.trim()
      ..handle = handle.text.trim()
      ..bio = bio.text.trim()
      ..occupation = occupation.text.trim()
      ..city = city
      ..photo = photo
      ..visible = visible;
    store.connections
      ..clear()
      ..addAll(connections);
    store.preferences['Konum temelli öneriler'] = suggest;
    store.refresh();
    afterSave();
  }

  void afterSave() {
    if (widget.edit) {
      setState(() => leaving = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.pop(context);
        toast(context, 'Profilin güncellendi.');
      });
    } else {
      Navigator.pushReplacementNamed(context, '/interests', arguments: true);
    }
  }

  void pickAvatar(AppStore store) {
    runAccountAction(() async {
      try {
        final image = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          maxWidth: 1600,
          maxHeight: 1600,
          imageQuality: 88,
        );
        if (image == null || !mounted) return;
        await store.uploadAvatar(image);
        if (mounted) setState(() => photo = store.me.photo);
      } on PlatformException {
        throw const ApiFailure('Galeriden fotoğraf seçilemedi.');
      }
    });
  }

  void pickCover(AppStore store) {
    runAccountAction(() async {
      try {
        final image = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          maxWidth: 1600,
          maxHeight: 1600,
          imageQuality: 88,
        );
        if (image == null || !mounted) return;
        await store.uploadCover(image);
        if (mounted) {
          setState(() {});
          toast(context, 'Kapak fotoğrafın güncellendi.');
        }
      } on PlatformException {
        throw const ApiFailure('Galeriden fotoğraf seçilemedi.');
      }
    });
  }

  void removeCover(AppStore store) {
    runAccountAction(() async {
      await store.removeCover();
      if (mounted) {
        setState(() {});
        toast(context, 'Kapak fotoğrafın kaldırıldı.');
      }
    });
  }

  Future<void> changeCover(AppStore store) async {
    if ((store.account?.cover ?? '').isEmpty) return pickCover(store);
    final remove = await showModalBottomSheet<bool>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: Space.page,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SettingsRow(
                'Yeni fotoğraf seç',
                Icons.image_outlined,
                onTap: () => Navigator.pop(ctx, false),
              ),
              SettingsRow(
                'Kapak fotoğrafını kaldır',
                Icons.delete_outline_rounded,
                danger: true,
                onTap: () => Navigator.pop(ctx, true),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || remove == null) return;
    remove ? removeCover(store) : pickCover(store);
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return PopScope(
      canPop: !busy && (!widget.edit || !hasChanges || leaving),
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || busy || leaving || !widget.edit || !hasChanges) return;
        final discard = await confirmAction(
          context,
          title: 'Değişiklikler kaydedilmedi',
          message: 'Kaydetmeden çıkarsan bu formdaki değişiklikler kaybolacak.',
          action: 'Kaydetmeden Çık',
          scrollable: true,
        );
        if (!discard || !mounted) return;
        setState(() => leaving = true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.pop(context);
        });
      },
      child: AppPage(
        title: widget.edit ? 'Profil Düzenle' : 'Profilini Tamamla',
        child: SingleChildScrollView(
          padding: Space.page,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!widget.edit) ...[
                const SetupProgress(step: 1),
                const InfoBanner(
                  'Profilini Tamamla',
                  'İlk izlenim önemli.',
                  icon: Icons.person_outline_rounded,
                ),
                const SizedBox(height: Space.xl),
              ],
              Center(
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: busy
                          ? null
                          : store.connected
                          ? () => pickAvatar(store)
                          : () => showModalBottomSheet<void>(
                              context: context,
                              builder: (ctx) => SafeArea(
                                child: Padding(
                                  padding: Space.page,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Bir profil fotoğrafı seç',
                                        style: Theme.of(ctx)
                                            .textTheme
                                            .titleLarge,
                                      ),
                                      const SizedBox(height: Space.lg),
                                      Wrap(
                                        spacing: 16,
                                        runSpacing: 16,
                                        children: store.people
                                            .take(6)
                                            .map(
                                              (p) => GestureDetector(
                                                onTap: () {
                                                  setState(
                                                    () => photo = p.photo,
                                                  );
                                                  Navigator.pop(ctx);
                                                },
                                                child: Avatar(p, size: 65),
                                              ),
                                            )
                                            .toList(),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 51,
                            backgroundColor: AppColors.pale,
                            backgroundImage: profileImage(photo),
                            onBackgroundImageError: photo.isEmpty
                                ? null
                                : (_, _) {},
                            child: photo.isEmpty
                                ? const Icon(
                                    Icons.person_outline,
                                    color: AppColors.blue,
                                    size: 55,
                                  )
                                : null,
                          ),
                          const Positioned(
                            right: 0,
                            bottom: 0,
                            child: CircleAvatar(
                              radius: 14,
                              backgroundColor: AppColors.action,
                              child: Icon(
                                Icons.add,
                                color: Colors.white,
                                size: 21,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: Space.sm),
                    const Text(
                      'Fotoğraf ekle',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Space.xl),
              if (widget.edit) ...[
                if (store.connected)
                  SettingsRow(
                    'Kapak Fotoğrafı',
                    Icons.image_outlined,
                    subtitle: (store.account?.cover ?? '').isEmpty
                        ? 'Profilinin üst görselini ekle'
                        : 'Değiştir veya kaldır',
                    onTap: busy ? null : () => changeCover(store),
                  ),
                Field('Ad Soyad', Icons.person_outline, controller: name),
                Field(
                  'Kullanıcı Adı',
                  Icons.alternate_email,
                  controller: handle,
                ),
              ],
              Field(
                'Kısa Biyografi',
                Icons.edit_outlined,
                controller: bio,
                maxLines: 3,
                maxLength: 160,
              ),
              Field(
                'Meslek / Okul',
                Icons.work_outline,
                controller: occupation,
              ),
              SettingsRow(
                'Yaşadığın Şehir',
                Icons.location_on_outlined,
                subtitle: city,
                onTap: busy
                    ? null
                    : () async {
                        final v = await chooseCity(context, city);
                        if (mounted && v != null) {
                          setState(() => city = v);
                        }
                      },
              ),
              const SectionHeader(
                'Aradığın bağlantılar',
                icon: Icons.favorite_border,
              ),
              BalancedChoiceGrid(
                options: AppStore.connectionChoices.values.toList(),
                enabled: !busy,
                isSelected: connections.contains,
                onToggle: (c, v) => setState(
                  () => v ? connections.add(c) : connections.remove(c),
                ),
              ),
              PreferenceRow(
                'Konumumu şehir içinde göster',
                visible,
                busy ? null : (v) => setState(() => visible = v),
              ),
              PreferenceRow(
                'Yakınımdaki karşılaşmaları öner',
                suggest,
                busy ? null : (v) => setState(() => suggest = v),
              ),
              if (widget.edit)
                SettingsRow(
                  'İlgi Alanlarım',
                  Icons.interests_outlined,
                  subtitle: store.me.interests.join(', '),
                  onTap: busy
                      ? null
                      : () => openPage(context, '/interests', false),
                ),
              const SizedBox(height: Space.lg),
              PrimaryButton(
                busy
                    ? 'Kaydediliyor…'
                    : widget.edit
                    ? 'Değişiklikleri Kaydet'
                    : 'Devam Et',
                onPressed: busy ? null : save,
                icon: widget.edit ? Icons.check : Icons.arrow_forward,
              ),
              const SizedBox(height: Space.xl),
            ],
          ),
        ),
      ),
    );
  }
}

class InterestsPage extends StatefulWidget {
  const InterestsPage({super.key, this.setup = false});
  final bool setup;
  @override
  State<InterestsPage> createState() => _InterestsPageState();
}

class _InterestsPageState extends State<InterestsPage>
    with AccountAction<InterestsPage> {
  String query = '';
  final selected = <int>{};
  List<CatalogItem>? catalog;
  String? loadError;
  bool loading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!loading && catalog == null && loadError == null) loadCatalog();
  }

  Future<void> loadCatalog() async {
    final store = StoreScope.of(context);
    setState(() {
      loading = true;
      loadError = null;
    });
    try {
      final items = await store.loadInterests();
      if (!mounted) return;
      setState(() {
        catalog = items;
        selected.addAll(
          items
              .where(
                (item) =>
                    store.account?.interests.any(
                      (interest) => interest.id == item.id,
                    ) ??
                    store.me.interests.contains(item.name),
              )
              .map((item) => item.id),
        );
        loading = false;
      });
    } on ApiFailure catch (error) {
      if (!mounted) return;
      setState(() {
        loadError = error.detail;
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final results = (catalog ?? const <CatalogItem>[])
        .where(
          (item) =>
              turkishSearchKey(item.name).contains(turkishSearchKey(query)),
        )
        .toList();
    return PopScope(
      canPop: !busy,
      child: AppPage(
        title: widget.setup ? 'Hobilerini Seç' : 'İlgi Alanlarım',
        bottom: PrimaryButton(
          busy
              ? 'Kaydediliyor…'
              : widget.setup
              ? 'Devam Et'
              : trf('Kaydet ({0})', [selected.length]),
          onPressed: busy || selected.length < 5
              ? null
              : () => runAccountAction(() async {
                  await store.saveAccountInterests(
                    catalog!
                        .where((item) => selected.contains(item.id))
                        .toList(),
                  );
                  if (!context.mounted) return;
                  if (widget.setup) {
                    Navigator.pushReplacementNamed(context, '/permissions');
                  } else {
                    Navigator.pop(context);
                  }
                }),
        ),
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: Space.page,
              sliver: SliverList.list(
                children: [
                  if (widget.setup) const SetupProgress(step: 2),
                  const Center(
                    child: CircleAvatar(
                      radius: 34,
                      backgroundColor: AppColors.pale,
                      child: Icon(
                        Icons.favorite_border,
                        size: 38,
                        color: AppColors.blue,
                      ),
                    ),
                  ),
                  const SizedBox(height: Space.lg),
                  Text(
                    'Seni sen yapan şeyler.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: Space.sm),
                  const Text(
                    'İlgi alanların sana uygun paylaşımları bulmak için kullanılır; profilinde herkese gösterilmez.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.muted),
                  ),
                  const SizedBox(height: Space.lg),
                  TextField(
                    onChanged: (v) => setState(() => query = v),
                    decoration: InputDecoration(
                      hintText: tr('Hobi ara'),
                      prefixIcon: const Icon(Icons.search),
                    ),
                  ),
                  const SizedBox(height: Space.md),
                  InfoNote(
                    trf('{0} ilgi alanı seçtin. En az 5 seçim yap.', [
                      selected.length,
                    ]),
                  ),
                  const SizedBox(height: Space.md),
                ],
              ),
            ),
            if (loading)
              const SliverToBoxAdapter(child: LoadingState())
            else if (loadError != null)
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    Text(loadError!),
                    TextButton(
                      onPressed: loadCatalog,
                      child: const Text('Tekrar Dene'),
                    ),
                  ],
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverGrid.builder(
                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 230,
                    mainAxisExtent:
                        50 +
                        36 *
                            (MediaQuery.textScalerOf(context)
                                    .scale(1)
                                    .clamp(1.0, 3.0)
                                    .toDouble() -
                                1),
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: results.length,
                  itemBuilder: (_, i) {
                    final h = results[i], active = selected.contains(h.id);
                    return Semantics(
                      selected: active,
                      button: true,
                      enabled: !busy,
                      child: InkWell(
                        borderRadius: AppShape.rounded,
                        onTap: busy
                            ? null
                            : () => setState(
                                () => active
                                    ? selected.remove(h.id)
                                    : selected.add(h.id),
                              ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: AppShape.card(
                            color: active ? AppColors.action : Colors.white,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                interestIcon(h.name),
                                size: 21,
                                color: active ? Colors.white : AppColors.navy,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  h.name,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: active
                                        ? Colors.white
                                        : AppColors.navy,
                                  ),
                                ),
                              ),
                              if (active)
                                const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 16,
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class PermissionsPage extends StatefulWidget {
  const PermissionsPage({super.key});
  @override
  State<PermissionsPage> createState() => _PermissionsPageState();
}

class _PermissionsPageState extends State<PermissionsPage>
    with AccountAction<PermissionsPage> {
  bool? location;
  bool notifications = true;

  void finish({bool skip = false}) {
    final store = StoreScope.of(context);
    final useLocation = !skip && location!;
    final useNotifications = !skip && notifications;
    runAccountAction(() async {
      if (store.connected) {
        await store.saveAccountProfile({
          'city_discovery': useLocation,
          'finish_setup': true,
        });
      } else {
        store.me.visible = useLocation;
        store.login();
      }
      store.preferences['Bildirimlere izin ver'] = useNotifications;
      if (mounted) home(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    location ??= store.account?.cityDiscovery ?? true;
    return PopScope(
      canPop: !busy,
      child: AppPage(
        title: 'Kontrol Sende',
        bottom: PrimaryButton(
          busy ? 'Kaydediliyor…' : 'Keşfetmeye Başla',
          onPressed: busy ? null : finish,
        ),
        child: ListView(
          padding: Space.page,
          children: [
            const SetupProgress(step: 3),
            const SizedBox(height: Space.lg),
            const Center(
              child: CircleAvatar(
                radius: 47,
                backgroundColor: AppColors.pale,
                child: Icon(
                  Icons.shield_outlined,
                  color: AppColors.blue,
                  size: 48,
                ),
              ),
            ),
            const SizedBox(height: Space.xl),
            Text(
              'Güzel karşılaşmalara\nyer aç.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: Space.xl),
            PreferenceRow(
              'Şehir içinde keşif',
              location!,
              busy ? null : (v) => setState(() => location = v),
              subtitle: 'Yaşadığın şehirle ilgili keşif önerileri al.',
            ),
            if (store.connected) ...[
              InfoNote(
                store.location?.supportsBackground == true
                    ? 'Cihaz konumun şehir keşfi ve yakınlık için sunucuya gönderilir. Geçtiğim Yerler başlangıçta kapalıdır. Ayarlardan açarsan konumun uygulama arka plandayken de yaklaşık geçmiş bölgeleri kaydetmek ve ilgili hikâyeleri önermek için kullanılır. Bildirim tercihi ayrıdır; kesin konumun diğer kullanıcılara gösterilmez.'
                    : 'Cihaz konumun şehir keşfi ve yakınlık için sunucuya gönderilir. Geçtiğim Yerler başlangıçta kapalıdır. Ayarlardan açarsan uygulama açıkken yaklaşık geçmiş bölgeler kaydedilir ve ilgili hikâyeler önerilebilir. Arka planda konum kaydı yapılmaz; kesin konumun diğer kullanıcılara gösterilmez.',
              ),
              const SizedBox(height: Space.sm),
              DeviceLocationRow(enabled: !busy),
            ],
            const Divider(),
            PreferenceRow(
              'Bildirimler',
              notifications,
              busy ? null : (v) => setState(() => notifications = v),
              subtitle: 'Mesajlardan ve yeni karşılaşmalardan haberdar ol.',
            ),
            const SizedBox(height: Space.lg),

            const Text(
              'Cihaz konumu isteğe bağlıdır. Şehir akışını izinsiz de kullanabilirsin.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            TextButton(
              onPressed: busy ? null : () => finish(skip: true),
              child: const Text('Şimdilik atla'),
            ),
          ],
        ),
      ),
    );
  }
}

class SocialLoginPage extends StatefulWidget {
  const SocialLoginPage(this.provider, {super.key});
  final String provider;
  @override
  State<SocialLoginPage> createState() => _SocialLoginPageState();
}

class _SocialLoginPageState extends State<SocialLoginPage>
    with AccountAction<SocialLoginPage> {
  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final enabled = store.connected && SocialSignIn.configured(widget.provider);
    return AppPage(
      title: trf('{0} ile Devam Et', [widget.provider]),
      child: SingleChildScrollView(
        padding: Space.page,
        child: Column(
          children: [
            Icon(
              widget.provider == 'Apple'
                  ? Icons.apple
                  : Icons.g_mobiledata_rounded,
              size: 70,
              color: AppColors.blue,
            ),
            const SizedBox(height: Space.xl),
            Text(
              enabled
                  ? trf('{0} ile giriş', [widget.provider])
                  : 'Giriş şu anda kullanılamıyor',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: Space.md),
            InfoNote(
              enabled
                  ? 'Kimliğini güvenli şekilde doğrula. Yeni hesap için kayıt bilgilerini tamamlaman istenir.'
                  : trf(
                      '{0} ile giriş şu anda kullanılamıyor. E-posta ve şifrenle devam edebilirsin.',
                      [widget.provider],
                    ),
            ),
            const SizedBox(height: Space.xl),
            if (enabled)
              PrimaryButton(
                'Devam Et',
                onPressed: busy
                    ? null
                    : () => runAccountAction(() async {
                        final credential = await SocialSignIn.authenticate(
                          widget.provider,
                          store.auth!,
                        );
                        try {
                          await store.signIn(
                            'social/${credential.provider}',
                            credential.fields,
                          );
                          if (context.mounted) {
                            Navigator.pushNamedAndRemoveUntil(
                              context,
                              store.accountRoute,
                              (_) => false,
                            );
                          }
                        } on ApiFailure catch (failure) {
                          if (failure.status != 412) rethrow;
                          if (context.mounted) {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => AuthPage(
                                  register: true,
                                  social: credential,
                                ),
                              ),
                            );
                          }
                        }
                      }),
              ),
            PrimaryButton(
              'E-posta ile Giriş Yap',
              onPressed: busy
                  ? null
                  : () => Navigator.pushReplacementNamed(context, '/login'),
            ),
            const SizedBox(height: Space.sm),
            SecondaryButton(
              'Geri Dön',
              onPressed: busy ? null : () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}

class ForgotPage extends StatefulWidget {
  const ForgotPage({super.key});
  @override
  State<ForgotPage> createState() => _ForgotPageState();
}

class _ForgotPageState extends State<ForgotPage>
    with AccountAction<ForgotPage> {
  final email = TextEditingController();
  bool sent = false;
  @override
  void dispose() {
    email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: AppPage(
      title: 'Şifremi Unuttum',
      child: ListView(
        padding: Space.page,
        children: [
          const SizedBox(height: Space.xl),
          const Icon(
            Icons.mark_email_read_outlined,
            size: 65,
            color: AppColors.blue,
          ),
          const SizedBox(height: Space.xl),
          Text(
            sent ? 'İsteğin alındı' : 'Yeniden bağlanalım.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: Space.lg),
          if (sent) ...[
            const InfoNote(
              'Bu adresle kayıtlı bir hesap varsa şifre sıfırlama kodu e-posta ile gönderilir.',
            ),
            const SizedBox(height: Space.lg),
            PrimaryButton(
              'Kodu Gir',
              onPressed: () =>
                  openPage(context, '/reset-password', email.text.trim()),
            ),
          ] else ...[
            Field(
              'E-posta',
              Icons.mail_outline,
              controller: email,
              keyboardType: TextInputType.emailAddress,
            ),
            PrimaryButton(
              busy ? 'Gönderiliyor…' : 'Sıfırlama Kodu İste',
              onPressed: busy
                  ? null
                  : () {
                      if (!validEmail(email.text)) {
                        toast(context, 'Geçerli bir e-posta adresi gir.');
                        return;
                      }
                      final auth = StoreScope.of(context).auth;
                      runAccountAction(() async {
                        if (auth != null) await auth.forgot(email.text.trim());
                        if (mounted) setState(() => sent = true);
                      });
                    },
            ),
            TextButton(
              onPressed: busy
                  ? null
                  : () =>
                        openPage(context, '/reset-password', email.text.trim()),
              child: const Text('Sıfırlama Kodum Var'),
            ),
          ],
        ],
      ),
    ),
  );
}

class PasswordPage extends StatefulWidget {
  const PasswordPage({super.key, this.resetEmail});
  final String? resetEmail;

  @override
  State<PasswordPage> createState() => _PasswordPageState();
}

class _PasswordPageState extends State<PasswordPage>
    with AccountAction<PasswordPage> {
  final form = GlobalKey<FormState>();
  late final email = TextEditingController(text: widget.resetEmail);
  final code = TextEditingController();
  final current = TextEditingController();
  final password = TextEditingController();
  final confirmation = TextEditingController();
  bool get reset => widget.resetEmail != null;

  @override
  void dispose() {
    for (final controller in [email, code, current, password, confirmation]) {
      controller.dispose();
    }
    super.dispose();
  }

  void submit() {
    if (!form.currentState!.validate()) return;
    final auth = StoreScope.of(context).auth;
    if (auth == null) return;
    runAccountAction(() async {
      final fields = <String, Object?>{
        'password': password.text,
        'password_confirmation': confirmation.text,
      };
      if (reset) {
        await auth.reset({
          ...fields,
          'email': email.text.trim(),
          'token': code.text.trim(),
        });
      } else {
        await auth.changePassword({
          ...fields,
          'current_password': current.text,
        });
      }
      if (!mounted) return;
      toast(context, 'Şifren güncellendi.');
      if (reset) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
      } else {
        Navigator.pop(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: AppPage(
      title: reset ? 'Şifreyi Sıfırla' : 'Şifre Değiştir',
      child: Form(
        key: form,
        child: ListView(
          padding: Space.page,
          children: [
            if (reset) ...[
              Field(
                'E-posta',
                Icons.mail_outline,
                controller: email,
                keyboardType: TextInputType.emailAddress,
                validator: (value) => validEmail(value ?? '')
                    ? null
                    : 'Geçerli bir e-posta adresi gir.',
              ),
              Field(
                'Sıfırlama Kodu',
                Icons.key_outlined,
                controller: code,
                validator: requiredText,
              ),
            ] else
              Field(
                'Mevcut Şifre',
                Icons.lock_outline,
                controller: current,
                obscure: true,
                validator: requiredText,
              ),
            Field(
              'Yeni Şifre',
              Icons.lock_outline,
              controller: password,
              obscure: true,
              validator: newPasswordError,
            ),
            Field(
              'Yeni Şifre Tekrar',
              Icons.lock_outline,
              controller: confirmation,
              obscure: true,
              validator: (value) =>
                  value == password.text ? null : 'Yeni şifreler eşleşmiyor.',
            ),
            PrimaryButton(
              busy ? 'Kaydediliyor…' : 'Şifreyi Kaydet',
              onPressed: busy ? null : submit,
            ),
          ],
        ),
      ),
    ),
  );
}
