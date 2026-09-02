import 'package:flutter/widgets.dart';

/// Durable composition content, not a localized UI label. Project coordinates
/// already determine its size; OS accessibility scaling belongs to editor UI.
/// Flutter still owns Unicode shaping, bidi resolution, and font fallback.
class ProjectText extends StatelessWidget {
  const ProjectText(this.data,
      {super.key, required this.style, this.textAlign = TextAlign.center});
  final String data;
  final TextStyle style;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) => Text(data,
      style: style,
      textAlign: textAlign,
      textScaler: TextScaler.noScaling,
      softWrap: true);
}
