part of '../editor_application.dart';

// media operations owned by the editor state; extracted without changing timing.
extension _MediaMediaLibraryPanel on _EditorScreenState {
  Widget _mediaLibraryPanel() {
    final compositionVideos = _compositionVideos;
    return _mediaFileDropTarget(
      child: Card(
        elevation: 0,
        color: _panelColor,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 7, 8, 6),
              child: Row(
                children: [
                  const Expanded(
                    child: KText(
                      'Imported Videos',
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                  ),
                  KText('${compositionVideos.length}',
                      style: TextStyle(color: _mutedTextColor)),
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: 'Add video clips',
                    visualDensity: VisualDensity.compact,
                    onPressed: _importingDroppedMedia ? null : _pickVideos,
                    icon: const Icon(Icons.add_circle_outline, size: 20),
                  ),
                  IconButton(
                    tooltip: 'Add a video folder',
                    visualDensity: VisualDensity.compact,
                    onPressed: _importingDroppedMedia ? null : _pickVideoFolder,
                    icon:
                        const Icon(Icons.create_new_folder_outlined, size: 20),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: _panelBorderColor),
            Expanded(
              child: compositionVideos.isEmpty
                  ? Center(
                      child: InkWell(
                        onTap: _pickVideos,
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(22),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_importingDroppedMedia)
                                const CircularProgressIndicator()
                              else
                                const Icon(Icons.add_to_photos_outlined,
                                    size: 42),
                              const SizedBox(height: 12),
                              const KText('Add clips',
                                  style:
                                      TextStyle(fontWeight: FontWeight.w900)),
                              const SizedBox(height: 5),
                              KText(
                                'Click here or drop video files / folders',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: _mutedTextColor),
                              ),
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed: _pickVideoFolder,
                                icon: const Icon(Icons.folder_open_outlined),
                                label: const KText('Add folder'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(10),
                      itemCount: compositionVideos.length,
                      itemBuilder: (context, index) {
                        final video = compositionVideos[index];
                        final selected = video.path == _selectedCompositionPath;
                        final videoIndex = _videos.indexWhere(
                          (item) => item.path == video.path,
                        );
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () =>
                                unawaited(_selectComposition(video.path)),
                            child: Container(
                              decoration: BoxDecoration(
                                color: selected
                                    ? const Color(0xff1f6bff).withOpacity(0.22)
                                    : _controlSurfaceColor,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: selected
                                      ? const Color(0xff1f6bff)
                                      : _panelBorderColor,
                                ),
                              ),
                              padding: const EdgeInsets.all(8),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: SizedBox(
                                      width: 88,
                                      height: 52,
                                      child: video.thumbnailPath == null
                                          ? const ColoredBox(
                                              color: Color(0xff0f172a),
                                              child: Icon(Icons.movie_outlined),
                                            )
                                          : Image.file(
                                              File(video.thumbnailPath!),
                                              fit: BoxFit.cover,
                                            ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        KText(
                                          video.name,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        KText(
                                          _formatDuration(
                                              video.durationSeconds),
                                          style: TextStyle(
                                            color: _mutedTextColor,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    tooltip: 'Remove from imports',
                                    onPressed: videoIndex < 0
                                        ? null
                                        : () => unawaited(
                                              _removeImportedVideo(videoIndex),
                                            ),
                                    icon: const Icon(
                                      Icons.close,
                                      size: 18,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _importedVideosList() {
    final compositionVideos = _compositionVideos;
    return _mediaFileDropTarget(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                const Expanded(
                  child: KText(
                    'Imported Videos',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ),
                KText('${compositionVideos.length}',
                    style: TextStyle(color: _mutedTextColor)),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: 'Add video clips',
                  visualDensity: VisualDensity.compact,
                  onPressed: _importingDroppedMedia ? null : _pickVideos,
                  icon: const Icon(Icons.add_circle_outline, size: 20),
                ),
                IconButton(
                  tooltip: 'Add a video folder',
                  visualDensity: VisualDensity.compact,
                  onPressed: _importingDroppedMedia ? null : _pickVideoFolder,
                  icon: const Icon(Icons.create_new_folder_outlined, size: 20),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: _panelBorderColor),
          Expanded(
            child: compositionVideos.isEmpty
                ? Center(
                    child: InkWell(
                      onTap: _pickVideos,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(22),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_importingDroppedMedia)
                              const CircularProgressIndicator()
                            else
                              const Icon(Icons.add_to_photos_outlined,
                                  size: 42),
                            const SizedBox(height: 12),
                            const KText('Add clips',
                                style: TextStyle(fontWeight: FontWeight.w900)),
                            const SizedBox(height: 5),
                            KText(
                              'Click here or drop video files / folders',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: _mutedTextColor),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: _pickVideoFolder,
                              icon: const Icon(Icons.folder_open_outlined),
                              label: const KText('Add folder'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                : Scrollbar(
                    controller: _importScrollController,
                    thumbVisibility: true,
                    child: ListView.builder(
                      controller: _importScrollController,
                      padding: const EdgeInsets.all(10),
                      itemCount: compositionVideos.length,
                      itemBuilder: (context, index) {
                        final video = compositionVideos[index];
                        final selected = video.path == _selectedCompositionPath;
                        final videoIndex = _videos.indexWhere(
                          (item) => item.path == video.path,
                        );
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () =>
                                unawaited(_selectComposition(video.path)),
                            child: Container(
                              decoration: BoxDecoration(
                                color: selected
                                    ? const Color(0xff1f6bff).withOpacity(0.22)
                                    : _controlSurfaceColor,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: selected
                                      ? const Color(0xff1f6bff)
                                      : _panelBorderColor,
                                ),
                              ),
                              padding: const EdgeInsets.all(8),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: SizedBox(
                                      width: 88,
                                      height: 52,
                                      child: video.thumbnailPath == null
                                          ? const ColoredBox(
                                              color: Color(0xff0f172a),
                                              child: Icon(Icons.movie_outlined),
                                            )
                                          : Image.file(
                                              File(video.thumbnailPath!),
                                              fit: BoxFit.cover,
                                            ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        KText(
                                          video.name,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        KText(
                                          _formatDuration(
                                              video.durationSeconds),
                                          style: TextStyle(
                                            color: _mutedTextColor,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    tooltip: 'Remove from imports',
                                    onPressed: videoIndex < 0
                                        ? null
                                        : () => unawaited(
                                              _removeImportedVideo(videoIndex),
                                            ),
                                    icon: const Icon(
                                      Icons.close,
                                      size: 18,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _hookVideoButton() {
    final selectedVideo = _videos.isEmpty
        ? null
        : _videos[_selectedVideoIndex.clamp(0, _videos.length - 1)];
    final duration = selectedVideo?.durationSeconds ?? 0;
    final autoText = duration > 0
        ? 'Auto = ${_formatDuration(_autoHookEditSeconds(duration))}'
        : 'Auto length depends on selected video';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<_HookEditMode>(
          segments: const [
            ButtonSegment(
              value: _HookEditMode.hookWithVideo,
              icon: Icon(Icons.movie_filter_outlined, size: 18),
              label: KText('Hook + video'),
            ),
            ButtonSegment(
              value: _HookEditMode.bestMoments,
              icon: Icon(Icons.auto_awesome_outlined, size: 18),
              label: KText('Best moments'),
            ),
          ],
          selected: {_hookEditMode},
          onSelectionChanged: (selection) {
            _updateEditor(() => _hookEditMode = selection.first);
          },
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _hookDurationController,
          keyboardType: TextInputType.text,
          decoration: InputDecoration(
            labelText: 'Hook edit length',
            hintText: 'auto, 5m, 12m, 1:30',
            helperText: autoText,
            prefixIcon: const Icon(Icons.timer_outlined),
          ),
          onChanged: (_) => _updateEditor(() {}),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _videos.isEmpty
                    ? null
                    : () => unawaited(_applyHookVideoEdit()),
                icon: const Icon(Icons.flash_on_outlined),
                label: const KText('Hook selected'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.icon(
                onPressed: _videos.isEmpty
                    ? null
                    : () => unawaited(_chooseHookVideoTargets()),
                icon: const Icon(Icons.done_all_outlined),
                label: const KText('Hook videos...'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        KText(
          _hookEditMode == _HookEditMode.hookWithVideo
              ? 'Hook first, then keep the main video order for each video.'
              : 'Hook first, then strongest moments for each video.',
          style: TextStyle(color: _mutedTextColor, fontSize: 12),
        ),
      ],
    );
  }

  Widget _liveSourceVideo(VideoPlayerController controller) {
    final size = controller.value.size;
    final videoWidth = size.width <= 0 ? 16.0 : size.width;
    final videoHeight = size.height <= 0 ? 9.0 : size.height;
    return SizedBox.expand(
      child: Center(
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: videoWidth,
            height: videoHeight,
            child: VideoPlayer(controller),
          ),
        ),
      ),
    );
  }
}
