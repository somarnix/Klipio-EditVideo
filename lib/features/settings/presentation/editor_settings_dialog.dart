part of '../../editor_shell/presentation/editor_application.dart';

Future<void> showKlipioSettingsDialog(
  BuildContext context, {
  required AppSettings settings,
  required ValueChanged<AppSettings> onSaved,
}) async {
  final result = await showDialog<AppSettings>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _AppSettingsDialog(initial: settings),
  );
  if (result != null) onSaved(result);
}

class _AppSettingsDialog extends StatefulWidget {
  const _AppSettingsDialog({required this.initial});

  final AppSettings initial;

  @override
  State<_AppSettingsDialog> createState() => _AppSettingsDialogState();
}
