import 'package:flutter/widgets.dart';

/// Starts Klipio after completing required platform/service initialization.
///
/// Keeping startup sequencing here gives every platform one entry path while
/// allowing the legacy editor widget to be extracted in smaller safe units.
Future<void> bootstrapKlipio({
  required Widget app,
  Future<void> Function()? initialize,
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  await initialize?.call();
  runApp(app);
}
