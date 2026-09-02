part of '../editor_application.dart';

// controls operations owned by the editor state; extracted without changing timing.
extension _ControlsAutoHookBestMomentsSeconds on _EditorScreenState {
  double _autoHookBestMomentsSeconds(double duration) {
    if (duration <= 0) return 0;
    if (duration <= 60) return duration;
    final target = duration * 0.35;
    return target.clamp(45.0, math.min(duration, 15 * 60)).toDouble();
  }

  ({double start, double end}) _hookRangeForSection(
    List<({double start, double score})> scoredMoments,
    double sectionStart,
    double sectionEnd,
    double hookSeconds,
  ) {
    final sectionDuration = sectionEnd - sectionStart;
    final safeHookSeconds =
        math.min(hookSeconds, math.max(1.0, sectionDuration));
    final candidates = scoredMoments
        .where(
          (moment) =>
              moment.start >= sectionStart &&
              moment.start <= sectionEnd - safeHookSeconds,
        )
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    final start = candidates.isNotEmpty
        ? candidates.first.start
        : sectionStart + math.max(0.0, sectionDuration * 0.35);
    final clampedStart = start
        .clamp(
            sectionStart, math.max(sectionStart, sectionEnd - safeHookSeconds))
        .toDouble();
    return (start: clampedStart, end: clampedStart + safeHookSeconds);
  }

  Future<List<({double start, double score})>> _scoreHookMoments(
    String path,
    double duration, {
    bool fast = false,
  }) async {
    if (!(Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      return _fallbackHookScores(duration);
    }
    final sampleCount = fast
        ? duration < 1200
            ? 5
            : 7
        : duration < 1200
            ? 12
            : 18;
    final maxStart = math.max(0.0, duration - 5);
    final step = sampleCount <= 1 ? maxStart : maxStart / (sampleCount - 1);
    final moments = <({double start, double score})>[];
    for (var index = 0; index < sampleCount; index++) {
      final start = (step * index).clamp(0.0, maxStart).toDouble();
      final score = await _scoreAudioWindow(path, start);
      if (!mounted) return moments;
      if (score != null) {
        moments.add((start: start, score: score));
      }
      _updateEditor(() {
        _status = 'Scanning hook moments ${index + 1}/$sampleCount...';
      });
    }
    return moments.isEmpty ? _fallbackHookScores(duration) : moments;
  }

  List<({double start, double score})> _fallbackHookScores(double duration) {
    final maxStart = math.max(0.0, duration - 5);
    return [
      (start: maxStart * 0.18, score: 1),
      (start: maxStart * 0.38, score: 3),
      (start: maxStart * 0.62, score: 4),
      (start: maxStart * 0.82, score: 2),
    ];
  }

  List<({double start, double end})> _bestMainHookSegments(
    List<({double start, double score})> scoredMoments,
    double duration,
    ({double start, double end}) hook,
    double targetSeconds,
  ) {
    const maxSegmentCount = 3;
    final hookSeconds = hook.end - hook.start;
    final availableMainSeconds = math.max(0.0, duration - hookSeconds);
    final mainSeconds =
        (targetSeconds - hookSeconds).clamp(0.0, availableMainSeconds);
    final segmentCount =
        math.max(1, math.min(maxSegmentCount, mainSeconds ~/ 8));
    final segmentLength = mainSeconds / segmentCount;
    final selected = <({double start, double end})>[];
    if (segmentLength <= 0.001) return selected;
    final spans = _availableHookSpans(duration, hook);
    if (_totalRangeSeconds(spans) <= mainSeconds + 0.001) {
      return spans;
    }
    final candidates = scoredMoments.isEmpty
        ? _fallbackHookScores(duration)
        : ([...scoredMoments]..sort((a, b) => b.score.compareTo(a.score)));
    for (final moment in candidates) {
      if (selected.length >= segmentCount) break;
      final candidate = _segmentNearMoment(
        moment.start,
        segmentLength,
        spans,
        selected,
      );
      if (candidate != null) selected.add(candidate);
    }
    while (selected.length < segmentCount) {
      final remainingSeconds = mainSeconds - _totalRangeSeconds(selected);
      if (remainingSeconds <= 0.001) break;
      final remainingCount = segmentCount - selected.length;
      final nextLength = remainingSeconds / remainingCount;
      final next = _firstAvailableSegment(nextLength, spans, selected);
      if (next == null) break;
      selected.add(next);
    }
    selected.sort((a, b) => a.start.compareTo(b.start));
    return selected;
  }

  List<({double start, double end})> _availableHookSpans(
    double duration,
    ({double start, double end}) hook,
  ) {
    return [
      if (hook.start > 0.05) (start: 0.0, end: hook.start),
      if (hook.end < duration - 0.05) (start: hook.end, end: duration),
    ];
  }

  ({double start, double end})? _segmentNearMoment(
    double moment,
    double length,
    List<({double start, double end})> spans,
    List<({double start, double end})> selected,
  ) {
    final orderedSpans = [...spans]..sort(
        (a, b) => _distanceToRange(moment, a).compareTo(
          _distanceToRange(moment, b),
        ),
      );
    for (final span in orderedSpans) {
      final candidate = _candidateInsideSpan(moment, length, span);
      if (candidate != null &&
          !selected.any((range) => _rangesOverlap(candidate, range))) {
        return candidate;
      }
    }
    return _firstAvailableSegment(length, spans, selected);
  }

  ({double start, double end})? _candidateInsideSpan(
    double moment,
    double length,
    ({double start, double end}) span,
  ) {
    if (span.end - span.start < length - 0.001) return null;
    final start = (moment - length * 0.35)
        .clamp(span.start, span.end - length)
        .toDouble();
    return (start: start, end: start + length);
  }

  ({double start, double end})? _firstAvailableSegment(
    double length,
    List<({double start, double end})> spans,
    List<({double start, double end})> selected,
  ) {
    for (final gap in _availableGaps(spans, selected)) {
      if (gap.end - gap.start >= length - 0.001) {
        return (start: gap.start, end: gap.start + length);
      }
    }
    return null;
  }

  List<({double start, double end})> _availableGaps(
    List<({double start, double end})> spans,
    List<({double start, double end})> selected,
  ) {
    final gaps = <({double start, double end})>[];
    for (final span in spans) {
      var cursor = span.start;
      final blockers = selected
          .where((range) => _rangesOverlap(range, span))
          .toList()
        ..sort((a, b) => a.start.compareTo(b.start));
      for (final blocker in blockers) {
        if (blocker.start > cursor + 0.001) {
          gaps.add((start: cursor, end: blocker.start));
        }
        cursor = math.max(cursor, blocker.end);
      }
      if (span.end > cursor + 0.001) {
        gaps.add((start: cursor, end: span.end));
      }
    }
    return gaps;
  }

  double _distanceToRange(
    double value,
    ({double start, double end}) range,
  ) {
    if (value < range.start) return range.start - value;
    if (value > range.end) return value - range.end;
    return 0;
  }

  double _totalRangeSeconds(List<({double start, double end})> ranges) {
    return ranges.fold<double>(
      0,
      (sum, range) => sum + math.max(0.0, range.end - range.start),
    );
  }

  bool _rangesOverlap(
    ({double start, double end}) first,
    ({double start, double end}) second,
  ) {
    return first.start < second.end && second.start < first.end;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: KText(message)),
    );
  }

  Future<void> _showAppSettingsDialog() async {
    await showKlipioSettingsDialog(
      context,
      settings: widget.settings,
      onSaved: widget.onSettingsChanged,
    );
  }

  Widget _deckAction({
    required IconData icon,
    required String label,
    required String shortcut,
    required VoidCallback? onPressed,
    bool primary = false,
  }) {
    final enabled = onPressed != null;
    final accent = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(right: 5),
      child: Tooltip(
        message: '$label  |  $shortcut',
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(5),
          child: Container(
            constraints: const BoxConstraints(minWidth: 58),
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
            decoration: BoxDecoration(
              color: primary && enabled ? accent.withOpacity(0.11) : null,
              borderRadius: BorderRadius.circular(5),
              border: primary && enabled
                  ? Border.all(color: accent.withOpacity(0.24))
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon,
                    size: 18,
                    color: !enabled
                        ? _mutedTextColor.withOpacity(0.45)
                        : primary
                            ? accent
                            : null),
                const SizedBox(height: 1),
                KText(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: enabled ? null : _mutedTextColor.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _windowMenuAction() {
    const labels = {
      'project': 'Project / Media',
      'source': 'Source Monitor',
      'program': 'Program Monitor',
      'inspector': 'Inspector / Effects',
      'timeline': 'Timeline',
    };
    return Padding(
      padding: const EdgeInsets.only(right: 5),
      child: PopupMenuButton<String>(
        tooltip: 'Window • show, hide, or reset panels',
        onSelected: (value) {
          if (value == 'reset') {
            _updateEditor(() {
              _workspaceDockOrder
                ..clear()
                ..addAll(['project', 'source', 'program', 'inspector']);
              _workspaceDockWidths
                ..clear()
                ..addAll({
                  'project': 280,
                  'source': 470,
                  'program': 520,
                  'inspector': 340,
                });
              _visibleWorkspacePanels
                ..clear()
                ..addAll([
                  'project',
                  'source',
                  'program',
                  'inspector',
                  'timeline',
                ]);
              _timelineWorkspaceHeight = 330;
            });
          } else {
            _updateEditor(() {
              if (!_visibleWorkspacePanels.add(value)) {
                _visibleWorkspacePanels.remove(value);
              }
            });
          }
          unawaited(_saveWorkspaceMemory());
        },
        itemBuilder: (context) => [
          for (final entry in labels.entries)
            CheckedPopupMenuItem<String>(
              value: entry.key,
              checked: _visibleWorkspacePanels.contains(entry.key),
              child: KText(entry.value),
            ),
          const PopupMenuDivider(),
          const PopupMenuItem<String>(
            value: 'reset',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.restart_alt),
              title: KText('Reset workspace'),
            ),
          ),
        ],
        child: Container(
          constraints: const BoxConstraints(minWidth: 58),
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(5)),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.window_outlined, size: 18),
              SizedBox(height: 1),
              KText(
                'Window',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _phoneNavigationBar() {
    const items = <(IconData, String)>[
      (Icons.video_library_outlined, 'Media'),
      (Icons.tune_outlined, 'Edit'),
      (Icons.subtitles_outlined, 'Captions'),
      (Icons.view_timeline_outlined, 'Timeline'),
      (Icons.music_note_outlined, 'Audio'),
      (Icons.file_upload_outlined, 'Export'),
    ];
    return SafeArea(
      top: false,
      child: Container(
        height: 58,
        decoration: BoxDecoration(
          color: _panelColor,
          border: Border(top: BorderSide(color: _panelBorderColor)),
        ),
        child: Row(
          children: [
            for (final entry in items.indexed)
              Expanded(
                child: _phoneNavItem(
                  index: entry.$1,
                  icon: entry.$2.$1,
                  label: entry.$2.$2,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _phoneNavItem({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final selected = index == _phoneTabIndex;
    final accent = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: () => _updateEditor(() => _phoneTabIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 170),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: selected ? accent : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 21, color: selected ? accent : _mutedTextColor),
            const SizedBox(height: 2),
            KText(
              label,
              maxLines: 1,
              style: TextStyle(
                fontSize: 10,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? accent : _mutedTextColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _phoneQuickActions() {
    final hasVideo = _videos.isNotEmpty;
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: _panelColor,
        border: Border(
          top: BorderSide(color: _panelBorderColor),
          bottom: BorderSide(color: _panelBorderColor),
        ),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        children: [
          _phoneAction(
            icon: _phonePreviewExpanded ? Icons.expand_less : Icons.expand_more,
            label: 'Preview',
            onPressed: () => _updateEditor(
                () => _phonePreviewExpanded = !_phonePreviewExpanded),
          ),
          _phoneAction(
            icon: Icons.add_to_queue,
            label: 'Add',
            onPressed: _pickVideos,
            primary: true,
          ),
          _phoneAction(
            icon: Icons.content_cut,
            label: 'Split',
            onPressed: hasVideo ? _splitClipAtPlayhead : null,
          ),
          _phoneAction(
            icon: Icons.subtitles_outlined,
            label: 'Captions',
            onPressed:
                hasVideo ? () => _updateEditor(() => _phoneTabIndex = 2) : null,
          ),
          _phoneAction(
            icon: Icons.title_outlined,
            label: 'Text',
            onPressed: hasVideo
                ? () => _updateEditor(() {
                      _phoneTabIndex = 1;
                      _phoneEditToolIndex = 3;
                    })
                : null,
          ),
          _phoneAction(
            icon: Icons.undo,
            label: 'Undo',
            onPressed: _canUndoEditor ? _undoEditor : null,
          ),
          _phoneAction(
            icon: Icons.save_outlined,
            label: 'Save',
            onPressed: hasVideo ? _saveProjectAs : null,
          ),
          _phoneAction(
            icon: Icons.file_upload_outlined,
            label: 'Export',
            onPressed:
                hasVideo ? () => _updateEditor(() => _phoneTabIndex = 5) : null,
          ),
        ],
      ),
    );
  }

  Widget _phoneAction({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    bool primary = false,
  }) {
    final accent = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(5),
        child: SizedBox(
          width: 56,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 18,
                  color: onPressed == null
                      ? _mutedTextColor.withOpacity(0.4)
                      : primary
                          ? accent
                          : null),
              const SizedBox(height: 1),
              KText(label,
                  maxLines: 1,
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: onPressed == null
                          ? _mutedTextColor.withOpacity(0.4)
                          : null)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _propertySummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: KText(
              label,
              style: TextStyle(fontSize: 11, color: _mutedTextColor),
            ),
          ),
          KText(
            value,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  List<({TrackModel track, ClipModel clip})> _selectedProfessionalTargets() {
    final targets = <({TrackModel track, ClipModel clip})>[];
    for (final id in _effectiveSelectedTimelineClipIds) {
      final result = _multiTrackTimeline.clipById(id);
      if (result != null &&
          result.track.type == TrackType.video &&
          !result.track.isLocked) {
        targets.add(result);
      }
    }
    if (targets.isNotEmpty) return targets;
    final fallback = _professionalTargetClip();
    return fallback == null ? const [] : [fallback];
  }
}
