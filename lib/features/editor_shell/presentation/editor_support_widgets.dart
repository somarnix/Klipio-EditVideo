part of 'editor_application.dart';

class _CanvasPatternPainter extends CustomPainter {
  const _CanvasPatternPainter({required this.pattern, required this.color});

  final String pattern;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final hsl = HSLColor.fromColor(color);
    final dark = hsl
        .withLightness((hsl.lightness * 0.42).clamp(0.04, 0.42).toDouble())
        .toColor();
    final light = hsl
        .withLightness((hsl.lightness + 0.18).clamp(0.18, 0.92).toDouble())
        .toColor();
    canvas.drawRect(Offset.zero & size, Paint()..color = dark);
    switch (pattern) {
      case 'stripes':
        final paint = Paint()
          ..color = color.withOpacity(0.68)
          ..strokeWidth = math.max(10.0, size.shortestSide * 0.045);
        final step = math.max(30.0, size.shortestSide * 0.14);
        for (double x = -size.height; x < size.width + size.height; x += step) {
          canvas.drawLine(
            Offset(x, size.height),
            Offset(x + size.height, 0),
            paint,
          );
        }
        return;
      case 'checker':
        final cell = math.max(24.0, size.shortestSide * 0.12);
        final paint = Paint()..color = color.withOpacity(0.72);
        for (var row = 0; row * cell < size.height; row++) {
          for (var column = 0; column * cell < size.width; column++) {
            if ((row + column).isEven) {
              canvas.drawRect(
                Rect.fromLTWH(column * cell, row * cell, cell, cell),
                paint,
              );
            }
          }
        }
        return;
      case 'dots':
        final step = math.max(22.0, size.shortestSide * 0.095);
        final radius = math.max(3.0, step * 0.16);
        final paint = Paint()..color = light.withOpacity(0.82);
        for (double y = step / 2; y < size.height; y += step) {
          for (double x = step / 2; x < size.width; x += step) {
            canvas.drawCircle(Offset(x, y), radius, paint);
          }
        }
        return;
      default:
        final step = math.max(24.0, size.shortestSide * 0.11);
        final paint = Paint()
          ..color = color.withOpacity(0.58)
          ..strokeWidth = 2;
        for (double x = 0; x <= size.width; x += step) {
          canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
        }
        for (double y = 0; y <= size.height; y += step) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
        }
        return;
    }
  }

  @override
  bool shouldRepaint(covariant _CanvasPatternPainter oldDelegate) =>
      oldDelegate.pattern != pattern || oldDelegate.color != color;
}

class _ExportPreset {
  const _ExportPreset({
    required this.name,
    required this.outputName,
    required this.batchRenamePattern,
    required this.qualityPreset,
    required this.customBitrateKbps,
    required this.exportTimelineTogether,
    required this.useNumberRange,
    required this.rangeStart,
    required this.rangeEnd,
  });

  final String name;
  final String outputName;
  final String batchRenamePattern;
  final String qualityPreset;
  final double customBitrateKbps;
  final bool exportTimelineTogether;
  final bool useNumberRange;
  final String rangeStart;
  final String rangeEnd;

  factory _ExportPreset.fromJson(Map<String, Object?> json) {
    return _ExportPreset(
      name: '${json['name'] ?? 'Preset'}',
      outputName: '${json['outputName'] ?? ''}',
      batchRenamePattern: '${json['batchRenamePattern'] ?? ''}',
      qualityPreset: '${json['qualityPreset'] ?? '1080p'}',
      customBitrateKbps:
          double.tryParse('${json['customBitrateKbps'] ?? 8000}') ?? 8000,
      exportTimelineTogether: json['exportTimelineTogether'] as bool? ?? true,
      useNumberRange: json['useNumberRange'] as bool? ?? false,
      rangeStart: '${json['rangeStart'] ?? '1'}',
      rangeEnd: '${json['rangeEnd'] ?? ''}',
    );
  }

  Map<String, Object?> toJson() => {
        'name': name,
        'outputName': outputName,
        'batchRenamePattern': batchRenamePattern,
        'qualityPreset': qualityPreset,
        'customBitrateKbps': customBitrateKbps,
        'exportTimelineTogether': exportTimelineTogether,
        'useNumberRange': useNumberRange,
        'rangeStart': rangeStart,
        'rangeEnd': rangeEnd,
      };
}

class _QueuedExport {
  const _QueuedExport({
    required this.video,
    required this.outputPath,
    required this.settings,
    this.partIndex,
    this.partCount,
  });

  final PickedVideo video;
  final String outputPath;
  final VideoEditSettings settings;
  final int? partIndex;
  final int? partCount;
}

class _QueuedExportGroup {
  const _QueuedExportGroup({
    required this.video,
    required this.outputPath,
    required this.parts,
  });

  final PickedVideo video;
  final String outputPath;
  final List<_QueuedExport> parts;
}

class KlipioExportDialogDetails {
  const KlipioExportDialogDetails({
    required this.title,
    required this.name,
    required this.outputFolder,
    required this.durationSeconds,
    required this.estimatedSize,
    this.thumbnailPath,
  });

  final String title;
  final String name;
  final String outputFolder;
  final double durationSeconds;
  final String estimatedSize;
  final String? thumbnailPath;

  KlipioExportDialogDetails copyWith({
    String? title,
    String? name,
    String? outputFolder,
    double? durationSeconds,
    String? estimatedSize,
    String? thumbnailPath,
  }) {
    return KlipioExportDialogDetails(
      title: title ?? this.title,
      name: name ?? this.name,
      outputFolder: outputFolder ?? this.outputFolder,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      estimatedSize: estimatedSize ?? this.estimatedSize,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
    );
  }
}

class KlipioExportProgressView {
  const KlipioExportProgressView({
    this.details,
    this.progress = 0,
    this.elapsed = Duration.zero,
    this.status = 'Preparing export...',
  });

  final KlipioExportDialogDetails? details;
  final double progress;
  final Duration elapsed;
  final String status;
}

class _CaptionGenerationView {
  const _CaptionGenerationView({
    required this.videoName,
    this.currentVideo = 1,
    this.totalVideos = 1,
    this.progress = 0,
    this.status = 'Preparing speech detection...',
    this.cancelling = false,
  });

  final String videoName;
  final int currentVideo;
  final int totalVideos;
  final double progress;
  final String status;
  final bool cancelling;

  _CaptionGenerationView copyWith({
    int? currentVideo,
    int? totalVideos,
    double? progress,
    String? status,
    bool? cancelling,
  }) =>
      _CaptionGenerationView(
        videoName: videoName,
        currentVideo: currentVideo ?? this.currentVideo,
        totalVideos: totalVideos ?? this.totalVideos,
        progress: progress ?? this.progress,
        status: status ?? this.status,
        cancelling: cancelling ?? this.cancelling,
      );
}

class _CaptionGenerationDialog extends StatelessWidget {
  const _CaptionGenerationDialog({
    required this.progress,
    required this.onCancel,
  });

  final ValueNotifier<_CaptionGenerationView> progress;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: theme.colorScheme.surfaceContainerHigh,
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: 430,
          child: ValueListenableBuilder<_CaptionGenerationView>(
            valueListenable: progress,
            builder: (context, view, _) {
              final percent = (view.progress * 100).round().clamp(0, 100);
              return Padding(
                padding: const EdgeInsets.fromLTRB(28, 24, 28, 22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/branding/Loading.gif',
                      width: 92,
                      height: 92,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 16),
                    KText(
                      view.cancelling
                          ? 'Cancelling captions...'
                          : 'Video ${view.currentVideo} of ${view.totalVideos} โ€” $percent%',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 9),
                    KText(
                      '${view.videoName}\n${view.status}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: view.progress > 0 ? view.progress : null,
                        minHeight: 5,
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: 150,
                      child: FilledButton.tonal(
                        onPressed: view.cancelling ? null : onCancel,
                        child: const KText('Cancel'),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _TimelinePartDrag {
  const _TimelinePartDrag({
    required this.videoPath,
    required this.visualPartIndex,
  });

  final String videoPath;
  final int visualPartIndex;
}

class _CaptionPreset {
  const _CaptionPreset({
    required this.id,
    required this.name,
    required this.accentColor,
    this.inactiveColor = Colors.white,
    this.outlineColor = Colors.black,
    this.backgroundColor = Colors.transparent,
    this.activeBoxColor = Colors.transparent,
    this.outline = 4,
    this.shadow = 2,
    this.uppercase = true,
    this.bold = true,
    this.italic = false,
    this.bottomMargin = 0.13,
    this.motion = 'highlight',
  });

  final String id;
  final String name;
  final Color accentColor;
  final Color inactiveColor;
  final Color outlineColor;
  final Color backgroundColor;
  final Color activeBoxColor;
  final double outline;
  final double shadow;
  final bool uppercase;
  final bool bold;
  final bool italic;
  final double bottomMargin;
  final String motion;
}

class _CaptionStyleAnimationPreview extends StatefulWidget {
  const _CaptionStyleAnimationPreview({
    required this.preset,
    required this.fontFamily,
  });

  final _CaptionPreset preset;
  final String fontFamily;

  @override
  State<_CaptionStyleAnimationPreview> createState() =>
      _CaptionStyleAnimationPreviewState();
}

class _CaptionStyleAnimationPreviewState
    extends State<_CaptionStyleAnimationPreview>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<Shadow> _shadows(bool active) {
    final preset = widget.preset;
    final outline = preset.outline.clamp(0.0, 9.0).toDouble();
    final shadows = <Shadow>[];
    if (outline > 0) {
      for (final offset in const [
        Offset(-1, -1),
        Offset(1, -1),
        Offset(-1, 1),
        Offset(1, 1),
      ]) {
        shadows.add(
          Shadow(
            color: preset.outlineColor,
            blurRadius: 1,
            offset: Offset(offset.dx * outline, offset.dy * outline),
          ),
        );
      }
    }
    if (preset.shadow > 0) {
      shadows.add(
        Shadow(
          color: preset.motion == 'glow' && active
              ? preset.accentColor
              : preset.outlineColor,
          blurRadius: preset.motion == 'glow' && active
              ? preset.shadow * 2.5
              : preset.shadow,
          offset: preset.motion == 'glow'
              ? Offset.zero
              : Offset(preset.shadow * 0.7, preset.shadow),
        ),
      );
    }
    return shadows;
  }

  @override
  Widget build(BuildContext context) {
    const sample = ['THE', 'QUICK', 'BROWN', 'FOX'];
    final preset = widget.preset;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final activeIndex = (_controller.value * sample.length)
            .floor()
            .clamp(0, sample.length - 1);
        return DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xff172033), Color(0xff05070b)],
            ),
          ),
          child: Stack(
            children: [
              const Positioned(
                right: 28,
                top: 24,
                child: Icon(
                  Icons.videocam_outlined,
                  color: Color(0x337c8ba8),
                  size: 100,
                ),
              ),
              Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: preset.backgroundColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: preset.backgroundColor == Colors.transparent
                        ? EdgeInsets.zero
                        : const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      runSpacing: 10,
                      children: [
                        for (final entry in sample.indexed)
                          Builder(
                            builder: (context) {
                              final active = entry.$1 == activeIndex;
                              final activeBox = preset.motion == 'box' && active
                                  ? preset.activeBoxColor
                                  : Colors.transparent;
                              final text = KText(
                                preset.uppercase
                                    ? entry.$2
                                    : entry.$2.toLowerCase(),
                                style: TextStyle(
                                  color: active
                                      ? preset.accentColor
                                      : preset.inactiveColor,
                                  fontFamily: widget.fontFamily,
                                  fontSize: 42,
                                  fontWeight: preset.bold
                                      ? FontWeight.w900
                                      : FontWeight.w500,
                                  fontStyle: preset.italic
                                      ? FontStyle.italic
                                      : FontStyle.normal,
                                  shadows: _shadows(active),
                                ),
                              );
                              final animated = AnimatedContainer(
                                duration: const Duration(milliseconds: 120),
                                padding: activeBox == Colors.transparent
                                    ? EdgeInsets.zero
                                    : const EdgeInsets.symmetric(
                                        horizontal: 9,
                                        vertical: 4,
                                      ),
                                decoration: BoxDecoration(
                                  color: activeBox,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: text,
                              );
                              return AnimatedScale(
                                scale: active &&
                                        (preset.motion == 'pop' ||
                                            preset.motion == 'bounce')
                                    ? 1.2
                                    : 1,
                                duration: const Duration(milliseconds: 130),
                                curve: Curves.easeOutBack,
                                child: Transform.translate(
                                  offset: active && preset.motion == 'bounce'
                                      ? const Offset(0, -8)
                                      : Offset.zero,
                                  child: animated,
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 16,
                bottom: 14,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xaa000000),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    child: KText(
                      'AUTO PLAY โ€ข ${preset.motion.toUpperCase()}',
                      style: TextStyle(
                        color: preset.accentColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

typedef _CaptionWord = EditableCaptionWord;
typedef _CaptionCue = EditableCaptionCue;

class _TimelineRulerPainter extends CustomPainter {
  const _TimelineRulerPainter({
    required this.marks,
    required this.compact,
    required this.axisColor,
    required this.labelColor,
  });

  final List<({double x, double seconds, bool major})> marks;
  final bool compact;
  final Color axisColor;
  final Color labelColor;

  @override
  void paint(Canvas canvas, Size size) {
    final axisPaint = Paint()
      ..color = axisColor
      ..strokeWidth = 1;
    final minorPaint = Paint()
      ..color = axisColor.withOpacity(0.55)
      ..strokeWidth = 1;
    final labelPainter = TextPainter(
      textDirection: TextDirection.ltr,
      maxLines: 1,
    );
    final baselineY = size.height - 4;
    canvas.drawLine(
        Offset(0, baselineY), Offset(size.width, baselineY), axisPaint);
    for (final mark in marks) {
      final paint = mark.major ? axisPaint : minorPaint;
      final height = mark.major ? 11.0 : 6.0;
      canvas.drawLine(
        Offset(mark.x, baselineY),
        Offset(mark.x, baselineY - height),
        paint,
      );
      if (!compact && mark.major) {
        labelPainter.text = TextSpan(
          text: _formatTick(mark.seconds),
          style: TextStyle(color: labelColor, fontSize: 9),
        );
        labelPainter.layout(maxWidth: 60);
        final x = (mark.x - 22).clamp(0.0, size.width - labelPainter.width);
        labelPainter.paint(canvas, Offset(x, 0));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TimelineRulerPainter oldDelegate) {
    return oldDelegate.marks != marks ||
        oldDelegate.compact != compact ||
        oldDelegate.axisColor != axisColor ||
        oldDelegate.labelColor != labelColor;
  }

  static String _formatTick(double seconds) {
    if (seconds < 60 && seconds != seconds.roundToDouble()) {
      return seconds.toStringAsFixed(seconds < 1 ? 2 : 1);
    }
    final total = seconds.round();
    final minutes = total ~/ 60;
    final secs = total % 60;
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }
}
