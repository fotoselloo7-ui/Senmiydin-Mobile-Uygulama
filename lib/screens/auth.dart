import 'dart:async';

import 'package:flutter/material.dart';

import '../data/social_sign_in.dart';

import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../core/brand_assets.dart';
import '../core/theme.dart';
import '../core/navigation.dart';
import '../data/account_api.dart';
import '../data/app_store.dart';
import '../widgets/account_action.dart';
import '../widgets/common.dart';
import '../widgets/location_ui.dart';

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
  late final AnimationController _controller;
  late final Animation<double> _gazeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    );
    _gazeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween<double>(0.0), weight: 250),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.0,
          end: -1.0,
        ).chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 300,
      ),
      TweenSequenceItem(tween: ConstantTween<double>(-1.0), weight: 200),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: -1.0,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 200,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 300,
      ),
      TweenSequenceItem(tween: ConstantTween<double>(1.0), weight: 200),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 250,
      ),
    ]).animate(_controller);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(restore());
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> restore() async {
    setState(() => error = null);
    final disableAnimations =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final animFuture =
        (disableAnimations || widget.initialGazeOffset != null)
        ? Future<void>.value()
        : _controller.forward().orCancel.catchError((_) {});
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

  static Offset _leftPupilCenter(double t) {
    if (t < 0) {
      final s = -t;
      return Offset(524.0 * (1 - s) + 488.0 * s, 824.0 * (1 - s) + 826.0 * s);
    }
    final s = t;
    return Offset(524.0 * (1 - s) + 562.0 * s, 824.0 * (1 - s) + 815.0 * s);
  }

  static Offset _rightPupilCenter(double t) {
    if (t < 0) {
      final s = -t;
      return Offset(656.0 * (1 - s) + 624.0 * s, 791.0 * (1 - s) + 793.0 * s);
    }
    final s = t;
    return Offset(656.0 * (1 - s) + 688.0 * s, 791.0 * (1 - s) + 784.0 * s);
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return Scaffold(
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
                child: SizedBox(
                  width: 1080,
                  height: 1920,
                  child: AnimatedBuilder(
                    animation: _gazeAnimation,
                    builder: (context, _) {
                      final t =
                          widget.initialGazeOffset ??
                          (disableAnimations ? 0.0 : _gazeAnimation.value);
                      final lp = _leftPupilCenter(t);
                      final rp = _rightPupilCenter(t);

                      // Left sclera ellipse: center (515.8, 831.2), rx=78.5, ry=76.6
                      const lRect = Rect.fromLTWH(
                        515.8 - 78.5,
                        831.2 - 76.6,
                        157.0,
                        153.2,
                      );
                      // Right sclera ellipse: center (648.53, 793.66), rx=64.9, ry=65.4
                      const rRect = Rect.fromLTWH(
                        648.53 - 64.9,
                        793.66 - 65.4,
                        129.8,
                        130.8,
                      );

                      return Stack(
                        key: ValueKey<double>(
                          double.parse(t.toStringAsFixed(2)),
                        ),
                        children: [
                          Positioned.fill(
                            child: Image.asset(
                              BrandAssets.splashEyeless,
                              fit: BoxFit.fill,
                              gaplessPlayback: true,
                              filterQuality: FilterQuality.medium,
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
                                    left: lp.dx - lRect.left - 28.0,
                                    top: lp.dy - lRect.top - 33.0,
                                    width: 56.0,
                                    height: 66.0,
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
                                    key: const Key('splash-pupil-right'),
                                    left: rp.dx - rRect.left - 24.0,
                                    top: rp.dy - rRect.top - 29.0,
                                    width: 48.0,
                                    height: 58.0,
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
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(Space.xl),
                child: Brand(size: 30),
              ),
              Expanded(
                child: PageView(
                  onPageChanged: (v) => setState(() => index = v),
                  controller: controller,
                  children: const [
                    _WelcomeSlide(
                      Icons.favorite_border_rounded,
                      'Bir an. Bir bakış.\nBelki de sen.',
                      'Gerçek hayatta yolların kesiştiği insanlarla, yarım kalan hikâyene yeniden merhaba de.',
                    ),
                    _WelcomeSlide(
                      Icons.location_on_outlined,
                      'Şehrinin hikâyelerine\nyakından bak.',
                      'Düşünceler, anılar ve güzel tesadüfler. Aynı şehrin insanlarını keşfet.',
                    ),
                    _WelcomeSlide(
                      Icons.people_outline_rounded,
                      'Güzel karşılaşmalar\nbir merhabayla başlar.',
                      'İlgi alanlarını paylaş, yeni bağlar kur. Konumunun görünürlüğü her zaman senin kontrolünde.',
                    ),
                  ],
                ),
              ),
              Padding(
                padding: Space.page,
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        3,
                        (i) => AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: i == index ? 25 : 7,
                          height: 7,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: i == index ? AppColors.blue : AppColors.line,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: Space.xl),
                    PrimaryButton(
                      index < 2 ? 'Devam Et' : 'Hesap Oluştur',
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
                    const SizedBox(height: Space.sm),
                    SecondaryButton(
                      'Giriş Yap',
                      onPressed: () => openPage(context, '/login'),
                      icon: Icons.login_rounded,
                    ),
                    TextButton(
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
                      style: TextStyle(fontSize: 11, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _WelcomeSlide extends StatelessWidget {
  const _WelcomeSlide(this.icon, this.title, this.text);
  final IconData icon;
  final String title, text;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.xxl),
        child: Column(
          children: [
            const SizedBox(height: Space.lg),
            SizedBox(
              height: box.maxHeight > 360 ? 190 : 100,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 170,
                    height: 170,
                    decoration: const BoxDecoration(
                      color: AppColors.pale,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Icon(
                    icon,
                    size: box.maxHeight > 360 ? 82 : 66,
                    color: AppColors.blue,
                  ),
                  if (box.maxHeight > 360) ...[
                    Positioned(
                      top: 4,
                      left: 35,
                      child: Transform.rotate(
                        angle: -.15,
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: AppShape.card(),
                          child: Avatar(
                            StoreScope.of(context).people[1],
                            size: 47,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 3,
                      right: 32,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: AppShape.card(),
                        child: Avatar(
                          StoreScope.of(context).people[0],
                          size: 50,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: Space.xl),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: Space.lg),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 15,
                height: 1.6,
              ),
            ),
            const SizedBox(height: Space.lg),
          ],
        ),
      ),
    ),
  );
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
  final name = TextEditingController(),
      handle = TextEditingController(),
      email = TextEditingController(),
      password = TextEditingController();
  DateTime? birthday;
  String city = 'Alanya';
  bool accepted = false, obscure = true;
  @override
  void initState() {
    super.initState();
    email.text = widget.social?.email ?? '';
    name.text = widget.social?.name ?? '';
  }

  @override
  void dispose() {
    for (final c in [name, handle, email, password]) {
      c.dispose();
    }
    super.dispose();
  }

  void submit() {
    if (!form.currentState!.validate()) {
      return;
    }
    if (widget.register && birthday == null) {
      toast(context, 'Doğum tarihini seçmelisin.');
      return;
    }
    if (widget.register && !accepted) {
      toast(context, 'Devam etmek için koşulları kabul etmelisin.');
      return;
    }
    final store = StoreScope.of(context);
    if (store.connected) {
      runAccountAction(() async {
        if (widget.register) {
          await store.signIn(
            widget.social == null
                ? 'register'
                : 'social/${widget.social!.provider}',
            {
              ...?widget.social?.fields,
              'name': name.text.trim(),
              'username': handle.text.trim().replaceFirst(RegExp(r'^@'), ''),
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
      store.me.name = name.text.trim();
      store.me.handle = handle.text.trim().replaceFirst('@', '');
      store.me.city = city;
      store.city = city;
      store.refresh();
      openPage(context, '/complete');
    } else {
      store.login();
      home(context);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: AppPage(
      title: widget.register ? 'Kayıt Ol' : 'Giriş Yap',
      child: SingleChildScrollView(
        padding: Space.page,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Form(
          key: form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.register)
                const SetupProgress(step: 0)
              else ...[
                Text(
                  'Yeniden merhaba! 💙',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 6),
                const Text(
                  'Yarım kalan hikâyene kaldığın yerden devam et.',
                  style: TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: Space.xl),
              ],
              if (widget.register) ...[
                Field(
                  'Ad Soyad',
                  Icons.person_outline,
                  controller: name,
                  validator: requiredText,
                ),
                Field(
                  'Kullanıcı Adı',
                  Icons.alternate_email,
                  controller: handle,
                  validator: (v) =>
                      RegExp(r'^[a-zA-Z0-9_\.]{3,24}$')
                          .hasMatch((v ?? '').replaceFirst('@', ''))
                      ? null
                      : '3–24 harf, rakam, nokta veya alt çizgi kullan.',
                ),
              ],
              Field(
                widget.register ? 'E-posta' : 'E-posta veya kullanıcı adı',
                Icons.mail_outline,
                controller: email,
                keyboardType: TextInputType.emailAddress,
                validator: widget.register
                    ? (v) => validEmail(v ?? '')
                          ? null
                          : 'Geçerli bir e-posta adresi gir.'
                    : requiredText,
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: Space.md),
                child: TextFormField(
                  controller: password,
                  textInputAction: widget.register
                      ? TextInputAction.next
                      : TextInputAction.done,
                  onFieldSubmitted: widget.register ? null : (_) => submit(),
                  obscureText: obscure,
                  validator: widget.register ? newPasswordError : requiredText,
                  decoration: InputDecoration(
                    labelText: 'Şifre',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      tooltip: 'Şifreyi göster / gizle',
                      onPressed: () => setState(() => obscure = !obscure),
                      icon: Icon(
                        obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                ),
              ),
              if (widget.register) ...[
                SettingsRow(
                  birthday == null
                      ? 'Doğum Tarihi'
                      : '${birthday!.day}.${birthday!.month}.${birthday!.year}',
                  Icons.calendar_month_outlined,
                  onTap: busy
                      ? null
                      : () async {
                          final now = DateTime.now();
                          final value = await showDatePicker(
                            context: context,
                            initialDate: DateTime(
                              now.year - 20,
                              now.month,
                              now.day,
                            ),
                            firstDate: DateTime(1920),
                            lastDate: DateTime(
                              now.year - 18,
                              now.month,
                              now.day,
                            ),
                            helpText:
                                'Devam etmek için 18 yaşını doldurmalısın',
                          );
                          if (mounted && value != null) {
                            setState(() => birthday = value);
                          }
                        },
                ),
                SettingsRow(
                  city,
                  Icons.location_on_outlined,
                  onTap: busy
                      ? null
                      : () async {
                          final value = await chooseCity(context, city);
                          if (mounted && value != null) {
                            setState(() => city = value);
                          }
                        },
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Checkbox(
                      value: accepted,
                      onChanged: busy
                          ? null
                          : (v) => setState(() => accepted = v!),
                    ),
                    const Expanded(
                      child: Text(
                        '18 yaşını doldurdum ve aşağıdaki koşulları kabul ediyorum.',
                        style: TextStyle(fontSize: 12, color: AppColors.muted),
                      ),
                    ),
                  ],
                ),
                Wrap(
                  children: [
                    TextButton(
                      onPressed: () => showLegal(context, 'Kullanım Koşulları'),
                      child: const Text('Kullanım Koşulları'),
                    ),
                    TextButton(
                      onPressed: () =>
                          showLegal(context, 'Gizlilik Politikası'),
                      child: const Text('Gizlilik Politikası'),
                    ),
                  ],
                ),
              ] else
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: busy ? null : () => openPage(context, '/forgot'),
                    child: const Text('Şifremi unuttum'),
                  ),
                ),
              const SizedBox(height: Space.sm),
              PrimaryButton(
                busy
                    ? 'Lütfen bekle…'
                    : widget.register
                    ? 'Devam Et'
                    : 'Giriş Yap',
                onPressed: busy ? null : submit,
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: Space.lg),
                child: Row(
                  children: [
                    Expanded(child: Divider()),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: Space.md),
                      child: Text(
                        'veya',
                        style: TextStyle(color: AppColors.muted, fontSize: 12),
                      ),
                    ),
                    Expanded(child: Divider()),
                  ],
                ),
              ),
              SecondaryButton(
                'Google ile devam et',
                icon: Icons.g_mobiledata_rounded,
                onPressed: busy
                    ? null
                    : () => openPage(context, '/social', 'Google'),
              ),
              const SizedBox(height: Space.sm),
              SecondaryButton(
                'Apple ile devam et',
                icon: Icons.apple,
                onPressed: busy
                    ? null
                    : () => openPage(context, '/social', 'Apple'),
              ),
              const SizedBox(height: Space.lg),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    widget.register
                        ? 'Zaten hesabın var mı?'
                        : 'Henüz hesabın yok mu?',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => openPage(
                            context,
                            widget.register ? '/login' : '/register',
                          ),
                    child: Text(widget.register ? 'Giriş Yap' : 'Kayıt Ol'),
                  ),
                ],
              ),
              const SizedBox(height: Space.sm),
            ],
          ),
        ),
      ),
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
              Wrap(
                spacing: Space.sm,
                children: AppStore.connectionChoices.values
                    .map(
                      (c) => FilterChip(
                        label: Text(
                          c,
                          style: TextStyle(
                            color: connections.contains(c)
                                ? Colors.white
                                : AppColors.navy,
                          ),
                        ),
                        checkmarkColor: Colors.white,
                        selected: connections.contains(c),
                        onSelected: busy
                            ? null
                            : (v) => setState(
                                () => v
                                    ? connections.add(c)
                                    : connections.remove(c),
                              ),
                      ),
                    )
                    .toList(),
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
              : 'Kaydet (${selected.length})',
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
                    'İlgi alanların profilinde görünsün ve ortak noktalarımız bizi buluştursun.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.muted),
                  ),
                  const SizedBox(height: Space.lg),
                  TextField(
                    onChanged: (v) => setState(() => query = v),
                    decoration: const InputDecoration(
                      hintText: 'Hobi ara',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                  const SizedBox(height: Space.md),
                  InfoNote(
                    '${selected.length} ilgi alanı seçtin. En az 5 seçim yap.',
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
                    : 'Cihaz konumun şehir keşfi ve yakınlık için sunucuya gönderilir. Geçtiğim Yerler başlangıçta kapalıdır. Ayarlardan açarsan uygulama açıkken yaklaşık geçmiş bölgeler kaydedilir ve ilgili hikâyeler önerilebilir. iOS’ta arka planda konum kaydı yapılmaz; kesin konumun diğer kullanıcılara gösterilmez.',
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
      title: '${widget.provider} ile Devam Et',
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
                  ? '${widget.provider} ile giriş'
                  : 'Giriş şu anda kullanılamıyor',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: Space.md),
            InfoNote(
              enabled
                  ? 'Kimliğini güvenli şekilde doğrula. Yeni hesap için kayıt bilgilerini tamamlaman istenir.'
                  : '${widget.provider} ile giriş şu anda kullanılamıyor. E-posta ve şifrenle devam edebilirsin.',
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
