import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:klipio/services/tasks/media_job_manager.dart';

void main() {
  test('media scheduler enforces total and per-kind concurrency', () async {
    final manager = MediaJobManager(
      maximumConcurrentJobs: 2,
      concurrencyLimits: const {
        MediaJobType.waveform: 1,
        MediaJobType.thumbnail: 2,
      },
    );
    var running = 0;
    var maximumRunning = 0;
    var waveformRunning = 0;
    var maximumWaveforms = 0;
    final release = Completer<void>();

    Future<int> work(
      int value,
      MediaJobType type,
      MediaJobCancellationToken token,
    ) async {
      running++;
      maximumRunning = running > maximumRunning ? running : maximumRunning;
      if (type == MediaJobType.waveform) {
        waveformRunning++;
        maximumWaveforms = waveformRunning > maximumWaveforms
            ? waveformRunning
            : maximumWaveforms;
      }
      await release.future;
      token.throwIfCanceled();
      running--;
      if (type == MediaJobType.waveform) waveformRunning--;
      return value;
    }

    final jobs = <Future<int>>[
      manager.schedule(
        type: MediaJobType.waveform,
        task: (token) => work(1, MediaJobType.waveform, token),
      ),
      manager.schedule(
        type: MediaJobType.waveform,
        task: (token) => work(2, MediaJobType.waveform, token),
      ),
      manager.schedule(
        type: MediaJobType.thumbnail,
        task: (token) => work(3, MediaJobType.thumbnail, token),
      ),
    ];
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(manager.runningCount, 2);
    expect(maximumRunning, 2);
    expect(maximumWaveforms, 1);
    release.complete();
    expect(await Future.wait(jobs), containsAll(<int>[1, 2, 3]));
    expect(manager.runningCount, 0);
  });

  test('canceling a project scope cancels queued and running work', () async {
    final manager = MediaJobManager(maximumConcurrentJobs: 1);
    final started = Completer<void>();
    final running = manager.schedule<void>(
      type: MediaJobType.proxy,
      scopeId: 'project-a',
      task: (token) async {
        started.complete();
        await token.whenCanceled;
        token.throwIfCanceled();
      },
    );
    final queued = manager.schedule<void>(
      type: MediaJobType.proxy,
      scopeId: 'project-a',
      task: (_) async {},
    );
    final runningExpectation =
        expectLater(running, throwsA(isA<MediaJobCanceledException>()));
    final queuedExpectation =
        expectLater(queued, throwsA(isA<MediaJobCanceledException>()));
    await started.future;
    await manager.cancelScope('project-a');
    await runningExpectation;
    await queuedExpectation;
    expect(manager.runningCount, 0);
    expect(manager.pendingCount, 0);
  });

  test('critical jobs run while background work is paused', () async {
    final manager = MediaJobManager(maximumConcurrentJobs: 1);
    manager.pauseBackgroundWork();
    var normalStarted = false;
    final normal = manager.schedule<int>(
      type: MediaJobType.thumbnail,
      task: (_) async {
        normalStarted = true;
        return 1;
      },
    );
    final critical = manager.schedule<int>(
      type: MediaJobType.export,
      priority: MediaJobPriority.critical,
      task: (_) async => 2,
    );
    expect(await critical, 2);
    expect(normalStarted, isFalse);
    manager.resumeBackgroundWork();
    expect(await normal, 1);
  });

  test('job handles expose progress and cancel running work', () async {
    final manager = MediaJobManager(maximumConcurrentJobs: 1);
    final progressReported = Completer<void>();
    final handle = manager.scheduleJob<void>(
      id: 'proxy-with-progress',
      type: MediaJobType.proxy,
      task: (token) async {
        token.reportProgress(0.4);
        progressReported.complete();
        await token.whenCanceled;
        token.throwIfCanceled();
      },
    );
    final canceledExpectation = expectLater(
      handle.result,
      throwsA(isA<MediaJobCanceledException>()),
    );
    await progressReported.future;
    expect(manager.jobs.single.progress, 0.4);
    await handle.cancel();
    await canceledExpectation;
    await handle.dispose();
    expect(manager.jobs, isEmpty);
  });

  test('visible filmstrips run during background pause within decoder bounds',
      () async {
    final manager = MediaJobManager();
    manager.pauseBackgroundWork();
    var proxyStarted = false;
    var secondStarted = false;
    final release = Completer<void>();
    final firstStarted = Completer<void>();
    final proxy = manager.schedule<void>(
      type: MediaJobType.proxy,
      task: (_) async {
        proxyStarted = true;
      },
    );
    final first = manager.schedule<void>(
      type: MediaJobType.thumbnail,
      priority: MediaJobPriority.interactive,
      task: (_) async {
        firstStarted.complete();
        await release.future;
      },
    );
    final second = manager.schedule<void>(
      type: MediaJobType.thumbnail,
      priority: MediaJobPriority.interactive,
      task: (_) async {
        secondStarted = true;
      },
    );
    await firstStarted.future;
    expect(proxyStarted, isFalse);
    expect(secondStarted, isFalse);
    expect(manager.runningCount, 1, reason: 'Only one thumbnail decoder');
    release.complete();
    await Future.wait([first, second]);
    expect(secondStarted, isTrue);
    expect(proxyStarted, isFalse);
    manager.resumeBackgroundWork();
    await proxy;
    expect(manager.pendingCount, 0);
    expect(manager.runningCount, 0);
  });
}
