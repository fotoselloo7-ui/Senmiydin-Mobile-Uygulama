import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:senmiydin/data/account_api.dart';
import 'package:senmiydin/data/app_store.dart';
import 'package:senmiydin/data/location_service.dart';
import 'package:senmiydin/screens/discovery.dart';
import 'package:senmiydin/screens/live_map.dart';
import 'package:senmiydin/screens/settings.dart';

Position point({double latitude = 36.544}) => Position(
  latitude: latitude,
  longitude: 32,
  timestamp: DateTime.now(),
  accuracy: 20,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

class TestLocationDevice extends LocationDevice {
  bool serviceEnabled = true;
  LocationPermission permissionValue = LocationPermission.denied;
  LocationPermission requested = LocationPermission.whileInUse;
  LocationAccuracyStatus accuracyValue = LocationAccuracyStatus.precise;
  int reads = 0, prompts = 0;
  final watches = <bool>[];
  final updatesController = StreamController<Position>.broadcast();

  @override
  bool get supportsBackground => true;
  @override
  Future<bool> enabled() async => serviceEnabled;
  @override
  Future<LocationPermission> permission() async => permissionValue;
  @override
  Future<LocationPermission> requestPermission() async {
    prompts++;
    return permissionValue = requested;
  }

  @override
  Future<LocationAccuracyStatus> accuracy() async => accuracyValue;
  @override
  Future<Position?> lastKnown() async => null;
  @override
  Future<Position> current() async {
    reads++;
    return point();
  }

  @override
  Stream<Position> updates({required bool background}) {
    watches.add(background);
    return updatesController.stream;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Location reads require consent and expose approximate permission',
    () async {
      final device = TestLocationDevice()
        ..accuracyValue = LocationAccuracyStatus.reduced;
      final samples = <bool>[];
      final service = LocationService(
        device: device,
        publish: (_, background) async => samples.add(background),
        clear: () async {},
      );
      addTearDown(() async {
        service.dispose();
        await device.updatesController.close();
      });
      service.configure(active: true, history: false);
      await service.refresh();
      expect(service.state, DeviceLocationState.denied);
      expect(device.reads, 0);
      expect(device.prompts, 0);
      await service.activateFromUi();
      expect(service.state, DeviceLocationState.approximate);
      expect(service.synced, true);
      expect(samples, [false]);
    },
  );

  test(
    'Disabled and permanently denied locations never read a position',
    () async {
      final device = TestLocationDevice()..serviceEnabled = false;
      final service = LocationService(
        device: device,
        publish: (_, _) async {},
        clear: () async {},
      );
      addTearDown(() async {
        service.dispose();
        await device.updatesController.close();
      });
      service.configure(active: true, history: false);
      await service.refresh();
      expect(service.state, DeviceLocationState.disabled);
      device.serviceEnabled = true;
      device.requested = LocationPermission.deniedForever;
      await service.refresh(request: true);
      expect(service.state, DeviceLocationState.deniedForever);
      expect(device.reads, 0);
    },
  );

  test(
    'Only opted-in Android streams produce background history samples',
    () async {
      final device = TestLocationDevice()
        ..permissionValue = LocationPermission.whileInUse;
      final samples = <bool>[];
      final service = LocationService(
        device: device,
        publish: (_, background) async => samples.add(background),
        clear: () async {},
      );
      addTearDown(() async {
        service.dispose();
        await device.updatesController.close();
      });
      service.configure(active: true, history: false);
      await service.refresh();
      expect(device.watches, [false]);
      service.didChangeAppLifecycleState(AppLifecycleState.paused);
      device.updatesController.add(point(latitude: 36.560));
      await Future<void>.delayed(Duration.zero);
      expect(samples, [false]);

      service.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await service.refresh();
      service.configure(active: true, history: true);
      await service.refresh();
      expect(device.watches.last, true);
      service.didChangeAppLifecycleState(AppLifecycleState.paused);
      device.updatesController.add(point(latitude: 36.560));
      await Future<void>.delayed(Duration.zero);
      expect(samples.last, true);
      final beforeDisable = samples.length;
      service.configure(active: true, history: false);
      device.updatesController.add(point(latitude: 36.570));
      await Future<void>.delayed(Duration.zero);
      expect(service.historyAllowed, false);
      expect(samples.length, beforeDisable);
    },
  );

  testWidgets('Map keeps a loading state and presents API errors', (
    tester,
  ) async {
    final response = Completer<http.Response>();
    final client = mockApi((request) async {
      if (request.url.path.endsWith('/cities')) {
        return ok([
          {'id': 1, 'name': 'Alanya'},
        ]);
      }
      return response.future;
    });
    final store = AppStore(api: client, locationDevice: TestLocationDevice());
    addTearDown(store.dispose);
    await client.saveToken('test');
    await tester.pumpWidget(
      StoreScope(
        store: store,
        child: const MaterialApp(home: Scaffold(body: LiveMapContent())),
      ),
    );
    expect(find.byKey(const Key('map-loading')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 300));
    response.complete(http.Response('{}', 503));
    await tester.pumpAndSettle();
    expect(find.text('Tekrar Dene'), findsOneWidget);
  });

  testWidgets(
    'Nearby renders a real result and privacy saves through the API',
    (tester) async {
      var visible = true;
      final device = TestLocationDevice()
        ..permissionValue = LocationPermission.whileInUse;
      final client = mockApi((request) async {
        if (request.url.path.endsWith('/auth/login')) {
          return ok({'token': 'test', 'user': profile(visible)});
        }
        if (request.url.path.endsWith('/location')) {
          return ok({
            'city': {'id': 1, 'name': 'Alanya'},
          });
        }
        if (request.url.path.endsWith('/cities')) {
          return ok([
            {'id': 1, 'name': 'Alanya'},
          ]);
        }
        if (request.url.path.endsWith('/nearby/users')) {
          return ok({
            'items': [
              {
                'id': 2,
                'username': 'deniz',
                'name': 'Deniz',
                'city': {'id': 1, 'name': 'Alanya'},
                'distance_meters': 400,
              },
            ],
          });
        }
        expect(request.url.path, endsWith('/profile'));
        visible = (jsonDecode(request.body) as Map)['nearby_visible'] as bool;
        return ok(profile(visible));
      });
      final store = AppStore(api: client, locationDevice: device);
      addTearDown(() async {
        store.dispose();
        await device.updatesController.close();
      });
      await store.signIn('login', {});
      await store.location!.refresh();
      await tester.pumpWidget(
        StoreScope(
          store: store,
          child: const MaterialApp(home: NearbyPage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Deniz'), findsOneWidget);
      expect(find.text('@deniz · 400 m'), findsOneWidget);

      await tester.pumpWidget(
        StoreScope(
          store: store,
          child: const MaterialApp(home: PreferencesPage()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text("Yakınındaki İnsanlar'da görün"));
      await tester.pumpAndSettle();
      expect(visible, false);
      expect(store.account!.nearbyVisible, false);
      await tester.pumpWidget(const SizedBox.shrink());
      store.location!.configure(active: false, history: false);
    },
  );
}

ApiClient mockApi(Future<http.Response> Function(http.Request) respond) {
  FlutterSecureStorage.setMockInitialValues({});
  return ApiClient(httpClient: MockClient(respond));
}

http.Response ok(Object data) => http.Response(
  jsonEncode({'success': true, 'data': data}),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Map<String, Object?> profile(bool visible) => {
  'id': 1,
  'name': 'Ada',
  'username': 'ada',
  'city': {'id': 1, 'name': 'Alanya'},
  'avatar': null,
  'cover_image': null,
  'bio': '',
  'occupation_school': '',
  'connections': [],
  'nearby_visible': visible,
  'encounter_suggestions': false,
  'city_discovery': true,
  'location_history_enabled': false,
  'onboarding_step': 3,
  'interests': [],
};
