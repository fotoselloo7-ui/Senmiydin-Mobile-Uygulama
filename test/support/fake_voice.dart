import 'dart:async';
import 'dart:io';

import 'package:senmiydin/data/voice_service.dart';

/// A microphone that never touches the platform: it writes a few bytes to the requested path.
class FakeRecorder implements VoiceRecorderDevice {
  FakeRecorder({this.granted = true, this.failToStart = false});

  bool granted;
  bool failToStart;
  int permissionRequests = 0;
  int starts = 0;
  int cancels = 0;
  bool disposed = false;
  String? path;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return granted;
  }

  @override
  Future<void> start(String target) async {
    if (failToStart) throw StateError('recorder busy');
    starts++;
    path = target;
    File(target).writeAsBytesSync(List.filled(64, 7), flush: true);
  }

  @override
  Future<String?> stop() async => path;

  @override
  Future<void> cancel() async {
    cancels++;
    final target = path;
    if (target != null && File(target).existsSync()) File(target).deleteSync();
  }

  @override
  Future<void> dispose() async => disposed = true;
}

/// A player that records what was played; positions and completion are pushed by the test.
class FakePlayer implements VoicePlayerDevice {
  final played = <String>[];
  int pauses = 0;
  int resumes = 0;
  int stops = 0;
  bool disposed = false;
  final _positions = StreamController<Duration>.broadcast();
  final _completed = StreamController<void>.broadcast();

  void emitPosition(Duration value) => _positions.add(value);
  void finish() => _completed.add(null);

  @override
  Future<void> play(String path) async => played.add(path);
  @override
  Future<void> pause() async => pauses++;
  @override
  Future<void> resume() async => resumes++;
  @override
  Future<void> stop() async => stops++;
  @override
  Stream<Duration> get positions => _positions.stream;
  @override
  Stream<void> get completed => _completed.stream;
  @override
  Future<void> dispose() async => disposed = true;
}

/// Installs fakes for every voice seam; returns the handles a test can steer.
class FakeVoice {
  FakeVoice({bool granted = true, bool failToStart = false}) {
    VoiceServices.reset();
    recorder = FakeRecorder(granted: granted, failToStart: failToStart);
    player = FakePlayer();
    clock = DateTime(2026, 11, 15, 12);
    VoiceServices.recorder = () => recorder;
    VoiceServices.player = () => player;
    VoiceServices.now = () => clock;
    VoiceServices.download = (url, headers) async {
      downloads.add(url);
      final directory = await VoiceServices.workDirectory();
      final file = File('${directory.path}/fake_play_${downloads.length}.m4a');
      file.writeAsBytesSync(List.filled(64, 9), flush: true);
      return file.path;
    };
    VoiceServices.workDirectory = () async {
      final directory = Directory('${Directory.systemTemp.path}/senmiydin_voice_test');
      if (!directory.existsSync()) directory.createSync(recursive: true);
      return directory;
    };
  }

  late final FakeRecorder recorder;
  late final FakePlayer player;
  late DateTime clock;
  final downloads = <String>[];

  void advance(Duration by) => clock = clock.add(by);
}
