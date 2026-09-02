import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import '../domain/export_models.dart';
import '../../text/presentation/caption_paragraph.dart';
import '../../text/domain/caption_visual_state.dart';
import '../../text/domain/title_visual_state.dart';
import '../../text/presentation/project_text_raster.dart';

/// One loopback input per export. No caption files; backpressure bounds queued
/// frames. Reconnection restarts at frame zero for encoder fallback.
class CaptionFrameStream {
  CaptionFrameStream._(this.server, this.cues, this.spec, this.width,
      this.height, this.fps, this.duration, this.token, this.titles);
  final List<TextOverlaySettings> titles;
  final ServerSocket server;
  final List<CaptionCueSettings> cues;
  final CaptionParagraphSpec spec;
  final int width, height;
  final double fps, duration;
  final ExportCancelToken? token;
  final Set<Socket> _sockets = {};
  final Set<Future<void>> _workers = {};
  bool _closed = false;
  final Completer<void> _finished = Completer<void>();
  Future<void>? _closeFuture;
  Object? error;
  int rasterizations = 0;
  int peakCachedBytes = 0;
  int paragraphLayouts = 0;
  int peakCachedParagraphs = 0;
  int titleLayouts = 0, peakTitleGlyphBytes = 0, retainedTitleGlyphBytes = 0;
  final Map<CaptionCueSettings, CaptionTimelineResolver> _resolvers = {};
  String get url => 'tcp://127.0.0.1:${server.port}';

  static Future<CaptionFrameStream> open(
      {required List<CaptionCueSettings> cues,
      required CaptionParagraphSpec spec,
      required int width,
      required int height,
      required double fps,
      required double duration,
      List<TextOverlaySettings> titles = const [],
      ExportCancelToken? token}) async {
    if (width <= 0 ||
        height <= 0 ||
        !fps.isFinite ||
        fps <= 0 ||
        !duration.isFinite ||
        duration <= 0) {
      throw ArgumentError('Invalid caption stream dimensions/timebase');
    }
    // Capture before the first await. A copied outer list alone still exposes
    // editable word lists to a running export or encoder reconnect.
    final capturedCues = List<CaptionCueSettings>.unmodifiable([
      for (final cue in cues)
        CaptionCueSettings(
            id: cue.id,
            start: cue.start,
            end: cue.end,
            text: cue.text,
            x: cue.x,
            y: cue.y,
            words: List.unmodifiable(cue.words)),
    ]);
    final capturedTitles = List<TextOverlaySettings>.unmodifiable(
        titles.map((title) => title.withComposition()));
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final stream = CaptionFrameStream._(server, capturedCues, spec, width,
        height, fps, duration, token, capturedTitles);
    server.listen((socket) {
      // At most one decoder connection. Encoder retries begin after the old
      // worker stops; never allow two full raster producers in one job.
      if (stream._closed || stream._sockets.isNotEmpty) {
        socket.destroy();
        return;
      }
      stream._sockets.add(socket);
      final worker = stream._serve(socket);
      stream._workers.add(worker);
      unawaited(worker.whenComplete(() => stream._workers.remove(worker)));
    });
    if (token != null) {
      unawaited(Future.any([token.whenCanceled, stream._finished.future])
          .then((_) => stream.close()));
    }
    return stream;
  }

  CaptionVisualState _visual(CaptionCueSettings cue, double time) => _resolvers
      .putIfAbsent(
          cue,
          () => CaptionTimelineResolver(
              cueId: cue.id,
              text: cue.text,
              start: cue.start,
              end: cue.end,
              textCase: spec.textCase,
              motion: spec.motion,
              words: cue.words.indexed.map((e) => CaptionTimedWord(
                  id: e.$2.id.isEmpty ? '${cue.id}/word/${e.$1}' : e.$2.id,
                  rangeStart: e.$2.rangeStart,
                  rangeEnd: e.$2.rangeEnd,
                  text: e.$2.text,
                  start: e.$2.start,
                  end: e.$2.end))))
      .resolve(time);

  Future<Uint8List> _raster(
      List<CaptionCueSettings> active,
      double time,
      Map<CaptionCueSettings, CaptionParagraphLayout> layouts,
      Map<TextOverlaySettings, (List<Object>, ProjectTitleLayout)>
          titleCache) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    try {
      final activeTitles = titles
          .where((t) => TitleTimelineResolver.resolve(t, time).active)
          .toList();
      for (final title in titleCache.keys.toList()) {
        if (!activeTitles.contains(title)) {
          titleCache.remove(title)!.$2.dispose();
        }
      }
      for (final title in activeTitles) {
        final visual = TitleTimelineResolver.resolve(title, time);
        final key = ProjectTextRaster.layoutKey(
            title, width.toDouble(), height.toDouble(),
            content: visual.text);
        var cached = titleCache[title];
        if (cached == null || !listEquals(cached.$1, key)) {
          cached?.$2.dispose();
          titleCache.remove(title);
          final shaped = ProjectTextRaster.shape(
              title, width.toDouble(), height.toDouble(),
              content: visual.text);
          titleCache[title] =
              (key, shaped); // Own before await, including failure.
          await shaped.cacheGlyphs();
          cached = (key, shaped);
          titleLayouts++;
        }
        cached.$2.paint(
            canvas, ui.Size(width.toDouble(), height.toDouble()), visual);
      }
      retainedTitleGlyphBytes = titleCache.values
          .fold(0, (bytes, item) => bytes + item.$2.cachedBytes);
      if (retainedTitleGlyphBytes > peakTitleGlyphBytes) {
        peakTitleGlyphBytes = retainedTitleGlyphBytes;
      }
      for (final cue in active) {
        final paragraph = layouts.putIfAbsent(cue, () {
          paragraphLayouts++;
          return cue.words.isNotEmpty && spec.timedHighlight
              ? spec.highlightedLayout(
                  cue.text, width.toDouble(), height.toDouble(), const [])
              : spec.layout(cue.text, width.toDouble(), height.toDouble());
        });
        if (layouts.length > peakCachedParagraphs) {
          peakCachedParagraphs = layouts.length;
        }
        paragraph.paint(
            canvas,
            ui.Offset((width - paragraph.size.width) * cue.x.clamp(0, 1),
                (height - paragraph.size.height) * cue.y.clamp(0, 1)),
            visualState: _visual(cue, time));
      }
    } catch (_) {
      recorder.endRecording().dispose();
      rethrow;
    }
    final picture = recorder.endRecording();
    ui.Image? image;
    try {
      image = await picture.toImage(width, height);
      final data =
          await image.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
      if (data == null) throw StateError('Caption RGBA conversion failed');
      rasterizations++;
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } finally {
      image?.dispose();
      picture.dispose();
    }
  }

  Future<void> _serve(Socket socket) async {
    Uint8List? cached;
    List<Object>? previous;
    // Retain shaping only for currently visible cues, never the whole project.
    // Word emphasis changes composition, not wrapping or glyph layout.
    final layouts = <CaptionCueSettings, CaptionParagraphLayout>{};
    final titleCache =
        <TextOverlaySettings, (List<Object>, ProjectTitleLayout)>{};
    try {
      for (var frame = 0; frame < (duration * fps).ceil(); frame++) {
        if (_closed || token?.isCanceled == true) break;
        final time = frame / fps;
        final active =
            cues.where((c) => time >= c.start && time < c.end).toList();
        for (final cue in layouts.keys.toList()) {
          if (!active.contains(cue)) {
            layouts.remove(cue)!.dispose();
            _resolvers.remove(cue);
          }
        }
        final key = <Object>[
          for (final title in titles)
            ...TitleTimelineResolver.resolve(title, time).compositionKey,
          for (final cue in active) ...[
            cue,
            if (spec.timedHighlight) ..._visual(cue, time).ranges,
            if (spec.motion == 'bounce' || spec.motion == 'pop')
              for (final w in _visual(cue, time).words) (w.scale, w.offsetY)
          ]
        ];
        if (previous == null || !listEquals(previous, key)) {
          cached = await _raster(active, time, layouts, titleCache);
          previous = key;
          peakCachedBytes = cached.length;
        }
        if (_closed || token?.isCanceled == true) break;
        socket.add(cached!);
        await socket.flush();
      }
      await socket.close();
    } on SocketException {
      // Decoder cancellation/fallback closes the connection. The owning
      // export result determines success; reconnecting regenerates from zero.
    } catch (failure) {
      if (!_closed) error = failure;
    } finally {
      for (final layout in layouts.values) {
        layout.dispose();
      }
      layouts.clear();
      for (final entry in titleCache.values) {
        entry.$2.dispose();
      }
      titleCache.clear();
      retainedTitleGlyphBytes = 0;
      _resolvers.clear();
      socket.destroy();
      _sockets.remove(socket);
    }
  }

  Future<void> close() => _closeFuture ??= _close();

  Future<void> _close() async {
    _closed = true;
    _finished.complete();
    await server.close();
    for (final socket in _sockets.toList()) {
      socket.destroy();
    }
    await Future.wait(_workers.toList());
  }
}
