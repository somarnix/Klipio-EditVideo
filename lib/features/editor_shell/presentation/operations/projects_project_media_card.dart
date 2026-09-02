part of '../editor_application.dart';

// projects operations owned by the editor state; extracted without changing timing.
extension _ProjectsProjectMediaCard on _EditorScreenState {
  Widget _projectMediaThumbnail(PickedVideo video) {
    const fallback = ColoredBox(
      color: Color(0xff0f172a),
      child: Center(child: Icon(Icons.movie_outlined, color: Colors.white70)),
    );
    return video.thumbnailPath == null
        ? fallback
        : Image.file(
            File(video.thumbnailPath!),
            fit: BoxFit.cover,
            cacheWidth: 320,
            errorBuilder: (context, error, stack) => const Tooltip(
              message:
                  'Thumbnail unavailable. The source can still be selected.',
              child: fallback,
            ),
          );
  }

  Widget _projectMediaListItem(PickedVideo video) {
    final index = _videos.indexWhere((item) => item.path == video.path);
    final instances = _multiTrackTimeline.videoTracks
        .expand((track) => track.clips)
        .where((clip) => clip.mediaPath == video.path)
        .length;
    return ListTile(
      key: ValueKey('asset-list-${video.path}'),
      dense: true,
      selected: index >= 0 && index == _selectedVideoIndex,
      leading: SizedBox(
          width: 52,
          height: 36,
          child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: _projectMediaThumbnail(video))),
      title: Text(video.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
          'Video • ${_formatDuration(video.durationSeconds)} • $instances timeline instances',
          maxLines: 2,
          overflow: TextOverflow.ellipsis),
      onTap: index < 0
          ? null
          : () => unawaited(_selectVideo(index, saveCurrentEdit: false)),
      trailing: IconButton(
          tooltip: 'Add to end of timeline',
          onPressed: index < 0
              ? null
              : () => unawaited(_addImportedVideoToTimeline(index)),
          icon: const Icon(Icons.add_circle_outline, size: 20)),
    );
  }

  Widget _projectMediaCard(PickedVideo video) {
    final videoIndex = _videos.indexWhere((item) => item.path == video.path);
    final added = _multiTrackTimeline.videoTracks.any(
      (track) => track.clips.any((clip) => clip.mediaPath == video.path),
    );
    final card = InkWell(
      borderRadius: BorderRadius.circular(7),
      onTap: videoIndex < 0
          ? null
          : () => unawaited(
                _selectVideo(videoIndex, saveCurrentEdit: false),
              ),
      onDoubleTap: videoIndex < 0
          ? null
          : () async {
              await _selectVideo(videoIndex, saveCurrentEdit: false);
              await _addImportedVideoToTimeline(videoIndex);
            },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _projectMediaThumbnail(video),
                  Positioned(
                    left: 4,
                    top: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: added
                            ? const Color(0xdd0f766e)
                            : const Color(0xaa111827),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: KText(
                        added ? 'Added' : 'Not added',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 3,
                    bottom: 3,
                    child: KText(
                      _formatDuration(video.durationSeconds),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        shadows: [Shadow(blurRadius: 3)],
                      ),
                    ),
                  ),
                  Positioned(
                    right: 2,
                    top: 1,
                    child: IconButton(
                      tooltip: 'Add to end of timeline',
                      visualDensity: VisualDensity.compact,
                      onPressed: videoIndex < 0
                          ? null
                          : () => unawaited(
                                _addImportedVideoToTimeline(videoIndex),
                              ),
                      icon: const Icon(
                        Icons.add_circle,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          KText(
            video.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10),
          ),
        ],
      ),
    );
    if (videoIndex < 0) return card;
    final dragData = TimelineMediaDragData(
      mediaPath: video.path,
      duration: math.max(0.001, video.durationSeconds ?? 0.001).toDouble(),
    );
    return Draggable<TimelineMediaDragData>(
      data: dragData,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          width: 150,
          height: 72,
          decoration: BoxDecoration(
            color: const Color(0xee0f766e),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xff22d3ee), width: 2),
          ),
          alignment: Alignment.center,
          child: KText(
            video.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 11),
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: card),
      child: card,
    );
  }

  Future<void> _showProjectDetailsDialog() async {
    var colorSpace = _projectColorSpace;
    var resolution = _projectResolution;
    var ratio = _outputRatio;
    var copyMedia = _projectCopyMedia;
    var arrangeLayers = _projectArrangeLayers;
    var frameRate = _projectFrameRate;
    var proxyEnabled = _projectProxyEnabled;
    var proxyResolution = _projectProxyResolution;
    final draftsRoot = await _klipioDraftsRoot();
    if (!mounted) return;
    final currentProjectDirectory =
        _currentProjectPath == null ? null : File(_currentProjectPath!).parent;
    final projectName = _nameController.text.trim().isEmpty
        ? (currentProjectDirectory == null
            ? 'Untitled Klipio Project'
            : platform.basename(currentProjectDirectory.path))
        : _nameController.text.trim();
    final savePath = currentProjectDirectory?.path ?? draftsRoot.path;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: _panelColor,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 650, maxHeight: 720),
            child: DefaultTabController(
              length: 2,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
                    child: Row(
                      children: [
                        const Expanded(
                          child: KText(
                            'Project Detail',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(dialogContext, false),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  const TabBar(
                    tabs: [Tab(text: 'Details'), Tab(text: 'Performance')],
                  ),
                  Flexible(
                    child: TabBarView(
                      children: [
                        SingleChildScrollView(
                          padding: const EdgeInsets.all(22),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _projectSettingReadout('Name', projectName),
                              _projectSettingReadout('Save to', savePath),
                              const SizedBox(height: 8),
                              const KText('Imported media'),
                              RadioListTile<bool>(
                                value: false,
                                groupValue: copyMedia,
                                title: const KText('Stay in original location'),
                                onChanged: (value) => setDialogState(
                                  () => copyMedia = value ?? false,
                                ),
                              ),
                              RadioListTile<bool>(
                                value: true,
                                groupValue: copyMedia,
                                title: const KText('Copy media to project'),
                                subtitle: const KText(
                                  'Applied when project media collection is enabled.',
                                ),
                                onChanged: (value) => setDialogState(
                                  () => copyMedia = value ?? true,
                                ),
                              ),
                              DropdownButtonFormField<String>(
                                value: colorSpace,
                                decoration: const InputDecoration(
                                    labelText: 'Color space'),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'Rec. 709 SDR',
                                    child: Text('Rec. 709 SDR'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Display P3',
                                    child: Text('Display P3'),
                                  ),
                                ],
                                onChanged: (value) => setDialogState(
                                  () => colorSpace = value ?? colorSpace,
                                ),
                              ),
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const KText('Arrange layers'),
                                value: arrangeLayers,
                                onChanged: (value) => setDialogState(
                                  () => arrangeLayers = value,
                                ),
                              ),
                              const Divider(height: 28),
                              DropdownButtonFormField<String>(
                                value: ratio,
                                decoration: const InputDecoration(
                                    labelText: 'Aspect ratio'),
                                items: [
                                  for (final value in const [
                                    'original',
                                    '16:9',
                                    '9:16',
                                    '4:5',
                                    '1:1',
                                    '3:4',
                                    '4:3',
                                  ])
                                    DropdownMenuItem(
                                      value: value,
                                      child: KText(value),
                                    ),
                                ],
                                onChanged: (value) => setDialogState(
                                  () => ratio = value ?? ratio,
                                ),
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                value: resolution,
                                decoration: const InputDecoration(
                                    labelText: 'Resolution'),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'Adapted',
                                    child: Text('Adapted'),
                                  ),
                                  DropdownMenuItem(
                                    value: '3840x2160',
                                    child: Text('3840 × 2160'),
                                  ),
                                  DropdownMenuItem(
                                    value: '1920x1080',
                                    child: Text('1920 × 1080'),
                                  ),
                                  DropdownMenuItem(
                                    value: '1280x720',
                                    child: Text('1280 × 720'),
                                  ),
                                ],
                                onChanged: (value) => setDialogState(
                                  () => resolution = value ?? resolution,
                                ),
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<double>(
                                value: frameRate,
                                decoration: const InputDecoration(
                                    labelText: 'Frame rate'),
                                items: [
                                  for (final value in const [
                                    24.0,
                                    25.0,
                                    30.0,
                                    50.0,
                                    60.0
                                  ])
                                    DropdownMenuItem(
                                      value: value,
                                      child: Text(
                                          '${value.toStringAsFixed(2)} fps'),
                                    ),
                                ],
                                onChanged: (value) => setDialogState(
                                  () => frameRate = value ?? frameRate,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(22),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const KText('Proxy preview'),
                                subtitle: const KText(
                                  'Reduces preview refresh and expensive live effects for smoother editing. Export stays full quality.',
                                ),
                                value: proxyEnabled,
                                onChanged: (value) => setDialogState(
                                  () => proxyEnabled = value,
                                ),
                              ),
                              if (proxyEnabled)
                                DropdownButtonFormField<String>(
                                  value: proxyResolution,
                                  decoration: const InputDecoration(
                                    labelText: 'Preview resolution',
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: '720p',
                                      child: Text('720p'),
                                    ),
                                    DropdownMenuItem(
                                      value: '540p',
                                      child: Text('540p (fastest)'),
                                    ),
                                  ],
                                  onChanged: (value) => setDialogState(
                                    () => proxyResolution =
                                        value ?? proxyResolution,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () =>
                                Navigator.pop(dialogContext, false),
                            child: const KText('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: () => Navigator.pop(dialogContext, true),
                            child: const KText('Save'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (saved != true || !mounted) return;
    _recordEditorHistory('project-detail');
    _updateEditor(() {
      _projectColorSpace = colorSpace;
      _projectResolution = resolution;
      _outputRatio = ratio;
      _projectCopyMedia = copyMedia;
      _projectArrangeLayers = arrangeLayers;
      _projectFrameRate = frameRate;
      _projectProxyEnabled = proxyEnabled;
      _projectProxyResolution = proxyResolution;
      _status = proxyEnabled
          ? 'Proxy preview enabled at $proxyResolution'
          : 'Project settings updated';
    });
    unawaited(_autosaveProject());
  }

  Widget _projectSettingReadout(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 115,
            child: KText(label, style: TextStyle(color: _mutedTextColor)),
          ),
          Expanded(child: KText(value)),
        ],
      ),
    );
  }

  Widget _recentProjectMenu() {
    return PopupMenuButton<String>(
      enabled: _recentProjectPaths.isNotEmpty,
      tooltip: 'Recent projects',
      onSelected: (path) => unawaited(_loadProject(path)),
      itemBuilder: (context) => [
        for (final path in _recentProjectPaths)
          PopupMenuItem(
            value: path,
            child: KText(
              platform.basename(path),
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      child: IgnorePointer(
        child: OutlinedButton.icon(
          onPressed: _recentProjectPaths.isEmpty ? null : () {},
          icon: const Icon(Icons.history),
          label: const KText('Recent'),
        ),
      ),
    );
  }

  Widget _recentFolderMenu() {
    return PopupMenuButton<String>(
      enabled: _recentFolders.isNotEmpty,
      tooltip: 'Recent video folders',
      onSelected: (folder) => unawaited(_openVideoFolderPath(folder)),
      itemBuilder: (context) => [
        for (final folder in _recentFolders)
          PopupMenuItem(
            value: folder,
            child: KText(folder, overflow: TextOverflow.ellipsis),
          ),
      ],
      child: IgnorePointer(
        child: OutlinedButton.icon(
          onPressed: _recentFolders.isEmpty ? null : () {},
          icon: const Icon(Icons.folder_special_outlined),
          label: KText(
            _recentFolders.isEmpty ? 'No recent folders' : 'Recent folders',
          ),
        ),
      ),
    );
  }
}
