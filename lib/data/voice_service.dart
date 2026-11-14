import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Limits shared by the recorder UI and (independently re-checked) by the server.
class VoiceLimits {
  VoiceLimits._();
  static const maxDuration = Duration(minutes: 2);
  static const minDuration = Duration(seconds: 1);
  static const maxBytes = 3 * 1024 * 1024;
}

/// "00:12" style clock for a recording or a player.
String voiceClock(Duration value) {
  final seconds = value.inSeconds;
  final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
  final rest = (seconds % 60).toString().padLeft(2, '0');
  return '$minutes:$rest';
}

/// The microphone, behind a seam so screens and tests never touch the platform plugin directly.
abstract class VoiceRecorderDevice {
  /// Asks the system for the microphone permission (no dialog when it is already decided). True when granted.
  Future<bool> requestPermission();
  Future<void> start(String path);

  /// Stops and returns the file path (null when nothing was recorded).
  Future<String?> stop();
  Future<void> cancel();
  Future<void> dispose();
}

class RecordPackageRecorder implements VoiceRecorderDevice {
  final _recorder = AudioRecorder();

  @override
  Future<bool> requestPermission() => _recorder.hasPermission();

  @override
  Future<void> start(String path) => _recorder.start(
    // AAC-LC in an M4A container: small, native on Android and iOS and what the server accepts.
    const RecordConfig(
      encoder: AudioEncoder.aacLc,
      bitRate: 64000,
      sampleRate: 44100,
      numChannels: 1,
    ),
    path: path,
  );

  @override
  Future<String?> stop() => _recorder.stop();

  @override
  Future<void> cancel() => _recorder.cancel();

  @override
  Future<void> dispose() => _recorder.dispose();
}

/// Plays one local file at a time.
abstract class VoicePlayerDevice {
  Future<void> play(String path);
  Future<void> pause();
  Future<void> resume();
  Future<void> stop();
  Stream<Duration> get positions;
  Stream<void> get completed;
  Future<void> dispose();
}

class AudioplayersPlayer implements VoicePlayerDevice {
  final _player = AudioPlayer();

  @override
  Future<void> play(String path) => _player.play(DeviceFileSource(path));
  @override
  Future<void> pause() => _player.pause();
  @override
  Future<void> resume() => _player.resume();
  @override
  Future<void> stop() => _player.stop();
  @override
  Stream<Duration> get positions => _player.onPositionChanged;
  @override
  Stream<void> get completed => _player.onPlayerComplete;
  @override
  Future<void> dispose() => _player.dispose();
}

/// Where the app gets its voice devices from. Tests replace the factories with fakes.
class VoiceServices {
  VoiceServices._();
  static VoiceRecorderDevice Function() recorder = RecordPackageRecorder.new;
  static VoicePlayerDevice Function() player = AudioplayersPlayer.new;

  /// Downloads a (private) voice file with the account's credentials and returns the local path.
  static Future<String> Function(String url, Map<String, String> headers)
  download = _download;

  /// Folder for drafts and downloaded voice files; removed when a chat closes.
  static Future<Directory> Function() workDirectory = _workDirectory;

  /// The explanation dialog was accepted once in this session; a denial is remembered too, so nobody is asked in a loop.
  static bool explained = false;
  static bool denied = false;

  /// The clock behind recording time; tests drive it by hand.
  static DateTime Function() now = DateTime.now;

  static Future<Directory> _workDirectory() async {
    final base = await getTemporaryDirectory();
    final directory = Directory('${base.path}/voice');
    if (!await directory.exists()) await directory.create(recursive: true);
    return directory;
  }

  static Future<String> _download(
    String url,
    Map<String, String> headers,
  ) async {
    final response = await http.get(Uri.parse(url), headers: headers);
    if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
      throw const FileSystemException('voice download failed');
    }
    final directory = await workDirectory();
    final file = File(
      '${directory.path}/play_${url.hashCode.abs()}_${DateTime.now().microsecondsSinceEpoch}.m4a',
    );
    await file.writeAsBytes(response.bodyBytes, flush: true);
    return file.path;
  }

  @visibleForTesting
  static void reset() {
    recorder = RecordPackageRecorder.new;
    player = AudioplayersPlayer.new;
    download = _download;
    workDirectory = _workDirectory;
    explained = false;
    denied = false;
    now = DateTime.now;
  }
}

enum VoiceRecordingPhase { idle, recording, preview }

/// The recording state machine behind the composer: idle → recording → preview (listen, send or discard).
class VoiceRecordingController extends ChangeNotifier {
  VoiceRecordingController({VoiceRecorderDevice? device})
    : _device = device ?? VoiceServices.recorder();

  final VoiceRecorderDevice _device;
  Timer? _ticker;
  DateTime? _startedAt;
  String? _path;
  var _phase = VoiceRecordingPhase.idle;
  var _elapsed = Duration.zero;
  var _disposed = false;

  VoiceRecordingPhase get phase => _phase;
  Duration get elapsed => _elapsed;

  /// The finished recording while in the preview phase.
  String? get path => _path;
  bool get recording => _phase == VoiceRecordingPhase.recording;
  bool get hasPreview => _phase == VoiceRecordingPhase.preview;

  Future<bool> requestPermission() => _device.requestPermission();

  /// Starts recording into a fresh file. False when the device refused.
  Future<bool> start() async {
    if (_phase != VoiceRecordingPhase.idle) return false;
    try {
      final directory = await VoiceServices.workDirectory();
      final path =
          '${directory.path}/draft_${DateTime.now().microsecondsSinceEpoch}.m4a';
      await _device.start(path);
      _path = path;
      _startedAt = VoiceServices.now();
      _elapsed = Duration.zero;
      _phase = VoiceRecordingPhase.recording;
      _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
        _elapsed = VoiceServices.now().difference(_startedAt!);
        if (_elapsed >= VoiceLimits.maxDuration) {
          unawaited(stop());
        } else {
          _notify();
        }
      });
      _notify();
      return true;
    } catch (_) {
      _phase = VoiceRecordingPhase.idle;
      _notify();
      return false;
    }
  }

  /// Stops the recording. Anything shorter than [VoiceLimits.minDuration] (a silent tap) is thrown away: returns false.
  Future<bool> stop() async {
    if (_phase != VoiceRecordingPhase.recording) return false;
    _ticker?.cancel();
    final length = _startedAt == null
        ? _elapsed
        : VoiceServices.now().difference(_startedAt!);
    String? path;
    try {
      path = await _device.stop();
    } catch (_) {
      path = null;
    }
    _elapsed = length > VoiceLimits.maxDuration
        ? VoiceLimits.maxDuration
        : length;
    if (path == null || _elapsed < VoiceLimits.minDuration) {
      await _deleteFile(path ?? _path);
      _reset();
      return false;
    }
    _path = path;
    _phase = VoiceRecordingPhase.preview;
    _notify();
    return true;
  }

  /// Cancels a running recording or discards the preview; the file is deleted.
  Future<void> discard() async {
    _ticker?.cancel();
    if (_phase == VoiceRecordingPhase.recording) {
      try {
        await _device.cancel();
      } catch (_) {
        // Nothing left to stop.
      }
    }
    await _deleteFile(_path);
    _reset();
  }

  /// After a successful send the file is no longer needed.
  Future<void> finish() async {
    await _deleteFile(_path);
    _reset();
  }

  void _reset() {
    _ticker?.cancel();
    _path = null;
    _startedAt = null;
    _elapsed = Duration.zero;
    _phase = VoiceRecordingPhase.idle;
    _notify();
  }

  Future<void> _deleteFile(String? path) async {
    if (path == null) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Temporary file; the OS cleans it up eventually.
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _ticker?.cancel();
    unawaited(_cleanup());
    super.dispose();
  }

  Future<void> _cleanup() async {
    if (_phase == VoiceRecordingPhase.recording) {
      try {
        await _device.cancel();
      } catch (_) {
        // Already stopped.
      }
    }
    await _deleteFile(_path);
    await _device.dispose();
  }
}

enum VoiceItemState { idle, loading, playing, paused, failed }

/// Playback of voice messages (and of the draft preview): one sound at a time, cleaned up with the chat.
class VoicePlayback extends ChangeNotifier {
  VoicePlayback({VoicePlayerDevice? device})
    : _device = device ?? VoiceServices.player() {
    _subscriptions.add(
      _device.positions.listen((position) {
        _position = position;
        _notify();
      }),
    );
    _subscriptions.add(
      _device.completed.listen((_) {
        _state = VoiceItemState.idle;
        _position = Duration.zero;
        _notify();
      }),
    );
  }

  final VoicePlayerDevice _device;
  final _subscriptions = <StreamSubscription<Object?>>[];
  final _downloaded = <String>{};
  final _cache = <String, String>{};
  Object? _current;
  var _state = VoiceItemState.idle;
  var _position = Duration.zero;
  var _disposed = false;

  Object? get current => _current;
  Duration get position => _position;

  VoiceItemState stateOf(Object key) =>
      key == _current ? _state : VoiceItemState.idle;
  Duration positionOf(Object key) =>
      key == _current ? _position : Duration.zero;

  /// Play / pause [key]. [source] resolves the local file (downloading a message's audio the first time). Starting a
  /// different sound stops the one that was playing.
  Future<void> toggle(Object key, Future<String> Function() source) async {
    if (_disposed) return;
    if (key == _current) {
      switch (_state) {
        case VoiceItemState.playing:
          await _device.pause();
          _state = VoiceItemState.paused;
          _notify();
          return;
        case VoiceItemState.paused:
          await _device.resume();
          _state = VoiceItemState.playing;
          _notify();
          return;
        case VoiceItemState.loading:
          return;
        case VoiceItemState.idle:
        case VoiceItemState.failed:
          break;
      }
    }
    if (_current != null && _current != key) {
      await _device.stop();
    }
    _current = key;
    _position = Duration.zero;
    _state = VoiceItemState.loading;
    _notify();
    try {
      final path = _cache[key.toString()] ??= await source();
      if (_disposed || _current != key) return;
      if (key is int) _downloaded.add(path);
      await _device.play(path);
      _state = VoiceItemState.playing;
    } catch (_) {
      _cache.remove(key.toString());
      _state = VoiceItemState.failed;
    }
    _notify();
  }

  Future<void> stopAll() async {
    _current = null;
    _state = VoiceItemState.idle;
    _position = Duration.zero;
    try {
      await _device.stop();
    } catch (_) {
      // Already stopped.
    }
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    unawaited(_cleanup());
    super.dispose();
  }

  Future<void> _cleanup() async {
    try {
      await _device.stop();
    } catch (_) {
      // Already stopped.
    }
    for (final path in _downloaded) {
      try {
        final file = File(path);
        if (await file.exists()) await file.delete();
      } catch (_) {
        // Temporary download.
      }
    }
    await _device.dispose();
  }
}
