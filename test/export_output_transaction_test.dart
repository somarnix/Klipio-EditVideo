import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:klipio/features/export/domain/export_models.dart';
import 'package:klipio/features/export/services/export_output_transaction.dart';

void main() {
  for (final mode in [
    'success',
    'failure',
    'throw',
    'invalid',
    'cancel',
    'empty'
  ]) {
    test('export transaction $mode preserves ownership and cleans staging',
        () async {
      final root =
          await Directory.systemTemp.createTemp('klipio-publish-test-');
      addTearDown(() => root.delete(recursive: true));
      final destination = File('${root.path}/output.mp4');
      await destination.writeAsString('old valid output');
      final token = ExportCancelToken();
      final result = await exportOutputTransaction(
          outputPath: destination.path,
          cancelToken: token,
          render: (path) async {
            expect(path, isNot(destination.path));
            expect(await destination.readAsString(), 'old valid output');
            await File(path).writeAsString(mode == 'empty' ? '' : 'new output');
            if (mode == 'throw') throw StateError('worker failure');
            if (mode == 'cancel') token.cancel();
            return ExportResult(
                success: mode != 'failure', message: 'worker result');
          },
          validate: (_) async => mode != 'invalid');
      expect(result.success, mode == 'success');
      expect(await destination.readAsString(),
          mode == 'success' ? 'new output' : 'old valid output');
      expect(await root.list().map((e) => e.uri).toList(), [destination.uri]);
    });
  }
  test('simultaneous exports never share temporary paths', () async {
    final root = await Directory.systemTemp.createTemp('klipio-parallel-test-');
    addTearDown(() => root.delete(recursive: true));
    final paths = <String>[];
    final ready = Completer<void>();
    Future<ExportResult> run() => exportOutputTransaction(
        outputPath: '${root.path}/output.mp4',
        validate: (_) async => true,
        render: (path) async {
          paths.add(path);
          if (paths.length == 2) ready.complete();
          await ready.future;
          await File(path).writeAsString('complete');
          return const ExportResult(success: true, message: 'done');
        });
    final results = await Future.wait([run(), run()]);
    expect(paths.toSet().length, 2);
    expect(results.every((r) => r.success), isTrue,
        reason: results.map((r) => r.message).join('\n'));
    expect(await root.list().length, 1);
  });
  test('concurrent publication burst preserves each successful transaction',
      () async {
    final root = await Directory.systemTemp.createTemp('klipio-publish-burst-');
    addTearDown(() => root.delete(recursive: true));
    final barrier = Completer<void>();
    var prepared = 0;
    final paths = <String>{};
    final results = await Future.wait(List.generate(
        12,
        (i) => exportOutputTransaction(
            outputPath: '${root.path}/output.mp4',
            validate: (_) async => true,
            render: (path) async {
              paths.add(path);
              await File(path).writeAsString('complete-$i', flush: true);
              if (++prepared == 12) barrier.complete();
              await barrier.future;
              return const ExportResult(success: true, message: 'rendered');
            })));
    expect(paths.length, 12);
    expect(results.every((r) => r.success), isTrue,
        reason: results.map((r) => r.message).join('\n'));
    expect(await File('${root.path}/output.mp4').readAsString(),
        startsWith('complete-'));
    expect(await root.list().length, 1);
  });
}
