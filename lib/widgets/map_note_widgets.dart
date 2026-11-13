import 'package:flutter/material.dart';

import '../core/navigation.dart';
import '../core/theme.dart';
import '../data/map_notes_api.dart';
import '../data/models.dart';
import 'common.dart';

/// Warm white letter surface: a brand moment inside the final design system (navy text, lilac details).
const mapNotePaper = Color(0xFFFFFCF8);

/// Brand-purple envelope pin. A single note is a plain envelope, several notes at the same approximate
/// point add a count badge. Standalone outline icon, never an emoji.
class MapNotePin extends StatelessWidget {
  const MapNotePin({
    super.key,
    required this.count,
    required this.onPressed,
    this.highlighted = false,
  });
  final int count;
  final bool highlighted;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    excludeSemantics: true,
    label: count == 1 ? 'Haritadaki not' : 'Haritadaki $count not',
    child: Tooltip(
      excludeFromSemantics: true,
      message: count == 1 ? 'Haritadaki not' : '$count not',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: SizedBox.square(
          dimension: AppDimensions.touch,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              if (highlighted)
                // A brief halo for a freshly left note; no animation, it is removed after about two seconds.
                Container(
                  key: const Key('map-note-halo'),
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.brandLilac.withValues(alpha: .22),
                    border: Border.all(
                      color: AppColors.brandLilac.withValues(alpha: .55),
                    ),
                  ),
                ),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.brandLilac, width: 1.6),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.brandPurple.withValues(alpha: .22),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.mail_outline_rounded,
                  size: AppDimensions.iconMD,
                  color: AppColors.brandPurple,
                ),
              ),
              if (count > 1)
                Positioned(
                  top: 1,
                  right: 0,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 20),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.brandPurple,
                      borderRadius: BorderRadius.circular(AppShape.pill),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Text(
                      '$count',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                      ),
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

class _Identity extends StatelessWidget {
  const _Identity({required this.person, this.onTap, this.badge});
  final Person? person;
  final VoidCallback? onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final who = person;
    if (who == null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: const BoxDecoration(
              color: AppColors.surfaceLilac,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person_outline_rounded,
              size: 17,
              color: AppColors.brandPurple,
            ),
          ),
          const SizedBox(width: 8),
          const Flexible(
            child: Text(
              'Anonim',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.cardTitle,
            ),
          ),
          if (badge != null) ...[
            const SizedBox(width: 6),
            Flexible(child: _Badge(badge!)),
          ],
        ],
      );
    }
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppShape.compact),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Avatar(who, size: 30),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  who.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.cardTitle,
                ),
                Text(
                  '@${who.handle}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.metadata,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: AppColors.surfaceLilac,
      borderRadius: BorderRadius.circular(AppShape.pill),
      border: Border.all(color: AppColors.borderLilac),
    ),
    child: Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: AppColors.brandPurpleDeep,
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

/// A digital letter: warm white paper, soft shadow, very thin lilac accent, envelope outline, navy text.
class MapNoteLetter extends StatelessWidget {
  const MapNoteLetter(
    this.note, {
    super.key,
    this.onTap,
    this.actions = const [],
    this.showPlace = true,
  });
  final MapNoteItem note;
  final VoidCallback? onTap;
  final List<Widget> actions;
  final bool showPlace;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: mapNotePaper,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: AppColors.borderLilac.withValues(alpha: .8)),
      boxShadow: [
        BoxShadow(
          color: AppColors.navy.withValues(alpha: .06),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    child: Material(
      type: MaterialType.transparency,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppIconBox(
                    icon: Icons.mail_outline_rounded,
                    size: AppDimensions.iconSM,
                    containerSize: AppDimensions.iconContainerSM,
                    color: AppColors.brandPurple,
                    backgroundColor: AppColors.surfaceLilac,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Identity(
                          person: note.author,
                          onTap: note.author == null
                              ? null
                              : () => openPage(
                                  context,
                                  '/profile',
                                  note.author!.id,
                                ),
                        ),
                        const SizedBox(height: 2),
                        // The letter's real date (a re-publication never rewrites it).
                        Text(
                          mapNoteTime(note.occurredAt),
                          style: AppTypography.metadata,
                        ),
                        if (note.republished)
                          Text(
                            'Tekrar paylaşıldı',
                            key: const Key('republished-mark'),
                            style: AppTypography.metadata.copyWith(
                              color: AppColors.brandPurple,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(note.body, style: AppTypography.body.copyWith(height: 1.55)),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (showPlace)
                    Flexible(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 15,
                            color: AppColors.brandLilac,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              note.placeLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.metadata,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const Spacer(),
                  const Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 15,
                    color: AppColors.muted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${note.replyCount} yanıt',
                    style: AppTypography.metadata,
                  ),
                ],
              ),
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 4, children: actions),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

/// One reply in the single-level thread (oldest first).
class MapNoteReplyTile extends StatelessWidget {
  const MapNoteReplyTile(this.reply, {super.key, this.onDelete, this.onReport});
  final MapNoteReplyItem reply;
  final VoidCallback? onDelete;
  final VoidCallback? onReport;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: Space.sm),
    padding: const EdgeInsets.fromLTRB(14, 10, 4, 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: AppShape.rounded,
      border: Border.all(color: AppColors.line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: _Identity(
                  person: reply.author,
                  badge: reply.fromNoteAuthor ? 'Not sahibi' : null,
                  onTap: reply.author == null
                      ? null
                      : () => openPage(context, '/profile', reply.author!.id),
                ),
              ),
            ),
            if (reply.mine ? onDelete != null : onReport != null)
              PopupMenuButton<String>(
                tooltip: 'Yanıt seçenekleri',
                icon: const Icon(Icons.more_horiz_rounded, size: 20),
                onSelected: (value) =>
                    value == 'delete' ? onDelete?.call() : onReport?.call(),
                itemBuilder: (_) => [
                  if (reply.mine)
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Yanıtı Sil'),
                    )
                  else
                    const PopupMenuItem(
                      value: 'report',
                      child: Text('Şikâyet Et'),
                    ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 2),
        Padding(
          padding: const EdgeInsets.only(right: 10),
          child: Text(
            mapNoteTime(reply.createdAt),
            style: AppTypography.metadata,
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.only(right: 10),
          child: Text(reply.body, style: AppTypography.body),
        ),
      ],
    ),
  );
}

/// A compact "Mektuplarım" card: preview, approximate area, replies, the letter's real date and what is left of its public days.
class MyLetterCard extends StatelessWidget {
  const MyLetterCard(this.note, {super.key, this.onTap});
  final MapNoteItem note;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final status = switch (note.state) {
      'active' => note.remaining(),
      'archived' => 'Haritadan kaldırıldı',
      _ => 'Süresi doldu',
    };
    return Container(
      decoration: BoxDecoration(
        color: mapNotePaper,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderLilac.withValues(alpha: .8)),
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('my-letter-${note.id}'),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppIconBox(
                      icon: Icons.mail_outline_rounded,
                      size: AppDimensions.iconSM,
                      containerSize: AppDimensions.iconContainerSM,
                      color: AppColors.brandPurple,
                      backgroundColor: AppColors.surfaceLilac,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        note.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.body.copyWith(height: 1.45),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 15,
                      color: AppColors.brandLilac,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        note.placeLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.metadata,
                      ),
                    ),
                    Text(
                      ' · ${note.replyCount} cevap',
                      style: AppTypography.metadata,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        // The real date of the letter; a re-publication keeps it.
                        mapNoteTime(note.occurredAt, withYear: true),
                        key: ValueKey('my-letter-date-${note.id}'),
                        style: AppTypography.metadata,
                      ),
                    ),
                    Text(
                      status,
                      key: ValueKey('my-letter-status-${note.id}'),
                      style: AppTypography.metadata.copyWith(
                        color: note.isActive
                            ? AppColors.brandPurple
                            : AppColors.muted,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                if (note.republished || note.hasLiveRepost)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      note.hasLiveRepost
                          ? 'Tekrar paylaşıldı · haritada'
                          : 'Tekrar paylaşıldı',
                      style: AppTypography.metadata.copyWith(
                        color: AppColors.brandPurple,
                        fontWeight: FontWeight.w700,
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
}
