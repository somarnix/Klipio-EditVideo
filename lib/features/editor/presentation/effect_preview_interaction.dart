import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// One browser gesture boundary: hover/focus are transient, click is Apply.
class EffectPreviewInteraction extends StatelessWidget {
  const EffectPreviewInteraction(
      {super.key,
      required this.enabled,
      required this.preview,
      required this.discard,
      required this.apply,
      required this.child});
  final bool enabled;
  final VoidCallback preview, discard, apply;
  final Widget child;
  @override
  Widget build(BuildContext context) => CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): discard},
      child: InkWell(
          borderRadius: BorderRadius.circular(9),
          onHover: (value) => value && enabled ? preview() : discard(),
          onFocusChange: (value) => value && enabled ? preview() : discard(),
          onTap: enabled ? apply : null,
          child: child));
}
