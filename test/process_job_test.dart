import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:klipio/services/process/windows_process_job.dart';

void main() {
  test('registered media worker is terminated and removed', () async {
    if (!Platform.isWindows) return;

    final process = await Process.start(
      'cmd.exe',
      const ['/c', 'ping', '-t', '127.0.0.1'],
    );
    await registerKlipioWorker(process);
    expect(activeKlipioWorkerCount, greaterThanOrEqualTo(1));

    await terminateKlipioWorker(process);
    await process.exitCode.timeout(const Duration(seconds: 5));
    for (var attempt = 0;
        attempt < 20 && activeKlipioWorkerCount != 0;
        attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }

    expect(activeKlipioWorkerCount, 0);
  });
}
