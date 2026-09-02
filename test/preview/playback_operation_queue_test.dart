import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:klipio/features/preview/engine/playback_operation_queue.dart';

class ControlledPlayer {
  final started = Completer<void>();
  final release = Completer<void>();
  double position = 0;
  final events = <String>[];
  Future<void> seek(double value, {bool hold = false}) async {
    events.add('seek:$value');
    if (hold) {
      started.complete();
      await release.future;
    }
    position = value;
  }
}

void main() {
  test('queued completion cannot start an old clip after user seeks', () async {
    final queue = PlaybackOperationQueue();
    final player = ControlledPlayer();
    var generation = 1;
    final busy = queue.run<void>(
        isCurrent: () => true, operation: () => player.seek(1, hold: true));
    await player.started.future;
    expect(queue.hasPending, isTrue);
    final completion = queue.run<void>(
        isCurrent: () => generation == 1,
        operation: () async {
          player.events.add('play:wrong-next-clip');
        });
    generation = 2;
    final latest = queue.run<void>(
        isCurrent: () => generation == 2, operation: () => player.seek(50));
    player.release.complete();
    await Future.wait([busy, completion, latest]);
    expect(queue.hasPending, isFalse);
    expect(player.position, 50);
    expect(player.events, ['seek:1.0', 'seek:50.0']);
  });
  test('newest seek wins native completion order and stale seek cannot resume',
      () async {
    final queue = PlaybackOperationQueue();
    final player = ControlledPlayer();
    var generation = 1;
    final a = queue.run<void>(
        isCurrent: () => generation == 1,
        operation: () async {
          await player.seek(10, hold: true);
          if (generation != 1) return;
          player.events.addAll(['inspector:A', 'audio:A', 'play:A', 'state:A']);
        });
    await player.started.future;
    generation = 2;
    final b = queue.run<void>(
        isCurrent: () => generation == 2,
        operation: () async {
          await player.seek(20);
          player.events.add('state:B');
        });
    generation = 3;
    final c = queue.run<void>(
        isCurrent: () => generation == 3,
        operation: () async {
          await player.seek(30);
          player.events.add('state:C');
        });
    player.release.complete();
    await Future.wait([a, b, c]);
    expect(player.position, 30);
    expect(player.events, ['seek:10.0', 'seek:30.0', 'state:C']);
  });

  test('superseded preparation cannot apply inspector or audio', () async {
    final queue = PlaybackOperationQueue();
    final started = Completer<void>();
    final preparation = Completer<void>();
    var current = true;
    final events = <String>[];
    final result = queue.run<void>(
        isCurrent: () => current,
        operation: () async {
          started.complete();
          await preparation.future;
          if (!current) return;
          events.addAll(['inspector', 'speed', 'volume', 'play']);
        });
    await started.future;
    current = false;
    preparation.complete();
    await result;
    expect(events, isEmpty);
  });

  test('superseded speed continuation cannot apply volume', () async {
    final queue = PlaybackOperationQueue();
    final speedStarted = Completer<void>();
    final speedDone = Completer<void>();
    var current = true;
    final events = <String>[];
    final result = queue.run<void>(
        isCurrent: () => current,
        operation: () async {
          events.add('speed');
          speedStarted.complete();
          await speedDone.future;
          if (!current) return;
          events.addAll(['volume', 'play']);
        });
    await speedStarted.future;
    current = false;
    speedDone.complete();
    await result;
    expect(events, ['speed']);
  });

  test('failed native operation does not poison the next request', () async {
    final queue = PlaybackOperationQueue();
    await expectLater(
        queue.run<void>(
            isCurrent: () => true,
            operation: () async => throw StateError('decoder')),
        throwsStateError);
    expect(
        await queue.run<int>(isCurrent: () => true, operation: () async => 42),
        42);
  });
}
