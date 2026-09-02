part of '../editor_application.dart';

// captions operations owned by the editor state; extracted without changing timing.
extension _CaptionsCaptionWordFlow on _EditorScreenState {
  CaptionParagraphSpec get _captionParagraphSpec {
    final resolved = _resolvedCaptionStyle;
    return CaptionParagraphSpec(
        motion: _captionPreset(_captionStyle).motion,
        timedHighlight: const {'highlight', 'box', 'bounce', 'pop'}
                .contains(_captionPreset(_captionStyle).motion) &&
            _captionCurve == 0,
        activeWordBackground: _captionPreset(_captionStyle).motion == 'box'
            ? _captionPreset(_captionStyle)
                .activeBoxColor
                .withOpacity(resolved.opacity)
            : Colors.transparent,
        inactiveColor: _captionPreset(_captionStyle)
            .inactiveColor
            .withOpacity(resolved.opacity),
        style: TextStyle(
            color: resolved.color.withOpacity(resolved.opacity),
            fontFamily: resolved.fontFamily,
            fontSize: resolved.fontSize,
            fontWeight: resolved.bold ? FontWeight.w900 : FontWeight.w400,
            fontStyle: resolved.italic ? FontStyle.italic : FontStyle.normal,
            decoration: resolved.underline
                ? TextDecoration.underline
                : TextDecoration.none,
            decorationColor: resolved.color,
            letterSpacing: resolved.letterSpacing,
            height:
                (1.05 + resolved.lineSpacing / math.max(5, resolved.fontSize))
                    .clamp(0.65, 3.0),
            shadows: _captionTextShadows(_captionPreset(_captionStyle), 1,
                custom: true)),
        textCase: _captionCase,
        background:
            resolved.backgroundColor.withOpacity(resolved.backgroundOpacity),
        padding: resolved.padding,
        radius: resolved.borderRadius,
        alignment: resolved.alignment);
  }

  // Compatibility / Needs Refactor: curvature lays out words separately in
  // Wrap and applies per-word baseline/rotation. It cannot promise full-cue
  // Khmer shaping or parity with ASS; modern uncurved styles bypass this path.
  Widget _captionWordFlow({
    required _CaptionCue cue,
    required double currentSeconds,
    required _CaptionPreset preset,
    required double fontSize,
    required double scale,
  }) {
    final resolved = _resolvedCaptionStyle;
    TextStyle style(Color color, {bool active = false}) {
      return TextStyle(
        color: color.withOpacity(resolved.opacity),
        fontFamily: resolved.fontFamily,
        fontSize: fontSize,
        fontWeight: resolved.bold ? FontWeight.w900 : FontWeight.w400,
        fontStyle: resolved.italic ? FontStyle.italic : FontStyle.normal,
        decoration:
            resolved.underline ? TextDecoration.underline : TextDecoration.none,
        decorationColor: color,
        letterSpacing: resolved.letterSpacing * scale,
        height: (1.05 + resolved.lineSpacing / math.max(5, resolved.fontSize))
            .clamp(0.65, 3.0)
            .toDouble(),
        shadows: _captionTextShadows(
          preset,
          preset.motion == 'glow' && active ? scale * 1.6 : scale,
          custom: true,
        ),
      );
    }

    String display(String text) {
      return applyTextCase(text, _captionCase);
    }

    if (cue.words.isEmpty) {
      return ProjectText(
        display(cue.text),
        textAlign: TextAlign.center,
        style: style(resolved.color, active: true),
      );
    }

    return Wrap(
      alignment: WrapAlignment.center,
      runAlignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: (fontSize * 0.22 + resolved.wordSpacing * scale)
          .clamp(2.0, 120.0)
          .toDouble(),
      runSpacing: (fontSize * 0.08).clamp(1.0, 12.0).toDouble(),
      children: [
        for (final entry in cue.words.indexed)
          Builder(
            builder: (context) {
              final word = entry.$2;
              final active =
                  currentSeconds >= word.start && currentSeconds < word.end;
              final activeBox = preset.motion == 'box' && active
                  ? preset.activeBoxColor
                  : Colors.transparent;
              final wordWidget = AnimatedContainer(
                duration: const Duration(milliseconds: 90),
                curve: Curves.easeOutBack,
                padding: preset.motion != 'box'
                    ? EdgeInsets.zero
                    : EdgeInsets.symmetric(
                        horizontal: (7 * scale).clamp(3.0, 12.0).toDouble(),
                        vertical: (3 * scale).clamp(1.5, 7.0).toDouble(),
                      ),
                decoration: BoxDecoration(
                  color: activeBox,
                  borderRadius: BorderRadius.circular(
                    (5 * scale).clamp(2.0, 9.0).toDouble(),
                  ),
                ),
                child: ProjectText(
                  display(word.text),
                  style: style(
                    active ? resolved.color : preset.inactiveColor,
                    active: active,
                  ),
                ),
              );
              final scaleValue = !active
                  ? 1.0
                  : preset.motion == 'big_word'
                      ? 1.48
                      : (preset.motion == 'pop' || preset.motion == 'bounce')
                          ? 1.18
                          : 1.0;
              final animated = AnimatedScale(
                scale: scaleValue,
                duration: const Duration(milliseconds: 110),
                curve: Curves.easeOutBack,
                child: wordWidget,
              );
              final center = (cue.words.length - 1) / 2;
              final normalized =
                  center <= 0 ? 0.0 : (entry.$1 - center) / center;
              final curveOffset =
                  _captionCurve / 100 * fontSize * normalized * normalized;
              final bounceOffset = !active
                  ? 0.0
                  : preset.motion == 'big_word'
                      ? -fontSize * 0.18
                      : preset.motion == 'bounce'
                          ? -fontSize * 0.12
                          : 0.0;
              return Transform.translate(
                offset: Offset(0, curveOffset + bounceOffset),
                child: Transform.rotate(
                  angle: -_captionCurve / 100 * normalized * 0.22,
                  child: animated,
                ),
              );
            },
          ),
      ],
    );
  }

  List<CaptionCueSettings> _exportTimelineCaptionCues(
    TimelineModel requestedTimeline, {
    TimelineModel? outputTimeline,
    Map<String, double> playbackSpeedsByMediaPath = const {},
  }) {
    if (!_automaticCaptions || _captionTrackHidden) return const [];
    return CaptionProjectExport.resolve(requestedTimeline,
        captions: _session.captions,
        outputTimeline: outputTimeline,
        timelineEnd: _actualMultiTrackExportDuration(
            outputTimeline ?? requestedTimeline),
        playbackSpeedsByMediaPath: playbackSpeedsByMediaPath,
        textCase: _captionCase,
        sharedWordClock: _captionParagraphSpec.timedHighlight);
  }

  Widget _fontDropdown(
    String label,
    String value,
    ValueChanged<String> onChanged,
  ) {
    final selected = _safeCaptionFont(value);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () async {
          final next = await _showFontPicker(label, selected);
          if (next != null && mounted) onChanged(next);
        },
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: const Icon(Icons.font_download_outlined),
            suffixIcon: const Icon(Icons.arrow_drop_down),
            border: const OutlineInputBorder(),
          ),
          child: Text(
            selected,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }

  Future<String?> _showFontPicker(String label, String current) async {
    final searchController = TextEditingController();
    var query = '';
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final filtered = _fontChoices
              .where(
                  (font) => query.isEmpty || font.toLowerCase().contains(query))
              .toList();
          return Dialog(
            backgroundColor: _panelColor,
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: _panelBorderColor),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520, maxHeight: 620),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 14, 8, 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: KText(
                            label,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          icon: const Icon(Icons.close),
                          tooltip: 'Close font picker',
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: TextField(
                      controller: searchController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: 'Search readable fonts',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) => setDialogState(
                        () => query = value.trim().toLowerCase(),
                      ),
                    ),
                  ),
                  Divider(height: 1, color: _panelBorderColor),
                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(child: KText('No matching fonts'))
                        : ListView.builder(
                            itemCount: filtered.length,
                            itemExtent: 54,
                            itemBuilder: (context, index) {
                              final font = filtered[index];
                              final isSelected = font == current;
                              return ListTile(
                                selected: isSelected,
                                leading: Icon(
                                  isSelected
                                      ? Icons.check_circle
                                      : Icons.font_download_outlined,
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.primary
                                      : _mutedTextColor,
                                ),
                                title: KText(
                                  font,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: Text(
                                  'Aa',
                                  style: TextStyle(
                                    fontFamily: font,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                onTap: () => Navigator.pop(dialogContext, font),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    searchController.dispose();
    return result;
  }
}
