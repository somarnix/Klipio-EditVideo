import 'dart:async';
import 'dart:io';
import 'dart:collection';
import '../../../core/storage/application_paths.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../../services/process/windows_process_job.dart';
import '../../../services/tasks/media_job_manager.dart';
import '../../timeline/domain/timeline_models.dart';
import 'professional_clip_preview.dart';
import '../../../services/diagnostics/performance_diagnostics.dart';

/// Bounded software source-frame decoder for native textures that cannot be
/// filtered safely. One process/one pending request; no frame files or history.
class EffectFrameDecoder {
  static int _nextScope = 0;
  final String _scope = 'effect-preview-${++_nextScope}';
  final LinkedHashMap<String, Uint8List> _frames = LinkedHashMap();
  int _cachedBytes = 0;
  int get cachedBytes => _cachedBytes;
  int get cachedFrameCount => _frames.length;
  int processLaunchCount = 0;
  static const maximumCachedBytes = 8 * 1024 * 1024;
  static const maximumCachedFrames = 32;
  // Effects are previewed at a bounded temporal resolution. Requests within
  // the same half-second bucket share one decoded frame, preventing a native
  // process launch for every playback tick while retaining smooth visual
  // updates through the widget's latest-request coalescing.
  static const previewBucketSeconds = 0.5;
  Process? _process;
  _EffectStreamSession? _session;
  final Map<String, Future<Uint8List>> _inFlight = {};
  bool _closed = false;
  Future<Uint8List> decode(String path, double sourceSeconds) async {
    if (_closed) throw StateError('Decoder closed');
    if (!sourceSeconds.isFinite || sourceSeconds < 0) {
      throw ArgumentError('Invalid source frame time');
    }
    final stat = await File(path).stat();
    if (_closed) throw StateError('Decoder closed');
    final sampledSeconds =
        (sourceSeconds / previewBucketSeconds).round() * previewBucketSeconds;
    final key =
        '$path:${stat.size}:${stat.modified.microsecondsSinceEpoch}:${sampledSeconds.toStringAsFixed(3)}';
    final cached = _frames.remove(key);
    if (cached != null) {
      PerformanceDiagnostics.instance.event(
          'EFFECT_CACHE_HIT', {'source': path, 'bucket': sampledSeconds});
      _frames[key] = cached;
      return cached;
    }
    final pending = _inFlight[key];
    if (pending != null) {
      PerformanceDiagnostics.instance.event('EFFECT_REQUEST_COALESCED',
          {'source': path, 'bucket': sampledSeconds});
      return pending;
    }
    final pendingDecode = MediaJobManager.instance.schedule<Uint8List>(
      type: MediaJobType.preview,
      priority: MediaJobPriority.interactive,
      scopeId: _scope,
      asset: path,
      interruptible: true,
      task: (token) => _decodeFrame(path, sampledSeconds, token),
    );
    _inFlight[key] = pendingDecode;
    late final Uint8List bytes;
    try {
      bytes = await pendingDecode;
    } finally {
      if (identical(_inFlight[key], pendingDecode)) _inFlight.remove(key);
    }
    PerformanceDiagnostics.instance
        .event('EFFECT_CACHE_MISS', {'source': path, 'bucket': sampledSeconds});
    if (_closed) throw StateError('Decoder closed');
    final replaced = _frames.remove(key);
    if (replaced != null) _cachedBytes -= replaced.length;
    _frames[key] = bytes;
    _cachedBytes += bytes.length;
    while (_cachedBytes > maximumCachedBytes ||
        _frames.length > maximumCachedFrames) {
      _cachedBytes -= _frames.remove(_frames.keys.first)!.length;
    }
    return bytes;
  }

  Future<Uint8List> _decodeFrame(String path, double sourceSeconds,
      MediaJobCancellationToken token) async {
    token.throwIfCanceled();
    if (_closed) throw StateError('Decoder closed');
    final session = _session;
    if (session != null && session.matches(path, sourceSeconds)) {
      return session.frameAt(sourceSeconds, token);
    }
    if (session != null) await session.close();
    final stream = _EffectStreamSession(path, sourceSeconds);
    _session = stream;
    final bytes =
        await stream.frameAt(sourceSeconds, token, onProcess: (process) {
      _process = process;
      processLaunchCount++;
      PerformanceDiagnostics.instance.event('EFFECT_FFMPEG_LAUNCH', {
        'source': path,
        'bucket': sourceSeconds,
        'launchCount': processLaunchCount,
        'pid': process.pid,
        'persistentSession': true,
      });
    });
    if (identical(_session, stream)) _process = stream.process;
    return bytes;
    /*
    final process = await Process.start(ApplicationPaths.mediaTool('ffmpeg'), [
      '-v',
      'error',
      '-ss',
      sourceSeconds.toStringAsFixed(6),
      '-threads',
      '1',
      '-filter_threads',
      '1',
      '-i',
      path,
      '-frames:v',
      '1',
      '-vf',
      'scale=640:640:force_original_aspect_ratio=decrease',
      '-threads',
      '1',
      '-f',
      'image2pipe',
      '-vcodec',
      'png',
      'pipe:1'
    ]);
    processLaunchCount++;
    PerformanceDiagnostics.instance.event('EFFECT_FFMPEG_LAUNCH', {
      'source': path,
      'bucket': sourceSeconds,
      'launchCount': processLaunchCount,
      'pid': process.pid,
    });
    _process = process;
    await registerKlipioWorker(process,
        jobType: 'preview', asset: path, executable: 'ffmpeg');
    final output = BytesBuilder(copy: false);
    final reading = process.stdout.listen((chunk) {
      if (output.length + chunk.length <= 4 * 1024 * 1024) {
        output.add(chunk);
      } else {
        process.kill();
      }
    });
    final errors = process.stderr.drain<void>();
    final drained = reading.asFuture<void>();
    var exited = false;
    try {
      if (_closed || token.isCanceled) await terminateKlipioWorker(process);
      final code = await Future.any([
        process.exitCode,
        token.whenCanceled.then((_) => -3),
      ]).timeout(const Duration(seconds: 8));
      if (code == -3) await terminateKlipioWorker(process);
      exited = true;
      await errors;
      // exitCode can precede stdout completion; wait for all bytes.
      await drained;
      if (code != 0 || output.isEmpty || _closed) {
        throw StateError('Effect frame decode failed');
      }
      return output.takeBytes();
    } finally {
      if (!exited) await terminateKlipioWorker(process);
      await reading.cancel();
      if (identical(_process, process)) _process = null;
    }
  }
  */
  }

  Future<void> close() async {
    _closed = true;
    _frames.clear();
    _inFlight.clear();
    _cachedBytes = 0;
    await MediaJobManager.instance.cancelScope(_scope);
    final session = _session;
    _session = null;
    if (session != null) await session.close();
    final process = _process;
    if (process != null) await terminateKlipioWorker(process);
  }
}

/// A short-lived, reusable decode window. FFmpeg emits a fixed-rate PNG stream
/// for a bounded window, so sequential playback requests reuse one process
/// instead of spawning a process for every bucket. A seek outside the window
/// replaces the window; this keeps memory and native process ownership bounded.
class _EffectStreamSession {
  _EffectStreamSession(this.path, this.startSeconds);

  final String path;
  final double startSeconds;
  static const double windowSeconds = 20;
  Process? process;
  StreamSubscription<List<int>>? _stdout;
  final List<Uint8List> _frames = [];
  final List<Completer<Uint8List>> _waiters = [];
  Uint8List _buffer = Uint8List(0);
  bool _started = false;
  bool _closed = false;

  bool matches(String candidate, double seconds) =>
      candidate == path &&
      seconds >= startSeconds - 0.01 &&
      seconds <= startSeconds + windowSeconds;

  Future<Uint8List> frameAt(double seconds, MediaJobCancellationToken token,
      {void Function(Process process)? onProcess}) async {
    token.throwIfCanceled();
    if (!_started) await _start(onProcess);
    final wanted = ((seconds - startSeconds) * 2).round().clamp(0, 40);
    while (_frames.length <= wanted && !_closed) {
      final waiter = Completer<Uint8List>();
      _waiters.add(waiter);
      final frame = await Future.any<Uint8List>([
        waiter.future,
        token.whenCanceled.then<Uint8List>(
            (_) => throw StateError('Effect preview request canceled')),
      ]);
      if (frame.isNotEmpty) {
        _frames.add(frame);
      }
    }
    if (wanted >= _frames.length) throw StateError('Effect frame unavailable');
    return _frames[wanted];
  }

  Future<void> _start(void Function(Process process)? onProcess) async {
    if (_started) return;
    _started = true;
    final started = await Process.start(ApplicationPaths.mediaTool('ffmpeg'), [
      '-v',
      'error',
      '-ss',
      startSeconds.toStringAsFixed(6),
      '-i',
      path,
      '-t',
      windowSeconds.toStringAsFixed(1),
      '-vf',
      'fps=2,scale=640:640:force_original_aspect_ratio=decrease,pad=640:640:(ow-iw)/2:(oh-ih)/2',
      '-threads',
      '1',
      '-filter_threads',
      '1',
      '-f',
      'image2pipe',
      '-vcodec',
      'png',
      'pipe:1',
    ]);
    process = started;
    onProcess?.call(started);
    await registerKlipioWorker(started,
        jobType: 'preview-stream', asset: path, executable: 'ffmpeg');
    _stdout = started.stdout.listen(_consume);
    unawaited(started.exitCode.then((_) {
      if (!_closed) {
        for (final waiter in _waiters) {
          if (!waiter.isCompleted) {
            waiter.completeError(StateError('Effect preview stream ended'));
          }
        }
        _waiters.clear();
      }
    }));
  }

  void _consume(List<int> chunk) {
    final combined = Uint8List(_buffer.length + chunk.length)
      ..setRange(0, _buffer.length, _buffer)
      ..setRange(_buffer.length, _buffer.length + chunk.length, chunk);
    _buffer = combined;
    const signature = <int>[137, 80, 78, 71, 13, 10, 26, 10];
    const end = <int>[73, 69, 78, 68, 174, 66, 96, 130];
    while (true) {
      var start = _indexOf(_buffer, signature);
      if (start < 0) {
        _buffer = Uint8List(0);
        return;
      }
      final finish = _indexOf(_buffer, end, start + signature.length);
      if (finish < 0) {
        if (start > 0) _buffer = _buffer.sublist(start);
        return;
      }
      final length = finish + end.length;
      final frame = Uint8List.fromList(_buffer.sublist(start, length));
      _buffer = _buffer.sublist(length);
      if (_waiters.isNotEmpty) _waiters.removeAt(0).complete(frame);
    }
  }

  int _indexOf(Uint8List data, List<int> needle, [int from = 0]) {
    for (var i = from; i <= data.length - needle.length; i++) {
      var found = true;
      for (var j = 0; j < needle.length; j++) {
        if (data[i + j] != needle[j]) {
          found = false;
          break;
        }
      }
      if (found) return i;
    }
    return -1;
  }

  Future<void> close() async {
    _closed = true;
    await _stdout?.cancel();
    final current = process;
    if (current != null) await terminateKlipioWorker(current);
    for (final waiter in _waiters) {
      if (!waiter.isCompleted) {
        waiter.completeError(StateError('Session closed'));
      }
    }
    _waiters.clear();
    process = null;
  }
}

/// Sampled software preview, not a claim of native frame-rate playback parity.
/// Effects still use ProfessionalClipPreview; this only replaces source decode.
class SoftwareEffectFrame extends StatefulWidget {
  const SoftwareEffectFrame(
      {super.key, required this.clip, required this.time, this.decoder});
  final ClipModel clip;
  final double time;
  final EffectFrameDecoder? decoder;
  @override
  State<SoftwareEffectFrame> createState() => _SoftwareEffectFrameState();
}

class _SoftwareEffectFrameState extends State<SoftwareEffectFrame> {
  late final EffectFrameDecoder _decoder =
      widget.decoder ?? EffectFrameDecoder();
  Uint8List? _bytes;
  Object? _error;
  bool _busy = false, _again = false;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(SoftwareEffectFrame old) {
    super.didUpdateWidget(old);
    if (old.clip.id != widget.clip.id ||
        old.clip.mediaPath != widget.clip.mediaPath) {
      _generation++;
      _bytes = null;
    }
    if (old.time != widget.time || !identical(old.clip, widget.clip)) {
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    if (_busy) {
      _again = true;
      return;
    }
    _busy = true;
    do {
      _again = false;
      final generation = _generation;
      final clip = widget.clip;
      final source = clip.sourceStart +
          (widget.time - clip.timelineStart).clamp(0, clip.duration) *
              clip.resolvedPlaybackSpeed();
      try {
        final bytes = await _decoder.decode(clip.mediaPath, source);
        if (mounted && generation == _generation) {
          setState(() {
            _bytes = bytes;
            _error = null;
          });
        }
      } catch (error) {
        if (mounted && generation == _generation) {
          setState(() {
            _error = error;
            _bytes = null;
          });
        }
      }
    } while (mounted && _again);
    _busy = false;
  }

  @override
  void dispose() {
    _generation++;
    unawaited(_decoder.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return ColoredBox(
          color: Colors.black,
          child: Center(
              child: TextButton(
                  onPressed: () => unawaited(_load()),
                  child: const Text('Effect preview failed — Retry'))));
    }
    if (_bytes == null) {
      return const ColoredBox(
          color: Colors.black,
          child: Center(
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))));
    }
    return ProfessionalClipPreview(
        clip: widget.clip,
        playheadSeconds: widget.time,
        child: Image.memory(_bytes!, fit: BoxFit.fill, gaplessPlayback: false));
  }
}
