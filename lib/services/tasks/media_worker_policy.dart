/// Conservative software-worker settings. Input decoder options and output
/// encoder options are separate FFmpeg option groups; neither caps the other.
abstract final class MediaWorkerPolicy {
  static const decoderThreads = 2;
  static const encoderThreads = 2;
  static const filterThreads = 1;
  static const proxyProfile = 'h264-30fps-crf30-aac96-v2';
}

/// Progress is advancing media time, not merely stderr/stdout activity.
/// Accepts FFmpeg -progress output split at arbitrary pipe chunk boundaries.
class MediaWorkerProgress {
  String _pending = '';
  int outputMicroseconds = -1;

  bool add(String text) {
    _pending += text;
    var advanced = false;
    var newline = _pending.indexOf('\n');
    while (newline >= 0) {
      final line = _pending.substring(0, newline).trim();
      _pending = _pending.substring(newline + 1);
      if (line.startsWith('out_time_us=')) {
        final value = int.tryParse(line.substring('out_time_us='.length));
        if (value != null && value > outputMicroseconds) {
          outputMicroseconds = value;
          advanced = true;
        }
      }
      newline = _pending.indexOf('\n');
    }
    if (_pending.length > 4096) _pending = '';
    return advanced;
  }
}
