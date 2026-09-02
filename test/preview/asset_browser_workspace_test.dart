import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klipio/features/editor/presentation/asset_browser_shell.dart';
import 'package:klipio/features/editor/presentation/creative_browser.dart';
import 'package:klipio/features/editor/presentation/layout/workspace_panel_tabs.dart';
import 'package:klipio/features/settings/data/app_settings.dart';
import 'package:klipio/main.dart';

void main() {
  testWidgets(
      'category filtering composes with search and reset without changing items',
      (tester) async {
    const items = ['Color invert', 'Color tint', 'Blur soft'];
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: AssetBrowserShell<String>(
      items: items,
      searchText: (value) => value,
      categoryOf: (value) => value.split(' ').first,
      itemBuilder: (_, value, layout) => Text(value),
    ))));
    await tester.tap(find.text('Color'));
    await tester.pump();
    expect(find.text('Blur soft'), findsNothing);
    await tester.enterText(find.byType(TextField), 'soft');
    await tester.pump();
    expect(find.text('No matching assets'), findsOneWidget);
    await tester.tap(find.text('Clear filters'));
    await tester.pump();
    expect(find.text('Blur soft'), findsOneWidget);
    expect(find.text('Color invert'), findsOneWidget);
    expect(items, ['Color invert', 'Color tint', 'Blur soft']);
  });
  testWidgets(
      'asset search and view switching retain asset identity and never apply',
      (tester) async {
    final applied = <String>[];
    var views = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SizedBox(
      width: 320,
      child: AssetBrowserShell<String>(
        items: const ['Khmer scene', 'English scene'],
        searchText: (v) => v,
        onViewChanged: () => views++,
        itemBuilder: (context, value, layout) =>
            TextButton(onPressed: () => applied.add(value), child: Text(value)),
      ),
    ))));
    await tester.enterText(find.byType(TextField), 'khmer scene');
    await tester.pump();
    expect(find.text('English scene'), findsNothing);
    await tester.tap(find.byTooltip('List view'));
    await tester.pump();
    expect(applied, isEmpty);
    expect(find.text('Khmer scene'), findsOneWidget);
    await tester.tap(find.text('Khmer scene'));
    expect(applied, ['Khmer scene']);
    await tester.enterText(find.byType(TextField), 'missing');
    await tester.pump();
    expect(find.text('No matching assets'), findsOneWidget);
    await tester.tap(find.text('Clear search'));
    await tester.pump();
    expect(find.text('English scene'), findsOneWidget);
    expect(views, 4);
    expect(tester.takeException(), isNull);
  });

  testWidgets('browser loading, empty import and error retry are explicit',
      (tester) async {
    var imports = 0, retries = 0;
    Future<void> show({bool loading = false, String? error}) =>
        tester.pumpWidget(MaterialApp(
            home: Scaffold(
                body: AssetBrowserShell<String>(
          items: const [],
          searchText: (v) => v,
          itemBuilder: (_, v, layout) => Text(v),
          loading: loading,
          error: error,
          onRetry: () => retries++,
          emptyAction: TextButton(
              onPressed: () => imports++, child: const Text('Import fixture')),
        ))));
    await show(loading: true);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('Preparing assets'), findsOneWidget);
    await show();
    await tester.tap(find.text('Import fixture'));
    expect(imports, 1);
    await show(error: 'Fixture unavailable');
    expect(find.text('Fixture unavailable'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    expect(retries, 1);
  });

  testWidgets(
      'creative search and layout changes discard preview; disabled assets cannot apply',
      (tester) async {
    var previews = 0, discards = 0, applies = 0;
    Future<void> show({String? disabled}) => tester.pumpWidget(MaterialApp(
            home: Scaffold(
                body: SizedBox(
          width: 320,
          child: CreativeBrowser<int>(
              items: const [
                CreativeBrowserItem(
                    id: 'dissolve',
                    label: 'Dissolve',
                    value: 1,
                    icon: Icons.blur_on)
              ],
              onApply: (_) => applies++,
              onPreview: (_) => previews++,
              onDiscard: () => discards++,
              disabledReason: disabled),
        ))));
    await show();
    final mouse = await tester.createGesture(kind: ui.PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.text('Dissolve')));
    await tester.pump();
    expect(previews, greaterThan(0));
    await tester.enterText(find.byType(TextField), 'none');
    await tester.pump();
    expect(discards, greaterThan(0));
    expect(applies, 0);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.tap(find.text('Clear search'));
    await tester.pump();
    await tester.tap(find.byTooltip('Grid view'));
    await tester.pump();
    await tester.tap(find.text('Dissolve'));
    expect(applies, 1);
    await show(disabled: 'Select a video');
    await tester.pump();
    await tester.tap(find.text('Dissolve'));
    expect(applies, 1);
    await mouse.removePointer();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'pane tabs preserve presentation state and recover when a panel closes',
      (tester) async {
    Future<void> show(bool inspector) => tester.pumpWidget(MaterialApp(
            home: Scaffold(
                body: WorkspacePanelTabs(
          labels: const {'assets': 'Assets', 'inspector': 'Inspector'},
          panels: {
            'assets': const TextField(),
            if (inspector) 'inspector': const Text('Inspector content')
          },
        ))));
    await show(true);
    await tester.enterText(find.byType(TextField), 'search retained');
    await tester.tap(find.text('Inspector'));
    await tester.pump();
    expect(find.text('Inspector content'), findsOneWidget);
    await show(false);
    await tester.pump();
    expect(find.text('search retained'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'active narrow desktop keeps monitor and exposes real asset and inspector panes',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
        home: EditorScreen(
      checkExportAvailable: false,
      settings: const AppSettings(),
      onSettingsChanged: (_) {},
      onBackHome: () {},
    )));
    await tester.pump();
    expect(find.byKey(const Key('program-monitor-canvas')), findsOneWidget);
    expect(find.byTooltip('Save project (Ctrl+S)'), findsOneWidget);
    await tester.tap(find.byTooltip('Transitions browser'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('transition-browser')), findsOneWidget);
    await tester.tap(find.byTooltip('Effects browser'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('effects-asset-browser')), findsOneWidget);
    await tester.enterText(
        find.widgetWithText(TextField, 'Search effects'), 'Negative');
    await tester.pump();
    expect(find.text('Negative'), findsWidgets);
    await tester.tap(find.text('Inspector').first);
    await tester.pump();
    expect(find.text('Details'), findsOneWidget);
    final apply = find.byKey(const ValueKey('inspector-apply-video-settings'));
    expect(apply, findsOneWidget);
    expect(tester.widget<TextButton>(apply).onPressed, isNull,
        reason: 'Apply is visible but safely disabled without imported videos');
    expect(find.byKey(const Key('program-monitor-canvas')), findsOneWidget);
    await tester.tap(find.text('Project media'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('project-asset-browser')), findsOneWidget);
    await tester.tap(find.byTooltip('Effects browser'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    for (final size in const [
      Size(720, 500),
      Size(1100, 700),
      Size(1400, 900)
    ]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pump();
      expect(find.byKey(const Key('program-monitor-canvas')), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'Workspace at $size');
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
