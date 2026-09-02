import 'package:flutter/widgets.dart';

import 'dependencies.dart';

class AppBindings {
  const AppBindings._();

  static Future<AppDependencies> initializeServices() async {
    return AppDependencies();
  }
}

class AppDependenciesScope extends InheritedWidget {
  const AppDependenciesScope({
    super.key,
    required this.dependencies,
    required super.child,
  });

  final AppDependencies dependencies;

  static AppDependencies of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<AppDependenciesScope>();
    assert(scope != null, 'AppDependenciesScope is missing above this widget.');
    return scope!.dependencies;
  }

  @override
  bool updateShouldNotify(AppDependenciesScope oldWidget) =>
      !identical(dependencies, oldWidget.dependencies);
}
