import 'package:flutter/material.dart';

import '../../../timeline/domain/timeline_models.dart';
import 'inspector_value_control.dart';

/// Presentation units only. Project files continue to store multipliers and
/// normalized placement; enabling the link never rewrites a nonuniform scale.
class ClipTransformControls extends StatefulWidget {
  const ClipTransformControls(
      {super.key,
      required this.transform,
      required this.onChanged,
      this.onPreview,
      this.onCancel,
      this.enabled = true});

  final ClipTransform transform;
  final ValueChanged<ClipTransform> onChanged;
  final ValueChanged<ClipTransform>? onPreview;
  final VoidCallback? onCancel;
  final bool enabled;

  @override
  State<ClipTransformControls> createState() => _ClipTransformControlsState();
}

abstract final class TransformDisplayUnits {
  static String number(double value) =>
      value.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
  static String percent(double value) => '${number(value * 100)}%';
  static String degrees(double value) => '${number(value)}°';
  static double? parsePercent(String value) => _parse(value, '%', divisor: 100);
  static double? parseDegrees(String value) => _parse(value, '°');
  static double? _parse(String value, String unit, {double divisor = 1}) {
    final text = value.trim();
    final parsed = double.tryParse((text.endsWith(unit)
            ? text.substring(0, text.length - unit.length)
            : text)
        .trim()
        .replaceAll(',', '.'));
    return parsed != null && parsed.isFinite ? parsed / divisor : null;
  }

  static ClipTransform scale(ClipTransform transform, double value,
      {required bool width, required bool uniform}) {
    return transform.withScale(value, width: width, uniform: uniform);
  }
}

class _ClipTransformControlsState extends State<ClipTransformControls> {
  bool _uniform = true; // Interaction preference, never durable project data.
  ({String label, double value, ClipTransform transform})? _preview;

  void _cancelPreview() {
    _preview = null;
    widget.onCancel?.call();
  }

  Widget _value(String label, double current, double min, double max,
          double reset, ClipTransform Function(double) change,
          {bool degrees = false, bool localScaleReset = false}) =>
      InspectorValueControl(
        key: ValueKey(label),
        label: label,
        value: current,
        min: min,
        max: max,
        divisions: 400,
        resetValue: reset,
        enabled: widget.enabled,
        valueFormatter: degrees
            ? TransformDisplayUnits.degrees
            : TransformDisplayUnits.percent,
        valueParser: degrees
            ? TransformDisplayUnits.parseDegrees
            : TransformDisplayUnits.parsePercent,
        onChanged: (value) {
          final preview = _preview;
          _preview = null;
          // Accept the exact displayed draft, not another proportional scaling
          // calculation against the already-previewed transform.
          widget.onChanged(preview?.label == label && preview?.value == value
              ? preview!.transform
              : change(value));
        },
        onPreview: (value) {
          final transform = change(value);
          _preview = (label: label, value: value, transform: transform);
          widget.onPreview?.call(transform);
        },
        onCancel: _cancelPreview,
        onReset: localScaleReset
            ? () => widget.onChanged(label == 'Scale Width'
                ? widget.transform.copyWith(scaleX: 1)
                : widget.transform.copyWith(scaleY: 1))
            : null,
      );

  @override
  Widget build(BuildContext context) {
    final t = widget.transform;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('Position travel · 50% is centered',
          style: TextStyle(fontSize: 11)),
      const SizedBox(height: 8),
      _value(
          'Position X', t.positionX, 0, 1, .5, (v) => t.copyWith(positionX: v)),
      _value(
          'Position Y', t.positionY, 0, 1, .5, (v) => t.copyWith(positionY: v)),
      SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: const Text('Uniform scale'),
          value: _uniform,
          subtitle: const Text('Preserve width / height ratio'),
          onChanged:
              widget.enabled ? (v) => setState(() => _uniform = v) : null),
      _value(
          'Scale Width',
          t.scaleX,
          ClipTransform.minimumScale,
          ClipTransform.maximumScale,
          1,
          (v) =>
              TransformDisplayUnits.scale(t, v, width: true, uniform: _uniform),
          localScaleReset: true),
      _value(
          'Scale Height',
          t.scaleY,
          ClipTransform.minimumScale,
          ClipTransform.maximumScale,
          1,
          (v) => TransformDisplayUnits.scale(t, v,
              width: false, uniform: _uniform),
          localScaleReset: true),
      _value('Rotation', t.rotationDegrees, -360, 360, 0,
          (v) => t.copyWith(rotationDegrees: v),
          degrees: true),
      _value('Opacity', t.opacity, 0, 1, 1, (v) => t.copyWith(opacity: v)),
      TextButton.icon(
          icon: const Icon(Icons.restart_alt, size: 16),
          label: const Text('Reset transform'),
          onPressed: widget.enabled
              ? () => widget.onChanged(t.copyWith(
                  scaleX: 1,
                  scaleY: 1,
                  positionX: .5,
                  positionY: .5,
                  rotationDegrees: 0,
                  opacity: 1))
              : null),
    ]);
  }
}
