import 'package:flutter/material.dart' hide Text;

import '../core/app_locale.dart';
import '../core/theme.dart';
import '../data/app_store.dart';
import 'translated_text.dart';

/// "Rate SenMiydin?": a small sheet in the app's own design. It is honest and the same for everyone: no "do you like
/// the app?" question first, no routing of happy people only. "Rate" asks the platform's official review sheet.
Future<void> showReviewInvite(BuildContext context, AppStore store) async {
  // The weekly cooldown starts the moment the invitation is on screen, whatever the answer (or a swipe away).
  await store.reviewInviteShown();
  if (!context.mounted) return;
  final rate = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheet) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.star_rounded, color: AppColors.blue, size: 40),
            const SizedBox(height: Space.sm),
            Text(
              tr("SenMiydin?'i değerlendir"),
              key: const Key('review-title'),
              textAlign: TextAlign.center,
              style: Theme.of(sheet).textTheme.titleLarge,
            ),
            const SizedBox(height: Space.sm),
            Text(
              tr(
                'Uygulamayı kullanmaktan memnunsan görüşün bize çok yardımcı olur.',
              ),
              key: const Key('review-body'),
              textAlign: TextAlign.center,
              style: AppTypography.secondaryBody,
            ),
            const SizedBox(height: Space.lg),
            FilledButton(
              key: const Key('review-rate'),
              onPressed: () => Navigator.pop(sheet, true),
              child: Text(tr('Değerlendir')),
            ),
            const SizedBox(height: Space.xs),
            TextButton(
              key: const Key('review-not-now'),
              onPressed: () => Navigator.pop(sheet, false),
              child: Text(tr('Şimdi Değil')),
            ),
          ],
        ),
      ),
    ),
  );
  if (rate == true) await store.reviews.rate();
}
