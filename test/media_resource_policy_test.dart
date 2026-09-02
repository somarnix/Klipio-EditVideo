import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:klipio/features/settings/data/app_settings.dart';
import 'package:klipio/services/platform/platform_support.dart' as platform;
import 'package:klipio/services/tasks/media_job_manager.dart';
import 'package:klipio/services/tasks/media_worker_policy.dart';
import 'package:klipio/features/preview/engine/software_effect_frame.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'legacy disabled stays off despite smart optimization; explicit modes persist',
      () async {
    SharedPreferences.setMockInitialValues({
      'settings.proxyEnabled': false,
      'settings.autoOptimization': 'smart',
      'settings.language': 'en',
    });
    final legacy = await AppSettings.load();
    expect(legacy.proxyMode, ProxyMode.off);
    expect(legacy.shouldGenerateProxy(demandingMedia: true), isFalse);
    for (final mode in ProxyMode.values) {
      await legacy.copyWith(proxyMode: mode).save();
      final loaded = await AppSettings.load();
      expect(loaded.proxyMode, mode);
      expect(loaded.shouldGenerateProxy(demandingMedia: false),
          mode == ProxyMode.always);
      expect(loaded.shouldGenerateProxy(demandingMedia: true),
          mode != ProxyMode.off);
      expect(
          loaded.shouldGenerateProxy(
              demandingMedia: false, projectOverride: true),
          isTrue);
    }
    expect(const AppSettings(proxyEnabled: true).proxyMode, ProxyMode.always);
  });

  test('duration alone never requests proxies; complexity can qualify Auto',
      () {
    for (final duration in [600.0, 2687.454331, 3600.0]) {
      for (final codec in ['h264', 'vp9']) {
        expect(
            platform.mediaNeedsProxy((
              durationSeconds: duration,
              width: 1920,
              height: 1080,
              frameRate: 30.0,
              videoCodec: codec,
              bitrate: 4600000,
              hasAudio: true
            )),
            isFalse);
      }
    }
    expect(
        platform.mediaNeedsProxy((
          durationSeconds: 10.0,
          width: 3840,
          height: 2160,
          frameRate: 60.0,
          videoCodec: 'hevc',
          bitrate: 24000000,
          hasAudio: true
        )),
        isTrue);
  });

  test(
      'progress watchdog requires advancing media clock, including split pipe chunks',
      () {
    final progress = MediaWorkerProgress();
    expect(progress.add('frame=1\nout_time_'), isFalse);
    expect(progress.add('us=1000000\nprogress=continue\n'), isTrue);
    expect(progress.outputMicroseconds, 1000000);
    expect(progress.add('out_time_us=1000000\n'), isFalse);
    expect(progress.add('out_time_us=N/A\nerrors=0\n'), isFalse);
    expect(progress.add('out_time_us=2000000\nprogress=end\n'), isTrue);
  });

  test(
      'playback preempts interruptible running work; owners do not release each other',
      () async {
    final manager = MediaJobManager();
    final started = Completer<void>();
    var cleaned = false;
    final job = manager.schedule<void>(
        type: MediaJobType.proxy,
        asset: 'long.mp4',
        interruptible: true,
        task: (token) async {
          started.complete();
          try {
            await token.whenCanceled;
            token.throwIfCanceled();
          } finally {
            cleaned = true;
          }
        });
    final expectation =
        expectLater(job, throwsA(isA<MediaJobCanceledException>()));
    await started.future;
    expect(manager.jobs.single.asset, 'long.mp4');
    expect(manager.jobs.single.startedAt, isNotNull);
    await manager.pauseBackgroundWork(owner: 'playback');
    await expectation;
    expect(cleaned, isTrue);
    expect(manager.runningCount, 0);
    expect(manager.cancellationCount, 1);
    await manager.pauseBackgroundWork(owner: 'export');
    manager.resumeBackgroundWork(owner: 'playback');
    expect(manager.isBackgroundPaused, isTrue);
    manager.resumeBackgroundWork(owner: 'export');
    expect(manager.isBackgroundPaused, isFalse);
    await manager.shutdown();
    await expectLater(
        manager.schedule(type: MediaJobType.probe, task: (_) async => 1),
        throwsA(isA<MediaJobCanceledException>()));
  });

  test('real proxy cache deduplicates, publishes, and cleans canceled work',
      () async {
    final root = await Directory.systemTemp.createTemp('klipio-proxy-policy-');
    addTearDown(() async {
      MediaJobManager.instance.resumeBackgroundWork(owner: 'test-playback');
      await platform.cancelBackgroundMediaTasks();
      await root.delete(recursive: true);
    });
    final source = '${root.path}/source.mp4';
    final generated = await Process.run('ffmpeg', [
      '-v',
      'error',
      '-f',
      'lavfi',
      '-i',
      'testsrc2=size=320x180:rate=30:duration=5',
      '-c:v',
      'libx264',
      '-threads',
      '1',
      source
    ]);
    expect(generated.exitCode, 0, reason: '${generated.stderr}');
    final probes = await Future.wait(
        [platform.probeMedia(source), platform.probeMedia(source)]);
    expect(probes.first.durationSeconds, closeTo(5, .01));
    expect(await platform.probeMedia(source), probes.first);
    final decoder = EffectFrameDecoder();
    final frame = await decoder.decode(source, 1);
    expect(frame, isNotEmpty);
    expect(identical(await decoder.decode(source, 1), frame), isTrue);
    expect(decoder.processLaunchCount, 1);
    await decoder.decode(source, 2);
    expect(decoder.processLaunchCount, 2);
    expect(decoder.cachedBytes,
        lessThanOrEqualTo(EffectFrameDecoder.maximumCachedBytes));
    await decoder.close();
    expect(decoder.cachedBytes, 0);
    expect(decoder.cachedFrameCount, 0);
    final cache = '${root.path}/cache';
    final outputs = await Future.wait([
      platform.generateProxyMedia(source, cache, durationSeconds: 5),
      platform.generateProxyMedia(source, cache, durationSeconds: 5),
    ]);
    expect(outputs.first, isNotNull);
    expect(outputs.last, outputs.first);
    expect(await File(outputs.first!).length(), greaterThan(0));
    expect(await Directory(cache).list().length, 1);
    final modified = await File(outputs.first!).lastModified();
    expect(await platform.generateProxyMedia(source, cache), outputs.first);
    expect(await File(outputs.first!).lastModified(), modified);

    final canceled = platform.generateProxyMedia(source, '${root.path}/cancel');
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (!MediaJobManager.instance.jobs
            .any((j) => j.type == MediaJobType.proxy) &&
        DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(
        MediaJobManager.instance.jobs.any((j) => j.type == MediaJobType.proxy),
        isTrue);
    await MediaJobManager.instance.pauseBackgroundWork(owner: 'test-playback');
    // Cancel queued work too if it had not started at the observation boundary.
    await platform.cancelBackgroundMediaTasks();
    expect(await canceled, isNull);
    expect(await Directory('${root.path}/cancel').list().length, 0);
  });
}
