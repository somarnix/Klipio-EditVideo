part of '../editor_application.dart';

// effects operations owned by the editor state; extracted without changing timing.
extension _EffectsMutedTextColor on _EditorScreenState {
  Color get _mutedTextColor =>
      _isLightUi ? const Color(0xff536174) : const Color(0xffa1a1aa);

  Color get _softBarColor =>
      _isLightUi ? const Color(0xffeef0f6) : const Color(0xff15171c);

  Widget _colorWheel(String label) {
    return Column(
      children: [
        SizedBox(
          width: 58,
          height: 58,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const SweepGradient(
                colors: [
                  Colors.red,
                  Colors.yellow,
                  Colors.green,
                  Colors.cyan,
                  Colors.blue,
                  Colors.purple,
                  Colors.red,
                ],
              ),
              border: Border.all(color: const Color(0xff374151)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x66000000),
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: const Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0xff111827),
                  shape: BoxShape.circle,
                ),
                child: SizedBox(width: 16, height: 16),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        KText(
          label,
          style: TextStyle(fontSize: 11, color: _mutedTextColor),
        ),
      ],
    );
  }

  Widget _colorSelector(
    String label,
    Color value,
    ValueChanged<Color> onChanged,
  ) {
    final hasPreset = _EditorScreenState._colorChoices
        .any((color) => color.value == value.value);
    final visibleColors = hasPreset
        ? _EditorScreenState._colorChoices
        : [value, ..._EditorScreenState._colorChoices];

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: KText(label)),
              Container(
                width: 18,
                height: 18,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: value,
                  border: Border.all(color: _controlBorderColor),
                ),
              ),
              KText(
                _colorToHex(value),
                style: TextStyle(color: _mutedTextColor),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final color in visibleColors)
                InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () => onChanged(color),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color,
                      border: Border.all(
                        color: color.value == value.value
                            ? const Color(0xff93c5fd)
                            : const Color(0xff4b5563),
                        width: color.value == value.value ? 3 : 1,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x66000000),
                          blurRadius: 5,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              OutlinedButton.icon(
                onPressed: () => _editColor(label, value, onChanged),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const KText('Custom'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _editColor(
    String label,
    Color value,
    ValueChanged<Color> onChanged,
  ) async {
    final controller = TextEditingController(text: _colorToHex(value));
    var hsv = HSVColor.fromColor(value);
    final picked = await showDialog<Color>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void updateColor(Color color) {
              setDialogState(() {
                hsv = HSVColor.fromColor(color);
                controller.text = _colorToHex(color);
              });
            }

            void updateHsv(HSVColor next) {
              setDialogState(() {
                hsv = next;
                controller.text = _colorToHex(next.toColor());
              });
            }

            final selected = hsv.toColor();
            final screenWidth = MediaQuery.sizeOf(context).width;
            final dialogWidth = screenWidth < 620 ? screenWidth - 32 : 540.0;
            final pickerHeight = screenWidth < 620 ? 210.0 : 300.0;
            return AlertDialog(
              insetPadding: const EdgeInsets.all(16),
              title: KText(label),
              content: SizedBox(
                width: dialogWidth,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: pickerHeight,
                        child: _SaturationValuePicker(
                          hsv: hsv,
                          onChanged: updateHsv,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _HueSlider(
                        hue: hsv.hue,
                        onChanged: (hue) => updateHsv(hsv.withHue(hue)),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: selected,
                              shape: BoxShape.circle,
                              border:
                                  Border.all(color: const Color(0xff4b5563)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: controller,
                              decoration: const InputDecoration(
                                labelText: 'Hex color',
                                hintText: '#FFFFFF',
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (text) {
                                final color = _parseHexColor(text);
                                if (color != null) {
                                  updateColor(color);
                                  controller.selection =
                                      TextSelection.collapsed(
                                    offset: controller.text.length,
                                  );
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const KText('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(selected),
                  child: const KText('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
    controller.dispose();
    if (picked != null && mounted) {
      onChanged(picked);
    }
  }

  String _colorToHex(Color color) {
    return '#${(color.value & 0x00ffffff).toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  Color? _parseHexColor(String input) {
    var hex = input.trim().replaceFirst('#', '');
    if (hex.length == 3) {
      hex = hex.split('').map((char) => '$char$char').join();
    }
    if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(hex)) {
      return null;
    }
    return Color(0xff000000 | int.parse(hex, radix: 16));
  }
}
