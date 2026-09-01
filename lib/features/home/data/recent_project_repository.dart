import 'dart:convert';

import '../../../core/storage/recovering_shared_preferences.dart';

class RecentProjectRepository {
  const RecentProjectRepository();

  static const _key = 'klipio.recentProjects.v2';

  Future<List<String>> read() async {
    final preferences = await loadSharedPreferencesRecovering();
    final value = preferences.getString(_key);
    if (value == null) return const [];
    try {
      return [for (final item in jsonDecode(value) as List) '$item'];
    } catch (_) {
      return const [];
    }
  }

  Future<void> remember(String projectPath, {int maximum = 30}) async {
    final current = await read();
    final normalized = projectPath.toLowerCase();
    final next = [
      projectPath,
      ...current.where((path) => path.toLowerCase() != normalized),
    ].take(maximum).toList();
    final preferences = await loadSharedPreferencesRecovering();
    await preferences.setString(_key, jsonEncode(next));
  }

  Future<void> forget(String projectPath) async {
    final current = await read();
    final normalized = projectPath.toLowerCase();
    final preferences = await loadSharedPreferencesRecovering();
    await preferences.setString(
      _key,
      jsonEncode(
          current.where((path) => path.toLowerCase() != normalized).toList()),
    );
  }
}
