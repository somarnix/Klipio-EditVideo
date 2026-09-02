import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'asset_browser_shell.dart';
import 'effect_preview_interaction.dart';

/// Local catalog entry. Applying is owned by the editor, never by this view.
class CreativeBrowserItem<T> {
  const CreativeBrowserItem(
      {required this.id,
      required this.label,
      required this.value,
      required this.icon,
      this.tags = const []});
  final String id;
  final String label;
  final T value;
  final IconData icon;
  final List<String> tags;
}

class CreativeBrowser<T> extends StatefulWidget {
  const CreativeBrowser(
      {super.key,
      required this.items,
      required this.onApply,
      this.onPreview,
      this.onDiscard,
      this.selectedId,
      this.disabledReason,
      this.header,
      this.footer});
  final List<CreativeBrowserItem<T>> items;
  final ValueChanged<T> onApply;
  final ValueChanged<T>? onPreview;
  final VoidCallback? onDiscard;
  final String? selectedId;
  final String? disabledReason;
  final Widget? footer;
  final Widget? header;
  @override
  State<CreativeBrowser<T>> createState() => _CreativeBrowserState<T>();
}

class _CreativeBrowserState<T> extends State<CreativeBrowser<T>> {
  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): () =>
              widget.onDiscard?.call(),
        },
        child: AssetBrowserShell<CreativeBrowserItem<T>>(
          items: widget.items,
          searchText: (item) => '${item.label} ${item.tags.join(' ')}',
          searchLabel: 'Search creative assets',
          initialLayout: AssetBrowserLayout.list,
          onViewChanged: widget.onDiscard,
          footer: widget.footer,
          toolbar: Column(children: [
            if (widget.header != null)
              Padding(padding: const EdgeInsets.all(10), child: widget.header!),
            if (widget.disabledReason != null)
              Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text(widget.disabledReason!)),
          ]),
          itemBuilder: (context, item, layout) {
            final selected = item.id == widget.selectedId;
            if (layout == AssetBrowserLayout.grid) {
              return Semantics(
                selected: selected,
                button: true,
                label: item.label,
                child: Card(
                  key: ValueKey(item.id),
                  color: selected
                      ? Theme.of(context).colorScheme.secondaryContainer
                      : null,
                  child: EffectPreviewInteraction(
                    enabled: widget.disabledReason == null,
                    preview: () => widget.onPreview?.call(item.value),
                    discard: () => widget.onDiscard?.call(),
                    apply: () => widget.onApply(item.value),
                    child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(item.icon, size: 26),
                            const SizedBox(height: 8),
                            Flexible(
                                child: Text(item.label,
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis)),
                            if (selected)
                              const Icon(Icons.check_circle, size: 16),
                          ],
                        )),
                  ),
                ),
              );
            }
            return Card(
                key: ValueKey(item.id),
                child: MouseRegion(
                    onEnter: (_) {
                      if (widget.disabledReason == null) {
                        widget.onPreview?.call(item.value);
                      }
                    },
                    onExit: (_) => widget.onDiscard?.call(),
                    child: ListTile(
                      dense: true,
                      onFocusChange: (focused) {
                        if (focused && widget.disabledReason == null) {
                          widget.onPreview?.call(item.value);
                        } else {
                          widget.onDiscard?.call();
                        }
                      },
                      selected: item.id == widget.selectedId,
                      enabled: widget.disabledReason == null,
                      leading: Icon(item.icon),
                      title: Text(item.label),
                      trailing: item.id == widget.selectedId
                          ? const Icon(Icons.check_circle)
                          : const Icon(Icons.add_circle_outline),
                      onTap: widget.disabledReason == null
                          ? () => widget.onApply(item.value)
                          : null,
                    )));
          },
        ));
  }
}
