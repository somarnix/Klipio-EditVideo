import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A numeric edit is one command, not one command per pointer sample.
/// The draft lives only in this control. Consumers may opt into a visual
/// preview; only [onChanged] is allowed to commit durable state.
class InspectorValueControl extends StatefulWidget {
  const InspectorValueControl({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.divisions = 100,
    this.valueFormatter,
    this.valueParser,
    this.onPreview,
    this.onCancel,
    this.resetValue,
    this.onReset,
    this.enabled = true,
  });

  final String label;
  final double value, min, max;
  final int divisions;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onPreview;
  final VoidCallback? onCancel;
  final String Function(double)? valueFormatter;
  final double? Function(String)? valueParser;
  final double? resetValue;
  final VoidCallback? onReset;
  final bool enabled;

  @override
  State<InspectorValueControl> createState() => _InspectorValueControlState();
}

class _InspectorValueControlState extends State<InspectorValueControl> {
  late final TextEditingController _text;
  late final FocusNode _focus;
  double? _draft;
  double? _gestureInitialValue;
  bool _typed = false;
  bool _gestureCanceled = false;

  String _format(double value) =>
      widget.valueFormatter?.call(value) ??
      value.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');

  @override
  void initState() {
    super.initState();
    _text = TextEditingController(text: _format(widget.value));
    _focus = FocusNode()..addListener(_focusChanged);
  }

  @override
  void didUpdateWidget(covariant InspectorValueControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((!_focus.hasFocus && _draft == null) || !widget.enabled) {
      _text.text = _format(widget.value);
      _typed = false;
    }
    if (!widget.enabled) _draft = null;
  }

  void _focusChanged() {
    if (!_focus.hasFocus) _commitText();
  }

  void _commitText() {
    if (!_typed) return;
    _typed = false;
    final parsed = widget.valueParser != null
        ? widget.valueParser!(_text.text)
        : double.tryParse(_text.text.trim().replaceAll(',', '.'));
    if (!widget.enabled ||
        parsed == null ||
        !parsed.isFinite ||
        parsed < widget.min ||
        parsed > widget.max) {
      _text.text = _format(widget.value);
      return;
    }
    _commit(parsed);
  }

  void _commit(double value) {
    final initial = _gestureInitialValue ?? widget.value;
    _gestureInitialValue = null;
    _typed = false;
    setState(() => _draft = null);
    _text.text = _format(value);
    if (widget.enabled && value != initial) {
      widget.onChanged(value);
    } else {
      widget.onCancel?.call();
    }
  }

  void _cancel() {
    setState(() {
      _gestureCanceled = true;
      _gestureInitialValue = null;
      _draft = null;
      _typed = false;
      _text.text = _format(widget.value);
    });
    widget.onCancel?.call();
    _focus.unfocus();
  }

  @override
  void dispose() {
    _focus
      ..removeListener(_focusChanged)
      ..dispose();
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Focus(
        onKeyEvent: (_, event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.escape) {
            _cancel();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                  child: Text(widget.label,
                      maxLines: 2,
                      style: Theme.of(context).textTheme.bodySmall)),
              if (widget.resetValue != null)
                IconButton(
                  tooltip: 'Reset ${widget.label}',
                  visualDensity: VisualDensity.compact,
                  constraints:
                      const BoxConstraints.tightFor(width: 26, height: 28),
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.restart_alt, size: 15),
                  onPressed: widget.enabled
                      ? () {
                          if (widget.onReset != null) {
                            _cancel();
                            widget.onReset!();
                          } else {
                            _commit(widget.resetValue!);
                          }
                        }
                      : null,
                ),
              SizedBox(
                  width: 80,
                  height: 30,
                  child: TextField(
                    controller: _text,
                    focusNode: _focus,
                    enabled: widget.enabled,
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 12),
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true, signed: true),
                    onChanged: (_) => _typed = true,
                    onTap: () => _text.selection = TextSelection(
                        baseOffset: 0, extentOffset: _text.text.length),
                    onSubmitted: (_) {
                      _commitText();
                      _focus.unfocus();
                    },
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: widget.label,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 6),
                      border: const OutlineInputBorder(),
                    ),
                  )),
            ]),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
              ),
              child: Slider(
                value: (_draft ?? widget.value).clamp(widget.min, widget.max),
                min: widget.min,
                max: widget.max,
                divisions: widget.divisions,
                label: _format(_draft ?? widget.value),
                onChangeStart: widget.enabled
                    ? (_) {
                        _typed = false;
                        _gestureCanceled = false;
                        _gestureInitialValue = widget.value;
                      }
                    : null,
                onChanged: widget.enabled
                    ? (value) {
                        if (_gestureCanceled) return;
                        setState(() => _draft = value);
                        _text.text = _format(value);
                        widget.onPreview?.call(value);
                      }
                    : null,
                onChangeEnd: widget.enabled
                    ? (value) {
                        // Escape may have canceled the gesture before mouse-up.
                        if (_draft != null) _commit(value);
                      }
                    : null,
              ),
            ),
          ]),
        ),
      );
}
