import '../core/brand_assets.dart';

import 'package:flutter/material.dart' hide Text;
import 'package:flutter/material.dart' as material show Text;

import 'translated_text.dart';

import '../core/theme.dart';
import '../core/navigation.dart';
import '../data/account_api.dart';
import '../data/app_store.dart';
import '../data/models.dart';
import '../core/app_locale.dart';

class Brand extends StatelessWidget {
  const Brand({super.key, this.size = 27, this.alignment = Alignment.center});
  final double size;
  final Alignment alignment;
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'SenMiydin?',
    excludeSemantics: true,
    child: FittedBox(
      fit: BoxFit.scaleDown,
      alignment: alignment,
      child: Image.asset(
        BrandAssets.logoPrimaryLight,
        height: size * 1.52,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
      ),
    ),
  );
}

class AppPage extends StatelessWidget {
  const AppPage({
    super.key,
    required this.title,
    required this.child,
    this.actions,
    this.bottom,
    this.brand = true,
    this.compactHeader = false,
  });
  final String title;
  final Widget child;
  final List<Widget>? actions;
  final Widget? bottom;
  final bool brand;
  final bool compactHeader;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: compactHeader
        ? AppBar(title: const Brand(size: 25), actions: actions)
        : AppBar(
            automaticallyImplyLeading: false,
            toolbarHeight:
                (brand ? 104.0 : AppDimensions.topBar) +
                24 * (MediaQuery.textScalerOf(context).scale(1) - 1),
            titleSpacing: 0,
            title: Column(
              children: [
                if (brand)
                  const Padding(
                    padding: EdgeInsets.only(top: 4, bottom: 8),
                    child: Brand(size: 25),
                  ),
                Row(
                  children: [
                    IconButton(
                      tooltip: tr('Geri'),
                      onPressed: () => Navigator.maybePop(context),
                      icon: const Icon(Icons.chevron_left_rounded, size: 29),
                    ),
                    Expanded(
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    if (actions == null)
                      const SizedBox(width: 48)
                    else
                      ...actions!,
                  ],
                ),
              ],
            ),
          ),
    body: SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: child,
        ),
      ),
    ),
    bottomNavigationBar: bottom == null
        ? null
        : SafeArea(top: false, minimum: Space.page, child: bottom!),
  );
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton(
    this.label, {
    super.key,
    required this.onPressed,
    this.icon,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: icon == null
        ? FilledButton(
            onPressed: onPressed,
            child: Text(label, textAlign: TextAlign.center),
          )
        : FilledButton.icon(
            onPressed: onPressed,
            icon: Icon(icon, size: 19),
            label: Text(label, textAlign: TextAlign.center),
          ),
  );
}

class SecondaryButton extends StatelessWidget {
  const SecondaryButton(
    this.label, {
    super.key,
    required this.onPressed,
    this.icon,
    this.tonal = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool tonal;
  @override
  Widget build(BuildContext context) {
    final style = OutlinedButton.styleFrom(
      backgroundColor: tonal ? AppColors.pale : Colors.white,
      foregroundColor: tonal ? AppColors.action : AppColors.navy,
      side: BorderSide(color: tonal ? const Color(0xFFD5E3F7) : AppColors.line),
    );
    return SizedBox(
      width: double.infinity,
      child: icon == null
          ? OutlinedButton(
              onPressed: onPressed,
              style: style,
              child: Text(label, textAlign: TextAlign.center),
            )
          : OutlinedButton.icon(
              onPressed: onPressed,
              style: style,
              icon: Icon(icon, size: 19),
              label: Text(label, textAlign: TextAlign.center),
            ),
    );
  }
}

class DestructiveButton extends StatelessWidget {
  const DestructiveButton(
    this.label, {
    super.key,
    required this.onPressed,
    this.icon = Icons.delete_outline,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.danger,
        foregroundColor: Colors.white,
      ),
      onPressed: onPressed,
      icon: icon == null ? const SizedBox.shrink() : Icon(icon, size: 19),
      label: Text(label, textAlign: TextAlign.center),
    ),
  );
}

ImageProvider? profileImage(String path) {
  if (path.isEmpty) return null;
  final uri = Uri.tryParse(path);
  return uri?.scheme == 'https' || uri?.scheme == 'http'
      ? NetworkImage(path)
      : AssetImage(path);
}

String turkishSearchKey(String value) => value
    .replaceAll('İ', 'i')
    .toLowerCase()
    .replaceAll('ı', 'i')
    .replaceAll('ş', 's')
    .replaceAll('ğ', 'g')
    .replaceAll('ü', 'u')
    .replaceAll('ö', 'o')
    .replaceAll('ç', 'c')
    .replaceAll('@', '')
    .trim();

class Avatar extends StatelessWidget {
  const Avatar(
    this.person, {
    super.key,
    this.size = 44,
    this.online = false,
    this.onTap,
  });
  final Person? person;
  final double size;
  final bool online;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final image = profileImage(person?.photo ?? '');
    final initials = (person?.name ?? '')
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part.characters.first)
        .join()
        .toUpperCase();
    final placeholder = SizedBox.square(
      dimension: size,
      child: Center(
        child: initials.isEmpty
            ? Icon(
                Icons.person_outline_rounded,
                size: size * .6,
                color: AppColors.action,
              )
            : Text(
                initials,
                style: TextStyle(
                  fontSize: size * .34,
                  fontWeight: FontWeight.w700,
                  color: AppColors.action,
                ),
              ),
      ),
    );
    return Semantics(
      label: person?.name ?? 'Anonim',
      button: onTap != null,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(
                    color: size >= 50
                        ? const Color(0xFFD2E3FA)
                        : const Color(0xFFE2ECF8),
                    width: size >= 50 ? 1.5 : 1,
                  ),
                  boxShadow: size >= 50
                      ? [
                          BoxShadow(
                            color: const Color(0xFF1877F2)
                                .withValues(alpha: .10),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                padding: EdgeInsets.all(size >= 50 ? 2.2 : 1.5),
                child: ClipOval(
                  child: ColoredBox(
                    color: AppColors.pale,
                    child: image == null
                        ? placeholder
                        : Image(
                            image: image,
                            width: size,
                            height: size,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => placeholder,
                          ),
                  ),
                ),
              ),
              if (online)
                Positioned(
                  right: 1,
                  bottom: 1,
                  child: Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      color: AppColors.green,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class UserRow extends StatelessWidget {
  const UserRow(
    this.person, {
    super.key,
    this.onTap,
    this.trailing,
    this.subtitle,
  });
  final Person person;
  final VoidCallback? onTap;
  final Widget? trailing;
  final String? subtitle;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(
      horizontal: Space.md,
      vertical: Space.xs,
    ),
    onTap: onTap,
    leading: Avatar(person, size: 46),
    title: Text(person.name, style: Theme.of(context).textTheme.titleMedium),
    subtitle: Text(
      subtitle ?? '@${person.handle}',
      style: Theme.of(context).textTheme.bodySmall,
    ),
    trailing: trailing ?? const Icon(Icons.chevron_right_rounded, size: 21),
  );
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(
    this.title, {
    super.key,
    this.icon,
    this.iconColor,
    this.action = 'Tümünü Gör',
    this.onTap,
  });
  final String title, action;
  final IconData? icon;
  final Color? iconColor;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: Space.sm, bottom: 6),
    child: Row(
      children: [
        if (icon != null) ...[
          Icon(icon, color: iconColor ?? AppColors.primary, size: 20),
          const SizedBox(width: 7),
        ],
        Expanded(
          child: Text(
            title,
            style: AppTypography.section.copyWith(
              fontSize: 16.5,
              fontWeight: FontWeight.w800,
              color: AppColors.navy,
            ),
          ),
        ),
        if (onTap != null)
          TextButton(
            onPressed: onTap,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              minimumSize: const Size(44, 40),
              padding: const EdgeInsets.symmetric(horizontal: Space.sm),
              textStyle: const TextStyle(
                fontFamily: 'NunitoSans',
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: Text(action),
          ),
      ],
    ),
  );
}

class InfoBanner extends StatelessWidget {
  const InfoBanner(
    this.title,
    this.subtitle, {
    super.key,
    this.icon = Icons.location_on_rounded,
    this.trailing,
    this.prominent = true,
  });
  final String title, subtitle;
  final IconData icon;
  final Widget? trailing;
  final bool prominent;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final stackAction =
          constraints.maxWidth < 340 ||
          MediaQuery.textScalerOf(context).scale(1) > 1.2;
      final leadingBadge = prominent
          ? SizedBox(
              width: 38,
              height: 38,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: .18),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: .32),
                      ),
                    ),
                  ),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                    child: Icon(icon, color: AppColors.primary, size: 17),
                  ),
                ],
              ),
            )
          : Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: const Color(0xFFD6E4F7)),
                color: Colors.white,
              ),
              child: Icon(icon, color: AppColors.action, size: 19),
            );
      final content = Row(
        children: [
          leadingBadge,
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: prominent ? 13.5 : 14.5,
                      fontWeight: FontWeight.w800,
                      color: prominent ? Colors.white : AppColors.navy,
                      height: 1.25,
                      letterSpacing: -.2,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'NunitoSans',
                    fontSize: 12,
                    height: 1.3,
                    color: prominent
                        ? const Color(0xFFE6F2FF)
                        : AppColors.muted,
                    fontWeight: prominent ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null && !stackAction) ...[
            const SizedBox(width: Space.sm),
            trailing!,
          ],
        ],
      );
      return ClipRRect(
        borderRadius: AppShape.rounded,
        child: Container(
          decoration: prominent
              ? BoxDecoration(
                  borderRadius: AppShape.rounded,
                  gradient: AppShape.bannerGradient,
                  boxShadow: AppShape.bannerShadow,
                )
              : BoxDecoration(
                  borderRadius: AppShape.rounded,
                  color: AppColors.pale,
                  border: Border.all(color: const Color(0xFFD8E5F7)),
                ),
          child: Stack(
            children: [
              if (prominent) ...[
                Positioned(
                  left: -18,
                  top: -22,
                  child: IgnorePointer(
                    child: Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: .08),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: -24,
                  bottom: -28,
                  child: IgnorePointer(
                    child: Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: .09),
                      ),
                    ),
                  ),
                ),
              ],
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: prominent ? 13 : 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    content,
                    if (trailing != null && stackAction)
                      Padding(
                        padding: const EdgeInsets.only(top: Space.sm),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: trailing!,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class InfoNote extends StatelessWidget {
  const InfoNote(
    this.text, {
    super.key,
    this.icon = Icons.info_outline_rounded,
  });
  final String text;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(Space.md),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: AppShape.control,
      border: Border.all(color: AppColors.line),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.action, size: 19),
        const SizedBox(width: Space.sm),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              height: 1.45,
              color: AppColors.navy,
            ),
          ),
        ),
      ],
    ),
  );
}

class InlineState extends StatelessWidget {
  const InlineState({
    super.key,
    required this.title,
    this.description,
    this.icon = Icons.info_outline_rounded,
    this.actionLabel,
    this.onAction,
  });
  final String title;
  final String? description;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: AppShape.rounded,
      border: Border.all(color: AppColors.line),
    ),
    child: Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.pale,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.action, size: 19),
        ),
        const SizedBox(width: Space.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                ),
              ),
              if (description != null && description!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(description!, style: AppTypography.metadata),
              ],
            ],
          ),
        ),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(width: Space.xs),
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: const Size(44, 40),
              textStyle: const TextStyle(
                fontFamily: 'NunitoSans',
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: Text(actionLabel!),
          ),
        ],
      ],
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState(
    this.title,
    this.description, {
    super.key,
    this.icon = Icons.explore_outlined,
    this.action,
  });
  final String title, description;
  final IconData icon;
  final Widget? action;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.xl,
        vertical: Space.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.pale,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: AppColors.action, size: 26),
          ),
          const SizedBox(height: Space.md),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTypography.section,
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              description,
              textAlign: TextAlign.center,
              style: AppTypography.secondaryBody,
            ),
          ],
          if (action != null) ...[
            const SizedBox(height: Space.lg),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 240),
              child: action!,
            ),
          ],
        ],
      ),
    ),
  );
}

class AppIconBox extends StatelessWidget {
  const AppIconBox({
    super.key,
    required this.icon,
    this.size = AppDimensions.iconMD,
    this.containerSize = AppDimensions.iconContainerMD,
    this.color = AppColors.navy,
    this.backgroundColor,
    this.radius = 12.0,
  });

  final IconData icon;
  final double size;
  final double containerSize;
  final Color color;
  final Color? backgroundColor;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: containerSize,
      height: containerSize,
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.surfaceIcon,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Center(
        child: Icon(icon, size: size, color: color),
      ),
    );
  }
}

class SettingsRow extends StatelessWidget {
  const SettingsRow(
    this.title,
    this.icon, {
    super.key,
    this.subtitle,
    this.onTap,
    this.trailing,
    this.danger = false,
  });
  final String title;
  final IconData icon;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool danger;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Space.sm),
    child: Container(
      decoration: AppShape.card(),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppShape.rounded,
        child: ListTile(
          minTileHeight: 56,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 4,
          ),
          onTap: onTap,
          leading: AppIconBox(
            icon: icon,
            size: AppDimensions.iconMD,
            containerSize: 40,
            radius: 12,
            color: danger ? AppColors.danger : AppColors.action,
            backgroundColor: danger
                ? AppColors.danger.withValues(alpha: 0.1)
                : AppColors.surfaceIcon,
          ),
          title: Text(
            title,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              color: danger ? AppColors.danger : AppColors.navy,
            ),
          ),
          subtitle: subtitle == null
              ? null
              : Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
          trailing:
              trailing ??
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: AppColors.muted,
              ),
        ),
      ),
    ),
  );
}

class PreferenceRow extends StatelessWidget {
  const PreferenceRow(
    this.title,
    this.value,
    this.onChanged, {
    super.key,
    this.subtitle,
  });
  final String title;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? subtitle;
  @override
  Widget build(BuildContext context) => SwitchListTile.adaptive(
    contentPadding: const EdgeInsets.symmetric(horizontal: Space.sm),
    title: Text(
      title,
      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
    ),
    subtitle: subtitle == null
        ? null
        : Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
    value: value,
    activeTrackColor: AppColors.action,
    onChanged: onChanged,
  );
}

/// Multi-select options laid out in an even grid: an even number of options (4 -> 2x2, 6 -> 2x3) never leaves one
/// orphan option alone on the last row, and every tile in a row has the same width and height. Odd counts fall back
/// to a centred wrap. Used where balance matters (profile "Aradığın bağlantılar"); [ChoicePills] is untouched.
class BalancedChoiceGrid extends StatelessWidget {
  const BalancedChoiceGrid({
    super.key,
    required this.options,
    required this.isSelected,
    required this.onToggle,
    this.enabled = true,
  });
  final List<String> options;
  final bool Function(String option) isSelected;
  final void Function(String option, bool selected) onToggle;
  final bool enabled;

  Widget _tile(String option) {
    final on = isSelected(option);
    return Semantics(
      button: true,
      selected: on,
      label: tr(option),
      excludeSemantics: true,
      child: Material(
        color: on ? AppColors.action : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: on ? AppColors.action : AppColors.line),
        ),
        child: InkWell(
          key: ValueKey('choice-$option'),
          customBorder: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          onTap: enabled ? () => onToggle(option, !on) : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (on) ...[
                    const Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 4),
                  ],
                  Flexible(
                    child: Text(
                      option,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'NunitoSans',
                        fontSize: 13,
                        height: 1.2,
                        fontWeight: on ? FontWeight.w800 : FontWeight.w600,
                        color: on ? Colors.white : AppColors.navy,
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

  @override
  Widget build(BuildContext context) {
    if (options.length.isOdd || options.length < 2) {
      return Wrap(
        alignment: WrapAlignment.center,
        spacing: Space.sm,
        runSpacing: Space.sm,
        children: [for (final o in options) _tile(o)],
      );
    }
    return Column(
      children: [
        for (var i = 0; i < options.length; i += 2) ...[
          if (i > 0) const SizedBox(height: Space.sm),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _tile(options[i])),
                const SizedBox(width: Space.sm),
                Expanded(child: _tile(options[i + 1])),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class ChoicePills extends StatelessWidget {
  const ChoicePills({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.singleRow = false,
  });
  final List<String> options;
  final String value;
  final ValueChanged<String> onChanged;

  /// Keep every option on ONE line: compact paddings, and a horizontal scroll (never a second row) on very narrow screens.
  final bool singleRow;
  @override
  Widget build(BuildContext context) {
    final chips = options.map(
      (v) => ChoiceChip(
        label: Text(v),
        labelPadding: singleRow
            ? const EdgeInsets.symmetric(horizontal: 1)
            : null,
        padding: singleRow ? const EdgeInsets.symmetric(horizontal: 6) : null,
        selectedColor: AppColors.action,
        backgroundColor: AppColors.surface,
        side: BorderSide(color: value == v ? AppColors.action : AppColors.line),
        selected: value == v,
        showCheckmark: false,
        labelStyle: TextStyle(
          fontFamily: 'NunitoSans',
          fontSize: 12.5,
          fontWeight: value == v ? FontWeight.w700 : FontWeight.w600,
          color: value == v ? Colors.white : AppColors.navy,
        ),
        onSelected: (_) => onChanged(v),
      ),
    );
    if (singleRow) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final (i, chip) in chips.indexed) ...[
              if (i > 0) const SizedBox(width: 6),
              chip,
            ],
          ],
        ),
      );
    }
    return Wrap(spacing: Space.sm, runSpacing: 4, children: chips.toList());
  }
}

IconData interestIcon(String interest) => switch (interest) {
  'Kahve' => Icons.coffee_outlined,
  'Müzik' => Icons.music_note_outlined,
  'Kitap' => Icons.menu_book_outlined,
  'Seyahat' => Icons.flight_outlined,
  'Fotoğraf' => Icons.camera_alt_outlined,
  'Sinema' => Icons.movie_outlined,
  'Fitness' || 'Spor' => Icons.fitness_center_outlined,
  'Kamp' => Icons.terrain_outlined,
  'Yemek' => Icons.restaurant_outlined,
  'Bisiklet' => Icons.directions_bike_outlined,
  'Kediler' || 'Köpekler' => Icons.pets_outlined,
  'Oyun' => Icons.sports_esports_outlined,
  'Girişimcilik' => Icons.rocket_launch_outlined,
  'Teknoloji' => Icons.devices_outlined,
  'Gece yürüyüşü' => Icons.nightlight_outlined,
  'Sanat' => Icons.palette_outlined,
  'Etkinlik' => Icons.event_outlined,
  _ => Icons.waves_outlined,
};

class InterestChip extends StatelessWidget {
  const InterestChip(
    this.label, {
    super.key,
    this.selected = false,
    this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final avatar = Icon(
      interestIcon(label),
      size: 18,
      color: selected ? Colors.white : AppColors.navy,
    );
    final text = Text(
      label,
      style: TextStyle(color: selected ? Colors.white : AppColors.navy),
    );
    if (onTap == null) {
      return Chip(
        backgroundColor: selected ? AppColors.action : AppColors.pale,
        avatar: avatar,
        label: text,
      );
    }
    return ActionChip(
      backgroundColor: selected ? AppColors.action : AppColors.pale,
      avatar: avatar,
      label: text,
      onPressed: onTap,
    );
  }
}

/// The location picker used everywhere a place is chosen (registration, profile, active area, posts, journeys).
/// Real places come from the SenMiydin API (OpenStreetMap data): city, district, town, suburb, neighbourhood, worldwide.
/// Searching is explicit (the search button or the keyboard's search key), never one request per keystroke.
Future<ChosenPlace?> choosePlace(
  BuildContext context, {
  String? current,
  String title = 'Konumunu seç',
}) {
  final store = StoreScope.of(context);
  return showModalBottomSheet<ChosenPlace>(
    context: context,
    isScrollControlled: true,
    builder: (_) => store.connected
        ? PlacePicker(store, title: title, current: current)
        : _CityPicker(store, current ?? ''),
  );
}

/// [choosePlace] for screens that only need the area name.
Future<String?> chooseCity(BuildContext context, String current) async =>
    (await choosePlace(context, current: current))?.city.name;

class PlacePicker extends StatefulWidget {
  const PlacePicker(this.store, {super.key, required this.title, this.current});
  final AppStore store;
  final String title;
  final String? current;

  @override
  State<PlacePicker> createState() => _PlacePickerState();
}

class _PlacePickerState extends State<PlacePicker> {
  final query = TextEditingController();
  List<PlaceResult>? results;
  String? error, searched;
  bool searching = false, locating = false, resolving = false;

  @override
  void dispose() {
    query.dispose();
    super.dispose();
  }

  bool get busy => searching || locating || resolving;

  Future<void> search() async {
    final text = query.text.trim();
    if (busy) return;
    FocusManager.instance.primaryFocus?.unfocus();
    if (text.characters.length < 2) {
      setState(() {
        error = 'Aramak için en az 2 harf yaz.';
        results = null;
      });
      return;
    }
    setState(() {
      searching = true;
      error = null;
    });
    try {
      final found = await widget.store.searchPlaces(text);
      if (!mounted) return;
      setState(() {
        results = found;
        searched = text;
      });
    } on ApiFailure catch (failure) {
      if (mounted) setState(() => error = failure.detail);
    } finally {
      if (mounted) setState(() => searching = false);
    }
  }

  Future<void> useDevice() async {
    if (busy) return;
    if (await widget.store.locationPermissionUndecided()) {
      if (!mounted) return;
      final allowed = await confirmAction(
        context,
        title: 'Konumun kullanılsın mı?',
        message: 'Bulunduğun mahalle veya ilçeyi bulmak için cihaz konumun bir kez kullanılır. Konum yaklaşık 1 km’ye yuvarlanarak gönderilir ve bu adımda kaydedilmez. İzin vermezsen yeri aramayla seçebilirsin.',
        action: 'Devam',
        scrollable: true,
      );
      if (!allowed || !mounted) return;
    }
    setState(() {
      locating = true;
      error = null;
    });
    try {
      final place = await widget.store.placeAtDevice();
      if (!mounted) return;
      if (place == null) {
        setState(
          () =>
              error = 'Bulunduğun yer tanınamadı. Yeri aramayla seçebilirsin.',
        );
        return;
      }
      setState(() => locating = false);
      await pick(place);
    } on ApiFailure catch (failure) {
      if (mounted) setState(() => error = failure.detail);
    } finally {
      if (mounted) setState(() => locating = false);
    }
  }

  Future<void> pick(PlaceResult place) async {
    if (resolving) return;
    setState(() {
      resolving = true;
      error = null;
    });
    try {
      final chosen = await widget.store.resolvePlace(place);
      if (mounted) Navigator.pop(context, chosen);
    } on ApiFailure catch (failure) {
      if (mounted) setState(() => error = failure.detail);
    } finally {
      if (mounted) setState(() => resolving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final found = results;
    return SafeArea(
      child: Padding(
        padding:
            Space.page +
            EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
              if ((widget.current ?? '').isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  trf('Şu an: {0}', [widget.current]),
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 12.5,
                  ),
                ),
              ],
              const SizedBox(height: Space.sm),
              TextField(
                key: const Key('place-search'),
                controller: query,
                enabled: !resolving,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => search(),
                decoration: InputDecoration(
                  hintText: tr('Şehir, ilçe veya mahalle ara'),
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    key: const Key('place-search-button'),
                    tooltip: tr('Ara'),
                    onPressed: busy ? null : search,
                    icon: const Icon(Icons.arrow_forward_rounded),
                  ),
                ),
              ),
              ListTile(
                key: const Key('place-use-device'),
                contentPadding: EdgeInsets.zero,
                enabled: !busy,
                leading: locating
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.4),
                      )
                    : const Icon(
                        Icons.my_location_rounded,
                        color: AppColors.blue,
                      ),
                title: const Text('Mevcut konumumu kullan'),
                subtitle: const Text('Bulunduğun mahalle veya ilçe önerilir.'),
                onTap: useDevice,
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: Space.sm),
                  child: Text(
                    error!,
                    key: const Key('place-error'),
                    style: const TextStyle(color: AppColors.red, fontSize: 13),
                  ),
                ),
              if (searching || resolving)
                const Padding(
                  padding: EdgeInsets.all(Space.lg),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (found != null && found.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: Space.md),
                  child: Text(
                    trf(
                      '“{0}” için sonuç bulunamadı. Farklı bir yazım veya daha büyük bir yer dene.',
                      [searched],
                    ),
                    style: const TextStyle(color: AppColors.muted),
                  ),
                )
              else if (found != null)
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: found.length,
                    itemBuilder: (context, index) {
                      final place = found[index];
                      return ListTile(
                        key: Key('place-result-$index'),
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.location_on_outlined,
                          color: AppColors.blue,
                        ),
                        // Place names are shown exactly as the map data gives them, never translated here.
                        title: material.Text(
                          place.name,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: place.context.isEmpty
                            ? null
                            : material.Text(place.context),
                        onTap: () => pick(place),
                      );
                    },
                  ),
                ),
              const SizedBox(height: Space.sm),
              const Text(
                '© OpenStreetMap katkıcıları',
                style: TextStyle(color: AppColors.muted, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Offline preview (no server): the small built-in list.
class _CityPicker extends StatefulWidget {
  const _CityPicker(this.store, this.current);
  final AppStore store;
  final String current;

  @override
  State<_CityPicker> createState() => _CityPickerState();
}

class _CityPickerState extends State<_CityPicker> {
  late Future<List<CatalogItem>> cities = widget.store.loadCities();

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: Space.page,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .56,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Konumunu seç', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: Space.sm),
            Flexible(
              child: FutureBuilder(
                future: cities,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return ListView(
                    shrinkWrap: true,
                    children: [
                      for (final city in snapshot.data!)
                        ListTile(
                          leading: const Icon(
                            Icons.location_on_outlined,
                            color: AppColors.blue,
                          ),
                          title: material.Text(city.name),
                          trailing: widget.current == city.name
                              ? const Icon(
                                  Icons.check_circle,
                                  color: AppColors.blue,
                                )
                              : null,
                          onTap: () =>
                              Navigator.pop(context, ChosenPlace(city)),
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
}

class Field extends StatefulWidget {
  const Field(
    this.label,
    this.icon, {
    super.key,
    this.controller,
    this.obscure = false,
    this.keyboardType,
    this.validator,
    this.maxLines = 1,
    this.maxLength,
    this.onChanged,
    this.textInputAction,
  });
  final String label;
  final IconData icon;
  final TextEditingController? controller;
  final bool obscure;
  final TextInputType? keyboardType;
  final FormFieldValidator<String>? validator;
  final int maxLines;
  final int? maxLength;
  final ValueChanged<String>? onChanged;
  final TextInputAction? textInputAction;
  @override
  State<Field> createState() => _FieldState();
}

class _FieldState extends State<Field> {
  bool visible = false;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Space.md),
    child: TextFormField(
      controller: widget.controller,
      obscureText: widget.obscure && !visible,
      keyboardType: widget.keyboardType,
      textInputAction:
          widget.textInputAction ??
          (widget.maxLines > 1
              ? TextInputAction.newline
              : TextInputAction.next),
      validator: widget.validator,
      maxLines: widget.maxLines,
      maxLength: widget.maxLength,
      onChanged: widget.onChanged,
      decoration: InputDecoration(
        labelText: tr(widget.label),
        prefixIcon: Icon(widget.icon, size: AppDimensions.icon),
        suffixIcon: !widget.obscure
            ? null
            : IconButton(
                tooltip: visible ? tr('Şifreyi gizle') : tr('Şifreyi göster'),
                onPressed: () => setState(() => visible = !visible),
                icon: Icon(
                  visible
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
              ),
      ),
    ),
  );
}

/// Static placeholders avoid continuous animation while data is fetched.
class LoadingState extends StatelessWidget {
  const LoadingState({
    super.key,
    this.label = 'İçerik yükleniyor',
    this.compact = false,
  });
  final String label;
  final bool compact;
  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    liveRegion: true,
    child: ExcludeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < (compact ? 1 : 3); i++)
              Padding(
                padding: const EdgeInsets.only(bottom: Space.lg),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 20,
                      backgroundColor: AppColors.pale,
                    ),
                    const SizedBox(width: Space.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 12,
                            width: 140,
                            decoration: BoxDecoration(
                              color: AppColors.pale,
                              borderRadius: BorderRadius.circular(
                                AppShape.compact,
                              ),
                            ),
                          ),
                          const SizedBox(height: Space.sm),
                          Container(
                            height: 10,
                            decoration: BoxDecoration(
                              color: AppColors.pale,
                              borderRadius: BorderRadius.circular(
                                AppShape.compact,
                              ),
                            ),
                          ),
                        ],
                      ),
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

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: Space.xl, bottom: Space.md),
    child: Text(
      text,
      style: AppTypography.metadata.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: .4,
      ),
    ),
  );
}

void showLegal(BuildContext context, String title) =>
    openPage(context, '/legal', title);
