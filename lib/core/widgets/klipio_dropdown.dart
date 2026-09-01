import 'package:flutter/material.dart';

class KlipioDropdown<T> extends StatelessWidget {
  const KlipioDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.labelBuilder,
    required this.onChanged,
  });

  final T? value;
  final List<T> items;
  final String Function(T value) labelBuilder;
  final ValueChanged<T?>? onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      value: value,
      isExpanded: true,
      decoration: const InputDecoration(isDense: true),
      items: [
        for (final item in items)
          DropdownMenuItem<T>(value: item, child: Text(labelBuilder(item))),
      ],
      onChanged: onChanged,
    );
  }
}
