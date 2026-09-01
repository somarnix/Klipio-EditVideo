import 'dart:developer' as developer;

enum LogLevel { debug, info, warning, error }

abstract final class KlipioLogger {
  static void log(
    String message, {
    LogLevel level = LogLevel.info,
    Object? error,
    StackTrace? stackTrace,
  }) {
    developer.log(
      message,
      name: 'Klipio.${level.name}',
      error: error,
      stackTrace: stackTrace,
      level: switch (level) {
        LogLevel.debug => 500,
        LogLevel.info => 800,
        LogLevel.warning => 900,
        LogLevel.error => 1000,
      },
    );
  }
}
