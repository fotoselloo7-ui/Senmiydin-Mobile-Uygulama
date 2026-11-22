import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/app_locale.dart';
import '../core/brand_assets.dart';
import '../widgets/share_card.dart';
import 'app_store.dart';
import 'map_notes_api.dart';
import 'models.dart';
import 'share_renderer.dart';

/// What the person picked in the share sheet.
enum ShareTarget { story, card, link, other }

/// The platform side of sharing, behind a seam so tests never open a system sheet.
abstract class SharePlatform {
  /// Opens the system share sheet with an image (and the link as text).
  Future<void> shareImage(String path, {required String text, Rect? origin});

  /// Opens the system share sheet with a link / text only.
  Future<void> shareText(String text, {Rect? origin});

  /// True when Instagram can take a Story directly (installed, and a Facebook App ID was configured at build time).
  Future<bool> canShareToInstagramStory();

  /// Hands the 1080x1920 image to Instagram's Story composer. False when it could not be done (the caller then uses the
  /// normal share sheet).
  Future<bool> shareToInstagramStory(String path);

  Future<void> copyText(String text);
}

class OfficialSharePlatform implements SharePlatform {
  static const _channel = MethodChannel('senmiydin/share');

  /// Instagram's Story intent wants the app's Facebook App ID (a public identifier, not a secret). Without one there is
  /// no direct Story hand-off and Instagram is still reachable from the normal share sheet.
  static const facebookAppId = String.fromEnvironment(
    'INSTAGRAM_FACEBOOK_APP_ID',
  );

  @override
  Future<void> shareImage(
    String path, {
    required String text,
    Rect? origin,
  }) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(path, mimeType: 'image/png')],
        text: text,
        sharePositionOrigin: origin,
      ),
    );
  }

  @override
  Future<void> shareText(String text, {Rect? origin}) async {
    await SharePlus.instance.share(
      ShareParams(text: text, sharePositionOrigin: origin),
    );
  }

  @override
  Future<bool> canShareToInstagramStory() async {
    if (!Platform.isAndroid || facebookAppId.isEmpty) return false;
    try {
      return await _channel.invokeMethod<bool>('instagramInstalled') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<bool> shareToInstagramStory(String path) async {
    try {
      return await _channel.invokeMethod<bool>('instagramStory', {
            'path': path,
            'appId': facebookAppId,
          }) ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<void> copyText(String text) =>
      Clipboard.setData(ClipboardData(text: text));
}

typedef ShareImageLoader = Future<Uint8List?> Function(
  String url,
  Map<String, String> headers,
);

Future<Uint8List?> _downloadImage(
  String url,
  Map<String, String> headers,
) async {
  try {
    final response = await http
        .get(Uri.parse(url), headers: headers)
        .timeout(const Duration(seconds: 12));
    return response.statusCode == 200 && response.bodyBytes.isNotEmpty
        ? response.bodyBytes
        : null;
  } catch (_) {
    return null;
  }
}

Future<ui.Image> decodeShareImage(Uint8List bytes, {int? targetWidth}) async {
  final codec = await ui.instantiateImageCodec(bytes, targetWidth: targetWidth);
  final frame = await codec.getNextFrame();
  codec.dispose();
  return frame.image;
}

const _monthsTr = [
  'Ocak',
  'Şubat',
  'Mart',
  'Nisan',
  'Mayıs',
  'Haziran',
  'Temmuz',
  'Ağustos',
  'Eylül',
  'Ekim',
  'Kasım',
  'Aralık',
];
const _monthsEn = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// "15 Kasım 2026" / "November 15, 2026" in the sharing person's language.
String shareDateLabel(DateTime? date) {
  if (date == null) return '';
  return AppLocale.code == 'en'
      ? '${_monthsEn[date.month - 1]} ${date.day}, ${date.year}'
      : '${date.day} ${_monthsTr[date.month - 1]} ${date.year}';
}

/// Builds, renders and hands over a share card. Everything shown on a card is public data; an anonymous item never
/// gets a name, an avatar or a handle.
class ShareService {
  ShareService({
    SharePlatform? platform,
    ShareImageLoader? loader,
    Future<Directory> Function()? workDirectory,
  }) : platform = platform ?? OfficialSharePlatform(),
       _loader = loader ?? _downloadImage,
       _workDirectory = workDirectory ?? _defaultWorkDirectory;

  final SharePlatform platform;
  final ShareImageLoader _loader;
  final Future<Directory> Function() _workDirectory;

  /// Our own cache folder. (share_plus empties its own `share_plus` folder at the start of every share, so cards are not
  /// kept there; it copies the file it is given, and the Instagram hand-off copies it as well.)
  static Future<Directory> _defaultWorkDirectory() async {
    final base = await getTemporaryDirectory();
    final directory = Directory('${base.path}/senmiydin_share');
    if (!await directory.exists()) await directory.create(recursive: true);
    return directory;
  }

  Future<ui.Image?> _image(
    String url,
    Map<String, String> headers, {
    int? targetWidth,
  }) async {
    if (url.isEmpty) return null;
    final bytes = await _loader(url, headers);
    if (bytes == null) return null;
    try {
      return await decodeShareImage(bytes, targetWidth: targetWidth);
    } catch (_) {
      return null;
    }
  }

  Future<ui.Image> _logo() async {
    final data = await rootBundle.load(BrandAssets.logoHeaderLight);
    return decodeShareImage(data.buffer.asUint8List());
  }

  /// A post: text, photo (the first one only), encounter story (confirmed and published only) or anonymous.
  Future<ShareCardData> postCard(Post post, AppStore store) async {
    final url = post.shareUrl;
    if (url == null) {
      throw StateError('This post has no public link and is not shareable.');
    }
    final logo = await _logo();
    final photo = post.images.isEmpty
        ? null
        : await _image(
            post.images.first,
            store.mediaHeaders(post.images.first),
            targetWidth: 1080,
          );
    final encounter =
        !post.anonymous &&
        post.storyStatus == 'published' &&
        post.storyParticipants.isNotEmpty;
    final author = post.anonymous ? null : store.person(post.authorId);
    ui.Image? avatar;
    final pairAvatars = <ui.Image>[];
    if (encounter) {
      for (final person in post.storyParticipants.take(2)) {
        final image = await _image(person.photo, const {}, targetWidth: 160);
        if (image != null) pairAvatars.add(image);
      }
    } else if (author != null) {
      avatar = await _image(author.photo, const {}, targetWidth: 160);
    }
    return ShareCardData(
      kind: encounter ? ShareCardKind.encounter : ShareCardKind.post,
      kindLabel: tr(post.kind.label),
      body: post.text.trim(),
      dateLabel: shareDateLabel(post.createdAt),
      placeLabel: post.locationLabel ?? post.city,
      url: url,
      cta: tr("SenMiydin?'de gör"),
      continueLabel: tr("Devamını SenMiydin?'de gör"),
      logo: logo,
      anonymous: post.anonymous,
      anonymousLabel: tr('Anonim'),
      authorName: encounter ? null : author?.name,
      handle: encounter ? null : author?.handle,
      avatar: avatar,
      pairNames: encounter
          ? post.storyParticipants
                .take(2)
                .map((p) => p.name.trim().split(RegExp(r'\s+')).first)
                .join(' & ')
          : null,
      pairAvatars: pairAvatars,
      badge: encounter ? tr('Karşılaşıldı') : null,
      photo: photo,
    );
  }

  /// A live public Map Note: the approximate area label only, never a coordinate.
  Future<ShareCardData> noteCard(MapNoteItem note, AppStore store) async {
    final url = note.shareUrl;
    if (url == null) {
      throw StateError('This letter has no public link and is not shareable.');
    }
    final logo = await _logo();
    final photo = note.hasImage
        ? await _image(
            note.image,
            store.mediaHeaders(note.image),
            targetWidth: 1080,
          )
        : null;
    final author = note.anonymous ? null : note.author;
    final avatar = author == null
        ? null
        : await _image(author.photo, const {}, targetWidth: 160);
    return ShareCardData(
      kind: ShareCardKind.mapNote,
      kindLabel: tr('Harita Notu'),
      body: note.body.trim(),
      dateLabel: shareDateLabel(note.occurredAt),
      placeLabel: note.placeLabel,
      url: url,
      cta: tr("SenMiydin?'de gör"),
      continueLabel: tr("Devamını SenMiydin?'de gör"),
      logo: logo,
      anonymous: note.anonymous,
      anonymousLabel: tr('Anonim'),
      authorName: author?.name,
      handle: author?.handle,
      avatar: avatar,
      photo: photo,
    );
  }

  /// Renders the card into the share cache folder and returns the file. Old cards are removed first.
  Future<File> renderFile(ShareCardData data, ShareCardFormat format) async {
    final directory = await _workDirectory();
    await cleanUp(olderThan: const Duration(hours: 1));
    final bytes = await renderShareCard(data, format);
    final file = File(
      '${directory.path}/senmiydin_${format.name}_${DateTime.now().microsecondsSinceEpoch}.png',
    );
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  /// Deletes the cards this service wrote ([olderThan] null: all of them).
  Future<void> cleanUp({Duration? olderThan}) async {
    try {
      final directory = await _workDirectory();
      final now = DateTime.now();
      await for (final entry in directory.list()) {
        if (entry is! File ||
            !entry.uri.pathSegments.last.startsWith('senmiydin_')) {
          continue;
        }
        if (olderThan != null &&
            now.difference(await entry.lastModified()) < olderThan) {
          continue;
        }
        try {
          await entry.delete();
        } catch (_) {
          // Temporary file; removed next time.
        }
      }
    } catch (_) {
      // Nothing to clean.
    }
  }

  /// Runs a share target for [data] (the link is the card's own address).
  Future<void> share(
    ShareTarget target,
    ShareCardData data, {
    Rect? origin,
  }) async {
    switch (target) {
      case ShareTarget.link:
        await platform.copyText(data.url);
      case ShareTarget.other:
        await platform.shareText(data.url, origin: origin);
      case ShareTarget.card:
        final file = await renderFile(data, ShareCardFormat.portrait);
        try {
          await platform.shareImage(file.path, text: data.url, origin: origin);
        } finally {
          _removeLater(file);
        }
      case ShareTarget.story:
        final file = await renderFile(data, ShareCardFormat.story);
        try {
          if (await platform.canShareToInstagramStory() &&
              await platform.shareToInstagramStory(file.path)) {
            return;
          }
          // No direct hand-off: the normal share sheet (Instagram Stories is one of its targets when installed).
          await platform.shareImage(file.path, text: data.url, origin: origin);
        } finally {
          _removeLater(file);
        }
    }
  }

  /// The chosen app reads the file after the sheet closes (possibly much later), so it is never deleted right away:
  /// it goes after a while, and anything left behind is swept by the next share ([cleanUp]).
  void _removeLater(File file) {
    unawaited(
      Future<void>.delayed(const Duration(minutes: 10), () => _remove(file)),
    );
  }

  Future<void> _remove(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Removed by the next cleanup.
    }
  }

  /// Tests and the debug build can swap the whole service.
  static ShareService? override;
}
