import 'dart:convert';

import '../domain/klipio_project.dart';

class ProjectSerializer {
  const ProjectSerializer();

  String encode(KlipioProject project, {bool pretty = true}) {
    final json = project.toJson();
    return pretty
        ? const JsonEncoder.withIndent('  ').convert(json)
        : jsonEncode(json);
  }

  KlipioProject decode(String source) =>
      KlipioProject.fromJson(jsonDecode(source));
}
