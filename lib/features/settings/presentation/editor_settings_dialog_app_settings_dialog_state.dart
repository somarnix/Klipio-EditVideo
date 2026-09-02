part of '../../editor_shell/presentation/editor_application.dart';

class _AppSettingsDialogState extends State<_AppSettingsDialog> {
  late AppSettings _draft;
  late final Future<Directory> _draftsRootFuture;
  int _tab = 0;
  String _cacheSize = 'Calculating...';
  bool _clearingCache = false;

  @override
  void initState() {
    super.initState();
    _draft = widget.initial;
    _draftsRootFuture = _klipioDraftsRoot();
    unawaited(_loadCacheSize());
  }

  void _update(AppSettings value) => setState(() => _draft = value);

  Future<String> _defaultCachePath() async {
    final root = await getCacheDirectory();
    return '${root.path}${Platform.pathSeparator}KlipioCache';
  }

  Future<String> _effectiveCachePath() async =>
      _draft.cacheFolder.trim().isEmpty
          ? _defaultCachePath()
          : Future.value(_draft.cacheFolder.trim());

  Future<void> _loadCacheSize() async {
    try {
      final directory = Directory(await _effectiveCachePath());
      if (!await directory.exists()) {
        if (mounted) setState(() => _cacheSize = '0 B');
        return;
      }
      var bytes = 0;
      await for (final entry in directory.list(recursive: true)) {
        if (entry is File) bytes += await entry.length();
      }
      if (!mounted) return;
      setState(() => _cacheSize = _formatBytes(bytes));
    } catch (_) {
      if (mounted) setState(() => _cacheSize = 'Unavailable');
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  Future<void> _pickFolder(String current, ValueChanged<String> save) async {
    final selected = await FilePicker.platform.getDirectoryPath(
      initialDirectory: current.trim().isEmpty ? null : current,
    );
    if (selected != null) save(selected);
  }

  Future<void> _openDraftsRoot() async {
    final root = await _draftsRootFuture;
    await root.create(recursive: true);
    if (Platform.isWindows) {
      await Process.start('explorer.exe', [root.path]);
    } else if (Platform.isMacOS) {
      await Process.start('open', [root.path]);
    } else {
      await Process.start('xdg-open', [root.path]);
    }
  }

  Widget _managedProjectFolderRow() => FutureBuilder<Directory>(
        future: _draftsRootFuture,
        builder: (context, snapshot) => ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.folder_special_outlined),
          title: const KText(
            'Save projects to',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: KText(
            snapshot.data?.path ?? r'C:\Users\<user>\Klipio Drafts',
          ),
          trailing: IconButton(
            tooltip: 'Open Klipio Drafts',
            onPressed: () => unawaited(_openDraftsRoot()),
            icon: const Icon(Icons.open_in_new),
          ),
        ),
      );

  Future<void> _clearAppCache() async {
    final path = await _effectiveCachePath();
    final normalized = path.toLowerCase().replaceAll('\\', '/');
    if (!normalized.contains('klipio') || !normalized.contains('cache')) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: KText(
            'For safety, only a Klipio cache folder can be cleared here.',
          ),
        ),
      );
      return;
    }
    setState(() => _clearingCache = true);
    try {
      final directory = Directory(path);
      if (await directory.exists()) await directory.delete(recursive: true);
      await directory.create(recursive: true);
      if (mounted) setState(() => _cacheSize = '0 B');
    } finally {
      if (mounted) setState(() => _clearingCache = false);
    }
  }

  Widget _section(String title, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          KText(title,
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _switchRow({
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    IconData? icon,
  }) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      value: value,
      onChanged: onChanged,
      secondary: icon == null ? null : Icon(icon, size: 21),
      title: KText(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: subtitle == null ? null : KText(subtitle),
    );
  }

  Widget _folderRow({
    required String title,
    required String value,
    required String fallback,
    required ValueChanged<String> onChanged,
  }) {
    final phone = MediaQuery.sizeOf(context).shortestSide <= 600;
    final field = Row(
      children: [
        Expanded(
          child: Container(
            height: 44,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: KText(
              value.trim().isEmpty ? fallback : value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: value.trim().isEmpty
                    ? Theme.of(context).colorScheme.onSurfaceVariant
                    : null,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          tooltip: 'Choose folder',
          onPressed: () => _pickFolder(value, onChanged),
          icon: const Icon(Icons.folder_open_outlined),
        ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: phone
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                KText(title),
                const SizedBox(height: 7),
                field,
              ],
            )
          : Row(children: [
              SizedBox(width: 155, child: KText(title)),
              Expanded(child: field)
            ]),
    );
  }

  Widget _selectRow<T>({
    required String title,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T> onChanged,
    String? helper,
  }) {
    final phone = MediaQuery.sizeOf(context).shortestSide <= 600;
    final field = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<T>(
          value: value,
          isExpanded: true,
          items: items,
          onChanged: (next) {
            if (next != null) onChanged(next);
          },
        ),
        if (helper != null) ...[
          const SizedBox(height: 5),
          KText(helper, style: Theme.of(context).textTheme.bodySmall),
        ],
      ],
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: phone
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [KText(title), const SizedBox(height: 7), field],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                    width: 155,
                    child: Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: KText(title))),
                Expanded(child: field),
              ],
            ),
    );
  }

  Widget _draftTab() => Column(
        children: [
          _section('Files and projects', [
            _managedProjectFolderRow(),
            _folderRow(
              title: 'Export videos to',
              value: _draft.defaultExportFolder,
              fallback: 'Documents / Klipio Exports',
              onChanged: (v) =>
                  _update(_draft.copyWith(defaultExportFolder: v)),
            ),
            _folderRow(
              title: 'Cache',
              value: _draft.cacheFolder,
              fallback: 'Temporary / KlipioCache',
              onChanged: (v) {
                _update(_draft.copyWith(cacheFolder: v));
                unawaited(_loadCacheSize());
              },
            ),
          ]),
          _section('Cache management', [
            _switchRow(
              title: 'Automatically delete old cache',
              subtitle: 'Keeps project and source files; removes cache only.',
              value: _draft.autoDeleteCache,
              onChanged: (v) => _update(_draft.copyWith(autoDeleteCache: v)),
              icon: Icons.auto_delete_outlined,
            ),
            if (_draft.autoDeleteCache)
              _selectRow<int>(
                title: 'Delete after',
                value: _draft.cacheRetentionDays,
                items: const [7, 14, 30, 60, 90]
                    .map((v) =>
                        DropdownMenuItem(value: v, child: KText('$v days')))
                    .toList(),
                onChanged: (v) =>
                    _update(_draft.copyWith(cacheRetentionDays: v)),
              ),
            Builder(builder: (context) {
              final phone = MediaQuery.sizeOf(context).shortestSide <= 600;
              final clearButton = OutlinedButton.icon(
                onPressed: _clearingCache ? null : _clearAppCache,
                icon: _clearingCache
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.delete_outline, size: 18),
                label: const KText('Clear app cache'),
              );
              if (phone) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      const Expanded(child: KText('Cache size')),
                      KText(_cacheSize,
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                    ]),
                    const SizedBox(height: 10),
                    clearButton,
                  ],
                );
              }
              return Row(children: [
                const SizedBox(width: 155, child: KText('Cache size')),
                KText(_cacheSize,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                const Spacer(),
                clearButton,
              ]);
            }),
          ]),
        ],
      );

  Widget _editTab() => Column(
        children: [
          _section('Timeline defaults', [
            _selectRow<double>(
              title: 'Image duration',
              value: _draft.defaultImageDuration,
              items: const [2.0, 3.0, 5.0, 8.0, 10.0]
                  .map((v) => DropdownMenuItem(
                      value: v,
                      child: KText('${v.toStringAsFixed(0)} seconds')))
                  .toList(),
              onChanged: (v) =>
                  _update(_draft.copyWith(defaultImageDuration: v)),
            ),
            _selectRow<double>(
              title: 'Frame rate',
              value: _draft.defaultFrameRate,
              items: const [23.976, 24.0, 25.0, 29.97, 30.0, 50.0, 60.0]
                  .map((v) => DropdownMenuItem(
                      value: v,
                      child: KText(
                          '${v.toStringAsFixed(v % 1 == 0 ? 0 : 3)} fps')))
                  .toList(),
              onChanged: (v) => _update(_draft.copyWith(defaultFrameRate: v)),
            ),
            _selectRow<String>(
              title: 'Time code',
              value: _draft.timecodeFormat,
              items: const ['HH:MM:SS+frame', 'HH:MM:SS:ms', 'Frames']
                  .map((v) => DropdownMenuItem(value: v, child: KText(v)))
                  .toList(),
              onChanged: (v) => _update(_draft.copyWith(timecodeFormat: v)),
            ),
          ]),
          _section('Editing behavior', [
            _switchRow(
              title: 'Play audio while scrubbing',
              subtitle: 'Hear audio while dragging the playhead.',
              value: _draft.playAudioWhileScrubbing,
              onChanged: (v) =>
                  _update(_draft.copyWith(playAudioWhileScrubbing: v)),
              icon: Icons.graphic_eq,
            ),
            _switchRow(
              title: 'Arrange layers in new projects',
              subtitle: 'Allow track layers to be reordered.',
              value: _draft.arrangeLayers,
              onChanged: (v) => _update(_draft.copyWith(arrangeLayers: v)),
              icon: Icons.layers_outlined,
            ),
            _switchRow(
              title: 'Auto-play next clip',
              value: _draft.autoAdvanceTimeline,
              onChanged: (v) =>
                  _update(_draft.copyWith(autoAdvanceTimeline: v)),
              icon: Icons.skip_next,
            ),
            _switchRow(
              title: 'Sound when export completes',
              value: _draft.exportCompleteSound,
              onChanged: (v) =>
                  _update(_draft.copyWith(exportCompleteSound: v)),
              icon: Icons.notifications_active_outlined,
            ),
          ]),
        ],
      );

  Widget _performanceTab() => Column(
        children: [
          _section('Encode and decode', [
            _switchRow(
              title: 'Speed up hardware encoding',
              subtitle: 'Use NVENC when an NVIDIA encoder is available.',
              value: _draft.hardwareEncoding,
              onChanged: (v) => _update(_draft.copyWith(hardwareEncoding: v)),
              icon: Icons.memory,
            ),
            _switchRow(
              title: 'Speed up hardware decoding',
              subtitle:
                  'Use GPU decoding when supported by the media pipeline.',
              value: _draft.hardwareDecoding,
              onChanged: (v) => _update(_draft.copyWith(hardwareDecoding: v)),
              icon: Icons.speed,
            ),
            _switchRow(
              title: 'Render interface with GPU',
              subtitle: 'Requires restarting the app after changing.',
              value: _draft.gpuInterface,
              onChanged: (v) => _update(_draft.copyWith(gpuInterface: v)),
              icon: Icons.developer_board_outlined,
            ),
          ]),
          _section('Preview and optimization', [
            _selectRow<String>(
              title: 'Auto optimization',
              value: _draft.autoOptimization,
              items: const {
                'smart': 'Smart optimization',
                'quality': 'Prefer quality',
                'speed': 'Prefer speed',
                'off': 'Off',
              }
                  .entries
                  .map((e) =>
                      DropdownMenuItem(value: e.key, child: KText(e.value)))
                  .toList(),
              onChanged: (v) => _update(_draft.copyWith(autoOptimization: v)),
            ),
            _selectRow<PreviewQuality>(
              title: 'Preview quality',
              value: _draft.previewQuality,
              items: const {
                PreviewQuality.full: 'Full resolution',
                PreviewQuality.half: 'Half resolution',
                PreviewQuality.low: 'Performance mode',
              }
                  .entries
                  .map((e) =>
                      DropdownMenuItem(value: e.key, child: KText(e.value)))
                  .toList(),
              onChanged: (v) => _update(_draft.copyWith(previewQuality: v)),
            ),
            _switchRow(
              title: 'Smooth preview refresh',
              value: _draft.smoothPreview,
              onChanged: (v) => _update(_draft.copyWith(smoothPreview: v)),
            ),
            _switchRow(
              title: 'Compact workspace',
              value: _draft.compactWorkspace,
              onChanged: (v) => _update(_draft.copyWith(compactWorkspace: v)),
            ),
          ]),
          _section('Proxy and render cache', [
            _selectRow<ProxyMode>(
              title: 'Editing proxies',
              value: _draft.proxyMode,
              items: const [
                DropdownMenuItem(
                    value: ProxyMode.off, child: KText('Off — original media')),
                DropdownMenuItem(
                    value: ProxyMode.auto,
                    child: KText('Auto — demanding active media')),
                DropdownMenuItem(
                    value: ProxyMode.always,
                    child: KText('On — prepare editing proxies')),
              ],
              onChanged: (v) => _update(_draft.copyWith(proxyMode: v)),
            ),
            _folderRow(
              title: 'Save proxies to',
              value: _draft.proxyFolder,
              fallback: 'Cache / proxies',
              onChanged: (v) => _update(_draft.copyWith(proxyFolder: v)),
            ),
            _folderRow(
              title: 'Render cache',
              value: _draft.renderCacheFolder,
              fallback: 'Cache / render',
              onChanged: (v) => _update(_draft.copyWith(renderCacheFolder: v)),
            ),
          ]),
        ],
      );

  Widget _futureCard(IconData icon, String title, String description) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: CircleAvatar(child: Icon(icon, size: 20)),
      title: Row(
        children: [
          Expanded(
              child: KText(title,
                  style: const TextStyle(fontWeight: FontWeight.w800))),
          const Chip(
              label: KText('Coming soon'),
              visualDensity: VisualDensity.compact),
        ],
      ),
      subtitle: KText(description),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: KText('$title is planned for a future release.')),
      ),
    );
  }

  Widget _generalTab() => Column(
        children: [
          _section('Appearance and language', [
            _selectRow<String>(
              title: 'Language',
              value: _draft.language,
              items: KlipioLanguages.all
                  .map((language) => DropdownMenuItem(
                      value: language.id, child: KText(language.label)))
                  .toList(),
              onChanged: (v) => _update(_draft.copyWith(language: v)),
              helper: 'The interface changes after you save settings.',
            ),
            const SizedBox(height: 6),
            Builder(builder: (context) {
              final phone = MediaQuery.sizeOf(context).shortestSide <= 600;
              final selector = SegmentedButton<AppThemeChoice>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                      value: AppThemeChoice.system,
                      label: KText('System'),
                      icon: Icon(Icons.computer, size: 17)),
                  ButtonSegment(
                      value: AppThemeChoice.light,
                      label: KText('Light'),
                      icon: Icon(Icons.light_mode_outlined, size: 17)),
                  ButtonSegment(
                      value: AppThemeChoice.dark,
                      label: KText('Dark'),
                      icon: Icon(Icons.dark_mode_outlined, size: 17)),
                ],
                selected: {_draft.themeChoice},
                onSelectionChanged: (v) =>
                    _update(_draft.copyWith(themeChoice: v.first)),
              );
              return phone
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const KText('Theme'),
                        const SizedBox(height: 8),
                        FittedBox(fit: BoxFit.scaleDown, child: selector),
                      ],
                    )
                  : Row(children: [
                      const SizedBox(width: 155, child: KText('Theme')),
                      Expanded(child: selector),
                    ]);
            }),
          ]),
          _section('Notifications and updates', [
            _switchRow(
              title: 'Allow desktop notifications',
              value: _draft.notifications,
              onChanged: (v) => _update(_draft.copyWith(notifications: v)),
              icon: Icons.notifications_outlined,
            ),
            _selectRow<String>(
              title: 'Software updates',
              value: _draft.updateMode,
              items: const {
                'automatic': 'Install automatically',
                'notify': 'Notify before installing',
                'manual': 'Check manually',
              }
                  .entries
                  .map((e) =>
                      DropdownMenuItem(value: e.key, child: KText(e.value)))
                  .toList(),
              onChanged: (v) => _update(_draft.copyWith(updateMode: v)),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonalIcon(
                onPressed: () => showKlipioUpdateDialog(context),
                icon: const Icon(Icons.system_update_alt, size: 19),
                label: const KText('Check for updates'),
              ),
            ),
          ]),
          _section('AI Control', [
            ListTile(
              leading: const Icon(Icons.smart_toy_outlined),
              title: const Text('Enable MCP AI Control'),
              subtitle: Text(
                _draft.mcpEnabled
                    ? 'MCP bridge will run on localhost:${_draft.mcpPort} after saving.'
                    : 'Connect an MCP-compatible assistant to control Klipio.',
              ),
              trailing: Switch(
                value: _draft.mcpEnabled,
                onChanged: (value) =>
                    _update(_draft.copyWith(mcpEnabled: value)),
              ),
              onTap: () =>
                  _update(_draft.copyWith(mcpEnabled: !_draft.mcpEnabled)),
            ),
            _selectRow<int>(
              title: 'MCP port',
              value: _draft.mcpPort,
              items: const [8765, 8766, 9000, 3000]
                  .map((port) => DropdownMenuItem(
                        value: port,
                        child: KText('$port (localhost)'),
                      ))
                  .toList(),
              onChanged: (port) => _update(_draft.copyWith(mcpPort: port)),
              helper: 'The assistant connects to ws://127.0.0.1:<port>.',
            ),
          ]),
          _section('Account and future services', [
            _futureCard(Icons.workspace_premium_outlined, 'Klipio Pro',
                'Premium templates, cloud storage, and advanced export profiles.'),
            const Divider(),
            _futureCard(Icons.auto_awesome_outlined, 'AI Studio',
                'Cloud AI tools for captions, reframing, cleanup, and short creation.'),
            const Divider(),
            _futureCard(Icons.credit_card_outlined, 'Billing',
                'Plans, invoices, payment methods, and redeem codes.'),
            const Divider(),
            _futureCard(Icons.cloud_outlined, 'Manage spaces',
                'Team workspaces, cloud sync, and shared projects.'),
          ]),
        ],
      );

  @override
  Widget build(BuildContext context) {
    const labels = ['Draft', 'Edit', 'Performance', 'General'];
    final tabs = [_draftTab(), _editTab(), _performanceTab(), _generalTab()];
    final size = MediaQuery.sizeOf(context);
    final phone = size.shortestSide <= 600;
    return Dialog(
      insetPadding: phone ? EdgeInsets.zero : const EdgeInsets.all(24),
      child: SizedBox(
        width: phone ? double.infinity : 760,
        height: phone ? size.height : math.min(size.height - 48, 720),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 16, 10, 12),
              child: Row(
                children: [
                  const Icon(Icons.settings_outlined),
                  const SizedBox(width: 10),
                  const Expanded(
                      child: KText('Settings',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w900))),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding:
                  EdgeInsets.fromLTRB(phone ? 12 : 18, 12, phone ? 12 : 18, 10),
              child: SizedBox(
                height: 42,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: labels.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (context, index) => SizedBox(
                    width: phone ? 116 : (706 / labels.length),
                    child: FilledButton.tonal(
                      style: FilledButton.styleFrom(
                        backgroundColor: _tab == index
                            ? Theme.of(context).colorScheme.primaryContainer
                            : Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                      ),
                      onPressed: () => setState(() => _tab = index),
                      child: KText(labels[index]),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Scrollbar(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                      phone ? 10 : 18, 0, phone ? 10 : 18, 12),
                  child: tabs[_tab],
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(_draft),
                      child: const KText('Save settings'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const KText('Cancel'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
