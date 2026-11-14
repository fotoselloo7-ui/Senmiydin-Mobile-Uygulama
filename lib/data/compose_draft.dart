import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'models.dart';
import 'post_context.dart';

/// Everything the composer holds that is worth keeping when the user leaves it unpublished.
/// Photos are referenced by file name inside the draft's private media folder, never by a picker cache path.
class ComposeDraft {
  ComposeDraft({
    this.body = '',
    this.kind = PostKind.memory,
    this.anonymous = false,
    this.cityWide = true,
    this.city,
    this.attachLocation = false,
    this.place,
    this.occurredAt,
    this.taggedId,
    this.requestId,
    TravelDraft? travel,
    List<String>? images,
  }) : travel = travel ?? TravelDraft(),
       images = images ?? [];

  static const version = 1;

  String body;
  PostKind kind;
  bool anonymous, cityWide, attachLocation;
  String? city, taggedId, requestId;
  PostPlaceSelection? place;
  DateTime? occurredAt;
  TravelDraft travel;

  /// Absolute paths of the photos (in order). Inside the draft folder once saved.
  List<String> images;

  /// Nothing worth restoring (an empty composer never leaves a draft behind).
  bool get isEmpty =>
      body.trim().isEmpty &&
      images.isEmpty &&
      taggedId == null &&
      place == null &&
      occurredAt == null &&
      !travel.enabled;

  Map<String, Object?> toJson(List<String> imageNames) => {
    'v': version,
    'body': body,
    'kind': kind.name,
    'anonymous': anonymous,
    'city_wide': cityWide,
    'city': city,
    'attach_location': attachLocation,
    'place': place == null
        ? null
        : {
            'source': place!.source,
            'history_id': place!.historyId,
            'latitude': place!.latitude,
            'longitude': place!.longitude,
            'city': place!.city,
            'label': place!.label,
            'recorded_at': place!.recordedAt?.toIso8601String(),
          },
    'occurred_at': occurredAt?.toIso8601String(),
    'tagged_id': taggedId,
    'request_id': requestId,
    'travel': {
      'enabled': travel.enabled,
      'is_public': travel.isPublic,
      'transport': travel.transport,
      'operator': travel.operatorName,
      'service': travel.serviceCode,
      'vehicle': travel.vehicleIdentifier,
      'origin': travel.origin,
      'destination': travel.destination,
      'departure_at': travel.departureAt?.toIso8601String(),
    },
    'images': imageNames,
  };

  /// Returns null for anything that is not a well-formed draft of this version (corrupt files are ignored, never thrown).
  static (ComposeDraft, List<String>)? fromJson(Object? raw) {
    try {
      if (raw is! Map || raw['v'] != version) return null;
      DateTime? date(Object? value) =>
          value is String ? DateTime.tryParse(value) : null;
      final travel = TravelDraft();
      final t = raw['travel'];
      if (t is Map) {
        travel
          ..enabled = t['enabled'] == true
          ..isPublic = t['is_public'] == true
          ..transport = t['transport'] as String? ?? 'bus'
          ..operatorName = t['operator'] as String? ?? ''
          ..serviceCode = t['service'] as String? ?? ''
          ..vehicleIdentifier = t['vehicle'] as String? ?? ''
          ..origin = t['origin'] as String?
          ..destination = t['destination'] as String?
          ..departureAt = date(t['departure_at']);
      }
      PostPlaceSelection? place;
      final p = raw['place'];
      if (p is Map) {
        place = PostPlaceSelection(
          p['source'] as String,
          historyId: (p['history_id'] as num?)?.toInt(),
          latitude: (p['latitude'] as num?)?.toDouble(),
          longitude: (p['longitude'] as num?)?.toDouble(),
          city: p['city'] as String?,
          label: p['label'] as String?,
          recordedAt: date(p['recorded_at']),
        );
      }
      final kindName = raw['kind'] as String?;
      final draft = ComposeDraft(
        body: raw['body'] as String? ?? '',
        kind: PostKind.values.firstWhere(
          (k) => k.name == kindName,
          orElse: () => PostKind.memory,
        ),
        anonymous: raw['anonymous'] == true,
        cityWide: raw['city_wide'] != false,
        city: raw['city'] as String?,
        attachLocation: raw['attach_location'] == true,
        place: place,
        occurredAt: date(raw['occurred_at']),
        taggedId: raw['tagged_id'] as String?,
        requestId: raw['request_id'] as String?,
        travel: travel,
      );
      final names = [
        for (final name in (raw['images'] as List? ?? const []))
          if (name is String && !name.contains(RegExp(r'[\\/]'))) name,
      ];
      return (draft, names);
    } catch (_) {
      return null;
    }
  }
}

/// Local, per-account draft storage in the app's private support directory (never the gallery, never the server).
/// Layout: `<support>/compose_drafts/<account>/draft.json` and `.../media/<n>.<ext>`.
class ComposeDraftStore {
  ComposeDraftStore({Future<Directory> Function()? root})
    : _root = root ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _root;
  Future<void> _queue = Future.value();

  /// The account namespace: digits and letters only, so a hostile id can never escape the folder.
  static String key(Object accountId) =>
      accountId.toString().replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');

  Future<Directory> _dir(Object account, {bool create = false}) async {
    final base = await _root();
    final dir = Directory('${base.path}/compose_drafts/${key(account)}');
    if (create) await dir.create(recursive: true);
    return dir;
  }

  /// Serialises writes so a slow save can never overwrite a newer one.
  Future<T> _exclusive<T>(Future<T> Function() job) {
    final done = Completer<T>();
    _queue = _queue.then((_) async {
      try {
        done.complete(await job());
      } catch (error, stack) {
        done.completeError(error, stack);
      }
    });
    return done.future;
  }

  /// Persists [draft] for [account]. Photos outside the draft folder are copied in (private app storage) and
  /// the returned list holds their new paths, in the same order. Files no longer referenced are removed.
  Future<List<String>> save(Object account, ComposeDraft draft) =>
      _exclusive(() async {
        if (draft.isEmpty) {
          await _clear(account);
          return const [];
        }
        final dir = await _dir(account, create: true);
        final media = Directory('${dir.path}/media');
        await media.create(recursive: true);
        final kept = <String>[];
        final names = <String>[];
        for (final source in draft.images) {
          final file = File(source);
          if (!await file.exists()) continue;
          if (file.parent.path == media.path) {
            kept.add(file.path);
            names.add(file.uri.pathSegments.last);
            continue;
          }
          final extension = _extension(source);
          var name =
              '${DateTime.now().microsecondsSinceEpoch}_${kept.length}$extension';
          while (await File('${media.path}/$name').exists()) {
            name = '_$name';
          }
          final copy = await file.copy('${media.path}/$name');
          kept.add(copy.path);
          names.add(name);
        }
        await File('${dir.path}/draft.json.tmp').writeAsString(
          jsonEncode(draft.toJson(names)),
          flush: true,
        );
        // Write-then-rename: a process kill mid-write leaves the previous draft intact.
        await File('${dir.path}/draft.json.tmp').rename('${dir.path}/draft.json');
        if (await media.exists()) {
          await for (final entry in media.list()) {
            if (entry is File && !names.contains(entry.uri.pathSegments.last)) {
              await entry.delete();
            }
          }
        }
        return kept;
      });

  /// The saved draft, or null when there is none, it is unreadable, or it is empty. Corrupt data is discarded quietly.
  Future<ComposeDraft?> load(Object account) => _exclusive(() async {
    final dir = await _dir(account);
    final file = File('${dir.path}/draft.json');
    if (!await file.exists()) return null;
    try {
      final parsed = ComposeDraft.fromJson(jsonDecode(await file.readAsString()));
      if (parsed == null) {
        await _clear(account);
        return null;
      }
      final (draft, names) = parsed;
      for (final name in names) {
        final image = File('${dir.path}/media/$name');
        if (await image.exists()) draft.images.add(image.path);
      }
      if (draft.isEmpty) {
        await _clear(account);
        return null;
      }
      return draft;
    } catch (_) {
      await _clear(account);
      return null;
    }
  });

  Future<bool> exists(Object account) => _exclusive(() async {
    final dir = await _dir(account);
    return File('${dir.path}/draft.json').exists();
  });

  /// Removes the draft JSON and every photo copy of this account.
  Future<void> clear(Object account) => _exclusive(() => _clear(account));

  Future<void> _clear(Object account) async {
    final dir = await _dir(account);
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  static String _extension(String path) {
    final dot = path.lastIndexOf('.');
    final slash = path.lastIndexOf(RegExp(r'[\\/]'));
    if (dot <= slash || path.length - dot > 6) return '.jpg';
    final extension = path.substring(dot).toLowerCase();
    return RegExp(r'^\.[a-z0-9]{1,5}$').hasMatch(extension) ? extension : '.jpg';
  }
}
