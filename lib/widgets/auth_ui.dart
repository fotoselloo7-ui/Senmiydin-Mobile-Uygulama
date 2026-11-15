import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' hide Text;

import '../core/app_locale.dart';
import '../core/theme.dart';
import 'common.dart';
import 'translated_text.dart';

/// Shared building blocks of the sign-in / sign-up screens: a soft lilac backdrop with light waves, rounded
/// outlined fields, a lilac gradient call-to-action and the Google / Apple buttons. Purely visual: all behaviour
/// stays in the screens.

const _ink = Color(0xFF1B1140);
const _fieldFill = Color(0xFFFFFFFF);

/// Lilac wash with two very light waves (top and bottom), behind the whole screen.
class AuthBackdrop extends StatelessWidget {
  const AuthBackdrop({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFF3ECFF), Color(0xFFFBF9FF), Color(0xFFFFFFFF)],
        stops: [0, .42, 1],
      ),
    ),
    child: Stack(
      children: [
        const Positioned.fill(
          child: IgnorePointer(child: CustomPaint(painter: _WavePainter())),
        ),
        child,
      ],
    ),
  );
}

class _WavePainter extends CustomPainter {
  const _WavePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final top = Path()
      ..moveTo(0, 0)
      ..lineTo(w, 0)
      ..lineTo(w, h * .13)
      ..cubicTo(w * .78, h * .24, w * .45, h * .07, 0, h * .2)
      ..close();
    canvas.drawPath(
      top,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0x3DB794F6), Color(0x1FC7D2FE)],
        ).createShader(Rect.fromLTWH(0, 0, w, h * .25)),
    );
    final bottom = Path()
      ..moveTo(0, h)
      ..lineTo(0, h * .93)
      ..cubicTo(w * .3, h * .87, w * .62, h * 1.0, w, h * .9)
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(
      bottom,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.bottomRight,
          end: Alignment.topLeft,
          colors: [Color(0x33A855F7), Color(0x14C7D2FE)],
        ).createShader(Rect.fromLTWH(0, h * .85, w, h * .15)),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Page frame: backdrop, centred logo with an optional back button, a width limit for tablets and a scroll view that
/// follows the keyboard (nothing overflows with the keyboard open or with large text).
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({super.key, required this.children, this.showBack = true});
  final List<Widget> children;
  final bool showBack;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    resizeToAvoidBottomInset: true,
    body: AuthBackdrop(
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 64,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        const Brand(size: 28),
                        if (showBack && Navigator.canPop(context))
                          Align(
                            alignment: Alignment.centerLeft,
                            child: IconButton.filledTonal(
                              tooltip: tr('Geri'),
                              onPressed: () => Navigator.maybePop(context),
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.white.withValues(
                                  alpha: .85,
                                ),
                                foregroundColor: AppColors.brandPurple,
                              ),
                              icon: const Icon(
                                Icons.arrow_back_ios_new_rounded,
                                size: 18,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  ...children,
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class AuthTitle extends StatelessWidget {
  const AuthTitle(this.title, this.subtitle, {super.key});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(
          fontSize: 28,
          height: 1.15,
          fontWeight: FontWeight.w800,
          color: _ink,
          letterSpacing: -.6,
        ),
      ),
      const SizedBox(height: 10),
      Text(
        subtitle,
        style: const TextStyle(
          fontSize: 15,
          height: 1.4,
          color: AppColors.textSecondary,
        ),
      ),
    ],
  );
}

InputDecoration authDecoration(
  String label,
  IconData icon, {
  Widget? suffix,
  String? errorText,
}) {
  OutlineInputBorder border(Color color, [double width = 1.2]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: color, width: width),
      );
  return InputDecoration(
    labelText: tr(label),
    errorText: errorText == null ? null : tr(errorText),
    errorMaxLines: 3,
    filled: true,
    fillColor: _fieldFill,
    prefixIcon: Icon(icon, size: 21, color: AppColors.brandPurple),
    suffixIcon: suffix,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
    floatingLabelStyle: const TextStyle(
      color: AppColors.brandPurple,
      fontWeight: FontWeight.w700,
    ),
    labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 15),
    enabledBorder: border(AppColors.borderLilac),
    border: border(AppColors.borderLilac),
    focusedBorder: border(AppColors.brandPurple, 1.6),
    errorBorder: border(AppColors.red),
    focusedErrorBorder: border(AppColors.red, 1.6),
    disabledBorder: border(AppColors.borderLilac),
  );
}

/// Rounded outlined text field; a password field gets the show / hide control.
class AuthField extends StatefulWidget {
  const AuthField(
    this.label,
    this.icon, {
    super.key,
    this.controller,
    this.obscure = false,
    this.keyboardType,
    this.validator,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
    this.enabled = true,
    this.autofillHints,
  });
  final String label;
  final IconData icon;
  final TextEditingController? controller;
  final bool obscure;
  final TextInputType? keyboardType;
  final FormFieldValidator<String>? validator;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;
  final Iterable<String>? autofillHints;

  @override
  State<AuthField> createState() => _AuthFieldState();
}

class _AuthFieldState extends State<AuthField> {
  bool visible = false;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: widget.controller,
      enabled: widget.enabled,
      obscureText: widget.obscure && !visible,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      onFieldSubmitted: widget.onSubmitted,
      autofillHints: widget.autofillHints,
      autocorrect:
          !widget.obscure && widget.keyboardType != TextInputType.emailAddress,
      enableSuggestions: !widget.obscure,
      validator: widget.validator == null
          ? null
          : (value) {
              final message = widget.validator!(value);
              return message == null ? null : tr(message);
            },
      style: const TextStyle(fontSize: 16, color: _ink),
      decoration: authDecoration(
        widget.label,
        widget.icon,
        suffix: !widget.obscure
            ? null
            : IconButton(
                tooltip: visible ? tr('Şifreyi gizle') : tr('Şifreyi göster'),
                onPressed: () => setState(() => visible = !visible),
                icon: Icon(
                  visible
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AppColors.textSecondary,
                ),
              ),
      ),
    ),
  );
}

/// A field-looking row that opens a picker (birth date).
class AuthSelectField extends StatelessWidget {
  const AuthSelectField({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.value,
    this.errorText,
  });
  final String label;
  final IconData icon;
  final String? value;
  final String? errorText;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Semantics(
      button: true,
      label: tr(label),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: InputDecorator(
          decoration: authDecoration(
            label,
            icon,
            errorText: errorText,
            suffix: const Icon(
              Icons.expand_more_rounded,
              color: AppColors.textSecondary,
            ),
          ).copyWith(enabled: onTap != null),
          isEmpty: value == null,
          child: Text(
            value ?? '',
            style: const TextStyle(fontSize: 16, color: _ink),
          ),
        ),
      ),
    ),
  );
}

/// Primary call-to-action: lilac gradient pill with an optional icon and a busy / disabled state.
class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton(
    this.label, {
    super.key,
    required this.onPressed,
    this.icon,
    this.busy = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    return Semantics(
      button: true,
      enabled: enabled,
      label: tr(label),
      excludeSemantics: true,
      child: Opacity(
        opacity: onPressed == null && !busy ? .55 : 1,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Color(0xFF5E17B8), Color(0xFF8B2FE0)],
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: AppColors.brandPurple.withValues(alpha: .30),
                blurRadius: 16,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(28),
              onTap: enabled ? onPressed : null,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 54),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (busy)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                      else if (icon != null)
                        Icon(icon, color: Colors.white, size: 21),
                      if (busy || icon != null) const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            letterSpacing: .1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum SocialProvider { google, apple }

/// Google (light) and Apple (dark) buttons in the familiar standard layout: glyph, label, full width.
class AuthSocialButton extends StatelessWidget {
  const AuthSocialButton(
    this.provider,
    this.label, {
    super.key,
    required this.onPressed,
  });
  final SocialProvider provider;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final dark = provider == SocialProvider.apple;
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: tr(label),
      excludeSemantics: true,
      child: Opacity(
        opacity: onPressed == null ? .55 : 1,
        child: Material(
          color: dark ? const Color(0xFF14111F) : Colors.white,
          borderRadius: BorderRadius.circular(28),
          elevation: 0,
          child: InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: onPressed,
            child: Container(
              constraints: const BoxConstraints(minHeight: 52),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: dark ? const Color(0xFF14111F) : AppColors.borderLilac,
                  width: 1.2,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (dark)
                    const Icon(Icons.apple, color: Colors.white, size: 25)
                  else
                    const _GoogleGlyph(),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: dark ? Colors.white : _ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
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
}

/// A plain multicolour "G" (a letter, not the official artwork).
class _GoogleGlyph extends StatelessWidget {
  const _GoogleGlyph();

  @override
  Widget build(BuildContext context) => ShaderMask(
    blendMode: BlendMode.srcIn,
    shaderCallback: (rect) => const LinearGradient(
      begin: Alignment.topRight,
      end: Alignment.bottomLeft,
      colors: [
        Color(0xFFEA4335),
        Color(0xFFFBBC05),
        Color(0xFF34A853),
        Color(0xFF4285F4),
      ],
      stops: [.15, .4, .65, .9],
    ).createShader(rect),
    child: const SizedBox(
      width: 24,
      child: Text(
        'G',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 24,
          height: 1.1,
          fontWeight: FontWeight.w900,
          color: Colors.white,
        ),
      ),
    ),
  );
}

class AuthDivider extends StatelessWidget {
  const AuthDivider(this.label, {super.key});
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: LayoutBuilder(
      builder: (context, box) => Row(
        children: [
          const Expanded(child: Divider(color: AppColors.borderLilac)),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: box.maxWidth * .72),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const Expanded(child: Divider(color: AppColors.borderLilac)),
        ],
      ),
    ),
  );
}

/// Inline message (error / information) shown above the form: lilac for information, red for a failure.
class AuthNotice extends StatelessWidget {
  const AuthNotice(this.message, {super.key, this.error = false});
  final String message;
  final bool error;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: error ? const Color(0xFFFEF2F2) : AppColors.surfaceLilac,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: error ? const Color(0xFFFECACA) : AppColors.borderLilac,
      ),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          error ? Icons.error_outline_rounded : Icons.info_outline_rounded,
          size: 20,
          color: error ? AppColors.red : AppColors.brandPurple,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.35,
              color: error ? const Color(0xFF991B1B) : _ink,
            ),
          ),
        ),
      ],
    ),
  );
}

/// One link inside a sentence.
class AuthLink {
  const AuthLink(this.text, this.onTap);
  final String text;
  final VoidCallback onTap;
}

/// A sentence with tappable underlined parts. [template] is a translated string with `{0}`, `{1}`… markers; each
/// marker is replaced by a link (an [AuthLink]) or plain text (a [String]) and the order may differ per language.
class AuthRichText extends StatefulWidget {
  const AuthRichText(
    this.template,
    this.parts, {
    super.key,
    this.style,
    this.textAlign,
  });
  final String template;
  final List<Object> parts;
  final TextStyle? style;
  final TextAlign? textAlign;

  @override
  State<AuthRichText> createState() => _AuthRichTextState();
}

class _AuthRichTextState extends State<AuthRichText> {
  final _recognizers = <TapGestureRecognizer>[];

  void _clear() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  @override
  void dispose() {
    _clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _clear();
    final spans = <InlineSpan>[];
    final pattern = RegExp(r'\{(\d+)\}');
    var last = 0;
    final template = tr(widget.template);
    for (final match in pattern.allMatches(template)) {
      if (match.start > last) {
        spans.add(TextSpan(text: template.substring(last, match.start)));
      }
      final part = widget.parts[int.parse(match.group(1)!)];
      if (part is AuthLink) {
        final recognizer = TapGestureRecognizer()..onTap = part.onTap;
        _recognizers.add(recognizer);
        spans.add(
          TextSpan(
            text: tr(part.text),
            recognizer: recognizer,
            style: const TextStyle(
              decoration: TextDecoration.underline,
              decorationColor: AppColors.brandLilac,
              color: AppColors.brandPurpleDeep,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
      } else {
        spans.add(TextSpan(text: '$part'));
      }
      last = match.end;
    }
    if (last < template.length) {
      spans.add(TextSpan(text: template.substring(last)));
    }
    return Text.rich(
      TextSpan(children: spans),
      textAlign: widget.textAlign,
      style:
          widget.style ??
          const TextStyle(
            fontSize: 12.5,
            height: 1.4,
            color: AppColors.textSecondary,
          ),
    );
  }
}

/// "16+" chip used by the legal note.
class AgeBadge extends StatelessWidget {
  const AgeBadge(this.age, {super.key});
  final int age;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: AppColors.surfaceLilac,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.borderLilac),
    ),
    child: Text(
      '$age+',
      style: const TextStyle(
        color: AppColors.brandPurple,
        fontSize: 12,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

/// Outlined, light call-to-action next to [AuthPrimaryButton] (same height and radius).
class AuthSecondaryButton extends StatelessWidget {
  const AuthSecondaryButton(
    this.label, {
    super.key,
    required this.onPressed,
    this.icon,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onPressed != null,
    label: tr(label),
    excludeSemantics: true,
    child: Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onPressed,
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.borderLilac, width: 1.4),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, color: AppColors.brandPurple, size: 20),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.brandPurple,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
