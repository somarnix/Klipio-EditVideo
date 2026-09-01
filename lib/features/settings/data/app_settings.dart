import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/storage/recovering_shared_preferences.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/klipio_localizations.dart';

class AppSettings {
  const AppSettings({
    this.themeChoice = AppThemeChoice.dark,
    this.smoothPreview = true,
    this.autoAdvanceTimeline = true,
    this.compactWorkspace = false,
    this.previewQuality = PreviewQuality.full,
    this.defaultProjectFolder = '',
    this.defaultExportFolder = '',
    this.cacheFolder = '',
    this.autoDeleteCache = false,
    this.cacheRetentionDays = 30,
    this.defaultImageDuration = 5,
    this.playAudioWhileScrubbing = false,
    this.arrangeLayers = true,
    this.defaultFrameRate = 30,
    this.timecodeFormat = 'HH:MM:SS+frame',
    this.exportCompleteSound = false,
    this.hardwareEncoding = false,
    this.hardwareDecoding = false,
    this.gpuInterface = true,
    this.autoOptimization = 'smart',
    this.proxyEnabled = false,
    this.proxyFolder = '',
    this.renderCacheFolder = '',
    this.language = 'en',
    this.notifications = true,
    this.updateMode = 'notify',
    this.mcpEnabled = false,
    this.mcpPort = 8765,
  });

  static const _themeKey = 'settings.theme';
  static const _smoothPreviewKey = 'settings.smoothPreview';
  static const _autoAdvanceTimelineKey = 'settings.autoAdvanceTimeline';
  static const _compactWorkspaceKey = 'settings.compactWorkspace';
  static const _previewQualityKey = 'settings.previewQuality';
  static const _defaultProjectFolderKey = 'settings.defaultProjectFolder';
  static const _defaultExportFolderKey = 'settings.defaultExportFolder';
  static const _cacheFolderKey = 'settings.cacheFolder';
  static const _autoDeleteCacheKey = 'settings.autoDeleteCache';
  static const _cacheRetentionDaysKey = 'settings.cacheRetentionDays';
  static const _defaultImageDurationKey = 'settings.defaultImageDuration';
  static const _playAudioWhileScrubbingKey = 'settings.playAudioWhileScrubbing';
  static const _arrangeLayersKey = 'settings.arrangeLayers';
  static const _defaultFrameRateKey = 'settings.defaultFrameRate';
  static const _timecodeFormatKey = 'settings.timecodeFormat';
  static const _exportCompleteSoundKey = 'settings.exportCompleteSound';
  static const _hardwareEncodingKey = 'settings.hardwareEncoding';
  static const _hardwareDecodingKey = 'settings.hardwareDecoding';
  static const _gpuInterfaceKey = 'settings.gpuInterface';
  static const _autoOptimizationKey = 'settings.autoOptimization';
  static const _proxyEnabledKey = 'settings.proxyEnabled';
  static const _proxyFolderKey = 'settings.proxyFolder';
  static const _renderCacheFolderKey = 'settings.renderCacheFolder';
  static const _languageKey = 'settings.language';
  static const _notificationsKey = 'settings.notifications';
  static const _updateModeKey = 'settings.updateMode';
  static const _mcpEnabledKey = 'settings.mcpEnabled';
  static const _mcpPortKey = 'settings.mcpPort';
  static const _stabilityMigrationKey = 'settings.stabilityMigration';

  final AppThemeChoice themeChoice;
  final bool smoothPreview;
  final bool autoAdvanceTimeline;
  final bool compactWorkspace;
  final PreviewQuality previewQuality;
  final String defaultProjectFolder;
  final String defaultExportFolder;
  final String cacheFolder;
  final bool autoDeleteCache;
  final int cacheRetentionDays;
  final double defaultImageDuration;
  final bool playAudioWhileScrubbing;
  final bool arrangeLayers;
  final double defaultFrameRate;
  final String timecodeFormat;
  final bool exportCompleteSound;
  final bool hardwareEncoding;
  final bool hardwareDecoding;
  final bool gpuInterface;
  final String autoOptimization;
  final bool proxyEnabled;
  final String proxyFolder;
  final String renderCacheFolder;
  final String language;
  final bool notifications;
  final String updateMode;
  final bool mcpEnabled;
  final int mcpPort;

  ThemeMode get themeMode => AppTheme.themeMode(themeChoice);

  AppSettings copyWith({
    AppThemeChoice? themeChoice,
    bool? smoothPreview,
    bool? autoAdvanceTimeline,
    bool? compactWorkspace,
    PreviewQuality? previewQuality,
    String? defaultProjectFolder,
    String? defaultExportFolder,
    String? cacheFolder,
    bool? autoDeleteCache,
    int? cacheRetentionDays,
    double? defaultImageDuration,
    bool? playAudioWhileScrubbing,
    bool? arrangeLayers,
    double? defaultFrameRate,
    String? timecodeFormat,
    bool? exportCompleteSound,
    bool? hardwareEncoding,
    bool? hardwareDecoding,
    bool? gpuInterface,
    String? autoOptimization,
    bool? proxyEnabled,
    String? proxyFolder,
    String? renderCacheFolder,
    String? language,
    bool? notifications,
    String? updateMode,
    bool? mcpEnabled,
    int? mcpPort,
  }) {
    return AppSettings(
      themeChoice: themeChoice ?? this.themeChoice,
      smoothPreview: smoothPreview ?? this.smoothPreview,
      autoAdvanceTimeline: autoAdvanceTimeline ?? this.autoAdvanceTimeline,
      compactWorkspace: compactWorkspace ?? this.compactWorkspace,
      previewQuality: previewQuality ?? this.previewQuality,
      defaultProjectFolder: defaultProjectFolder ?? this.defaultProjectFolder,
      defaultExportFolder: defaultExportFolder ?? this.defaultExportFolder,
      cacheFolder: cacheFolder ?? this.cacheFolder,
      autoDeleteCache: autoDeleteCache ?? this.autoDeleteCache,
      cacheRetentionDays: cacheRetentionDays ?? this.cacheRetentionDays,
      defaultImageDuration: defaultImageDuration ?? this.defaultImageDuration,
      playAudioWhileScrubbing:
          playAudioWhileScrubbing ?? this.playAudioWhileScrubbing,
      arrangeLayers: arrangeLayers ?? this.arrangeLayers,
      defaultFrameRate: defaultFrameRate ?? this.defaultFrameRate,
      timecodeFormat: timecodeFormat ?? this.timecodeFormat,
      exportCompleteSound: exportCompleteSound ?? this.exportCompleteSound,
      hardwareEncoding: hardwareEncoding ?? this.hardwareEncoding,
      hardwareDecoding: hardwareDecoding ?? this.hardwareDecoding,
      gpuInterface: gpuInterface ?? this.gpuInterface,
      autoOptimization: autoOptimization ?? this.autoOptimization,
      proxyEnabled: proxyEnabled ?? this.proxyEnabled,
      proxyFolder: proxyFolder ?? this.proxyFolder,
      renderCacheFolder: renderCacheFolder ?? this.renderCacheFolder,
      language: language ?? this.language,
      notifications: notifications ?? this.notifications,
      updateMode: updateMode ?? this.updateMode,
      mcpEnabled: mcpEnabled ?? this.mcpEnabled,
      mcpPort: mcpPort ?? this.mcpPort,
    );
  }

  static Future<AppSettings> load() async {
    try {
      final prefs = await loadSharedPreferencesRecovering();
      final themeName = prefs.getString(_themeKey);
      final previewQualityName = prefs.getString(_previewQualityKey);
      var storedLanguage = prefs.getString(_languageKey);
      final stabilityMigration = prefs.getInt(_stabilityMigrationKey) ?? 0;
      if (stabilityMigration < 1) {
        // Older builds enabled simultaneous GPU decode/encode by default.
        // Migrate once to the responsive CPU-safe mode; users can explicitly
        // re-enable acceleration afterward if their driver is stable.
        await prefs.setBool(_hardwareEncodingKey, false);
        await prefs.setBool(_hardwareDecodingKey, false);
        await prefs.setInt(_stabilityMigrationKey, 1);
      }
      if (storedLanguage == null && Platform.isWindows) {
        final installerLanguage = File(
          '${File(Platform.resolvedExecutable).parent.path}'
          '${Platform.pathSeparator}klipio-language.txt',
        );
        if (await installerLanguage.exists()) {
          storedLanguage = (await installerLanguage.readAsString()).trim();
        }
      }
      return AppSettings(
        themeChoice: AppThemeChoice.values.firstWhere(
          (choice) => choice.name == themeName,
          orElse: () => AppThemeChoice.dark,
        ),
        smoothPreview: prefs.getBool(_smoothPreviewKey) ?? true,
        autoAdvanceTimeline: prefs.getBool(_autoAdvanceTimelineKey) ?? true,
        compactWorkspace: prefs.getBool(_compactWorkspaceKey) ?? false,
        previewQuality: PreviewQuality.values.firstWhere(
          (quality) => quality.name == previewQualityName,
          orElse: () => PreviewQuality.full,
        ),
        defaultProjectFolder: prefs.getString(_defaultProjectFolderKey) ?? '',
        defaultExportFolder: prefs.getString(_defaultExportFolderKey) ?? '',
        cacheFolder: prefs.getString(_cacheFolderKey) ?? '',
        autoDeleteCache: prefs.getBool(_autoDeleteCacheKey) ?? false,
        cacheRetentionDays: prefs.getInt(_cacheRetentionDaysKey) ?? 30,
        defaultImageDuration: prefs.getDouble(_defaultImageDurationKey) ?? 5,
        playAudioWhileScrubbing:
            prefs.getBool(_playAudioWhileScrubbingKey) ?? false,
        arrangeLayers: prefs.getBool(_arrangeLayersKey) ?? true,
        defaultFrameRate: prefs.getDouble(_defaultFrameRateKey) ?? 30,
        timecodeFormat: prefs.getString(_timecodeFormatKey) ?? 'HH:MM:SS+frame',
        exportCompleteSound: prefs.getBool(_exportCompleteSoundKey) ?? false,
        hardwareEncoding: prefs.getBool(_hardwareEncodingKey) ?? false,
        hardwareDecoding: prefs.getBool(_hardwareDecodingKey) ?? false,
        gpuInterface: prefs.getBool(_gpuInterfaceKey) ?? true,
        autoOptimization: prefs.getString(_autoOptimizationKey) ?? 'smart',
        proxyEnabled: prefs.getBool(_proxyEnabledKey) ?? false,
        proxyFolder: prefs.getString(_proxyFolderKey) ?? '',
        renderCacheFolder: prefs.getString(_renderCacheFolderKey) ?? '',
        language: KlipioLanguages.fromId(storedLanguage ?? 'en').id,
        notifications: prefs.getBool(_notificationsKey) ?? true,
        updateMode: prefs.getString(_updateModeKey) ?? 'notify',
        mcpEnabled: prefs.getBool(_mcpEnabledKey) ??
            prefs.getBool('mcp_enabled') ??
            false,
        mcpPort: (prefs.getInt(_mcpPortKey) ?? 8765).clamp(1024, 65535),
      );
    } catch (_) {
      return const AppSettings();
    }
  }

  Future<void> save() async {
    try {
      final prefs = await loadSharedPreferencesRecovering();
      await prefs.setString(_themeKey, themeChoice.name);
      await prefs.setBool(_smoothPreviewKey, smoothPreview);
      await prefs.setBool(_autoAdvanceTimelineKey, autoAdvanceTimeline);
      await prefs.setBool(_compactWorkspaceKey, compactWorkspace);
      await prefs.setString(_previewQualityKey, previewQuality.name);
      await prefs.setString(_defaultProjectFolderKey, defaultProjectFolder);
      await prefs.setString(_defaultExportFolderKey, defaultExportFolder);
      await prefs.setString(_cacheFolderKey, cacheFolder);
      await prefs.setBool(_autoDeleteCacheKey, autoDeleteCache);
      await prefs.setInt(_cacheRetentionDaysKey, cacheRetentionDays);
      await prefs.setDouble(_defaultImageDurationKey, defaultImageDuration);
      await prefs.setBool(_playAudioWhileScrubbingKey, playAudioWhileScrubbing);
      await prefs.setBool(_arrangeLayersKey, arrangeLayers);
      await prefs.setDouble(_defaultFrameRateKey, defaultFrameRate);
      await prefs.setString(_timecodeFormatKey, timecodeFormat);
      await prefs.setBool(_exportCompleteSoundKey, exportCompleteSound);
      await prefs.setBool(_hardwareEncodingKey, hardwareEncoding);
      await prefs.setBool(_hardwareDecodingKey, hardwareDecoding);
      await prefs.setBool(_gpuInterfaceKey, gpuInterface);
      await prefs.setString(_autoOptimizationKey, autoOptimization);
      await prefs.setBool(_proxyEnabledKey, proxyEnabled);
      await prefs.setString(_proxyFolderKey, proxyFolder);
      await prefs.setString(_renderCacheFolderKey, renderCacheFolder);
      await prefs.setString(_languageKey, language);
      await prefs.setBool(_notificationsKey, notifications);
      await prefs.setString(_updateModeKey, updateMode);
      await prefs.setBool(_mcpEnabledKey, mcpEnabled);
      await prefs.setInt(_mcpPortKey, mcpPort);
    } catch (_) {
      // Settings persistence should not block the editor.
    }
  }
}
