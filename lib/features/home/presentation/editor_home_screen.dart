part of '../../editor_shell/presentation/editor_application.dart';

enum _HomeProjectAction {
  rename,
  duplicate,
  delete,
  openFolder,
}

class KlipioHomeScreen extends StatefulWidget {
  const KlipioHomeScreen({
    super.key,
    required this.settings,
    this.exportProgress,
    this.onCancelExport,
    this.onShowExportDetails,
    required this.onSettingsChanged,
    required this.onCreateProject,
    required this.onOpenProject,
    required this.onRecentProjectsChanged,
    required this.onProjectRenamed,
    required this.onProjectDeleted,
  });

  final AppSettings settings;
  final ValueListenable<KlipioExportProgressView>? exportProgress;
  final VoidCallback? onCancelExport;
  final VoidCallback? onShowExportDetails;
  final ValueChanged<AppSettings> onSettingsChanged;
  final Future<void> Function() onCreateProject;
  final Future<void> Function(String? path) onOpenProject;
  final ValueChanged<List<String>> onRecentProjectsChanged;
  final void Function(String oldPath, String newPath, String name)
      onProjectRenamed;
  final Future<void> Function(String path) onProjectDeleted;

  @override
  State<KlipioHomeScreen> createState() => _KlipioHomeScreenState();
}

class _KlipioHomeScreenState extends State<KlipioHomeScreen> {
  void _updateHome(VoidCallback change) => setState(change);

  final TextEditingController _searchController = TextEditingController();
  List<_HomeProject> _projects = const [];
  bool _loading = true;
  String? _loadError;
  int _projectLoadGeneration = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_loadProjects());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final phone =
        screenWidth < 700 || MediaQuery.sizeOf(context).shortestSide <= 600;
    final pagePadding = phone ? 14.0 : 28.0;
    final query = _searchController.text.trim().toLowerCase();
    final projects = _projects
        .where(
          (project) =>
              query.isEmpty ||
              project.name.toLowerCase().contains(query) ||
              project.path.toLowerCase().contains(query),
        )
        .toList();
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            if (screenWidth >= 850)
              Container(
                width: 220,
                padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
                decoration: BoxDecoration(
                  color: dark ? const Color(0xff111318) : Colors.white,
                  border: Border(
                    right: BorderSide(color: Theme.of(context).dividerColor),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset(
                            'assets/branding/KlipioLogo.jpeg',
                            width: 34,
                            height: 34,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const KText(
                          'Klipio',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 34),
                    FilledButton.tonalIcon(
                      onPressed: widget.onCreateProject,
                      icon: const Icon(Icons.home_outlined),
                      label: const KText('Home'),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () => widget.onOpenProject(null),
                      icon: const Icon(Icons.history),
                      label: const KText('Recent projects'),
                    ),
                    const SizedBox(height: 18),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: KText('FUTURE TOOLS',
                          style: TextStyle(
                              color: Color(0xff64748b),
                              fontSize: 11,
                              fontWeight: FontWeight.w900)),
                    ),
                    const SizedBox(height: 6),
                    TextButton.icon(
                      onPressed: () => _showFutureFeature('AI Studio',
                          'Cloud caption cleanup, smart reframing, and automatic short creation are planned here.'),
                      icon: const Icon(Icons.auto_awesome_outlined),
                      label: const KText('AI Studio'),
                    ),
                    TextButton.icon(
                      onPressed: () => _showFutureFeature('Klipio Pro',
                          'Premium templates, cloud spaces, and team collaboration are planned here.'),
                      icon: const Icon(Icons.workspace_premium_outlined),
                      label: const KText('Upgrade to Pro'),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _showSettings,
                      icon: const Icon(Icons.settings_outlined),
                      label: const KText('Settings'),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        final next =
                            widget.settings.themeChoice == AppThemeChoice.dark
                                ? AppThemeChoice.light
                                : AppThemeChoice.dark;
                        widget.onSettingsChanged(
                          widget.settings.copyWith(themeChoice: next),
                        );
                      },
                      icon: Icon(
                        dark ? Icons.light_mode_outlined : Icons.dark_mode,
                      ),
                      label: KText(dark ? 'Light theme' : 'Dark theme'),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding:
                        EdgeInsets.fromLTRB(pagePadding, 14, pagePadding, 0),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        children: [
                          if (phone) ...[
                            Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(11),
                                  child: Image.asset(
                                    'assets/branding/KlipioLogo.jpeg',
                                    width: 40,
                                    height: 40,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: KText('Klipio',
                                      style: TextStyle(
                                          fontSize: 21,
                                          fontWeight: FontWeight.w900)),
                                ),
                                IconButton(
                                  tooltip: 'Open project folder',
                                  onPressed: () => widget.onOpenProject(null),
                                  icon: const Icon(Icons.folder_open_outlined),
                                ),
                                IconButton(
                                  tooltip: 'Settings',
                                  onPressed: _showSettings,
                                  icon: const Icon(Icons.settings_outlined),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                          ],
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  onChanged: (_) => setState(() {}),
                                  decoration: const InputDecoration(
                                    hintText: 'Search projects',
                                    prefixIcon: Icon(Icons.search),
                                  ),
                                ),
                              ),
                              if (!phone) ...[
                                const SizedBox(width: 12),
                                OutlinedButton.icon(
                                  onPressed: () => widget.onOpenProject(null),
                                  icon: const Icon(Icons.folder_open_outlined),
                                  label: const KText('Open project folder'),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  tooltip: 'Refresh projects',
                                  onPressed: _loadProjects,
                                  icon: const Icon(Icons.refresh),
                                ),
                                IconButton(
                                  tooltip: 'Settings',
                                  onPressed: _showSettings,
                                  icon: const Icon(Icons.settings_outlined),
                                ),
                              ],
                              if (!phone)
                                PopupMenuButton<String>(
                                  tooltip: 'Account and services',
                                  onSelected: (value) {
                                    if (value == 'settings') {
                                      unawaited(_showSettings());
                                    } else if (value == 'ai') {
                                      _showFutureFeature('AI Studio',
                                          'Cloud AI editing tools are planned for a future release.');
                                    } else if (value == 'billing') {
                                      _showFutureFeature('Billing',
                                          'Plans, invoices, redeem codes, and payments will live here.');
                                    } else if (value == 'spaces') {
                                      _showFutureFeature('Manage spaces',
                                          'Cloud workspaces and team projects will live here.');
                                    }
                                  },
                                  itemBuilder: (context) => const [
                                    PopupMenuItem(
                                        value: 'settings',
                                        child: ListTile(
                                            leading:
                                                Icon(Icons.settings_outlined),
                                            title: KText('Settings'))),
                                    PopupMenuItem(
                                        value: 'spaces',
                                        child: ListTile(
                                            leading:
                                                Icon(Icons.groups_outlined),
                                            title: KText('Manage spaces'),
                                            trailing:
                                                Chip(label: KText('Soon')))),
                                    PopupMenuItem(
                                        value: 'ai',
                                        child: ListTile(
                                            leading: Icon(
                                                Icons.auto_awesome_outlined),
                                            title: KText('AI Studio'),
                                            trailing:
                                                Chip(label: KText('Soon')))),
                                    PopupMenuItem(
                                        value: 'billing',
                                        child: ListTile(
                                            leading: Icon(
                                                Icons.credit_card_outlined),
                                            title: KText('Billing'),
                                            trailing:
                                                Chip(label: KText('Soon')))),
                                  ],
                                  icon:
                                      const Icon(Icons.account_circle_outlined),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (widget.exportProgress != null)
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        pagePadding,
                        phone ? 12 : 16,
                        pagePadding,
                        0,
                      ),
                      sliver: SliverToBoxAdapter(
                        child: _homeExportProgressCard(
                          widget.exportProgress!,
                        ),
                      ),
                    ),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                        pagePadding, phone ? 16 : 24, pagePadding, 0),
                    sliver: SliverToBoxAdapter(
                      child: Container(
                        padding: EdgeInsets.all(phone ? 20 : 28),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: dark
                                ? const [Color(0xff172033), Color(0xff21182f)]
                                : const [Color(0xffe8edff), Color(0xfff3e8ff)],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Theme.of(context).dividerColor,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const KText(
                                    'Create a new project',
                                    style: TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  KText(
                                    'Import video, edit captions, arrange the timeline, and export.',
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  FilledButton.icon(
                                    onPressed: widget.onCreateProject,
                                    icon: const Icon(Icons.add),
                                    label: const KText('Create project'),
                                  ),
                                ],
                              ),
                            ),
                            if (!phone)
                              const Icon(
                                Icons.video_library_outlined,
                                size: 92,
                                color: Color(0xff8b5cf6),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding:
                        EdgeInsets.fromLTRB(pagePadding, 24, pagePadding, 12),
                    sliver: const SliverToBoxAdapter(
                      child: KText(
                        'Recent projects',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  if (_loading)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_loadError != null && projects.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 520),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline, size: 42),
                              const SizedBox(height: 12),
                              KText(
                                _loadError!,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 14),
                              FilledButton.icon(
                                onPressed: () => unawaited(_loadProjects()),
                                icon: const Icon(Icons.refresh),
                                label: const KText('Retry'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else if (projects.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: KText(
                          query.isEmpty
                              ? 'No saved projects yet'
                              : 'No projects match your search',
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding:
                          EdgeInsets.fromLTRB(pagePadding, 0, pagePadding, 32),
                      sliver: SliverGrid.builder(
                        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 500,
                          mainAxisExtent: phone ? 132 : 150,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                        ),
                        itemCount: projects.length,
                        itemBuilder: (context, index) {
                          final project = projects[index];
                          return Card(
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: project.missing
                                  ? null
                                  : () => widget.onOpenProject(project.path),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: phone ? 96 : 150,
                                    height: double.infinity,
                                    child: _homeProjectThumbnail(project),
                                  ),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.all(15),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: KText(
                                                  project.name,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w900,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                              ),
                                              PopupMenuButton<
                                                  _HomeProjectAction>(
                                                tooltip: 'Project options',
                                                onSelected: (action) =>
                                                    _handleHomeProjectAction(
                                                  project,
                                                  action,
                                                ),
                                                itemBuilder: (context) =>
                                                    const [
                                                  PopupMenuItem(
                                                    value: _HomeProjectAction
                                                        .rename,
                                                    child: ListTile(
                                                      dense: true,
                                                      leading: Icon(Icons
                                                          .drive_file_rename_outline),
                                                      title: KText('Rename'),
                                                    ),
                                                  ),
                                                  PopupMenuItem(
                                                    value: _HomeProjectAction
                                                        .duplicate,
                                                    child: ListTile(
                                                      dense: true,
                                                      leading: Icon(Icons
                                                          .content_copy_outlined),
                                                      title: KText('Duplicate'),
                                                    ),
                                                  ),
                                                  PopupMenuDivider(),
                                                  PopupMenuItem(
                                                    value: _HomeProjectAction
                                                        .openFolder,
                                                    child: ListTile(
                                                      dense: true,
                                                      leading: Icon(Icons
                                                          .folder_open_outlined),
                                                      title: KText(
                                                          'Open project folder'),
                                                    ),
                                                  ),
                                                  PopupMenuDivider(),
                                                  PopupMenuItem(
                                                    value: _HomeProjectAction
                                                        .delete,
                                                    child: ListTile(
                                                      dense: true,
                                                      leading: Icon(
                                                        Icons.delete_outline,
                                                        color:
                                                            Color(0xffdc2626),
                                                      ),
                                                      title: KText(
                                                        'Delete',
                                                        style: TextStyle(
                                                          color:
                                                              Color(0xffdc2626),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                                icon: const Icon(
                                                  Icons.more_vert,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 7),
                                          KText(
                                            project.missing
                                                ? 'Project file is missing'
                                                : '${project.videoCount} video${project.videoCount == 1 ? '' : 's'} โ€ข ${_modifiedLabel(project.modified)}',
                                            style: TextStyle(
                                              color: project.missing
                                                  ? const Color(0xffef4444)
                                                  : Theme.of(context)
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                            ),
                                          ),
                                          const Spacer(),
                                          KText(
                                            _isKlipioProjectBundlePath(
                                                    project.path)
                                                ? File(project.path).parent.path
                                                : project.path,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Color(0xff64748b),
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
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

class _HomeProject {
  const _HomeProject({
    required this.path,
    this.name = 'Missing project',
    this.modified,
    this.videoCount = 0,
    this.missing = false,
    this.sourceVideoPath,
    this.thumbnailPath,
  });

  final String path;
  final String name;
  final DateTime? modified;
  final int videoCount;
  final bool missing;
  final String? sourceVideoPath;
  final String? thumbnailPath;

  _HomeProject copyWith({String? thumbnailPath}) => _HomeProject(
        path: path,
        name: name,
        modified: modified,
        videoCount: videoCount,
        missing: missing,
        sourceVideoPath: sourceVideoPath,
        thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      );
}
