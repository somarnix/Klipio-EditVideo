import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:klipio/main.dart';
import 'package:klipio/core/theme/app_theme.dart';
import 'package:klipio/features/settings/data/app_settings.dart';
import 'package:klipio/features/updates/update_service.dart';

void main() {
  test('video title check ignores numbering, extension, and punctuation', () {
    expect(
      normalizeVideoTitle('1. We Drove A Van To Dinner...Then Sold It.mp4'),
      normalizeVideoTitle('We Drove A Van To Dinner…Then Sold It!'),
    );
    expect(
      normalizeVideoTitle("I Blew Up My '68 Camaro, Then DOUBLED.mp4"),
      normalizeVideoTitle('I Blew Up My ‘68 Camaro Then DOUBLED!'),
    );
  });

  test('output numbering prefixes normal and custom export names', () {
    expect(
      numberedExportBaseName('My title', number: 6, enabled: true),
      '6.My title',
    );
    expect(
      numberedExportBaseName(
        '6-My title',
        number: 6,
        enabled: true,
        patternIncludesNumber: true,
      ),
      '6-My title',
    );
    expect(
      numberedExportBaseName('My title', number: 6, enabled: false),
      'My title',
    );
  });

  testWidgets('Klipio app starts', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    await tester.pumpWidget(const KlipioApp(
      checkExportAvailable: false,
      showStartupAnimation: false,
    ));

    expect(find.text('Klipio - Pro v$klipioCurrentVersion'), findsWidgets);
    expect(find.text('PROJECT'), findsWidgets);
    expect(find.text('IMPORT'), findsOneWidget);
    expect(find.text('TIMELINE'), findsOneWidget);
    expect(find.text('Player-Timeline 01'), findsOneWidget);
    expect(find.text('AI Captions'), findsWidgets);
    expect(find.text('Transitions'), findsOneWidget);
    expect(find.text('Filters'), findsNothing);
    expect(find.text('Adjustment'), findsOneWidget);
    expect(find.text('Project media'), findsOneWidget);
    expect(find.text('Add media'), findsNothing);
    expect(find.text('Folder'), findsNothing);
  });

  testWidgets('light theme uses white source and program monitors',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        home: EditorScreen(
          checkExportAvailable: false,
          settings: const AppSettings(themeChoice: AppThemeChoice.light),
          onSettingsChanged: (_) {},
          onBackHome: () {},
        ),
      ),
    );
    await tester.pump();

    final sourceCanvas = tester.widget<ColoredBox>(
      find.byKey(const Key('source-monitor-canvas')),
    );
    final programCanvas = tester.widget<ColoredBox>(
      find.byKey(const Key('program-monitor-canvas')),
    );
    expect(sourceCanvas.color, Colors.white);
    expect(programCanvas.color, Colors.white);

    await tester.tap(find.text('Adjustment'));
    await tester.pump();
    expect(find.text('Select a timeline clip'), findsOneWidget);
    expect(find.text('Adjust selected clip'), findsNothing);
  });

  testWidgets('desktop app opens the project home page',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    await tester.pumpWidget(const KlipioApp(showStartupAnimation: false));
    await tester.pump();

    expect(find.text('Create a new project'), findsOneWidget);
    expect(find.text('Recent projects'), findsWidgets);
    expect(find.text('Create project'), findsOneWidget);
  });

  testWidgets('asset dock exposes media, text, caption, and effects workflows',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    await tester.pumpWidget(const KlipioApp(
      checkExportAvailable: false,
      showStartupAnimation: false,
    ));
    expect(find.text('Compositions'), findsNothing);
    expect(find.text('ASSETS & TOOLS'), findsNothing);
    expect(find.text('Details'), findsOneWidget);
    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Project details'), findsOneWidget);
    expect(find.text('BASIC VIDEO'), findsNothing);
    expect(find.text('IMPORT'), findsOneWidget);

    await tester.tap(find.text('AI Captions').first);
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Whisper model'), findsOneWidget);
    expect(find.text('Generate captions on export'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);

    await tester.tap(find.text('Text layer').first);
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Add text'), findsOneWidget);
    expect(find.byTooltip('Add lower third'), findsOneWidget);
    expect(find.text('Trending'), findsOneWidget);
    expect(find.text('Clean White'), findsWidgets);

    await tester.tap(find.text('Effects').first);
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('CLIP EFFECTS'), findsOneWidget);
    expect(find.text('Effects', skipOffstage: false), findsNWidgets(1));
    expect(find.text('MOTION KEYFRAMES'), findsNothing);

    await tester.tap(find.text('Transitions').first);
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('TRANSITIONS'), findsOneWidget);
    expect(find.text('Cross Dissolve'), findsOneWidget);
  });

  testWidgets('home settings exposes all desktop settings tabs',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    await tester.pumpWidget(const KlipioApp(showStartupAnimation: false));
    await tester.pump();
    await tester.tap(find.byTooltip('Settings').first);
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Draft'), findsOneWidget);
    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Performance'), findsOneWidget);
    expect(find.text('General'), findsOneWidget);
    expect(find.text('Save settings'), findsOneWidget);
    expect(find.textContaining('Klipio Drafts'), findsOneWidget);
    expect(find.text('Ask each time'), findsNothing);
    await tester.tap(find.text('General'));
    await tester.pump();
    expect(find.text('AI Control'), findsOneWidget);
    expect(find.text('Enable MCP AI Control'), findsOneWidget);
    expect(find.text('MCP port'), findsOneWidget);
  });

  testWidgets('home export card reopens details and keeps cancel separate',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });
    final progress = ValueNotifier(
      const KlipioExportProgressView(
        details: KlipioExportDialogDetails(
          title: 'Export videos',
          name: '6.Example.mp4',
          outputFolder: r'C:\Exports',
          durationSeconds: 60,
          estimatedSize: '10 MB',
        ),
        progress: 0.25,
        status: 'Exporting 1 of 5',
      ),
    );
    addTearDown(progress.dispose);
    var detailsOpened = 0;
    var cancelRequested = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: KlipioHomeScreen(
          settings: const AppSettings(),
          exportProgress: progress,
          onShowExportDetails: () => detailsOpened++,
          onCancelExport: () => cancelRequested++,
          onSettingsChanged: (_) {},
          onCreateProject: () async {},
          onOpenProject: (_) async {},
          onRecentProjectsChanged: (_) {},
          onProjectRenamed: (_, __, ___) {},
          onProjectDeleted: (_) async {},
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byTooltip('Open export details'));
    expect(detailsOpened, 1);
    expect(cancelRequested, 0);

    await tester.tap(find.byTooltip('Cancel export'));
    expect(detailsOpened, 1);
    expect(cancelRequested, 1);
  });

  testWidgets('phone editor exposes touch navigation and timeline',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    await tester.pumpWidget(const KlipioApp(
      checkExportAvailable: false,
      showStartupAnimation: false,
    ));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Klipio'), findsOneWidget);
    expect(find.text('Player-Timeline 01'), findsOneWidget);
    expect(find.byIcon(Icons.add_to_queue), findsOneWidget);
    expect(find.byIcon(Icons.view_timeline_outlined), findsOneWidget);

    await tester.tap(find.byIcon(Icons.view_timeline_outlined));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('TIMELINE'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('phone home and settings fit a narrow screen',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    await tester.pumpWidget(const KlipioApp(showStartupAnimation: false));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Create a new project'), findsOneWidget);

    await tester.tap(find.byTooltip('Settings').first);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Performance'), findsOneWidget);
    expect(find.text('Save settings'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
