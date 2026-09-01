import 'ffmpeg_service.dart';

class EncoderProbeService {
  const EncoderProbeService({this.ffmpeg = const FfmpegService()});

  final FfmpegService ffmpeg;

  Future<List<String>> available() async {
    const candidates = [
      'h264_nvenc',
      'h264_qsv',
      'h264_amf',
      'h264_videotoolbox',
      'libx264',
    ];
    final result = await ffmpeg.run(const ['-hide_banner', '-encoders']);
    if (!result.succeeded) return const ['libx264'];
    return [
      for (final encoder in candidates)
        if (result.stdout.contains(encoder)) encoder,
    ];
  }
}
