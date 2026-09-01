import 'dart:async';

enum MediaJobType {
  export,
  proxy,
  waveform,
  thumbnail,
  probe,
}

enum MediaJobPriority {
  critical(0),
  high(10),
  normal(20),
  low(30);

  const MediaJobPriority(this.weight);

  final int weight;
}

enum MediaJobState {
  queued,
  running,
  completed,
  failed,
  canceled,
}

class MediaJobCanceledException implements Exception {
  const MediaJobCanceledException([this.message = 'Media job canceled.']);

  final String message;

  @override
  String toString() => message;
}

class MediaJobCancellationToken {
  final Completer<void> _canceled = Completer<void>();
  void Function(double progress)? _progressListener;

  bool get isCanceled => _canceled.isCompleted;
  Future<void> get whenCanceled => _canceled.future;

  void throwIfCanceled() {
    if (isCanceled) throw const MediaJobCanceledException();
  }

  void reportProgress(double value) {
    if (!isCanceled) {
      _progressListener?.call(value.clamp(0.0, 1.0).toDouble());
    }
  }

  void _cancel() {
    if (!_canceled.isCompleted) _canceled.complete();
  }
}

class MediaJobSnapshot {
  const MediaJobSnapshot({
    required this.id,
    required this.scopeId,
    required this.type,
    required this.priority,
    required this.state,
    required this.progress,
  });

  final String id;
  final String scopeId;
  final MediaJobType type;
  final MediaJobPriority priority;
  final MediaJobState state;
  final double progress;
}

class MediaJobHandle<T> {
  MediaJobHandle._(this.id, this.result, this._manager);

  final String id;
  final Future<T> result;
  final MediaJobManager _manager;
  bool _disposed = false;

  Future<void> cancel() => _manager.cancelJob(id);

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await cancel();
  }
}

typedef MediaJobTask<T> = Future<T> Function(
  MediaJobCancellationToken cancellationToken,
);

/// Schedules expensive media work with strict global and per-kind limits.
///
/// FFmpeg and FFprobe remain external processes, but every background launch
/// passes through this scheduler. Canceling a project scope cancels queued
/// work immediately and signals running work so its process tree can exit.
class MediaJobManager {
  MediaJobManager({
    this.maximumConcurrentJobs = 3,
    Map<MediaJobType, int>? concurrencyLimits,
  }) : concurrencyLimits = Map.unmodifiable(
          concurrencyLimits ??
              const <MediaJobType, int>{
                MediaJobType.export: 1,
                MediaJobType.proxy: 1,
                MediaJobType.waveform: 1,
                MediaJobType.thumbnail: 2,
                MediaJobType.probe: 2,
              },
        );

  static final MediaJobManager instance = MediaJobManager();

  final int maximumConcurrentJobs;
  final Map<MediaJobType, int> concurrencyLimits;
  final List<_QueuedMediaJob> _queue = <_QueuedMediaJob>[];
  final Map<String, _QueuedMediaJob> _running = <String, _QueuedMediaJob>{};
  final Map<MediaJobType, int> _runningByType = <MediaJobType, int>{};
  int _sequence = 0;
  bool _backgroundPaused = false;

  int get pendingCount => _queue.length;
  int get runningCount => _running.length;

  List<MediaJobSnapshot> get jobs => <MediaJobSnapshot>[
        for (final job in _running.values) job.snapshot,
        for (final job in _queue) job.snapshot,
      ];

  Future<T> schedule<T>({
    required MediaJobType type,
    required MediaJobTask<T> task,
    MediaJobPriority priority = MediaJobPriority.normal,
    String scopeId = 'project-media',
    String? id,
  }) =>
      scheduleJob<T>(
        type: type,
        task: task,
        priority: priority,
        scopeId: scopeId,
        id: id,
      ).result;

  MediaJobHandle<T> scheduleJob<T>({
    required MediaJobType type,
    required MediaJobTask<T> task,
    MediaJobPriority priority = MediaJobPriority.normal,
    String scopeId = 'project-media',
    String? id,
  }) {
    final completer = Completer<T>();
    final resolvedId = id ?? '${type.name}-${++_sequence}';
    final job = _QueuedMediaJob(
      id: resolvedId,
      scopeId: scopeId,
      type: type,
      priority: priority,
      sequence: _sequence,
      completeResult: (value) => completer.complete(value as T),
      completeFailure: completer.completeError,
      isCompleted: () => completer.isCompleted,
      run: (token) async => task(token),
    );
    job.token._progressListener = job.updateProgress;
    _queue.add(job);
    _sortQueue();
    scheduleMicrotask(_drain);
    return MediaJobHandle<T>._(resolvedId, completer.future, this);
  }

  void pauseBackgroundWork() {
    _backgroundPaused = true;
  }

  void resumeBackgroundWork() {
    if (!_backgroundPaused) return;
    _backgroundPaused = false;
    scheduleMicrotask(_drain);
  }

  Future<void> cancelScope(String scopeId) async {
    _cancelWhere((job) => job.scopeId == scopeId);
    await _waitForCanceledJobs((job) => job.scopeId == scopeId);
  }

  Future<void> cancelJob(String id) async {
    _cancelWhere((job) => job.id == id);
    await _waitForCanceledJobs((job) => job.id == id);
  }

  Future<void> cancelType(MediaJobType type) async {
    _cancelWhere((job) => job.type == type);
    await _waitForCanceledJobs((job) => job.type == type);
  }

  Future<void> cancelAll() async {
    _cancelWhere((_) => true);
    await _waitForCanceledJobs((_) => true);
  }

  void _sortQueue() {
    _queue.sort((left, right) {
      final priority = left.priority.weight.compareTo(right.priority.weight);
      return priority != 0 ? priority : left.sequence.compareTo(right.sequence);
    });
  }

  void _cancelWhere(bool Function(_QueuedMediaJob job) predicate) {
    final queued = _queue.where(predicate).toList();
    for (final job in queued) {
      _queue.remove(job);
      job.cancelQueued();
    }
    for (final job in _running.values.where(predicate)) {
      job.cancelRunning();
    }
  }

  Future<void> _waitForCanceledJobs(
    bool Function(_QueuedMediaJob job) predicate,
  ) async {
    final completions = <Future<void>>[
      for (final job in _running.values.where(predicate)) job.finished,
    ];
    if (completions.isEmpty) return;
    await Future.wait<void>(completions).timeout(
      const Duration(seconds: 8),
      onTimeout: () => const <void>[],
    );
  }

  void _drain() {
    if (_queue.isEmpty || _running.length >= maximumConcurrentJobs) return;
    while (_running.length < maximumConcurrentJobs) {
      final index = _nextRunnableIndex();
      if (index < 0) return;
      final job = _queue.removeAt(index);
      _start(job);
    }
  }

  int _nextRunnableIndex() {
    for (var index = 0; index < _queue.length; index++) {
      final job = _queue[index];
      if (_backgroundPaused && job.priority != MediaJobPriority.critical) {
        continue;
      }
      final limit = concurrencyLimits[job.type] ?? 1;
      if ((_runningByType[job.type] ?? 0) < limit) return index;
    }
    return -1;
  }

  void _start(_QueuedMediaJob job) {
    job.state = MediaJobState.running;
    _running[job.id] = job;
    _runningByType[job.type] = (_runningByType[job.type] ?? 0) + 1;
    unawaited(() async {
      try {
        job.token.throwIfCanceled();
        final value = await job.run(job.token);
        if (job.token.isCanceled) {
          job.completeCanceled();
        } else {
          job.complete(value);
        }
      } catch (error, stackTrace) {
        if (job.token.isCanceled || error is MediaJobCanceledException) {
          job.completeCanceled();
        } else {
          job.completeError(error, stackTrace);
        }
      } finally {
        _running.remove(job.id);
        final remaining = (_runningByType[job.type] ?? 1) - 1;
        if (remaining <= 0) {
          _runningByType.remove(job.type);
        } else {
          _runningByType[job.type] = remaining;
        }
        job.markFinished();
        _drain();
      }
    }());
  }
}

class _QueuedMediaJob {
  _QueuedMediaJob({
    required this.id,
    required this.scopeId,
    required this.type,
    required this.priority,
    required this.sequence,
    required this.completeResult,
    required this.completeFailure,
    required this.isCompleted,
    required this.run,
  });

  final String id;
  final String scopeId;
  final MediaJobType type;
  final MediaJobPriority priority;
  final int sequence;
  final void Function(Object? value) completeResult;
  final void Function(Object error, [StackTrace? stackTrace]) completeFailure;
  final bool Function() isCompleted;
  final Future<Object?> Function(MediaJobCancellationToken token) run;
  final MediaJobCancellationToken token = MediaJobCancellationToken();
  final Completer<void> _finished = Completer<void>();
  MediaJobState state = MediaJobState.queued;
  double progress = 0;

  Future<void> get finished => _finished.future;

  MediaJobSnapshot get snapshot => MediaJobSnapshot(
        id: id,
        scopeId: scopeId,
        type: type,
        priority: priority,
        state: state,
        progress: progress,
      );

  void updateProgress(double value) {
    progress = value;
  }

  void cancelQueued() {
    token._cancel();
    completeCanceled();
    markFinished();
  }

  void cancelRunning() {
    token._cancel();
  }

  void complete(Object? value) {
    state = MediaJobState.completed;
    progress = 1;
    if (!isCompleted()) completeResult(value);
  }

  void completeError(Object error, StackTrace stackTrace) {
    state = MediaJobState.failed;
    if (!isCompleted()) completeFailure(error, stackTrace);
  }

  void completeCanceled() {
    state = MediaJobState.canceled;
    if (!isCompleted()) completeFailure(const MediaJobCanceledException());
  }

  void markFinished() {
    if (!_finished.isCompleted) _finished.complete();
  }
}
