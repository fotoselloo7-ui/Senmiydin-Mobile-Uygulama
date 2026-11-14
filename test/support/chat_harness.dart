import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:senmiydin/core/app_locale.dart';
import 'package:senmiydin/data/app_store.dart';
import 'package:senmiydin/screens/direct_chat.dart';

import '../global_release_test.dart' show account, connected, host, ok;

/// The eight server-controlled gifts: slug, Turkish name, English name.
const giftCatalog = [
  ('heart', 'Kalp', 'Heart'),
  ('rose', 'Gül', 'Rose'),
  ('coffee', 'Kahve', 'Coffee'),
  ('flower', 'Çiçek', 'Flower'),
  ('star', 'Yıldız', 'Star'),
  ('clover', 'Yonca', 'Clover'),
  ('cake', 'Pasta', 'Cake'),
  ('gift', 'Hediye kutusu', 'Gift box'),
];

Future<void> loadAppFont() async {
  final bytes = File('assets/fonts/NunitoSans.ttf').readAsBytesSync();
  final loader = FontLoader('NunitoSans')
    ..addFont(Future.value(ByteData.sublistView(bytes)));
  await loader.load();
}

void setScreen(WidgetTester tester, double width, [double height = 800]) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Lets real (non fake-async) work such as file IO finish, pumping between the waits.
Future<void> realWait(WidgetTester tester, [int ms = 240]) async {
  for (var i = 0; i < (ms / 30).ceil(); i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump();
  }
}

/// Waits (real time, for file IO) until [finder] matches; fails after about four seconds.
Future<void> realWaitFor(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 130 && finder.evaluate().isEmpty; i++) {
    await realWait(tester, 30);
  }
  expect(finder, findsWidgets, reason: 'Never appeared.');
}

Map<String, dynamic> chatPeer() => {
  'id': 22,
  'username': 'elif',
  'name': 'Elif Test',
  'avatar': null,
};

Map<String, dynamic> chatMessage(
  int id,
  String type, {
  String body = '',
  bool mine = false,
  int? durationMs,
  Map<String, dynamic>? gift,
}) => {
  'id': id,
  'body': body,
  'type': type,
  'mine': mine,
  'image': null,
  'read_at': null,
  'created_at': DateTime.now().toUtc().toIso8601String(),
  if (type == 'voice') 'audio': '/api/message-audio/$id',
  'duration_ms': ?durationMs,
  'gift': ?gift,
};

Map<String, dynamic> sendResult(Map<String, dynamic> message) => {
  'conversation': {
    'id': 3,
    'status': 'active',
    'peer': chatPeer(),
    'outgoing': false,
    'can_send': true,
    'unread': 0,
  },
  'message': message,
};

Future<AppStore> chatStore({
  List<Map<String, dynamic>>? messages,
  List<http.Request>? sent,
  Future<http.Response> Function(http.Request)? onSend,
  bool giftsFail = false,
  List<String>? giftLanguages,
}) => connected((request) async {
  final path = request.url.path;
  if (path.endsWith('/auth/login')) {
    return ok({'token': 't', 'user': account()});
  }
  if (path.endsWith('/unread-counts')) {
    return ok({'messages': 0, 'notifications': 0});
  }
  if (path.endsWith('/gifts')) {
    giftLanguages?.add(request.headers['Accept-Language'] ?? '');
    if (giftsFail) return http.Response('{"success":false}', 500);
    return ok({
      'items': [
        for (final g in giftCatalog)
          {
            'slug': g.$1,
            'name': AppLocale.code == 'en' ? g.$3 : g.$2,
            'asset': g.$1,
            'price_minor': 0,
          },
      ],
    });
  }
  if (request.method == 'POST' && path.endsWith('/messages')) {
    sent?.add(request);
    if (onSend != null) return onSend(request);
    return ok(sendResult(chatMessage(99, 'text', body: 'ok', mine: true)), 201);
  }
  if (path.endsWith('/conversations/3/messages')) {
    return ok({'items': messages ?? [], 'has_more': false});
  }
  if (path.contains('/conversations/3')) {
    return ok(sendResult(chatMessage(0, 'text'))['conversation']);
  }
  return ok({'items': [], 'next_page': null});
});

Future<AppStore> openChat(
  WidgetTester tester, {
  double width = 390,
  double scale = 1,
  List<Map<String, dynamic>>? messages,
  List<http.Request>? sent,
  Future<http.Response> Function(http.Request)? onSend,
  bool giftsFail = false,
  List<String>? giftLanguages,
  Locale locale = const Locale('tr'),
}) async {
  setScreen(tester, width);
  final store = await chatStore(
    messages: messages,
    sent: sent,
    onSend: onSend,
    giftsFail: giftsFail,
    giftLanguages: giftLanguages,
  );
  addTearDown(store.dispose);
  await tester.pumpWidget(
    host(store, const DirectChatPage('3'), scale: scale, locale: locale),
  );
  await tester.pumpAndSettle();
  await realWait(tester);
  await tester.pumpAndSettle();
  return store;
}

/// The text of a request body (a multipart upload reaches the mock client as one request).
String bodyText(http.Request request) =>
    utf8.decode(request.bodyBytes, allowMalformed: true);
