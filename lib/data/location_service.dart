import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';

import '../core/app_locale.dart';

enum DeviceLocationState {
  idle('Cihaz konumu kullanılabilir.'),
  disabled('Cihazın konum servisi kapalı.'),
  denied('Yakındaki sonuçlar için konum izni ver.'),
  deniedForever('Konum iznini cihaz ayarlarından aç.'),
  loading('Konum alınıyor…'),
  approximate('Yaklaşık konum kullanılıyor.'),
  precise('Cihaz konumu hazır.'),
  unavailable('Konum alınamadı. Tekrar dene.'),
  offline('Konum eşitlenemedi. Tekrar dene.');

  const DeviceLocationState(this.message);
  final String message;
}

class LocationDevice {
  const LocationDevice();

  bool get supportsBackground =>
      defaultTargetPlatform == TargetPlatform.android;
  Future<bool> enabled() => Geolocator.isLocationServiceEnabled();
  Future<LocationPermission> permission() => Geolocator.checkPermission();
  Future<LocationPermission> requestPermission() =>
      Geolocator.requestPermission();
  Future<LocationAccuracyStatus> accuracy() => Geolocator.getLocationAccuracy();
  Future<Position?> lastKnown() => Geolocator.getLastKnownPosition(
    forceAndroidLocationManager: supportsBackground,
  );
  Future<Position> current() => Geolocator.getCurrentPosition(
    locationSettings: supportsBackground
        ? AndroidSettings(
            forceLocationManager: true,
            accuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 12),
          )
        : const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 12),
          ),
  );
  Future<bool> appSettings() => Geolocator.openAppSettings();
  Future<bool> deviceSettings() => Geolocator.openLocationSettings();

  Stream<Position> updates({required bool background}) =>
      Geolocator.getPositionStream(
        locationSettings: supportsBackground
            ? AndroidSettings(
                forceLocationManager: true,
                accuracy: LocationAccuracy.high,
                distanceFilter: 150,
                intervalDuration: const Duration(minutes: 1),
                foregroundNotificationConfig: background
                    ? ForegroundNotificationConfig(
                        notificationTitle: AppLocale.english
                            ? 'SenMiydin? · Places I Passed'
                            : 'SenMiydin? · Geçtiğim Yerler',
                        notificationText: AppLocale.english
                            ? 'Approximate areas are being added to your location history.'
                            : 'Yaklaşık bölgeler konum geçmişine ekleniyor.',
                        notificationChannelName: AppLocale.english
                            ? 'Places I Passed'
                            : 'Geçtiğim Yerler',
                        setOngoing: true,
                      )
                    : null,
              )
            : const LocationSettings(
                accuracy: LocationAccuracy.high,
                distanceFilter: 150,
              ),
      );
}

class LocationService extends ChangeNotifier with WidgetsBindingObserver {
  LocationService({
    required this.publish,
    required this.clear,
    this.device = const LocationDevice(),
  }) {
    WidgetsBinding.instance.addObserver(this);
  }

  final LocationDevice device;
  final Future<void> Function(Position position, bool historyOnly) publish;
  final Future<void> Function() clear;
  DeviceLocationState state = DeviceLocationState.idle;
  Position? position;
  bool synced = false;
  bool get allowed =>
      state == DeviceLocationState.precise ||
      state == DeviceLocationState.approximate ||
      state == DeviceLocationState.offline;
  bool get supportsBackground => device.supportsBackground;
  bool get historyAllowed => _history;

  bool _active = false, _history = false, _foreground = true, _cleared = false;
  bool _disposed = false;
  int _session = 0, _streamVersion = 0;
  DateTime? _publishedAt;
  Position? _published;
  Future<void>? _refreshing, _sending;
  StreamSubscription<Position>? _stream;
  Timer? _refreshTimer;

  void configure({required bool active, required bool history}) {
    final changed = _history != history;
    _history = history;
    if (!active) {
      if (!_active) return;
      _active = false;
      _session++;
      _cleared = false;
      _publishedAt = null;
      _published = null;
      _refreshing = null;
      _sending = null;
      _stopStream();
      position = null;
      synced = false;
      state = DeviceLocationState.idle;
      return;
    }
    if (!_active || changed) {
      _active = true;
      if (changed) _stopStream();
      if (_foreground) unawaited(refresh(force: changed));
    }
  }

  Future<void> activateFromUi() async {
    if (state == DeviceLocationState.deniedForever) {
      await device.appSettings();
    } else if (state == DeviceLocationState.disabled) {
      await device.deviceSettings();
    } else {
      await refresh(request: true, force: true);
    }
  }

  Future<void> refresh({bool request = false, bool force = false}) {
    if (!_active || !_foreground) return Future.value();
    if (_refreshing != null) {
      if (!request) return _refreshing!;
      return _refreshing!.then((_) => refresh(request: true, force: force));
    }
    final work = _refresh(_session, request, force);
    _refreshing = work;
    return work.whenComplete(() {
      if (identical(_refreshing, work)) _refreshing = null;
    });
  }

  bool _valid(int session) => !_disposed && _active && _session == session;

  Future<void> _refresh(int session, bool request, bool force) async {
    try {
      if (!await device.enabled()) {
        await _unavailable(session, DeviceLocationState.disabled, revoke: true);
        return;
      }
      var permission = await device.permission();
      if (permission == LocationPermission.denied &&
          request &&
          _valid(session)) {
        permission = await device.requestPermission();
      }
      if (!_valid(session)) return;
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        await _unavailable(
          session,
          permission == LocationPermission.deniedForever
              ? DeviceLocationState.deniedForever
              : DeviceLocationState.denied,
          revoke: true,
        );
        return;
      }

      final accuracy = await device.accuracy();
      if (!_valid(session) || !_foreground) return;
      _cleared = false;
      final ready = accuracy == LocationAccuracyStatus.reduced
          ? DeviceLocationState.approximate
          : DeviceLocationState.precise;
      if (position == null) _set(DeviceLocationState.loading);
      final cached = await device.lastKnown();
      final fresh =
          cached != null &&
          DateTime.now().difference(cached.timestamp).abs() <=
              const Duration(minutes: 2);
      Position point;
      try {
        point = fresh && !force ? cached : await device.current();
      } on TimeoutException {
        if (!fresh) rethrow;
        point = cached;
      }
      if (!_valid(session) || !_foreground) return;
      position = point;
      _set(ready);
      await _sync(point, session, force: force);
      if (_valid(session) && _foreground) _startStream(session);
    } on MissingPluginException {
      if (_valid(session)) _set(DeviceLocationState.unavailable);
    } on Exception {
      if (_valid(session)) _set(DeviceLocationState.unavailable);
    }
  }

  Future<void> _unavailable(
    int session,
    DeviceLocationState next, {
    required bool revoke,
  }) async {
    if (!_valid(session)) return;
    _stopStream();
    position = null;
    synced = false;
    _published = null;
    _publishedAt = null;
    _set(next);
    if (!revoke || _cleared) return;
    try {
      await _sending;
      if (!_valid(session) || position != null) return;
      await clear();
      _cleared = true;
    } on Exception {
      // A later resume can retry the server-side removal.
    }
  }

  Future<void> _sync(Position point, int session, {bool force = false}) async {
    if (!_valid(session) || (!_foreground && !_history)) return;
    if (_sending != null) {
      if (!force) return;
      await _sending;
      if (!_valid(session)) return;
    }
    final now = DateTime.now();
    final previous = _published;
    if (!force &&
        previous != null &&
        _publishedAt != null &&
        now.difference(_publishedAt!) < const Duration(minutes: 10) &&
        Geolocator.distanceBetween(
              previous.latitude,
              previous.longitude,
              point.latitude,
              point.longitude,
            ) <
            150) {
      return;
    }
    final historyOnly = !_foreground;
    final work = () async {
      try {
        await publish(point, historyOnly);
        if (!_valid(session)) return;
        _published = point;
        _publishedAt = now;
        if (!historyOnly) {
          synced = true;
          if (state == DeviceLocationState.offline) {
            final accuracy = await device.accuracy();
            if (!_valid(session)) return;
            _set(
              accuracy == LocationAccuracyStatus.reduced
                  ? DeviceLocationState.approximate
                  : DeviceLocationState.precise,
            );
          } else {
            notifyListeners();
          }
        }
      } on Exception {
        if (_valid(session) && !historyOnly) _set(DeviceLocationState.offline);
      }
    }();
    _sending = work;
    await work;
    if (identical(_sending, work)) _sending = null;
  }

  void _startStream(int session) {
    if (_stream != null) return;
    final version = ++_streamVersion;
    _stream = device
        .updates(background: _history && supportsBackground)
        .listen(
          (point) {
            if (!_valid(session) ||
                version != _streamVersion ||
                (!_foreground && !_history)) {
              return;
            }
            if (_foreground) position = point;
            unawaited(_sync(point, session));
          },
          onError: (Object _) {
            if (_valid(session) && _foreground && version == _streamVersion) {
              _stopStream();
              _set(DeviceLocationState.unavailable);
            }
          },
        );
    _refreshTimer ??= Timer.periodic(const Duration(minutes: 10), (_) {
      if (_foreground) unawaited(refresh());
    });
  }

  void _stopStream() {
    _streamVersion++;
    unawaited(_stream?.cancel());
    _stream = null;
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  void _set(DeviceLocationState next) {
    state = next;
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!_foreground && _history) {
        _published = null;
        _publishedAt = null;
      }
      _foreground = true;
      if (_active) unawaited(refresh());
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _foreground = false;
      if (!_history ||
          !supportsBackground ||
          state == AppLifecycleState.detached) {
        _stopStream();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _stopStream();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
