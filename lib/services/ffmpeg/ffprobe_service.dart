import 'dart:convert';
import 'dart:io';
import '../../core/storage/application_paths.dart';

import '../process/windows_process_job.dart';

class FfprobeService {
  const FfprobeService({this.executable = 'ffprobe'});

  final String executable;

  Future<Map<String, Object?>> inspect(String mediaPath) async {
    final process =
        await Process.start(ApplicationPaths.mediaTool(executable), [
      '-v',
      'error',
      '-show_format',
      '-show_streams',
      '-of',
      'json',
      mediaPath,
    ]);
    await registerKlipioWorker(process);
    final stdout = process.stdout.transform(systemEncoding.decoder).join();
    final stderr = process.stderr.transform(systemEncoding.decoder).join();
    final exitCode = await Future.any<int>([
      process.exitCode,
      Future<int>.delayed(const Duration(seconds: 30), () => -1),
    ]);
    if (exitCode == -1) await terminateKlipioWorker(process);
    final output = await stdout.timeout(
      const Duration(seconds: 3),
      onTimeout: () => '',
    );
    final error = await stderr.timeout(
      const Duration(seconds: 3),
      onTimeout: () => 'FFprobe timed out.',
    );
    if (exitCode != 0) {
      throw ProcessException(
        executable,
        const [],
        error,
        exitCode,
      );
    }
    return Map<String, Object?>.from(jsonDecode(output) as Map);
  }
}
