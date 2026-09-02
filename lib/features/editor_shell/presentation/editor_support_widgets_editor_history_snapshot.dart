part of 'editor_application.dart';

class _EditorHistorySnapshot {
  const _EditorHistorySnapshot({
    required this.timeline,
    required this.timelinesByComposition,
    required this.projectMediaPathsByComposition,
    required this.textOverlays,
    required this.clipTimelineEdits,
    required this.captionCuesByVideo,
    required this.clipTransformOverrides,
    required this.timelineMarkers,
    required this.selectedCompositionPath,
    required this.selectedTimelineClipId,
    required this.programTimelineClipId,
    required this.editorSelection,
    required this.selectedTextOverlayIndex,
    required this.selectedCaptionCueIndex,
    required this.selectedVideoIndex,
    required this.brightness,
    required this.contrast,
    required this.saturation,
    required this.gamma,
    required this.originalVolume,
    required this.musicVolume,
    required this.watermarkX,
    required this.watermarkY,
    required this.watermarkSize,
    required this.watermarkPath,
    required this.musicPath,
    required this.outputRatio,
    required this.projectColorSpace,
    required this.projectResolution,
    required this.projectProxyResolution,
    required this.projectProxyEnabled,
    required this.projectCopyMedia,
    required this.projectArrangeLayers,
    required this.projectFrameRate,
    required this.automaticCaptions,
  });

  final TimelineModel timeline;
  final Map<String, TimelineModel> timelinesByComposition;
  final Map<String, List<String>> projectMediaPathsByComposition;
  final List<_TextOverlayDraft> textOverlays;
  final Map<String, _ClipTimelineEdit> clipTimelineEdits;
  final Map<String, List<_CaptionCue>> captionCuesByVideo;
  final Set<String> clipTransformOverrides;
  final List<double> timelineMarkers;
  final String? selectedCompositionPath;
  final String? selectedTimelineClipId;
  final String? programTimelineClipId;
  final EditorSelection editorSelection;
  final int selectedTextOverlayIndex;
  final int selectedCaptionCueIndex;
  final int selectedVideoIndex;
  final double brightness;
  final double contrast;
  final double saturation;
  final double gamma;
  final double originalVolume;
  final double musicVolume;
  final double watermarkX;
  final double watermarkY;
  final double watermarkSize;
  final String? watermarkPath;
  final String? musicPath;
  final String outputRatio;
  final String projectColorSpace;
  final String projectResolution;
  final String projectProxyResolution;
  final bool projectProxyEnabled;
  final bool projectCopyMedia;
  final bool projectArrangeLayers;
  final double projectFrameRate;
  final bool automaticCaptions;
}

class _ClipTimelineEdit {
  const _ClipTimelineEdit({
    this.trimStartSeconds = 0,
    this.trimEndSeconds = 0,
    this.splitEverySeconds = 0,
    this.speed = 1,
    this.flip = 'none',
    this.scaleX = 1,
    this.scaleY = 1,
    this.zoom = 1,
    this.panX = 0,
    this.panY = 0,
    this.originalVolume = 1,
    this.splitPoints = const [],
    this.deletedRanges = const [],
    this.partOrder = const [],
  });

  final double trimStartSeconds;
  final double trimEndSeconds;
  final double splitEverySeconds;
  final double speed;
  final String flip;
  final double scaleX;
  final double scaleY;
  final double zoom;
  final double panX;
  final double panY;
  final double originalVolume;
  final List<double> splitPoints;
  final List<({double start, double end})> deletedRanges;
  final List<double> partOrder;

  bool get hasStructuralTimelineEdit =>
      splitEverySeconds > 0 ||
      splitPoints.isNotEmpty ||
      deletedRanges.isNotEmpty ||
      partOrder.isNotEmpty;

  _ClipTimelineEdit copyWith({
    double? trimStartSeconds,
    double? trimEndSeconds,
    double? splitEverySeconds,
    double? speed,
    String? flip,
    double? scaleX,
    double? scaleY,
    double? zoom,
    double? panX,
    double? panY,
    double? originalVolume,
    List<double>? splitPoints,
    List<({double start, double end})>? deletedRanges,
    List<double>? partOrder,
  }) {
    return _ClipTimelineEdit(
      trimStartSeconds: trimStartSeconds ?? this.trimStartSeconds,
      trimEndSeconds: trimEndSeconds ?? this.trimEndSeconds,
      splitEverySeconds: splitEverySeconds ?? this.splitEverySeconds,
      speed: speed ?? this.speed,
      flip: flip ?? this.flip,
      scaleX: scaleX ?? this.scaleX,
      scaleY: scaleY ?? this.scaleY,
      zoom: zoom ?? this.zoom,
      panX: panX ?? this.panX,
      panY: panY ?? this.panY,
      originalVolume: originalVolume ?? this.originalVolume,
      splitPoints: splitPoints ?? this.splitPoints,
      deletedRanges: deletedRanges ?? this.deletedRanges,
      partOrder: partOrder ?? this.partOrder,
    );
  }

  bool sameAs(_ClipTimelineEdit other) {
    return (trimStartSeconds - other.trimStartSeconds).abs() < 0.001 &&
        (trimEndSeconds - other.trimEndSeconds).abs() < 0.001 &&
        (splitEverySeconds - other.splitEverySeconds).abs() < 0.001 &&
        (speed - other.speed).abs() < 0.001 &&
        flip == other.flip &&
        (scaleX - other.scaleX).abs() < 0.001 &&
        (scaleY - other.scaleY).abs() < 0.001 &&
        (zoom - other.zoom).abs() < 0.001 &&
        (panX - other.panX).abs() < 0.001 &&
        (panY - other.panY).abs() < 0.001 &&
        (originalVolume - other.originalVolume).abs() < 0.001 &&
        _sameValues(splitPoints, other.splitPoints) &&
        _sameRanges(deletedRanges, other.deletedRanges) &&
        _sameValues(partOrder, other.partOrder);
  }

  bool hasEdit(double? durationSeconds) {
    final duration = durationSeconds ?? 0;
    final hasTrimStart = trimStartSeconds > 0;
    final hasTrimEnd =
        trimEndSeconds > 0 && (duration <= 0 || trimEndSeconds < duration);
    return hasTrimStart ||
        hasTrimEnd ||
        splitEverySeconds > 0 ||
        (speed - 1).abs() > 0.001 ||
        flip != 'none' ||
        (scaleX - 1).abs() > 0.001 ||
        (scaleY - 1).abs() > 0.001 ||
        (zoom - 1).abs() > 0.001 ||
        panX.abs() > 0.001 ||
        panY.abs() > 0.001 ||
        (originalVolume - 1).abs() > 0.001 ||
        splitPoints.isNotEmpty ||
        deletedRanges.isNotEmpty ||
        partOrder.isNotEmpty;
  }

  String summary(double? durationSeconds) {
    final items = <String>[];
    if (trimStartSeconds > 0) {
      items.add('start ${_formatNumber(trimStartSeconds)}s');
    }
    final duration = durationSeconds ?? 0;
    if (trimEndSeconds > 0 && (duration <= 0 || trimEndSeconds < duration)) {
      items.add('end ${_formatNumber(trimEndSeconds)}s');
    }
    if (splitEverySeconds > 0) {
      items.add('split ${_formatNumber(splitEverySeconds)}s');
    }
    if ((zoom - 1).abs() > 0.001 || panX.abs() > 0.001 || panY.abs() > 0.001) {
      items.add('frame moved');
    }
    if (splitPoints.isNotEmpty) {
      items.add(
          '${splitPoints.length} split point${splitPoints.length == 1 ? '' : 's'}');
    }
    if (deletedRanges.isNotEmpty) {
      items.add(
          '${deletedRanges.length} deleted cut${deletedRanges.length == 1 ? '' : 's'}');
    }
    if (partOrder.isNotEmpty) {
      items.add('reordered');
    }
    return items.isEmpty ? 'full clip' : items.join(', ');
  }

  static String _formatNumber(double value) {
    return value
        .toStringAsFixed(2)
        .replaceAll(RegExp(r'0+$'), '')
        .replaceAll(RegExp(r'\.$'), '');
  }

  List<({double start, double end})> timelineParts(double? durationSeconds) {
    final parts = _rawTimelineParts(durationSeconds)
        .where(
          (part) => !deletedRanges.any(
            (deleted) => _sameRange(part, deleted),
          ),
        )
        .toList();
    if (partOrder.isEmpty) {
      return parts;
    }
    final originalIndex = {
      for (var index = 0; index < parts.length; index++)
        _partKey(parts[index].start): index,
    };
    final orderIndex = {
      for (var index = 0; index < partOrder.length; index++)
        _partKey(partOrder[index]): index,
    };
    parts.sort((a, b) {
      final aKey = _partKey(a.start);
      final bKey = _partKey(b.start);
      final aOrder = orderIndex[aKey] ?? 100000 + (originalIndex[aKey] ?? 0);
      final bOrder = orderIndex[bKey] ?? 100000 + (originalIndex[bKey] ?? 0);
      return aOrder.compareTo(bOrder);
    });
    return parts;
  }

  ({double start, double end})? timelinePartAt(
    double seconds,
    double? durationSeconds,
  ) {
    final parts = timelineParts(durationSeconds);
    for (final part in parts) {
      if (seconds >= part.start - 0.001 && seconds <= part.end + 0.001) {
        return part;
      }
    }
    if (parts.isEmpty) return null;
    return parts.reduce((closest, part) {
      final closestDistance =
          (seconds - closest.start).abs().clamp(0.0, double.infinity);
      final partDistance =
          (seconds - part.start).abs().clamp(0.0, double.infinity);
      return partDistance < closestDistance ? part : closest;
    });
  }

  List<({double start, double end})> _rawTimelineParts(
    double? durationSeconds,
  ) {
    final duration = durationSeconds ?? 0;
    final start =
        trimStartSeconds.clamp(0, duration > 0 ? duration : 999999).toDouble();
    final fallbackEnd = duration > 0 ? duration : trimEndSeconds;
    final rawEnd = trimEndSeconds > start ? trimEndSeconds : fallbackEnd;
    final end =
        duration > 0 ? rawEnd.clamp(start, duration).toDouble() : rawEnd;
    final boundaries = <double>{start, end};
    if (splitEverySeconds > 0 && end > start) {
      var split = start + splitEverySeconds;
      while (split < end) {
        boundaries.add(split);
        split += splitEverySeconds;
      }
    }
    for (final split in splitPoints) {
      if (split > start && split < end) {
        boundaries.add(split);
      }
    }
    final sorted = boundaries.toList()..sort();
    final parts = <({double start, double end})>[];
    for (var index = 0; index < sorted.length - 1; index++) {
      if (sorted[index + 1] > sorted[index]) {
        parts.add((start: sorted[index], end: sorted[index + 1]));
      }
    }
    return parts.isEmpty ? [(start: start, end: end)] : parts;
  }

  static bool _sameRange(
    ({double start, double end}) first,
    ({double start, double end}) second,
  ) {
    return (first.start - second.start).abs() < 0.001 &&
        (first.end - second.end).abs() < 0.001;
  }

  static String _partKey(double value) => value.toStringAsFixed(3);

  static bool _sameValues(List<double> first, List<double> second) {
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      if ((first[index] - second[index]).abs() >= 0.001) return false;
    }
    return true;
  }

  static bool _sameRanges(
    List<({double start, double end})> first,
    List<({double start, double end})> second,
  ) {
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      if (!_sameRange(first[index], second[index])) return false;
    }
    return true;
  }
}

class _PlayheadHandlePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xff3b82f6);
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TimelineWaveformPainter extends CustomPainter {
  const _TimelineWaveformPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final centerY = size.height / 2;
    final step = size.width < 80 ? 5.0 : 7.0;
    for (var x = 4.0; x < size.width - 2; x += step) {
      final phase = (x / step).round();
      final normalized = (phase % 5 + 1) / 5;
      final barHeight = (size.height * (0.18 + normalized * 0.42))
          .clamp(3.0, size.height - 6);
      canvas.drawLine(
        Offset(x, centerY - barHeight / 2),
        Offset(x, centerY + barHeight / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TimelineWaveformPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _SaturationValuePicker extends StatelessWidget {
  const _SaturationValuePicker({
    required this.hsv,
    required this.onChanged,
  });

  final HSVColor hsv;
  final ValueChanged<HSVColor> onChanged;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.65,
      child: LayoutBuilder(
        builder: (context, constraints) {
          void update(Offset localPosition) {
            final width =
                constraints.maxWidth <= 0 ? 1.0 : constraints.maxWidth;
            final height =
                constraints.maxHeight <= 0 ? 1.0 : constraints.maxHeight;
            final saturation =
                (localPosition.dx / width).clamp(0.0, 1.0).toDouble();
            final value =
                (1 - localPosition.dy / height).clamp(0.0, 1.0).toDouble();
            onChanged(hsv.withSaturation(saturation).withValue(value));
          }

          final handleX = hsv.saturation * constraints.maxWidth;
          final handleY = (1 - hsv.value) * constraints.maxHeight;
          return GestureDetector(
            onPanDown: (details) => update(details.localPosition),
            onPanUpdate: (details) => update(details.localPosition),
            child: CustomPaint(
              painter: _SaturationValuePainter(hue: hsv.hue),
              foregroundPainter: _PickerHandlePainter(
                offset: Offset(handleX, handleY),
              ),
              child: const SizedBox.expand(),
            ),
          );
        },
      ),
    );
  }
}

class _HueSlider extends StatelessWidget {
  const _HueSlider({
    required this.hue,
    required this.onChanged,
  });

  final double hue;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 24,
      child: LayoutBuilder(
        builder: (context, constraints) {
          void update(Offset localPosition) {
            final width =
                constraints.maxWidth <= 0 ? 1.0 : constraints.maxWidth;
            onChanged(
                (localPosition.dx / width * 360).clamp(0.0, 360.0).toDouble());
          }

          return GestureDetector(
            onPanDown: (details) => update(details.localPosition),
            onPanUpdate: (details) => update(details.localPosition),
            child: CustomPaint(
              painter: _HuePainter(),
              foregroundPainter: _PickerHandlePainter(
                offset: Offset(hue / 360 * constraints.maxWidth, 12),
                radius: 9,
              ),
              child: const SizedBox.expand(),
            ),
          );
        },
      ),
    );
  }
}

class _SaturationValuePainter extends CustomPainter {
  const _SaturationValuePainter({required this.hue});

  final double hue;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final hueColor = HSVColor.fromAHSV(1, hue, 1, 1).toColor();
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      Paint()
        ..shader = LinearGradient(
          colors: [Colors.white, hueColor],
        ).createShader(rect),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_SaturationValuePainter oldDelegate) {
    return oldDelegate.hue != hue;
  }
}

class _HuePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(999)),
      Paint()
        ..shader = LinearGradient(
          colors: [
            for (var hue = 0; hue <= 360; hue += 30)
              HSVColor.fromAHSV(1, hue.toDouble(), 1, 1).toColor(),
          ],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PickerHandlePainter extends CustomPainter {
  const _PickerHandlePainter({
    required this.offset,
    this.radius = 11,
  });

  final Offset offset;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final safeOffset = Offset(
      offset.dx.clamp(0.0, size.width).toDouble(),
      offset.dy.clamp(0.0, size.height).toDouble(),
    );
    canvas
      ..drawCircle(
        safeOffset,
        radius + 2,
        Paint()
          ..color = Colors.black.withOpacity(0.25)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4,
      )
      ..drawCircle(
        safeOffset,
        radius,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4,
      );
  }

  @override
  bool shouldRepaint(_PickerHandlePainter oldDelegate) {
    return oldDelegate.offset != offset || oldDelegate.radius != radius;
  }
}
