import 'dart:async';

import 'package:flutter/material.dart' hide Text;

import '../core/app_locale.dart';
import '../core/navigation.dart';
import '../core/theme.dart';
import '../data/share_service.dart';
import '../widgets/share_card.dart';
import 'translated_text.dart';

/// "Paylaş": share a public item outside the app as a SenMiydin? card (Stories 1080x1920, or 1080x1350 for everything
/// else) with its link, copy the link, or hand the link to any app. [build] makes the card data (it fetches the photo and
/// avatars); nothing private is ever part of it.
Future<void> showShareSheet(
  BuildContext context, {
  required Future<ShareCardData> Function(ShareService service) build,
  required String url,
  ShareService? service,
}) {
  final sharing = service ?? ShareService.override ?? ShareService();
  final box = context.findRenderObject();
  final origin = box is RenderBox && box.hasSize
      ? box.localToGlobal(Offset.zero) & box.size
      : null;
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheet) => _ShareSheet(
      parent: context,
      service: sharing,
      build: build,
      url: url,
      origin: origin,
    ),
  );
}

class _ShareSheet extends StatefulWidget {
  const _ShareSheet({
    required this.parent,
    required this.service,
    required this.build,
    required this.url,
    required this.origin,
  });
  final BuildContext parent;
  final ShareService service;
  final Future<ShareCardData> Function(ShareService service) build;
  final String url;
  final Rect? origin;

  @override
  State<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<_ShareSheet> {
  ShareTarget? busy;
  Future<ShareCardData>? card;

  Future<ShareCardData> data() => card ??= widget.build(widget.service);

  Future<void> run(ShareTarget target) async {
    if (busy != null) return;
    final messenger = widget.parent;
    if (target == ShareTarget.link || target == ShareTarget.other) {
      // These need no picture: the link itself.
      try {
        if (target == ShareTarget.link) {
          await widget.service.platform.copyText(widget.url);
        } else {
          await widget.service.platform.shareText(
            widget.url,
            origin: widget.origin,
          );
        }
        if (!mounted) return;
        Navigator.pop(context);
        if (target == ShareTarget.link && messenger.mounted) {
          toast(messenger, tr('Bağlantı kopyalandı.'));
        }
      } catch (_) {
        if (mounted) {
          Navigator.pop(context);
          if (messenger.mounted) {
            toast(messenger, tr('Paylaşım menüsü açılamadı.'));
          }
        }
      }
      return;
    }
    setState(() => busy = target);
    try {
      await widget.service.share(target, await data(), origin: widget.origin);
      if (mounted) Navigator.pop(context);
    } catch (error, stack) {
      debugPrint('Share card failed: $error');
      debugPrintStack(stackTrace: stack);
      if (!mounted) return;
      setState(() => busy = null);
      Navigator.pop(context);
      if (messenger.mounted) {
        toast(messenger, tr('Paylaşım hazırlanamadı. Tekrar dene.'));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget option(
      ShareTarget target,
      IconData icon,
      String label,
      String key,
    ) => ListTile(
      key: Key(key),
      enabled: busy == null,
      leading: busy == target
          ? const SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            )
          : Icon(icon, color: AppColors.blue),
      title: Text(label),
      onTap: () => run(target),
    );

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr('Paylaş'),
              key: const Key('share-sheet-title'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: Space.xs),
            option(
              ShareTarget.story,
              Icons.auto_stories_outlined,
              tr('Hikâyede Paylaş'),
              'share-story',
            ),
            option(
              ShareTarget.card,
              Icons.image_outlined,
              tr('Görsel Kart Olarak Paylaş'),
              'share-card',
            ),
            option(
              ShareTarget.link,
              Icons.link_rounded,
              tr('Bağlantıyı Kopyala'),
              'share-link',
            ),
            option(
              ShareTarget.other,
              Icons.ios_share_rounded,
              tr('Diğer…'),
              'share-other',
            ),
          ],
        ),
      ),
    );
  }
}
