part of '../../editor_shell/presentation/editor_application.dart';

Future<void> showKlipioUpdateDialog(BuildContext context) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _KlipioUpdateDialog(),
  );
}

class _KlipioUpdateDialog extends StatefulWidget {
  const _KlipioUpdateDialog();

  @override
  State<_KlipioUpdateDialog> createState() => _KlipioUpdateDialogState();
}

class _KlipioUpdateDialogState extends State<_KlipioUpdateDialog> {
  final KlipioUpdateService _service = KlipioUpdateService();
  KlipioUpdateInfo? _info;
  String? _error;
  bool _checking = true;
  bool _downloading = false;
  bool _installerReady = false;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_check());
  }

  Future<void> _check() async {
    setState(() {
      _checking = true;
      _error = null;
      _info = null;
    });
    try {
      final info = await _service.check();
      if (!mounted) return;
      setState(() {
        _info = info;
        _checking = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _error = '$error'.replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _install() async {
    final info = _info;
    if (info == null || _downloading) return;
    setState(() {
      _downloading = true;
      _error = null;
      _progress = 0;
    });
    try {
      final installer = await _service.downloadAndVerify(
        info,
        onProgress: (value) {
          if (mounted) setState(() => _progress = value.clamp(0, 1));
        },
      );
      await _service.launchInstaller(installer);
      if (!mounted) return;
      setState(() {
        _downloading = false;
        _installerReady = true;
        _progress = 1;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _downloading = false;
        _error = '$error'.replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.sizeOf(context);
    final info = _info;
    final available = info?.isNewer == true;
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: math.min(920, size.width - 48),
        height: math.min(620, size.height - 48),
        child: Column(
          children: [
            Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                border: Border(
                  top: BorderSide(color: theme.colorScheme.primary, width: 2),
                  bottom: BorderSide(color: theme.dividerColor),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.system_update_alt, size: 20),
                  const SizedBox(width: 9),
                  const Expanded(
                    child: KText('Version update',
                        style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed:
                        _downloading ? null : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                child: _checking
                    ? _checkingView(theme)
                    : _resultView(theme, info, available),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _checkingView(ThemeData theme) {
    return Center(
      key: const ValueKey('checking'),
      child: SizedBox(
        width: 430,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_sync_outlined, size: 48),
            const SizedBox(height: 22),
            const KText(
              'Checking for version updates, please wait',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 18),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: const LinearProgressIndicator(minHeight: 5),
            ),
            const SizedBox(height: 10),
            KText('Secure update channel', style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  Widget _resultView(ThemeData theme, KlipioUpdateInfo? info, bool available) {
    final title = _installerReady
        ? 'Installer is ready'
        : available
            ? 'You can update to the latest version'
            : 'Klipio is up to date';
    return Row(
      key: const ValueKey('result'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: 320,
          padding: const EdgeInsets.all(28),
          color: theme.colorScheme.surfaceContainerHighest,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              KText(title,
                  style: const TextStyle(
                      fontSize: 25, fontWeight: FontWeight.w900, height: 1.15)),
              const SizedBox(height: 20),
              const KText('Current version: $klipioCurrentVersion'),
              if (info != null) ...[
                const SizedBox(height: 7),
                KText('Latest version: ${info.version}'),
                if (info.releaseDate.isNotEmpty)
                  KText('Released: ${info.releaseDate}'),
              ],
              const Spacer(),
              if (_downloading) ...[
                LinearProgressIndicator(
                    value: _progress == 0 ? null : _progress),
                const SizedBox(height: 9),
                KText('Downloading securelyโ€ฆ ${(_progress * 100).round()}%'),
                const SizedBox(height: 14),
              ],
              if (available && !_installerReady)
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: _downloading ? null : _install,
                    icon: const Icon(Icons.download_for_offline_outlined),
                    label: const KText('Update now'),
                  ),
                )
              else if (_installerReady)
                const KText(
                  'The verified updater has opened. Klipio will close automatically, replace the old app version, and reopen when the update finishes.',
                  style: TextStyle(fontWeight: FontWeight.w700),
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _check,
                    icon: const Icon(Icons.refresh),
                    label: const KText('Check again'),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                KText(available ? "What's new" : 'Update status',
                    style: TextStyle(color: theme.colorScheme.primary)),
                const SizedBox(height: 18),
                KText(info?.title ?? 'Klipio $klipioCurrentVersion',
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                KText(
                  info?.notes.isNotEmpty == true
                      ? info!.notes
                      : 'No newer release is available from your configured update channel.',
                  style: const TextStyle(height: 1.45),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 22),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: KText(_error!,
                        style: TextStyle(
                            color: theme.colorScheme.onErrorContainer)),
                  ),
                ],
                const Spacer(),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed:
                        _downloading ? null : () => Navigator.of(context).pop(),
                    child: const KText('Close'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
