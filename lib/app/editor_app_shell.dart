part of '../features/editor_shell/presentation/editor_application.dart';

class KlipioApp extends StatefulWidget {
  const KlipioApp({
    super.key,
    this.checkExportAvailable = true,
    this.showStartupAnimation = true,
  });

  final bool checkExportAvailable;
  final bool showStartupAnimation;

  @override
  State<KlipioApp> createState() => _KlipioAppState();
}

class _KlipioAppState extends State<KlipioApp> {
  AppSettings _settings = const AppSettings();
  final GlobalKey<_EditorScreenState> _editorKey =
      GlobalKey<_EditorScreenState>();
  bool _showHome = false;
  bool _showStartup = false;
  bool _editorCreated = false;
  int _homeRefresh = 0;

  @override
  void initState() {
    super.initState();
    _showHome = widget.checkExportAvailable && startupAutomationJob == null;
    _showStartup = widget.showStartupAnimation && startupAutomationJob == null;
    _editorCreated = !_showHome;
    unawaited(_loadSettings());
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await AppSettings.load();
      if (!mounted) return;
      setState(() => _settings = settings);
    } catch (_) {
      // Keep the safe defaults. Settings must never block the Home screen.
    }
  }

  void _updateSettings(AppSettings settings) {
    setState(() => _settings = settings);
    unawaited(settings.save());
  }

  void _goHome() {
    setState(() {
      _showHome = true;
      _homeRefresh++;
    });
  }

  void _showEditor() => setState(() {
        _editorCreated = true;
        _showHome = false;
      });

  Future<void> _createProject() async {
    _showEditor();
    await WidgetsBinding.instance.endOfFrame;
    await _editorKey.currentState?._clearProject();
  }

  Future<void> _openProjectFromHome([String? path]) async {
    var selectedPath = path;
    if (selectedPath == null) {
      final draftsRoot = await _klipioDraftsRoot();
      await draftsRoot.create(recursive: true);
      final selectedFolder = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Open Klipio project folder',
        initialDirectory: draftsRoot.path,
      );
      if (selectedFolder == null) return;
      selectedPath = await _projectFileFromSelectedFolder(selectedFolder);
      if (selectedPath == null) {
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            icon: const Icon(Icons.folder_off_outlined),
            title: const KText('Not a Klipio project folder'),
            content: const KText(
              'Choose one project folder directly inside Klipio Drafts. The internal project file is opened automatically.',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const KText('OK'),
              ),
            ],
          ),
        );
        return;
      }
    }
    _showEditor();
    await WidgetsBinding.instance.endOfFrame;
    await _editorKey.currentState?._loadProject(selectedPath);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Klipio',
      themeMode: _settings.themeMode,
      locale: KlipioLanguages.localeFor(_settings.language),
      supportedLocales: KlipioLanguages.supportedLocales,
      localizationsDelegates: const [
        KlipioLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: _appTheme(Brightness.light),
      darkTheme: _appTheme(Brightness.dark),
      home: _showStartup
          ? KlipioStartupSplash(
              onComplete: () {
                if (mounted) setState(() => _showStartup = false);
              },
            )
          : IndexedStack(
              index: _showHome ? 0 : 1,
              children: [
                KlipioHomeScreen(
                  key: ValueKey(_homeRefresh),
                  settings: _settings,
                  exportProgress: _editorKey.currentState?._exportProgressView,
                  onCancelExport: () => unawaited(
                    _editorKey.currentState?._confirmCancelExport() ??
                        Future<void>.value(),
                  ),
                  onShowExportDetails: () =>
                      _editorKey.currentState?._showExportProgressDialog(),
                  onSettingsChanged: _updateSettings,
                  onCreateProject: _createProject,
                  onOpenProject: _openProjectFromHome,
                  onRecentProjectsChanged: (paths) =>
                      _editorKey.currentState?._syncRecentProjectPaths(paths),
                  onProjectRenamed: (oldPath, newPath, name) =>
                      _editorKey.currentState?._syncExternalProjectName(
                    oldPath,
                    newPath,
                    name,
                  ),
                  onProjectDeleted: (path) async {
                    await _editorKey.currentState
                        ?._closeExternallyDeletedProject(path);
                  },
                ),
                if (_editorCreated)
                  EditorScreen(
                    key: _editorKey,
                    active: !_showHome,
                    checkExportAvailable:
                        widget.checkExportAvailable && !_showHome,
                    settings: _settings,
                    onSettingsChanged: _updateSettings,
                    onBackHome: _goHome,
                    onShowEditor: _showEditor,
                  )
                else
                  const SizedBox.shrink(),
              ],
            ),
    );
  }

  ThemeData _appTheme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    // A restrained indigo accent keeps selection, focus, and export actions
    // consistent across the editor instead of mixing purple and gray tints.
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xff6d28d9),
      brightness: brightness,
      surface: dark ? const Color(0xff0d0f14) : const Color(0xfff8f9fc),
    );
    final border = dark ? const Color(0xff232328) : const Color(0xffd1d5db);
    final field = dark ? const Color(0xff161618) : const Color(0xffe5e7eb);
    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor:
          dark ? const Color(0xff050505) : const Color(0xfff3f4f6),
      fontFamily: Platform.isWindows ? 'Segoe UI Variable' : null,
      fontFamilyFallback: const ['Inter', 'SF Pro Display', 'Segoe UI'],
      visualDensity: VisualDensity.compact,
      dividerColor: border,
      appBarTheme: AppBarTheme(
        backgroundColor: dark ? const Color(0xff0a0a0a) : Colors.white,
        foregroundColor:
            dark ? const Color(0xfff8fafc) : const Color(0xff0f172a),
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: dark ? const Color(0xfff8fafc) : const Color(0xff0f172a),
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardTheme(
        color: dark ? const Color(0xff121214) : Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: border, width: 0.8),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: field,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          minimumSize: const Size(0, 30),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          minimumSize: const Size(0, 28),
          side: BorderSide(color: border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          iconSize: 18,
          minimumSize: const Size(30, 30),
          padding: const EdgeInsets.all(5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: field,
        selectedColor: dark ? const Color(0xff164e63) : const Color(0xffcceff2),
        disabledColor: dark ? const Color(0xff202023) : const Color(0xffe5e9ef),
        side: BorderSide(color: border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        labelPadding: const EdgeInsets.symmetric(horizontal: 3),
        labelStyle: TextStyle(
          color: dark ? const Color(0xffe4e4e7) : const Color(0xff1f2937),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        secondaryLabelStyle: TextStyle(
          color: dark ? const Color(0xffecfeff) : const Color(0xff075985),
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
      sliderTheme: SliderThemeData(
        trackHeight: 2,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 13),
        inactiveTrackColor:
            dark ? const Color(0xff3f3f46) : const Color(0xffd4d4d8),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: dark ? const Color(0xff242428) : Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(color: border),
        ),
        textStyle: TextStyle(
          fontSize: 12,
          color: dark ? const Color(0xffe4e4e7) : const Color(0xff27272a),
        ),
      ),
      textTheme: ThemeData(brightness: brightness).textTheme.apply(
            bodyColor: dark ? const Color(0xffe4e4e7) : const Color(0xff17202e),
            displayColor:
                dark ? const Color(0xfffafafa) : const Color(0xff0f172a),
          ),
      tabBarTheme: TabBarTheme(
        dividerColor: Colors.transparent,
        labelColor: scheme.primary,
        unselectedLabelColor:
            dark ? const Color(0xff9ca3af) : const Color(0xff64748b),
        indicatorColor: scheme.primary,
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(
          dark ? const Color(0xff4b5563) : const Color(0xffaab4c4),
        ),
        radius: const Radius.circular(3),
        thickness: WidgetStateProperty.all(4),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: dark ? const Color(0xff101218) : Colors.white,
        indicatorColor: scheme.primaryContainer,
      ),
      useMaterial3: true,
    );
  }
}

class KlipioStartupSplash extends StatefulWidget {
  const KlipioStartupSplash({super.key, required this.onComplete});

  final VoidCallback onComplete;

  @override
  State<KlipioStartupSplash> createState() => _KlipioStartupSplashState();
}

class _KlipioStartupSplashState extends State<KlipioStartupSplash> {
  VideoPlayerController? _controller;
  Timer? _fallbackTimer;
  bool _ready = false;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _fallbackTimer = Timer(const Duration(seconds: 12), _finish);
    unawaited(_openStartupVideo());
  }

  Future<void> _openStartupVideo() async {
    final phone = Platform.isAndroid || Platform.isIOS;
    final controller = VideoPlayerController.asset(
      phone
          ? 'assets/branding/OpenAppForPhone.mp4'
          : 'assets/branding/OpenAppForPC.mp4',
    );
    _controller = controller;
    try {
      await controller.initialize();
      await controller.setLooping(false);
      await controller.setVolume(0);
      controller.addListener(_watchPlayback);
      if (!mounted || _completed) return;
      setState(() => _ready = true);
      await controller.play();
    } catch (_) {
      _fallbackTimer?.cancel();
      _fallbackTimer = Timer(const Duration(seconds: 8), _finish);
    }
  }

  void _watchPlayback() {
    final value = _controller?.value;
    if (value == null ||
        !value.isInitialized ||
        value.duration == Duration.zero) {
      return;
    }
    if (value.position >= value.duration - const Duration(milliseconds: 120)) {
      _finish();
    }
  }

  void _finish() {
    if (_completed) return;
    _completed = true;
    _fallbackTimer?.cancel();
    widget.onComplete();
  }

  @override
  void dispose() {
    _fallbackTimer?.cancel();
    _controller?.removeListener(_watchPlayback);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_ready && controller != null)
            FittedBox(
              fit: BoxFit.cover,
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                width: controller.value.size.width,
                height: controller.value.size.height,
                child: VideoPlayer(controller),
              ),
            )
          else
            Center(
              child: Image.asset(
                'assets/branding/Loading.gif',
                width: math.min(
                    MediaQuery.sizeOf(context).shortestSide * 0.62, 400),
                fit: BoxFit.contain,
              ),
            ),
          Positioned(
            right: 18,
            top: MediaQuery.paddingOf(context).top + 12,
            child: TextButton(
              onPressed: _finish,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xff0b4f82),
                backgroundColor: Colors.white.withOpacity(0.78),
              ),
              child: const KText('Skip'),
            ),
          ),
        ],
      ),
    );
  }
}
