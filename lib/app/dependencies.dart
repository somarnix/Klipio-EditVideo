import '../features/home/data/recent_project_repository.dart';
import '../features/media/data/media_probe_repository.dart';
import '../features/media/services/thumbnail_cache_service.dart';
import '../features/projects/data/backup_service.dart';
import '../features/projects/data/project_repository.dart';
import '../services/ffmpeg/encoder_probe_service.dart';
import '../services/ffmpeg/ffmpeg_service.dart';
import '../services/ffmpeg/ffprobe_service.dart';

/// Explicit application service registry.
///
/// Services remain plain Dart objects, making them easy to replace in tests
/// without adding a runtime dependency-injection package.
class AppDependencies {
  AppDependencies({
    ProjectRepository? projects,
    RecentProjectRepository? recents,
    BackupService? backups,
    MediaProbeRepository? mediaProbe,
    ThumbnailCacheService? thumbnails,
    FfmpegService? ffmpeg,
    FfprobeService? ffprobe,
    EncoderProbeService? encoders,
  })  : projects = projects ?? const ProjectRepository(),
        recents = recents ?? const RecentProjectRepository(),
        backups = backups ?? const BackupService(),
        mediaProbe = mediaProbe ?? const MediaProbeRepository(),
        thumbnails = thumbnails ?? const ThumbnailCacheService(),
        ffmpeg = ffmpeg ?? const FfmpegService(),
        ffprobe = ffprobe ?? const FfprobeService(),
        encoders = encoders ?? const EncoderProbeService();

  final ProjectRepository projects;
  final RecentProjectRepository recents;
  final BackupService backups;
  final MediaProbeRepository mediaProbe;
  final ThumbnailCacheService thumbnails;
  final FfmpegService ffmpeg;
  final FfprobeService ffprobe;
  final EncoderProbeService encoders;
}
