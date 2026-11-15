import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

import '../core/api_config.dart';

/// A shared SenMiydin? link: `https://host/p/id` (a post) or `https://host/n/id` (a Map Note).
class ShareLink {
  const ShareLink(this.kind, this.publicId);
  final String kind, publicId;
  bool get isPost => kind == 'p';

  @override
  bool operator ==(Object other) =>
      other is ShareLink && other.kind == kind && other.publicId == publicId;
  @override
  int get hashCode => Object.hash(kind, publicId);
}

/// The public host links may use. It is the website's own domain: the API's host (without a leading `api.`), plus any
/// host passed at build time (`APP_LINK_HOST`, the same value the Android manifest uses).
Set<String> shareLinkHosts() {
  const configured = String.fromEnvironment('APP_LINK_HOST');
  final hosts = <String>{
    if (configured.isNotEmpty) configured.toLowerCase(),
    'senmiydin.com',
    'www.senmiydin.com',
  };
  final apiHost = ApiConfig.base.host.toLowerCase();
  if (apiHost.isNotEmpty && apiHost != 'localhost') {
    hosts.add(apiHost.replaceFirst(RegExp(r'^api\.'), ''));
  }
  return hosts;
}

/// Only https links on the website's own host with the exact `/p/<12 chars>` or `/n/<12 chars>` shape are accepted;
/// everything else (other hosts, other schemes, extra path, odd ids) is ignored.
ShareLink? parseShareLink(Uri uri, {Set<String>? hosts}) {
  if (uri.scheme != 'https') return null;
  if (!(hosts ?? shareLinkHosts()).contains(uri.host.toLowerCase())) {
    return null;
  }
  final match = RegExp(r'^/([pn])/([a-z0-9]{12})/?$').firstMatch(uri.path);
  return match == null ? null : ShareLink(match.group(1)!, match.group(2)!);
}

/// Listens for links the app is opened with (cold start and while running) and hands each valid one to [onLink].
class DeepLinks {
  // ignore: prefer_initializing_formals
  DeepLinks({required this.onLink, AppLinks? links}) : _links = links;

  final void Function(ShareLink link) onLink;
  AppLinks? _links;
  StreamSubscription<Uri>? _subscription;

  Future<void> start() async {
    try {
      final links = _links ??= AppLinks();
      final initial = await links.getInitialLink();
      if (initial != null) _deliver(initial);
      _subscription = links.uriLinkStream.listen(_deliver, onError: (_) {});
    } catch (error) {
      // No link handling on this platform/device: the app works exactly as before.
      debugPrint('Deep links unavailable: $error');
    }
  }

  void _deliver(Uri uri) {
    final link = parseShareLink(uri);
    if (link != null) onLink(link);
  }

  Future<void> dispose() async => _subscription?.cancel();
}
