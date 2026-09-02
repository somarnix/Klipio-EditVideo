part of 'editor_application.dart';

class PickedVideo {
  const PickedVideo({
    required this.name,
    required this.path,
    this.thumbnailPath,
    this.timelineThumbnailPaths = const [],
    this.durationSeconds,
    this.hasAudio = true,
    this.width = 0,
    this.height = 0,
    this.frameRate = 0,
    this.videoCodec = 'unknown',
    this.bitrate = 0,
    this.proxyPath,
  });

  final String name;
  final String path;
  final String? thumbnailPath;
  final List<String> timelineThumbnailPaths;
  final double? durationSeconds;
  final bool hasAudio;
  final int width;
  final int height;
  final double frameRate;
  final String videoCodec;
  final int bitrate;
  final String? proxyPath;

  PickedVideo copyWith({
    String? name,
    String? path,
    String? thumbnailPath,
    List<String>? timelineThumbnailPaths,
    double? durationSeconds,
    bool? hasAudio,
    int? width,
    int? height,
    double? frameRate,
    String? videoCodec,
    int? bitrate,
    String? proxyPath,
  }) {
    return PickedVideo(
      name: name ?? this.name,
      path: path ?? this.path,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      timelineThumbnailPaths:
          timelineThumbnailPaths ?? this.timelineThumbnailPaths,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      hasAudio: hasAudio ?? this.hasAudio,
      width: width ?? this.width,
      height: height ?? this.height,
      frameRate: frameRate ?? this.frameRate,
      videoCodec: videoCodec ?? this.videoCodec,
      bitrate: bitrate ?? this.bitrate,
      proxyPath: proxyPath ?? this.proxyPath,
    );
  }
}

class EditorScreen extends StatefulWidget {
  const EditorScreen({
    super.key,
    this.active = true,
    required this.checkExportAvailable,
    required this.settings,
    required this.onSettingsChanged,
    required this.onBackHome,
    this.onShowEditor,
  });

  final bool active;
  final bool checkExportAvailable;
  final AppSettings settings;
  final ValueChanged<AppSettings> onSettingsChanged;
  final VoidCallback onBackHome;
  final VoidCallback? onShowEditor;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  void _updateEditor(VoidCallback change) => setState(change);

  static const List<String> _defaultFontChoices = [
    'Arial',
    'Segoe UI',
    'Tahoma',
    'Verdana',
    'Calibri',
    'Georgia',
    'Impact',
    'Arial Black',
    'Times New Roman',
    'Khmer UI',
    'Khmer OS',
    'Khmer OS Battambang',
    'Khmer OS Muol Light',
    'DaunPenh',
    'Noto Sans Khmer',
    'Noto Serif Khmer',
  ];
  final List<String> _fontChoices = List.of(_defaultFontChoices);
  static const List<Color> _colorChoices = [
    Color(0xffffffff),
    Color(0xff111827),
    Color(0xffef4444),
    Color(0xfff97316),
    Color(0xfffacc15),
    Color(0xff22c55e),
    Color(0xff06b6d4),
    Color(0xff3b82f6),
    Color(0xff8b5cf6),
    Color(0xffec4899),
  ];
  static const double _minVideoSpeed = 0.25;
  static const double _maxVideoSpeed = 4.0;
  static const double _maxAudioBoost = 10.0;
  static const double _maxTransformScale = 5.0;
  static const int _maxRecentProjects = 32;
  static const String _recentProjectsKey = 'recent.projects';
  static const String _recentFoldersKey = 'recent.folders';
  static const String _exportPresetsKey = 'export.presets';
  static const String _workspaceDockOrderKey = 'workspace.dockOrder';
  static const String _workspaceDockWidthsKey = 'workspace.dockWidths';
  static const String _workspaceVisiblePanelsKey = 'workspace.visiblePanels';
  static const String _workspaceTimelineHeightKey = 'workspace.timelineHeight';
  static const String _workspaceTrackHeightsKey = 'workspace.trackHeights';

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _numberStartController =
      TextEditingController(text: '1');
  final TextEditingController _numberEndController = TextEditingController();
  final TextEditingController _titleCheckController = TextEditingController();
  final TextEditingController _trimStartController =
      TextEditingController(text: '0');
  final TextEditingController _trimEndController = TextEditingController();
  final TextEditingController _splitEveryController = TextEditingController();
  final TextEditingController _overlayTextController = TextEditingController();
  final TextEditingController _textStyleSearchController =
      TextEditingController();
  final TextEditingController _batchRenameController = TextEditingController();
  final TextEditingController _batchSplitMinutesController =
      TextEditingController(text: '15');
  final TextEditingController _partLabelController =
      TextEditingController(text: 'part');
  final TextEditingController _hookDurationController =
      TextEditingController(text: 'auto');
  final TextEditingController _captionVideoTargetsController =
      TextEditingController();
  final ScrollController _projectScrollController = ScrollController();
  final ScrollController _importScrollController = ScrollController();
  final ScrollController _timelineScrollController = ScrollController();
  final ValueNotifier<KlipioExportProgressView> _exportProgressView =
      ValueNotifier(const KlipioExportProgressView());
  final ValueNotifier<VideoPlayerValue> _emptyVideoValueListenable =
      ValueNotifier(const VideoPlayerValue.uninitialized());
  final ValueNotifier<double?> _timelineSkimmerSeconds = ValueNotifier(null);
  final ValueNotifier<TimelineGestureFeedback?> _timelineGestureFeedback =
      ValueNotifier(null);
  final ValueNotifier<double> _timelineScrollOffsetListenable =
      ValueNotifier(0);
  final ValueNotifier<TimelineModel?> _timelineEditPreviewModel =
      ValueNotifier(null);
  double _timelineScrollOffset = 0;

  final List<PickedVideo> _videos = [];
  final List<String> _compositionPaths = [];
  final Map<String, List<String>> _projectMediaPathsByComposition = {};
  final EditorSession _session = EditorSession();
  Map<String, TimelineModel> get _timelinesByComposition => _session.timelines;
  String? _selectedCompositionPath;
  bool _draggingMediaFiles = false;
  bool _importingDroppedMedia = false;
  final List<_TextOverlayDraft> _textOverlays = [const _TextOverlayDraft()];
  final List<String> _recentProjectPaths = [];
  final List<String> _recentFolders = [];
  final List<_ExportPreset> _exportPresets = [];
  final _editorHistory = SnapshotHistory<_EditorHistorySnapshot>();
  String _compactWorkspacePanel = 'project';
  List<_EditorHistorySnapshot> get _editorUndoHistory =>
      _editorHistory.undoEntries;
  List<_EditorHistorySnapshot> get _editorRedoHistory =>
      _editorHistory.redoEntries;
  bool _restoringEditorHistory = false;
  final Map<String, _ClipTimelineEdit> _clipTimelineEdits = {};
  final Map<String, List<_ClipTimelineEdit>> _clipTimelineUndoStacks = {};
  final Map<String, List<_ClipTimelineEdit>> _clipTimelineRedoStacks = {};
  Map<String, List<_CaptionCue>> get _captionCuesByVideo => _session.captions;
  final Set<String> _clipTransformOverrides = {};
  final Set<String> _favoriteCaptionStyles = {'capcut', 'orange_pop'};
  final TimelineEditor _timelineEditor = const TimelineEditor();
  final List<double> _timelineMarkers = [];
  TimelineModel get _multiTrackTimeline => _session.timeline;
  set _multiTrackTimeline(TimelineModel value) {
    _transformPreview.discard();
    _effectPreview.discard();
    _transitionPreview.discard();
    _session.timeline = value;
  }

  final _effectPreview = EffectPreview();
  final _transformPreview = TransformPreview();
  final _transitionPreview = TransitionPreview();
  String? _selectedEffectTarget;
  String? get _selectedTimelineClipId => _selectedEffectTarget;
  set _selectedTimelineClipId(String? value) {
    if (value != _selectedEffectTarget) {
      _transformPreview.discard();
      _effectPreview.discard();
      _transitionPreview.discard();
    }
    _selectedEffectTarget = value;
  }

  final Set<String> _selectedTimelineClipIds = {};
  final Set<String> _selectedCaptionIds = {};
  bool _musicTimelineSelected = false;
  String? _programTimelineClipId;
  final Map<String, double> _timelineTrackHeights = {};
  MCPBridge? _mcpBridge;
  int _mcpBridgeGeneration = 0;
  final Map<String, List<double>> _audioWaveformPeaks = {};
  final Map<String, double> _audioWaveformPeakRates = {};
  final Map<String, Future<String?>> _videoCoverJobsBySource = {};
  final Map<String, Future<String?>> _proxyJobsBySource = {};
  final TimelineMarqueeController _timelineMarqueeController =
      TimelineMarqueeController();
  ({ClipModel clip, TrackType type})? _timelineClipboard;
  List<
      ({
        ClipModel clip,
        TrackType type,
        int trackIndex,
        ClipModel? linkedAudio
      })> _timelineMultiClipboard = const [];
  ({
    ClipTransform transform,
    List<ClipEffect> effects,
    List<ClipKeyframe> keyframes,
  })? _timelineAttributeClipboard;
  _TextOverlayDraft? _textOverlayClipboard;
  LeftWorkspaceTab _leftWorkspaceTab = LeftWorkspaceTab.media;
  _EffectsWorkspaceCategory _effectsWorkspaceCategory =
      _EffectsWorkspaceCategory.effects;
  double _transitionDurationSeconds = 0.5;
  EditorSelection _editorSelection = const EditorSelection.none();
  final List<String> _workspaceDockOrder = [
    'project',
    'source',
    'program',
    'inspector',
  ];
  final Map<String, double> _workspaceDockWidths = {
    'project': 280,
    'source': 470,
    'program': 520,
    'inspector': 340,
  };
  final Set<String> _visibleWorkspacePanels = {
    'project',
    'source',
    'program',
    'inspector',
    'timeline',
  };
  VideoPlayerController? _sourceController;
  VideoPlayerController? _previewController;
  final AudioPlayer _musicPreviewPlayer = AudioPlayer();
  Timer? _autosaveTimer;
  Timer? _workspaceMemorySaveTimer;
  Timer? _timelineSeekDebounce;
  Timer? _timelineMediaLoadDebounce;
  final ValueNotifier<double?> _requestedTimelinePlayheadSeconds =
      ValueNotifier(null);
  late final TimelineScrubController _timelineScrubController;
  ProgramRenderSnapshot? _activeScrubSnapshot;
  int _timelineSeekGeneration = 0;
  final _programSeekQueue = PlaybackOperationQueue();
  double? _sourceInPoint;
  String? _activeTimelineTrimPath;
  _ClipTimelineEdit? _activeTimelineTrimOriginal;

  String? _currentProjectPath;
  Future<String>? _pendingAutosavePath;
  int _projectSaveGeneration = 0;
  int? _loadingProjectGeneration;
  String? _outputFolder;
  String? _watermarkPath;
  String? _musicPath;
  String? _musicPreviewPath;
  String? _sourceError;
  String? _previewError;
  String? _confirmedExportFolder;
  String _status = 'Ready';
  String _flip = 'none';
  String _outputRatio = 'original';
  String _canvasMode = 'none';
  String _canvasPattern = 'grid';
  Color _canvasColor = const Color(0xfff4c70f);
  double _canvasBlur = 24;
  String _qualityPreset = '1080p';
  String _exportCodec = 'h264';
  String _projectColorSpace = 'Rec. 709 SDR';
  String _projectResolution = 'Adapted';
  String _projectProxyResolution = '720p';
  String _overlayFont = 'Arial';
  String _overlayTextAnimation = 'none';
  String _captionModel = 'base.en';
  String _captionLanguage = 'en';
  String _captionDevice = 'auto';
  String _captionStyle = 'capcut';
  String _captionFont = 'Arial Black';
  String _captionCase = 'upper';
  String _batchRenamePattern = '';
  String _partLabel = 'part';
  bool _programTransformOverlayVisible = false;
  bool _projectProxyEnabled = false;
  bool _projectCopyMedia = false;
  late bool _projectArrangeLayers;
  late double _projectFrameRate;

  double _speed = 1.0;
  double _scaleX = 1.0;
  double _scaleY = 1.0;
  double _zoom = 1.0;
  double _panX = 0;
  double _panY = 0;
  double _watermarkX = 0.82;
  double _watermarkY = 0.82;
  double _watermarkSize = 0.12;
  double _overlayTextX = 0.5;
  double _overlayTextY = 0.75;
  double _overlayTextSize = 44;
  Color _overlayTextColor = Colors.white;
  double _overlayTextOpacity = 1;
  double _overlayTextStroke = 3;
  Color _overlayTextStrokeColor = Colors.black;
  double _overlayTextStrokeOpacity = 0.9;
  Color _overlayTextShadowColor = Colors.black;
  double _overlayTextShadowOpacity = 0.65;
  double _overlayTextAnimationDuration = 1.0;
  double _overlayTextTracking = 0;
  double _overlayTextCurve = 0;
  double _overlayTextStartX = 0.5;
  double _overlayTextStartY = 1.0;
  double _sourceVolume = 1.0;
  double _originalVolume = 1.0;
  double _musicVolume = 0.7;
  double _brightness = 0;
  double _contrast = 1;
  double _saturation = 1;
  double _gamma = 1;
  double _progress = 0;
  double _timelineZoom = 35;
  int _timelineZoomGeneration = 0;
  double _timelineViewportWidth = 1000;
  double _trimStartSeconds = 0;
  double _trimEndSeconds = 0;
  double _customBitrateKbps = 8000;
  double _exportFrameRate = 0;
  double _captionFontSize = 16;
  double _captionCharacterSpacing = 0;
  double _captionWordSpacing = 4;
  double _captionLineSpacing = 0;
  double _captionOpacity = 1;
  double _captionStrokeWidth = 6;
  double _captionBackgroundOpacity = 0.75;
  double _captionBackgroundPadding = 10;
  double _captionGlowStrength = 8;
  double _captionShadowStrength = 3;
  double _captionCurve = 0;
  Color _captionColor = const Color(0xfffff000);
  Color _captionStrokeColor = Colors.black;
  Color _captionBackgroundColor = Colors.black;
  Color _captionGlowColor = const Color(0xfffff000);
  Color _captionShadowColor = Colors.black;
  double _timelineWorkspaceHeight = 330;

  bool _isExporting = false;
  bool _automaticCaptions = false;
  bool _isGeneratingCaptions = false;
  bool _captionGenerateAllVideos = false;
  bool _captionBold = true;
  bool _captionUnderline = false;
  bool _captionItalic = false;
  bool _captionStrokeEnabled = true;
  bool _captionBackgroundEnabled = false;
  bool _captionGlowEnabled = false;
  bool _captionShadowEnabled = true;
  bool _exportAvailable = false;
  bool _exportTimelineTogether = true;
  bool _batchSplitLongVideos = false;
  bool _batchSplitSelectedVideoOnly = false;
  bool _exportSplitPartsAsFiles = false;
  bool _videoTrackHidden = false;
  bool _originalAudioMuted = false;
  bool _musicTrackMuted = false;
  bool _musicTrackLocked = false;
  bool _captionTrackHidden = false;
  bool _captionTrackLocked = false;
  bool _showExtractedAudioTrack = false;
  bool _clipEditMode = true;
  bool _useNumberRange = false;
  bool _capCutOneFolder = false;
  bool _capCutRenderEdits = false;
  bool _autoAdvancingPreview = false;
  bool _isSkippingPreviewEdit = false;
  bool _exportProgressDialogOpen = false;
  bool _renderQueuePaused = false;
  bool _renderQueueStopRequested = false;
  bool _startupAutomationStarted = false;
  bool _lastCapCutDraftSuccess = false;
  String? _lastCapCutDraftFolder;
  String _lastCapCutDraftMessage = '';
  _HookEditMode _hookEditMode = _HookEditMode.hookWithVideo;
  ExportCancelToken? _exportCancelToken;
  ExportCancelToken? _captionCancelToken;
  int _selectedVideoIndex = 0;
  int _captionWordsPerLine = 4;
  int _selectedCaptionCueIndex = 0;
  int _selectedTextOverlayIndex = 0;
  String _selectedTextStyleCategory = 'Trending';
  int _phoneTabIndex = 3;
  int _phoneEditToolIndex = 0;
  bool _phonePreviewExpanded = true;
  int _controllerLoadGeneration = 0;
  int _filmstripLoadGeneration = 0;
  bool _timelineMediaLoadRunning = false;
  bool _timelineMediaLoadAgain = false;
  int _timelineMediaRequestGeneration = 0;
  final Map<String, Future<void>> _waveformJobsBySource = {};
  int _sourceFramePrimeGeneration = 0;
  int _previewFramePrimeGeneration = 0;

  @override
  void initState() {
    super.initState();
    MediaJobManager.instance.openScope('project-media');
    WidgetsBinding.instance.addObserver(this);
    _timelineScrubController = TimelineScrubController(
      onSeek: (position, exact) async {
        final seconds = position.inMicroseconds / 1000000;
        final generation = ++_timelineSeekGeneration;
        _requestedTimelinePlayheadSeconds.value = seconds;
        await _commitMultiTrackTimelineSeek(
          seconds,
          generation,
          renderSnapshot: exact ? null : _activeScrubSnapshot,
          exactSeek: exact,
        );
      },
    );
    _projectArrangeLayers = widget.settings.arrangeLayers;
    _projectFrameRate = widget.settings.defaultFrameRate;
    // Project proxy override is explicit; application policy is resolved separately.
    _projectProxyEnabled = false;
    final imageCache = PaintingBinding.instance.imageCache;
    imageCache.maximumSize = math.min(imageCache.maximumSize, 256);
    imageCache.maximumSizeBytes =
        math.min(imageCache.maximumSizeBytes, 128 * 1024 * 1024);
    if (widget.settings.defaultExportFolder.trim().isNotEmpty) {
      _outputFolder = widget.settings.defaultExportFolder.trim();
    }
    _timelineScrollController.addListener(_handleTimelineScroll);
    unawaited(_musicPreviewPlayer.setReleaseMode(ReleaseMode.loop));
    unawaited(_musicPreviewPlayer.setVolume(_previewAudioVolume(_musicVolume)));
    unawaited(_loadWorkspaceMemory());
    unawaited(_loadInstalledWindowsFonts());
    _autosaveTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) {
        if (widget.active) unawaited(_autosaveProject());
      },
    );
    if (widget.checkExportAvailable) {
      _loadExportAvailability();
    }
    if (widget.settings.mcpEnabled) {
      unawaited(_syncMcpBridge(enabled: true, port: widget.settings.mcpPort));
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_runStartupAutomationJob());
    });
  }

  @override
  void didUpdateWidget(covariant EditorScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) {
      if (!widget.active) {
        _filmstripLoadGeneration++;
        unawaited(platform.cancelBackgroundMediaTasks());
        unawaited(_sourceController?.pause());
        unawaited(_previewController?.pause());
        unawaited(_pauseMusicPreview());
      } else {
        unawaited(_loadVisibleTimelineMedia());
      }
    }
    if (!oldWidget.checkExportAvailable && widget.checkExportAvailable) {
      _loadExportAvailability();
    }
    if (oldWidget.settings.proxyMode != widget.settings.proxyMode) {
      unawaited(
          MediaJobManager.instance.cancelType(MediaJobType.proxy).then((_) {
        if (mounted) _scheduleNeededProxies(_videos);
      }));
    }
    final oldDefault = oldWidget.settings.defaultExportFolder.trim();
    final newDefault = widget.settings.defaultExportFolder.trim();
    if (newDefault.isNotEmpty &&
        newDefault != oldDefault &&
        (_outputFolder == null || _outputFolder == oldDefault)) {
      _outputFolder = newDefault;
    }
    if (oldWidget.settings.mcpEnabled != widget.settings.mcpEnabled ||
        oldWidget.settings.mcpPort != widget.settings.mcpPort) {
      unawaited(
        _syncMcpBridge(
          enabled: widget.settings.mcpEnabled,
          port: widget.settings.mcpPort,
        ),
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.detached) return;
    unawaited(MediaJobManager.instance.shutdown());
    _exportCancelToken?.cancel();
    _filmstripLoadGeneration++;
    unawaited(platform.cancelBackgroundMediaTasks());
  }

  @override
  void dispose() {
    PerformanceDiagnostics.instance.event('CLOSE_REQUESTED', {
      'jobs': MediaJobManager.instance.jobs.length,
      'workers': activeKlipioWorkerCount,
    });
    unawaited(MediaJobManager.instance.closeScope('project-media'));
    MediaJobManager.instance.resumeBackgroundWork(owner: 'playback');
    MediaJobManager.instance.resumeBackgroundWork(owner: 'source-playback');
    _transformPreview.discard();
    _effectPreview.discard();
    _transitionPreview.discard();
    _session.dispose();
    _exportCancelToken?.cancel();
    _captionCancelToken?.cancel();
    unawaited(terminateAllKlipioWorkers());
    unawaited(PerformanceDiagnostics.instance.close());
    WidgetsBinding.instance.removeObserver(this);
    _exportCancelToken?.cancel();
    _filmstripLoadGeneration++;
    unawaited(platform.cancelBackgroundMediaTasks());
    unawaited(_mcpBridge?.stop());
    _mcpBridge = null;
    _nameController.dispose();
    _numberStartController.dispose();
    _numberEndController.dispose();
    _titleCheckController.dispose();
    _trimStartController.dispose();
    _trimEndController.dispose();
    _splitEveryController.dispose();
    _overlayTextController.dispose();
    _textStyleSearchController.dispose();
    _batchRenameController.dispose();
    _batchSplitMinutesController.dispose();
    _partLabelController.dispose();
    _hookDurationController.dispose();
    _captionVideoTargetsController.dispose();
    _projectScrollController.dispose();
    _importScrollController.dispose();
    _timelineScrollController.removeListener(_handleTimelineScroll);
    _timelineScrollController.dispose();
    _exportProgressView.dispose();
    _emptyVideoValueListenable.dispose();
    _timelineSkimmerSeconds.dispose();
    _timelineGestureFeedback.dispose();
    _timelineScrollOffsetListenable.dispose();
    _timelineEditPreviewModel.dispose();
    _timelineMarqueeController.dispose();
    _autosaveTimer?.cancel();
    _workspaceMemorySaveTimer?.cancel();
    _timelineSeekDebounce?.cancel();
    _timelineMediaLoadDebounce?.cancel();
    _requestedTimelinePlayheadSeconds.dispose();
    _timelineScrubController.dispose();
    unawaited(_autosaveProject());
    _sourceController?.removeListener(_handleSourceTick);
    _previewController?.removeListener(_handlePreviewTick);
    unawaited(_musicPreviewPlayer.dispose());
    _sourceController?.dispose();
    _previewController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: _shortcutBindings,
      child: Focus(
        autofocus: true,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final phoneMode = constraints.maxWidth < 720;
            final narrowToolbar = constraints.maxWidth < 1100;
            return Scaffold(
              appBar: AppBar(
                toolbarHeight: phoneMode ? 52 : 46,
                leadingWidth: phoneMode ? 46 : 42,
                shape: Border(
                  bottom: BorderSide(color: _panelBorderColor),
                ),
                leading: IconButton(
                  tooltip: 'Back to Home',
                  onPressed: () => unawaited(_returnToHome()),
                  icon: const Icon(Icons.home_outlined),
                ),
                title: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.asset(
                        'assets/branding/KlipioLogo.jpeg',
                        width: 25,
                        height: 25,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                        child: KText(
                      narrowToolbar
                          ? 'Klipio'
                          : 'Klipio - Pro v$klipioCurrentVersion',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    )),
                  ],
                ),
                actions: [
                  if (!phoneMode) ...[
                    IconButton(
                        tooltip: 'Undo (Ctrl+Z)',
                        onPressed:
                            _editorUndoHistory.isEmpty ? null : _undoEditor,
                        icon: const Icon(Icons.undo, size: 19)),
                    IconButton(
                        tooltip: 'Redo (Ctrl+Shift+Z)',
                        onPressed:
                            _editorRedoHistory.isEmpty ? null : _redoEditor,
                        icon: const Icon(Icons.redo, size: 19)),
                    IconButton(
                        tooltip: 'Save project (Ctrl+S)',
                        onPressed:
                            _videos.isEmpty || _loadingProjectGeneration != null
                                ? null
                                : () => unawaited(_saveProjectAs()),
                        icon: const Icon(Icons.save_outlined, size: 19)),
                  ],
                  if (!narrowToolbar)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Center(
                        child: Row(
                          children: [
                            PopupMenuButton<bool>(
                              tooltip: 'Workspace layout',
                              onSelected: (compact) => widget.onSettingsChanged(
                                widget.settings
                                    .copyWith(compactWorkspace: compact),
                              ),
                              itemBuilder: (context) => const [
                                PopupMenuItem(
                                  value: false,
                                  child: ListTile(
                                    leading: Icon(Icons.dashboard_outlined),
                                    title: KText('Standard workspace'),
                                    subtitle: KText('Comfortable panels'),
                                  ),
                                ),
                                PopupMenuItem(
                                  value: true,
                                  child: ListTile(
                                    leading: Icon(Icons.view_compact_outlined),
                                    title: KText('Compact workspace'),
                                    subtitle: KText('More editing space'),
                                  ),
                                ),
                              ],
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: _panelHeaderColor,
                                  border: Border.all(color: _panelBorderColor),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 9, vertical: 6),
                                  child: Row(
                                    children: [
                                      Icon(
                                        widget.settings.compactWorkspace
                                            ? Icons.view_compact_outlined
                                            : Icons.dashboard_outlined,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      KText(widget.settings.compactWorkspace
                                          ? 'Compact'
                                          : 'Workspace'),
                                      const SizedBox(width: 5),
                                      const Icon(Icons.expand_more, size: 17),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 7),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primaryContainer
                                    .withOpacity(0.55),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: KText(
                                '${_videos.length} clips',
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onPrimaryContainer,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            IconButton(
                              tooltip: widget.settings.themeChoice ==
                                      AppThemeChoice.dark
                                  ? 'Switch to light mode'
                                  : 'Switch to dark mode',
                              onPressed: () {
                                final next = widget.settings.themeChoice ==
                                        AppThemeChoice.dark
                                    ? AppThemeChoice.light
                                    : AppThemeChoice.dark;
                                widget.onSettingsChanged(
                                  widget.settings.copyWith(themeChoice: next),
                                );
                              },
                              icon: Icon(
                                widget.settings.themeChoice ==
                                        AppThemeChoice.dark
                                    ? Icons.light_mode_outlined
                                    : Icons.dark_mode_outlined,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Settings',
                              onPressed: () =>
                                  unawaited(_showAppSettingsDialog()),
                              icon: const Icon(Icons.tune),
                            ),
                            const SizedBox(width: 6),
                            FilledButton.icon(
                              onPressed: _isExporting
                                  ? _cancelExport
                                  : () => unawaited(_showExportHub()),
                              icon: Icon(
                                  _isExporting
                                      ? Icons.stop_circle_outlined
                                      : Icons.file_upload_outlined,
                                  size: 18),
                              label: KText(_isExporting ? 'Cancel' : 'Export'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (narrowToolbar)
                    IconButton(
                      tooltip: 'Settings',
                      onPressed: () => unawaited(_showAppSettingsDialog()),
                      icon: const Icon(Icons.tune),
                    ),
                  if (narrowToolbar)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilledButton(
                        onPressed: _isExporting
                            ? _cancelExport
                            : () => unawaited(_showExportHub()),
                        child: KText(_isExporting ? 'Cancel' : 'Export'),
                      ),
                    ),
                  if (!narrowToolbar)
                    Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: Center(
                        child: KText('PC',
                            style: TextStyle(
                                color: _mutedTextColor, fontSize: 11)),
                      ),
                    ),
                ],
              ),
              bottomNavigationBar: phoneMode ? _phoneNavigationBar() : null,
              body: SafeArea(
                child: Column(
                  children: [
                    if (!phoneMode) _workspaceActionDeck(),
                    Expanded(
                      child:
                          phoneMode ? _phoneWorkspace() : _desktopWorkspace(),
                    ),
                    if (!phoneMode)
                      Container(
                        height: 26,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                            color: _panelHeaderColor,
                            border: Border(
                                top: BorderSide(color: _panelBorderColor))),
                        child: Row(children: [
                          Icon(_isExporting ? Icons.sync : Icons.info_outline,
                              size: 14, color: _mutedTextColor),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Tooltip(
                                  message: _status,
                                  child: Text(_status,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 11)))),
                          if (constraints.maxWidth >= 1100) ...[
                            const SizedBox(width: 16),
                            ValueListenableBuilder<TextEditingValue>(
                              valueListenable: _nameController,
                              builder: (context, value, child) =>
                                  ConstrainedBox(
                                      constraints:
                                          const BoxConstraints(maxWidth: 240),
                                      child: Text(
                                          value.text.trim().isEmpty
                                              ? 'Untitled project'
                                              : value.text,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600))),
                            ),
                          ],
                        ]),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  static const Set<ClipEffectType> _clipAdjustmentTypes = {
    ClipEffectType.temperature,
    ClipEffectType.tint,
    ClipEffectType.exposure,
    ClipEffectType.brightness,
    ClipEffectType.contrast,
    ClipEffectType.highlights,
    ClipEffectType.shadows,
    ClipEffectType.whites,
    ClipEffectType.blacks,
    ClipEffectType.brilliance,
    ClipEffectType.saturation,
    ClipEffectType.gamma,
    ClipEffectType.clarity,
    ClipEffectType.fade,
    ClipEffectType.sharpen,
    ClipEffectType.blur,
    ClipEffectType.vignette,
    ClipEffectType.hueRotate,
    ClipEffectType.grayscale,
    ClipEffectType.sepia,
  };

  static String _percentText(double value) {
    final percent = value * 100;
    if ((percent - percent.round()).abs() < 0.01) {
      return '${percent.round()}%';
    }
    return '${percent.toStringAsFixed(1)}%';
  }

  static double? _parsePercent(String text) {
    final cleaned = text.trim().replaceAll('%', '').replaceAll(',', '.');
    final parsed = double.tryParse(cleaned);
    if (parsed == null) return null;
    return parsed / 100;
  }

  static String _volumeDbText(double value) {
    if (value <= 0.0001) return '-inf dB';
    final db = 20 * math.log(value) / math.ln10;
    if (db.abs() < 0.05) return '0 dB';
    return '${db.toStringAsFixed(1)} dB';
  }

  static double? _parseVolumeDb(String text) {
    final cleaned = text
        .trim()
        .toLowerCase()
        .replaceAll('db', '')
        .replaceAll(',', '.')
        .trim();
    if (cleaned == '-inf' || cleaned == '-infinity') return 0;
    final db = double.tryParse(cleaned);
    if (db == null) return null;
    return math.pow(10, db / 20).clamp(0.0, _maxAudioBoost).toDouble();
  }
}
