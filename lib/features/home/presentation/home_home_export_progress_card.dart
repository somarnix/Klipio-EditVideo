part of '../../editor_shell/presentation/editor_application.dart';

extension _HomeHomeExportProgressCard on _KlipioHomeScreenState {
  Widget _homeExportProgressCard(
    ValueListenable<KlipioExportProgressView> progressListenable,
  ) {
    return ValueListenableBuilder<KlipioExportProgressView>(
      valueListenable: progressListenable,
      builder: (context, view, _) {
        final details = view.details;
        final status = view.status.toLowerCase();
        final visible = details != null &&
            view.progress < 1 &&
            !status.contains('cancel') &&
            !status.contains('failed');
        if (!visible) return const SizedBox.shrink();
        final progress = view.progress.clamp(0.0, 1.0).toDouble();
        final thumbnail = details.thumbnailPath;
        return Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: 230,
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: widget.onShowExportDetails,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(7),
                            child: SizedBox(
                              width: double.infinity,
                              height: 126,
                              child: thumbnail != null &&
                                      File(thumbnail).existsSync()
                                  ? Image.file(
                                      File(thumbnail),
                                      fit: BoxFit.cover,
                                    )
                                  : const ColoredBox(
                                      color: Colors.black,
                                      child: Icon(
                                        Icons.movie_creation_outlined,
                                        color: Colors.white70,
                                        size: 38,
                                      ),
                                    ),
                            ),
                          ),
                          Container(
                            width: 54,
                            height: 54,
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.7),
                              shape: BoxShape.circle,
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                CircularProgressIndicator(
                                  value: progress <= 0 ? null : progress,
                                  strokeWidth: 3,
                                ),
                                KText(
                                  '${(progress * 100).round()}%',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 9),
                      Row(
                        children: [
                          Expanded(
                            child: KText(
                              details.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Open export details',
                            onPressed: widget.onShowExportDetails,
                            icon: const Icon(Icons.open_in_full_outlined),
                          ),
                          IconButton(
                            tooltip: 'Cancel export',
                            onPressed: widget.onCancelExport,
                            icon: const Icon(Icons.stop_circle_outlined),
                          ),
                        ],
                      ),
                      KText(
                        view.status,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 7),
                      LinearProgressIndicator(
                        value: progress <= 0 ? null : progress,
                        minHeight: 4,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _homeProjectThumbnail(_HomeProject project) {
    final thumbnailPath = project.thumbnailPath;
    Widget fallback() => ColoredBox(
          color: Colors.black,
          child: Center(
            child: Icon(
              project.missing ? Icons.link_off : Icons.movie_outlined,
              color: project.missing
                  ? const Color(0xffef4444)
                  : const Color(0xff60a5fa),
              size: 48,
            ),
          ),
        );
    if (thumbnailPath == null || !File(thumbnailPath).existsSync()) {
      return fallback();
    }
    return ColoredBox(
      color: Colors.black,
      child: Image.file(
        File(thumbnailPath),
        fit: BoxFit.cover,
        cacheWidth: 480,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, __, ___) => fallback(),
      ),
    );
  }
}
