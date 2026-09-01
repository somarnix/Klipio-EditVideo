import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<SharedPreferences>? _preferencesLoad;

/// Loads preferences and repairs the Windows JSON store if an interrupted
/// write left it malformed. The damaged bytes are preserved beside the file
/// before a valid empty store is created.
Future<SharedPreferences> loadSharedPreferencesRecovering() {
  return _preferencesLoad ??= _loadSharedPreferencesRecovering().whenComplete(
    () => _preferencesLoad = null,
  );
}

Future<SharedPreferences> _loadSharedPreferencesRecovering() async {
  try {
    return await SharedPreferences.getInstance();
  } on FormatException {
    if (!Platform.isWindows) rethrow;

    final supportDirectory = await getApplicationSupportDirectory();
    final preferencesFile = File(
      '${supportDirectory.path}${Platform.pathSeparator}'
      'shared_preferences.json',
    );
    if (!await preferencesFile.exists()) rethrow;

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final backupFile = File('${preferencesFile.path}.corrupt-$timestamp.bak');
    await preferencesFile.copy(backupFile.path);
    await preferencesFile.writeAsString(
      '{}',
      encoding: utf8,
      flush: true,
    );
    return SharedPreferences.getInstance();
  }
}
