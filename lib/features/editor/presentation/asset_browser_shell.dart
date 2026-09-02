import 'package:flutter/material.dart';

enum AssetBrowserLayout { grid, list }

/// Presentation-only browser state. Filtering never edits the project or its
/// selection; callers retain asset identity and own every add/apply operation.
class AssetBrowserShell<T> extends StatefulWidget {
  const AssetBrowserShell({
    super.key,
    required this.items,
    required this.searchText,
    required this.itemBuilder,
    this.categoryOf,
    this.toolbar,
    this.footer,
    this.onViewChanged,
    this.loading = false,
    this.error,
    this.onRetry,
    this.emptyAction,
    this.emptyTitle = 'No assets yet',
    this.emptyDescription = 'Import media or choose a category to get started.',
    this.searchLabel = 'Search assets',
    this.initialLayout = AssetBrowserLayout.grid,
    this.gridAspectRatio = 1.15,
  });

  final List<T> items;
  final String Function(T) searchText;
  final Widget Function(BuildContext, T, AssetBrowserLayout) itemBuilder;
  final String Function(T)? categoryOf;
  final Widget? toolbar, footer, emptyAction;
  final VoidCallback? onViewChanged, onRetry;
  final bool loading;
  final String? error;
  final String emptyTitle, emptyDescription, searchLabel;
  final AssetBrowserLayout initialLayout;
  final double gridAspectRatio;

  @override
  State<AssetBrowserShell<T>> createState() => _AssetBrowserShellState<T>();
}

class _AssetBrowserShellState<T> extends State<AssetBrowserShell<T>> {
  final _search = TextEditingController();
  late AssetBrowserLayout _layout = widget.initialLayout;
  String? _category;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _changed() {
    widget.onViewChanged?.call();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final categories = widget.categoryOf == null
        ? <String>[]
        : (widget.items
            .map(widget.categoryOf!)
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort());
    final category = categories.contains(_category) ? _category : null;
    final terms = _search.text.trim().toLowerCase().split(RegExp(r'\s+'));
    final visible = widget.items.where((item) {
      final text = widget.searchText(item).toLowerCase();
      return terms.every(text.contains) &&
          (category == null || widget.categoryOf!(item) == category);
    }).toList(growable: false);
    return CustomScrollView(slivers: [
      SliverToBoxAdapter(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (widget.toolbar != null) widget.toolbar!,
        if (categories.length > 1)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(children: [
              for (final value in <String?>[null, ...categories])
                Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(value ?? 'All'),
                      selected: category == value,
                      showCheckmark: false,
                      onSelected: (_) {
                        _category = value;
                        _changed();
                      },
                    )),
            ]),
          ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _search,
                onChanged: (_) => _changed(),
                decoration: InputDecoration(
                  isDense: true,
                  labelText: widget.searchLabel,
                  prefixIcon: const Icon(Icons.search, size: 18),
                  suffixIcon: _search.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          icon: const Icon(Icons.close, size: 16),
                          onPressed: () {
                            _search.clear();
                            _changed();
                          },
                        ),
                ),
              ),
            ),
            IconButton(
              tooltip: _layout == AssetBrowserLayout.grid
                  ? 'List view'
                  : 'Grid view',
              icon: Icon(_layout == AssetBrowserLayout.grid
                  ? Icons.view_list_outlined
                  : Icons.grid_view),
              onPressed: () {
                _layout = _layout == AssetBrowserLayout.grid
                    ? AssetBrowserLayout.list
                    : AssetBrowserLayout.grid;
                _changed();
              },
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Text('${visible.length} of ${widget.items.length} assets',
              style: Theme.of(context).textTheme.labelSmall),
        ),
        if (widget.loading) const LinearProgressIndicator(minHeight: 2),
      ])),
      if (widget.error != null)
        SliverToBoxAdapter(
            child: BrowserMessage(
                icon: Icons.error_outline,
                title: 'Unable to load assets',
                description: widget.error!,
                action: widget.onRetry == null
                    ? null
                    : TextButton.icon(
                        onPressed: widget.onRetry,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'))))
      else if (visible.isEmpty)
        SliverToBoxAdapter(
            child: BrowserMessage(
          icon: widget.items.isEmpty
              ? Icons.perm_media_outlined
              : Icons.search_off,
          title: widget.loading
              ? 'Preparing assets'
              : widget.items.isEmpty
                  ? widget.emptyTitle
                  : 'No matching assets',
          description: widget.items.isEmpty
              ? widget.emptyDescription
              : 'Try a different name or keyword.',
          action: widget.items.isEmpty
              ? widget.emptyAction
              : TextButton(
                  onPressed: () {
                    _search.clear();
                    _category = null;
                    _changed();
                  },
                  child: Text(
                      category == null ? 'Clear search' : 'Clear filters')),
        ))
      else
        SliverPadding(
            padding: const EdgeInsets.all(8),
            sliver: _layout == AssetBrowserLayout.grid
                ? SliverLayoutBuilder(
                    builder: (context, constraints) => SliverGrid(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount:
                                      (constraints.crossAxisExtent / 140)
                                          .floor()
                                          .clamp(1, 12),
                                  mainAxisSpacing: 8,
                                  crossAxisSpacing: 8,
                                  childAspectRatio: widget.gridAspectRatio),
                          delegate: SliverChildBuilderDelegate(
                              (context, i) => widget.itemBuilder(
                                  context, visible[i], _layout),
                              childCount: visible.length),
                        ))
                : SliverList(
                    delegate: SliverChildBuilderDelegate(
                        (context, i) =>
                            widget.itemBuilder(context, visible[i], _layout),
                        childCount: visible.length))),
      if (widget.footer != null)
        SliverToBoxAdapter(
            child: Padding(
                padding: const EdgeInsets.all(10), child: widget.footer)),
    ]);
  }
}

class BrowserMessage extends StatelessWidget {
  const BrowserMessage(
      {super.key,
      required this.icon,
      required this.title,
      required this.description,
      this.action});
  final IconData icon;
  final String title, description;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
          child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 28, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 10),
          Text(title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          Text(description,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall),
          if (action != null)
            Padding(padding: const EdgeInsets.only(top: 12), child: action),
        ]),
      ));
}
