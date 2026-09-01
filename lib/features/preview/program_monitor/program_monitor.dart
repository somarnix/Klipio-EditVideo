import 'package:flutter/material.dart';

class ProgramMonitor extends StatelessWidget {
  const ProgramMonitor({
    super.key,
    required this.viewport,
    required this.transport,
    this.title = 'Player-Timeline 01',
  });

  final Widget viewport;
  final Widget transport;
  final String title;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 34,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(title, style: const TextStyle(fontSize: 12)),
              ),
            ),
          ),
          Expanded(child: ColoredBox(color: Colors.black, child: viewport)),
          SizedBox(height: 42, child: transport),
        ],
      );
}
