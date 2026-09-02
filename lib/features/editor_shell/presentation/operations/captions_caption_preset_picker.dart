part of '../editor_application.dart';

// captions operations owned by the editor state; extracted without changing timing.
extension _CaptionsCaptionPresetPicker on _EditorScreenState {
  Widget _captionPresetPicker({
    required String selected,
    required ValueChanged<String> onChanged,
  }) {
    var query = '';
    var favoritesOnly = false;
    return StatefulBuilder(
      builder: (context, setPickerState) => LayoutBuilder(
        builder: (context, constraints) {
          const gap = 8.0;
          final columns = constraints.maxWidth >= 340 ? 3 : 2;
          final itemWidth =
              (constraints.maxWidth - gap * (columns - 1)) / columns;
          final visiblePresets = _captionPresets.where((preset) {
            final matchesSearch = query.isEmpty ||
                preset.name.toLowerCase().contains(query.toLowerCase()) ||
                preset.motion.toLowerCase().contains(query.toLowerCase());
            final matchesFavorite =
                !favoritesOnly || _favoriteCaptionStyles.contains(preset.id);
            return matchesSearch && matchesFavorite;
          }).toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: KText(
                      'Caption style library',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  KText(
                    '${_captionPresets.length} styles',
                    style: TextStyle(
                      color: _mutedTextColor,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                onChanged: (value) => setPickerState(() => query = value),
                decoration: InputDecoration(
                  hintText: 'Search Basic, Pop, Glow, Box...',
                  prefixIcon: const Icon(Icons.search, size: 19),
                  suffixIcon: IconButton(
                    onPressed: () => setPickerState(
                      () => favoritesOnly = !favoritesOnly,
                    ),
                    tooltip: 'Favorites',
                    icon: Icon(
                      favoritesOnly ? Icons.star : Icons.star_border,
                      color: favoritesOnly ? const Color(0xffffd400) : null,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 9),
              if (visiblePresets.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 22),
                  child: Center(child: KText('No matching caption styles')),
                )
              else
                Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final preset in visiblePresets)
                      SizedBox(
                        width: itemWidth,
                        child: Material(
                          color: selected == preset.id
                              ? preset.accentColor.withOpacity(0.16)
                              : const Color(0xff151922),
                          borderRadius: BorderRadius.circular(9),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => onChanged(preset.id),
                            onDoubleTap: () {
                              onChanged(preset.id);
                              unawaited(_showCaptionStylePreview(preset));
                            },
                            child: Container(
                              height: 96,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(9),
                                border: Border.all(
                                  color: selected == preset.id
                                      ? preset.accentColor
                                      : const Color(0xff323846),
                                  width: selected == preset.id ? 2 : 1,
                                ),
                              ),
                              child: Stack(
                                children: [
                                  Center(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 5,
                                      ),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          DecoratedBox(
                                            decoration: BoxDecoration(
                                              color: preset.backgroundColor,
                                              borderRadius:
                                                  BorderRadius.circular(3),
                                            ),
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 4,
                                                vertical: 2,
                                              ),
                                              child: RichText(
                                                maxLines: 1,
                                                overflow: TextOverflow.fade,
                                                text: TextSpan(
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: preset.bold
                                                        ? FontWeight.w900
                                                        : FontWeight.w500,
                                                    fontStyle: preset.italic
                                                        ? FontStyle.italic
                                                        : FontStyle.normal,
                                                    shadows:
                                                        _captionTextShadows(
                                                      preset,
                                                      0.25,
                                                    ),
                                                  ),
                                                  children: [
                                                    TextSpan(
                                                      text: preset.uppercase
                                                          ? 'THE '
                                                          : 'The ',
                                                      style: TextStyle(
                                                        color: preset
                                                            .inactiveColor,
                                                      ),
                                                    ),
                                                    TextSpan(
                                                      text: preset.uppercase
                                                          ? 'QUICK'
                                                          : 'Quick',
                                                      style: TextStyle(
                                                        color:
                                                            preset.accentColor,
                                                        backgroundColor: preset
                                                            .activeBoxColor,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 9),
                                          KText(
                                            preset.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: selected == preset.id
                                                  ? preset.accentColor
                                                  : const Color(0xffd6dbea),
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 1,
                                    right: 1,
                                    child: IconButton(
                                      visualDensity: VisualDensity.compact,
                                      constraints:
                                          const BoxConstraints.tightFor(
                                        width: 28,
                                        height: 28,
                                      ),
                                      padding: EdgeInsets.zero,
                                      onPressed: () {
                                        _updateEditor(() {
                                          if (!_favoriteCaptionStyles
                                              .add(preset.id)) {
                                            _favoriteCaptionStyles
                                                .remove(preset.id);
                                          }
                                        });
                                        setPickerState(() {});
                                      },
                                      icon: Icon(
                                        _favoriteCaptionStyles
                                                .contains(preset.id)
                                            ? Icons.star
                                            : Icons.star_border,
                                        size: 15,
                                        color: _favoriteCaptionStyles
                                                .contains(preset.id)
                                            ? const Color(0xffffd400)
                                            : const Color(0xff94a3b8),
                                      ),
                                    ),
                                  ),
                                  const Positioned(
                                    right: 5,
                                    bottom: 4,
                                    child: Icon(
                                      Icons.check_circle,
                                      size: 13,
                                      color: Color(0xff22c55e),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              const SizedBox(height: 14),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showCaptionStylePreview(_CaptionPreset preset) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        final size = MediaQuery.sizeOf(context);
        return Dialog(
          backgroundColor: const Color(0xff111318),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: preset.accentColor.withOpacity(0.7)),
          ),
          child: SizedBox(
            width: math.min(760, size.width - 40),
            height: math.min(460, size.height - 40),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 8, 8),
                  child: Row(
                    children: [
                      Icon(Icons.animation, color: preset.accentColor),
                      const SizedBox(width: 9),
                      Expanded(
                        child: KText(
                          '${preset.name} • ${preset.motion.toUpperCase()}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xff343a46)),
                    ),
                    child: _CaptionStyleAnimationPreview(
                      preset: preset,
                      fontFamily: _captionFont,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: KText(
                    'Double-click another card to preview it. The selected style is already applied.',
                    style: TextStyle(color: _mutedTextColor),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCaptionSettingsDialog() {
    _openLeftWorkspaceTab(LeftWorkspaceTab.captions);
  }

  Future<void> _generateSelectedCaptionPreview() async {
    if (_videos.isEmpty || _isGeneratingCaptions) return;
    if (_captionTrackLocked) {
      _showMessage('Unlock T1 before generating captions.');
      return;
    }
    _saveSelectedClipTimelineEdit();
    _storeActiveCompositionTimeline();
    final targetIndexes = _captionGenerateAllVideos
        ? _parseVideoTargetExpression(_captionVideoTargetsController.text)
        : (indexes: <int>[_selectedVideoIndex], error: null);
    if (targetIndexes.error != null || targetIndexes.indexes.isEmpty) {
      _showMessage(targetIndexes.error ?? 'Choose at least one video.');
      return;
    }
    final targets = [
      for (final index in targetIndexes.indexes) _videos[index],
    ];
    await _pausePlaybackForExport();
    if (!mounted) return;
    final video = targets.first;
    final cancelToken = ExportCancelToken();
    _captionCancelToken = cancelToken;
    final progress = ValueNotifier<_CaptionGenerationView>(
      _CaptionGenerationView(
        videoName: video.name,
        currentVideo: 1,
        totalVideos: targets.length,
      ),
    );
    var dialogOpen = true;
    _updateEditor(() {
      _isGeneratingCaptions = true;
      _automaticCaptions = true;
      _status = 'Starting Faster-Whisper for ${video.name}...';
    });
    final dialogClosed = showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _CaptionGenerationDialog(
        progress: progress,
        onCancel: () {
          cancelToken.cancel();
          progress.value = progress.value.copyWith(
            status: 'Cancelling caption generation...',
            cancelling: true,
          );
        },
      ),
    ).whenComplete(() => dialogOpen = false);
    ExportResult result = const ExportResult(
      success: true,
      message: 'Captions generated.',
    );
    final generatedByPath = <String, List<_CaptionCue>>{};
    final temporaryCaptionInputs = <File>[];
    _recordEditorHistory('caption-generate');
    try {
      final tempDirectory = await getTemporaryDirectory();
      for (var targetIndex = 0;
          targetIndex < targets.length && !cancelToken.isCanceled;
          targetIndex++) {
        final target = targets[targetIndex];
        if (mounted) {
          _updateEditor(() {
            // Regeneration replaces this video's old captions immediately.
            // Completed earlier videos remain saved if a later one is canceled.
            _captionCuesByVideo.remove(target.path);
            _status =
                'Generating captions for video ${targetIndex + 1} of ${targets.length}: ${target.name}';
          });
        }
        if (dialogOpen) {
          progress.value = _CaptionGenerationView(
            videoName: target.name,
            currentVideo: targetIndex + 1,
            totalVideos: targets.length,
            status: 'Preparing edited cuts...',
          );
        }
        final timeline = _selectedCompositionPath == target.path
            ? _multiTrackTimeline
            : _timelinesByComposition[target.path];
        var clips = <ClipModel>[
          for (final track in timeline?.videoTracks ?? const <TrackModel>[])
            if (!track.isMuted)
              for (final clip in track.clips)
                if (!clip.isMuted &&
                    clip.mediaPath == target.path &&
                    clip.duration > 0.001)
                  clip,
        ]..sort(
            (left, right) => left.timelineStart.compareTo(right.timelineStart));
        if (clips.isEmpty) {
          clips = [
            for (final part in _clipTimelineEditFor(target.path)
                .timelineParts(target.durationSeconds))
              ClipModel(
                id: 'caption-${target.path.hashCode}-${part.start}',
                mediaPath: target.path,
                timelineStart: part.start,
                duration: math.max(0.001, part.end - part.start).toDouble(),
                sourceStart: part.start,
                zIndex: 0,
              ),
          ];
        }
        if (clips.isEmpty) {
          generatedByPath[target.path] = const [];
          if (mounted) {
            _updateEditor(() => _captionCuesByVideo[target.path] = const []);
            await _autosaveProject();
          }
          continue;
        }

        final stamp = DateTime.now().microsecondsSinceEpoch;
        final editedInput = File(
          '${tempDirectory.path}${Platform.pathSeparator}'
          'klipio_caption_${targetIndex}_$stamp.wav',
        );
        temporaryCaptionInputs.add(editedInput);
        final segments = <({
          double outputStart,
          double outputEnd,
          double speed,
          ClipModel clip,
        })>[];
        final audioSegments = <CaptionAudioSegment>[];
        var outputCursor = 0.0;
        for (final clip in clips) {
          final edit = _clipTimelineEditFor(clip.mediaPath);
          final speed = edit.speed.clamp(_EditorScreenState._minVideoSpeed,
              _EditorScreenState._maxVideoSpeed);
          final outputDuration = clip.duration / speed;
          segments.add((
            outputStart: outputCursor,
            outputEnd: outputCursor + outputDuration,
            speed: speed,
            clip: clip,
          ));
          outputCursor += outputDuration;
          audioSegments.add(
            CaptionAudioSegment(
              inputPath: clip.mediaPath,
              sourceStart: clip.sourceStart,
              duration: clip.duration,
              speed: speed,
            ),
          );
        }
        final render = await exportCaptionAudioSequence(
          segments: audioSegments,
          outputPath: editedInput.path,
          cancelToken: cancelToken,
          onProgress: (value, status) {
            if (!dialogOpen) return;
            progress.value = _CaptionGenerationView(
              videoName: target.name,
              currentVideo: targetIndex + 1,
              totalVideos: targets.length,
              progress: value.clamp(0, 1) * 0.18,
              status: 'Preparing speech audio: $status',
              cancelling: cancelToken.isCanceled,
            );
          },
        );
        if (!render.success || cancelToken.isCanceled) {
          result = render;
          if (await editedInput.exists()) await editedInput.delete();
          break;
        }
        final captionResult = await generateCaptionPreview(
          ExportJob(
            inputPath: editedInput.path,
            outputPath: editedInput.path,
            settings: _settings.copyWith(
              automaticCaptions: true,
              speed: 1,
              trimStartSeconds: 0,
              trimEndSeconds: 0,
            ),
            cancelToken: cancelToken,
            onProgress: (value, status) {
              if (!dialogOpen) return;
              progress.value = _CaptionGenerationView(
                videoName: target.name,
                currentVideo: targetIndex + 1,
                totalVideos: targets.length,
                progress: 0.18 + value.clamp(0, 1) * 0.82,
                status: status,
                cancelling: cancelToken.isCanceled,
              );
            },
          ),
        );
        if (!captionResult.success || captionResult.outputPath == null) {
          result = captionResult;
          if (await editedInput.exists()) await editedInput.delete();
          break;
        }
        final localCues = await _captionCuesFromAss(captionResult.outputPath!);
        final mapped = <_CaptionCue>[];
        for (final cue in localCues) {
          for (final segment in segments) {
            final visibleStart = math.max(cue.start, segment.outputStart);
            final visibleEnd = math.min(cue.end, segment.outputEnd);
            if (visibleEnd <= visibleStart) continue;
            double sourceTime(double localTime) =>
                segment.clip.sourceStart +
                (localTime - segment.outputStart) * segment.speed;
            mapped.add(
              cue.copyWith(
                // A cue crossing edited segments creates distinct instances.
                // Ordinary edits retain identity; this is an explicit fork.
                id: '${cue.id}/clip/${segment.clip.id}',
                start: sourceTime(visibleStart),
                end: sourceTime(visibleEnd),
                words: [
                  for (final word in cue.words)
                    if (word.end > visibleStart && word.start < visibleEnd)
                      word.copyWith(
                        id: '${word.id}/clip/${segment.clip.id}',
                        start: sourceTime(math.max(word.start, visibleStart)),
                        end: sourceTime(math.min(word.end, visibleEnd)),
                        text: word.text,
                      ),
                ],
              ),
            );
          }
        }
        mapped.sort((left, right) => left.start.compareTo(right.start));
        generatedByPath[target.path] = mapped;
        if (mounted) {
          _updateEditor(() {
            _captionCuesByVideo[target.path] = mapped;
            _status =
                'Captions completed for video ${targetIndex + 1} of ${targets.length}';
          });
          await _autosaveProject();
        }
        if (await editedInput.exists()) await editedInput.delete();
      }
    } catch (error) {
      result = ExportResult(success: false, message: '$error');
    } finally {
      for (final temporaryInput in temporaryCaptionInputs) {
        try {
          if (await temporaryInput.exists()) await temporaryInput.delete();
        } catch (_) {
          // The OS may still be releasing a canceled FFmpeg worker handle.
        }
      }
      if (dialogOpen && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      await dialogClosed;
      progress.dispose();
      if (identical(_captionCancelToken, cancelToken)) {
        _captionCancelToken = null;
      }
      MediaJobManager.instance.resumeBackgroundWork();
    }
    if (!mounted) return;
    if (!result.success || cancelToken.isCanceled) {
      _updateEditor(() {
        _isGeneratingCaptions = false;
        _status = cancelToken.isCanceled
            ? 'Caption generation canceled after ${generatedByPath.length} of ${targets.length} videos'
            : 'Caption generation failed';
      });
      unawaited(_autosaveProject());
      if (!cancelToken.isCanceled) _showMessage(result.message);
      return;
    }
    _updateEditor(() {
      final cues = generatedByPath[video.path] ?? const <_CaptionCue>[];
      if (cues.isNotEmpty) {
        _selectedCaptionCueIndex = 0;
        _selectedTimelineClipId = null;
        _editorSelection = EditorSelection.caption(
          _captionTimelineId(video.path, 0),
          label: cues.first.text,
        );
        _visibleWorkspacePanels.add('inspector');
      }
      _isGeneratingCaptions = false;
      _status = cues.isEmpty
          ? 'No speech was detected in ${video.name}'
          : _captionGenerateAllVideos
              ? 'Captions ready for ${generatedByPath.length} videos'
              : '${cues.length} caption blocks ready on T1';
    });
    unawaited(_autosaveProject());
  }
}
