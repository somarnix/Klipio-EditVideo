import 'package:flutter/material.dart';

class KlipioTooltip extends StatelessWidget {
  const KlipioTooltip({
    super.key,
    required this.message,
    required this.child,
  });

  final String message;
  final Widget child;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: message,
        waitDuration: const Duration(milliseconds: 450),
        child: child,
      );
}
