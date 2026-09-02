import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

const klipioCurrentVersion = '2.0.22';

class KlipioUpdateInfo {
  const KlipioUpdateInfo({
    required this.version,
    required this.releaseDate,
    required this.title,
    required this.notes,
    required this.installerUri,
    required this.sha256,
  });

  final String version;
  final String releaseDate;
  final String title;
  final String notes;
  final Uri installerUri;
  final String sha256;

  bool get isNewer => _compareVersions(version, klipioCurrentVersion) > 0;

  static KlipioUpdateInfo fromJson(Map<String, dynamic> json, Uri feedUri) {
    final installer = '${json['installerUrl'] ?? ''}'.trim();
    if (installer.isEmpty) throw const FormatException('Missing installerUrl');
    return KlipioUpdateInfo(
      version: '${json['version'] ?? ''}'.trim(),
      releaseDate: '${json['releaseDate'] ?? ''}'.trim(),
      title: '${json['title'] ?? 'Klipio update'}'.trim(),
      notes: '${json['notes'] ?? ''}'.trim(),
      installerUri: feedUri.resolve(installer),
      sha256: '${json['sha256'] ?? ''}'.trim().toLowerCase(),
    );
  }
}

class KlipioUpdateService {
  static const _feedEnvironmentKey = 'KLIPIO_UPDATE_FEED_URL';

  /// Uses KLIPIO_UPDATE_FEED_URL in production. For offline QA, place an
  /// update-manifest.json beside Klipio.exe. Both feeds use the same schema.
  Future<KlipioUpdateInfo?> check() async {
    final configured = Platform.environment[_feedEnvironmentKey]?.trim() ?? '';
    final local = File('${File(Platform.resolvedExecutable).parent.path}'
        '${Platform.pathSeparator}update-manifest.json');

    late final Uri feedUri;
    late final String body;
    if (configured.isNotEmpty) {
      feedUri = Uri.parse(configured);
      body = await _readUri(feedUri);
    } else if (await local.exists()) {
      feedUri = local.uri;
      body = await local.readAsString();
    } else {
      return null;
    }

    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('The update feed is not a JSON object.');
    }
    final info = KlipioUpdateInfo.fromJson(decoded, feedUri);
    if (info.version.isEmpty) {
      throw const FormatException('The update feed has no version.');
    }
    return info;
  }

  Future<File> downloadAndVerify(
    KlipioUpdateInfo info, {
    void Function(double value)? onProgress,
  }) async {
    if (!Platform.isWindows) {
      throw UnsupportedError('The Windows updater is only available on PC.');
    }
    if (info.sha256.length != 64) {
      throw const FormatException(
          'The update feed must provide a SHA-256 checksum.');
    }
    final temp = await getTemporaryDirectory();
    final target = File('${temp.path}${Platform.pathSeparator}'
        'Klipio-${info.version}-Setup.exe');
    await _removeOldInstallerDownloads(temp, exceptPath: target.path);
    final sink = target.openWrite();
    try {
      if (info.installerUri.scheme == 'file') {
        final source = File.fromUri(info.installerUri);
        final total = await source.length();
        var received = 0;
        await for (final bytes in source.openRead()) {
          sink.add(bytes);
          received += bytes.length;
          if (total > 0) onProgress?.call(received / total);
        }
      } else {
        final client = HttpClient()
          ..connectionTimeout = const Duration(seconds: 20);
        try {
          final request = await client.getUrl(info.installerUri);
          request.headers.set(HttpHeaders.userAgentHeader,
              'Klipio/$klipioCurrentVersion Windows');
          final response = await request.close();
          if (response.statusCode < 200 || response.statusCode >= 300) {
            throw HttpException(
                'Update download failed (${response.statusCode}).',
                uri: info.installerUri);
          }
          final total = response.contentLength;
          var received = 0;
          await for (final bytes in response) {
            sink.add(bytes);
            received += bytes.length;
            if (total > 0) onProgress?.call(received / total);
          }
        } finally {
          client.close(force: true);
        }
      }
    } finally {
      await sink.flush();
      await sink.close();
    }

    final digest = sha256.convert(await target.readAsBytes()).toString();
    if (digest.toLowerCase() != info.sha256) {
      await target.delete();
      throw const FormatException(
          'Security check failed: installer checksum does not match.');
    }
    onProgress?.call(1);
    return target;
  }

  Future<void> launchInstaller(File installer) async {
    if (!Platform.isWindows) {
      throw UnsupportedError('The Windows updater is only available on PC.');
    }

    // Tell setup exactly which installed copy requested the update. This keeps
    // custom install locations working and lets setup close only this Klipio
    // process before transactionally replacing the old application files.
    final installDirectory = File(Platform.resolvedExecutable).parent.path;
    await Process.start(
      installer.path,
      <String>[
        '--update',
        '--install-dir',
        installDirectory,
        '--wait-pid',
        '$pid',
      ],
      mode: ProcessStartMode.detached,
    );
  }

  Future<void> _removeOldInstallerDownloads(
    Directory temp, {
    required String exceptPath,
  }) async {
    try {
      await for (final entry in temp.list(followLinks: false)) {
        if (entry is! File) continue;
        final name = entry.uri.pathSegments.last;
        if (!RegExp(r'^Klipio-.+-Setup\.exe$', caseSensitive: false)
            .hasMatch(name)) {
          continue;
        }
        if (entry.absolute.path.toLowerCase() ==
            File(exceptPath).absolute.path.toLowerCase()) {
          continue;
        }
        try {
          await entry.delete();
        } on FileSystemException {
          // A setup that is still running can remain until the next update.
        }
      }
    } on FileSystemException {
      // Temp cleanup is best-effort and must never block a verified update.
    }
  }

  Future<String> _readUri(Uri uri) async {
    if (uri.scheme == 'file') return File.fromUri(uri).readAsString();
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20);
    try {
      final request = await client.getUrl(uri);
      request.headers.set(
          HttpHeaders.userAgentHeader, 'Klipio/$klipioCurrentVersion Windows');
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('Update check failed (${response.statusCode}).',
            uri: uri);
      }
      return utf8.decode(await response
          .fold<List<int>>(<int>[], (buffer, bytes) => buffer..addAll(bytes)));
    } finally {
      client.close(force: true);
    }
  }
}

int _compareVersions(String left, String right) {
  List<int> parts(String value) => value
      .split(RegExp(r'[^0-9]+'))
      .where((part) => part.isNotEmpty)
      .map((part) => int.tryParse(part) ?? 0)
      .toList();
  final a = parts(left);
  final b = parts(right);
  for (var index = 0;
      index < (a.length > b.length ? a.length : b.length);
      index++) {
    final av = index < a.length ? a[index] : 0;
    final bv = index < b.length ? b[index] : 0;
    if (av != bv) return av.compareTo(bv);
  }
  return 0;
}
