import 'package:flutter/foundation.dart';

import '../../projects/data/project_repository.dart';

class HomeController extends ChangeNotifier {
  HomeController({ProjectRepository? projects})
      : projects = projects ?? const ProjectRepository();

  final ProjectRepository projects;
  List<String> _projectPaths = const [];
  bool _loading = false;

  List<String> get projectPaths => List.unmodifiable(_projectPaths);
  bool get loading => _loading;

  Future<void> refresh() async {
    _loading = true;
    notifyListeners();
    try {
      _projectPaths = await projects.listProjectFiles();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
