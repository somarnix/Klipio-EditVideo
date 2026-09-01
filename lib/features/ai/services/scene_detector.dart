class SceneDetector {
  const SceneDetector();

  /// Parses FFmpeg `select=gt(scene,threshold),showinfo` diagnostic output.
  List<double> parseSceneTimes(String ffmpegOutput) {
    final result = <double>[];
    final expression = RegExp(r'pts_time:([0-9]+(?:\.[0-9]+)?)');
    for (final match in expression.allMatches(ffmpegOutput)) {
      final seconds = double.tryParse(match.group(1)!);
      if (seconds != null && (result.isEmpty || seconds - result.last > 0.08)) {
        result.add(seconds);
      }
    }
    return result;
  }

  String filter({double threshold = 0.35}) =>
      "select='gt(scene,${threshold.clamp(0.01, 1).toStringAsFixed(3)})',showinfo";
}
