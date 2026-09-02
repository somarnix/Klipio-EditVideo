import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:klipio/features/projects/services/project_recovery.dart';

void main() {
  late Directory root;
  late File primary;
  late File backup;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('klipio-recovery-test-');
    primary = File('${root.path}/project.klipio.json');
    await Directory('${root.path}/Backups').create();
    backup = File('${root.path}/Backups/project.previous.klipio.json');
  });
  tearDown(() => root.delete(recursive: true));
  test('valid primary wins and missing source media is preserved', () async {
    await primary.writeAsString('{"videos":[{"path":"offline.mp4"}]}');
    await backup.writeAsString('{"videos":[]}');
    final result = await readProjectWithBackup(primary);
    expect(result.recovered, isFalse);
    expect((result.data['videos'] as List).length, 1);
  });
  test('truncated primary recovers without writing either candidate', () async {
    await primary.writeAsString('{"videos":');
    await backup.writeAsString('{"videos":[],"version":1}');
    final result = await readProjectWithBackup(primary);
    expect(result.recovered, isTrue);
    expect(result.data['version'], 1);
    expect(await primary.readAsString(), '{"videos":');
    expect(await backup.readAsString(), '{"videos":[],"version":1}');
  });
  test('malformed video entries recover instead of silently dropping media',
      () async {
    await primary.writeAsString('{"videos":[42,null]}');
    await backup.writeAsString('{"videos":[{"path":"offline.mp4"}]}');
    final result = await readProjectWithBackup(primary);
    expect(result.recovered, isTrue);
    expect((result.data['videos'] as List).single['path'], 'offline.mp4');
    expect(await primary.readAsString(), '{"videos":[42,null]}');
  });
  test('invalid primary and backup fail without destroying evidence', () async {
    await primary.writeAsString('[]');
    await backup.writeAsString('broken');
    await expectLater(readProjectWithBackup(primary), throwsFormatException);
    expect(await primary.readAsString(), '[]');
    expect(await backup.readAsString(), 'broken');
  });
  test('missing primary is not silently replaced with an older backup',
      () async {
    await backup.writeAsString('{"videos":[]}');
    await expectLater(
        readProjectWithBackup(primary), throwsA(isA<FileSystemException>()));
  });
}
