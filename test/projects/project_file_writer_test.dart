import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:klipio/features/projects/services/project_file_writer.dart';

void main() {
  test('queued replacements keep the latest successful revision', () async {
    final root = await Directory.systemTemp.createTemp('klipio-writer-test-');
    addTearDown(() => root.delete(recursive: true));
    final project = File('${root.path}/project.json');
    final queue = ProjectWriteQueue();
    await Future.wait([
      for (var revision = 0; revision < 12; revision++)
        queue.run(() => replaceProjectFile(project, '$revision')),
    ]);
    expect(await project.readAsString(), '11');
    expect(await root.list().length, 1);
  });

  test('save transactions wait and recover after a failed transaction',
      () async {
    final queue = ProjectWriteQueue();
    final gate = Completer<void>();
    final events = <int>[];
    final first = queue.run(() async {
      events.add(1);
      await gate.future;
      throw StateError('disk failure');
    });
    final failure = expectLater(first, throwsStateError);
    final second = queue.run(() async {
      events.add(2);
    });
    await Future<void>.delayed(Duration.zero);
    expect(events, [1]);
    gate.complete();
    await failure;
    await second;
    expect(events, [1, 2]);
  });

  test('replace existing project and clean staging files', () async {
    final root = await Directory.systemTemp.createTemp('klipio-writer-test-');
    addTearDown(() => root.delete(recursive: true));
    final project = File('${root.path}/project.json');
    await project.writeAsString('old');
    await replaceProjectFile(project, '{"revision":2}');
    expect(await project.readAsString(), '{"revision":2}');
    expect(await root.list().length, 1);
  });

  test('failed replacement does not delete destination or leave staging',
      () async {
    final root = await Directory.systemTemp.createTemp('klipio-writer-test-');
    addTearDown(() => root.delete(recursive: true));
    final occupied = await Directory('${root.path}/project.json').create();
    await expectLater(replaceProjectFile(File(occupied.path), 'new'),
        throwsA(isA<FileSystemException>()));
    expect(await occupied.exists(), isTrue);
    expect(await root.list().length, 1);
  });
}
