part of '../editor_application.dart';

// audio operations owned by the editor state; extracted without changing timing.
extension _AudioCacheWaveform on _EditorScreenState {
  Future<void> _ensureTimelineWaveform(String path, int generation,
      {double? duration}) async {
    if (_audioWaveformPeaks.containsKey(path)) return;
    final existing = _waveformJobsBySource[path];
    if (existing != null) {
      await existing;
      if (!mounted ||
          generation != _filmstripLoadGeneration ||
          _audioWaveformPeaks.containsKey(path)) return;
    }
    late final Future<void> job;
    job = (() async {
      final root = await getCacheDirectory();
      if (!mounted || generation != _filmstripLoadGeneration) return;
      final waveform = await platform.audioWaveformLod(
          path, '${root.path}${platform.pathSeparator}klipio_waveforms',
          durationSeconds: duration);
      if (!mounted || generation != _filmstripLoadGeneration) return;
      // Cache empty results too: a silent/missing stream is not a reason to
      // start another full decode on every scroll event.
      _updateEditor(() => _cacheWaveform(path, waveform));
    })()
        .onError<MediaJobCanceledException>((_, __) {
      // Playback preemption is not a silent asset. Retry on the next demand.
    }).whenComplete(() {
      if (identical(_waveformJobsBySource[path], job)) {
        _waveformJobsBySource.remove(path);
      }
    });
    _waveformJobsBySource[path] = job;
    await job;
  }

  void _cacheWaveform(String path, platform.AudioWaveformLod waveform) {
    _audioWaveformPeaks.remove(path);
    _audioWaveformPeakRates.remove(path);
    _audioWaveformPeaks[path] = waveform.peaks;
    _audioWaveformPeakRates[path] = waveform.peaksPerSecond;
    while (_audioWaveformPeaks.length > 8) {
      final oldest = _audioWaveformPeaks.keys.first;
      _audioWaveformPeaks.remove(oldest);
      _audioWaveformPeakRates.remove(oldest);
    }
  }

  Future<void> _pickMusic() async {
    if (_musicTrackLocked) {
      _showMessage('Unlock M1 before replacing its music.');
      return;
    }
    final result = await FilePicker.platform.pickFiles(type: FileType.audio);
    final path = result?.files.single.path;
    if (path == null || !mounted) return;
    _recordEditorHistory('music-file');
    _updateEditor(() {
      _musicPath = path;
      _status = 'Music selected';
    });
    _musicPreviewPath = null;
    unawaited(_ensureTimelineWaveform(path, _filmstripLoadGeneration));
    if (_previewController?.value.isPlaying == true) {
      await _playMusicPreview();
    }
  }

  Future<double?> _scoreAudioWindow(String path, double start) async {
    return platform.audioWindowLevelScore(path, start);
  }

  List<Widget> _audioControlSection() {
    return [
      _actionTile(
        icon: Icons.music_note_outlined,
        title: 'Background music',
        subtitle:
            _musicPath == null ? 'Optional' : platform.basename(_musicPath!),
        onPressed: _pickMusic,
      ),
      ..._audioMixControlSection(),
    ];
  }

  List<Widget> _audioMixControlSection() {
    return [
      _slider(
        'Original volume',
        _originalVolume,
        0,
        _EditorScreenState._maxAudioBoost,
        _setOriginalVolume,
        divisions: 60,
        valueFormatter: _EditorScreenState._volumeDbText,
        valueParser: _EditorScreenState._parseVolumeDb,
      ),
      _slider(
        'Music volume',
        _musicVolume,
        0,
        _EditorScreenState._maxAudioBoost,
        _setMusicVolume,
        divisions: 60,
        valueFormatter: _EditorScreenState._volumeDbText,
        valueParser: _EditorScreenState._parseVolumeDb,
      ),
    ];
  }

  void _setSourceVolume(double value) {
    _updateEditor(() => _sourceVolume = value);
    final controller = _sourceController;
    if (controller != null && controller.value.isInitialized) {
      unawaited(controller.setVolume(_previewAudioVolume(value)));
    }
  }

  void _setOriginalVolume(double value) {
    if (_videos.isEmpty) return;
    _recordEditorHistory('audio-original-volume');
    final path = _videos[_selectedVideoIndex].path;
    _updateEditor(() {
      _originalVolume = value;
      _clipTimelineEdits[path] =
          _clipTimelineEditFor(path).copyWith(originalVolume: value);
      _multiTrackTimeline = _multiTrackTimeline.copyWith(
        tracks: [
          for (final track in _multiTrackTimeline.tracks)
            track.type == TrackType.audio
                ? track.copyWith(
                    clips: [
                      for (final clip in track.clips)
                        clip.mediaPath == path
                            ? clip.copyWith(volume: value)
                            : clip,
                    ],
                  )
                : track,
        ],
      );
      _storeActiveCompositionTimeline();
    });
    final controller = _previewController;
    if (controller != null && controller.value.isInitialized) {
      unawaited(
          controller.setVolume(_previewAudioVolume(_effectiveOriginalVolume)));
    }
    unawaited(_autosaveProject());
  }

  void _setMusicVolume(double value) {
    _recordEditorHistory('audio-music-volume');
    _updateEditor(() => _musicVolume = value);
    unawaited(_musicPreviewPlayer
        .setVolume(_previewAudioVolume(_effectiveMusicVolume)));
  }

  double get _effectiveOriginalVolume =>
      _originalAudioMuted || _activeTimelineSourceAudioMuted
          ? 0
          : _originalVolume;

  double get _effectiveMusicVolume => _musicTrackMuted ? 0 : _musicVolume;
}
