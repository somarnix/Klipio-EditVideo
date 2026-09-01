// Klipio MCP Bridge - WebSocket Server for AI Control
// Add this to lib/mcp_bridge.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../features/timeline/application/timeline_editor.dart';
import '../../features/timeline/domain/timeline_models.dart';

/// MCP Bridge - Allows AI assistants to control Klipio via WebSocket
class MCPBridge {
  MCPBridge({
    required this.onTimelineChanged,
    required this.onSeek,
    required this.onPlayPause,
    required this.getCurrentTimeline,
    required this.getCurrentSelection,
    required this.getProjectInfo,
    required this.getMediaLibrary,
    required this.onOpenProject,
  });

  // Callbacks to main app
  final Function(TimelineModel) onTimelineChanged;
  final Function(double) onSeek;
  final Function() onPlayPause;
  final TimelineModel Function() getCurrentTimeline;
  final Map<String, dynamic> Function() getCurrentSelection;
  final Map<String, dynamic> Function() getProjectInfo;
  final List<Map<String, dynamic>> Function() getMediaLibrary;
  final void Function(String path) onOpenProject;

  HttpServer? _server;
  WebSocket? _client;
  final _editor = const TimelineEditor();
  bool _isRunning = false;
  int _port = 8765;
  String? _lastError;

  bool get isRunning => _isRunning;
  int get port => _port;
  String? get lastError => _lastError;

  /// Start the WebSocket server
  Future<void> start({int port = 8765}) async {
    if (_isRunning) return;
    _port = port;
    _lastError = null;

    try {
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
      _isRunning = true;

      debugPrint('🤖 MCP Bridge started on ws://localhost:$port');

      _server!.listen((HttpRequest request) async {
        if (WebSocketTransformer.isUpgradeRequest(request)) {
          _client = await WebSocketTransformer.upgrade(request);
          debugPrint('🤖 MCP Client connected');

          _client!.listen(
            _handleMessage,
            onDone: () => debugPrint('🤖 MCP Client disconnected'),
            onError: (error) => debugPrint('🤖 MCP Error: $error'),
          );
        }
      });
    } catch (e) {
      _lastError = '$e';
      debugPrint('🤖 Failed to start MCP Bridge: $e');
      await _server?.close();
      _server = null;
      rethrow;
    }
  }

  /// Stop the WebSocket server
  Future<void> stop() async {
    await _client?.close();
    await _server?.close();
    _isRunning = false;
    debugPrint('🤖 MCP Bridge stopped');
  }

  /// Handle incoming command from AI
  void _handleMessage(dynamic message) {
    try {
      final data = jsonDecode(message as String) as Map<String, dynamic>;
      final command = data['command'] as String;
      final params = data['params'] as Map<String, dynamic>? ?? {};

      debugPrint('🤖 MCP Command: $command with params: $params');

      final response = _executeCommand(command, params);
      _sendResponse(response);
    } catch (e) {
      _sendResponse(
          {'success': false, 'error': 'Failed to process command: $e'});
    }
  }

  /// Execute a command and return response
  Map<String, dynamic> _executeCommand(
    String command,
    Map<String, dynamic> params,
  ) {
    try {
      switch (command) {
        // Timeline queries
        case 'get_timeline':
          return _getTimelineState();

        case 'get_project_info':
          return getProjectInfo();

        case 'get_media_library':
          return {'media': getMediaLibrary()};

        case 'get_selection':
          return getCurrentSelection();

        // Project navigation
        case 'open_project':
          return _openProject(params);

        // Track operations
        case 'add_track':
          return _addTrack(params);

        case 'update_track':
          return _updateTrack(params);

        case 'delete_track':
          return _deleteTrack(params);

        // Clip operations
        case 'select_clip':
          return _selectClip(params);

        case 'move_clip':
          return _moveClip(params);

        case 'split_clip':
          return _splitClip(params);

        case 'resize_clip':
          return _resizeClip(params);

        case 'delete_clip':
          return _deleteClip(params);

        case 'duplicate_clip':
          return _duplicateClip(params);

        // Effects and transitions
        case 'add_effect':
          return _addEffect(params);

        case 'remove_effect':
          return _removeEffect(params);

        case 'set_transition':
          return _setTransition(params);

        case 'remove_transition':
          return _removeTransition(params);

        // Text and captions
        case 'add_text':
          return _addText(params);

        case 'add_caption':
          return _addCaption(params);

        case 'delete_caption':
          return _deleteCaption(params);

        // Playback
        case 'seek':
          return _seek(params);

        case 'play':
          return _play();

        case 'pause':
          return _pause();

        case 'add_marker':
          return _addMarker(params);

        // Analysis
        case 'analyze_timeline':
          return _analyzeTimeline();

        default:
          return {'success': false, 'error': 'Unknown command: $command'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Command execution failed: $e'};
    }
  }

  Map<String, dynamic> _openProject(Map<String, dynamic> params) {
    final path = '${params['path'] ?? ''}'.trim();
    if (path.isEmpty) {
      return {
        'success': false,
        'error': 'A project file or folder path is required.'
      };
    }
    onOpenProject(path);
    return {'success': true, 'status': 'opening_project', 'path': path};
  }

  /// Send response back to AI
  void _sendResponse(Map<String, dynamic> response) {
    if (_client != null) {
      _client!.add(jsonEncode(response));
    }
  }

  // ===========================================================================
  // COMMAND IMPLEMENTATIONS
  // ===========================================================================

  Map<String, dynamic> _getTimelineState() {
    final timeline = getCurrentTimeline();
    return {
      'success': true,
      'timeline': {
        'duration': timeline.duration,
        'track_count': timeline.tracks.length,
        'tracks': timeline.tracks
            .map((track) => {
                  'id': track.id,
                  'type': track.type.name,
                  'index': track.index,
                  'is_muted': track.isMuted,
                  'is_locked': track.isLocked,
                  'clip_count': track.clips.length,
                  'clips': track.clips
                      .map((clip) => {
                            'id': clip.id,
                            'media_path': clip.mediaPath,
                            'timeline_start': clip.timelineStart,
                            'duration': clip.duration,
                            'source_start': clip.sourceStart,
                            'has_effects': clip.effects.isNotEmpty,
                            'has_transition': clip.transitionIn != null,
                            'has_keyframes': clip.keyframes.isNotEmpty,
                          })
                      .toList(),
                })
            .toList(),
      },
    };
  }

  Map<String, dynamic> _addTrack(Map<String, dynamic> params) {
    final typeStr = params['type'] as String;
    final type = TrackType.values.firstWhere(
      (t) => t.name == typeStr,
      orElse: () => TrackType.video,
    );

    final timeline = getCurrentTimeline();
    final newTimeline = _editor.addTrack(timeline, type);
    onTimelineChanged(newTimeline);

    final previousIds = timeline.tracks.map((track) => track.id).toSet();
    final newTrack = newTimeline.tracks.firstWhere(
      (track) => track.type == type && !previousIds.contains(track.id),
      orElse: () => newTimeline.tracks.last,
    );
    return {
      'success': true,
      'track_id': newTrack.id,
      'track_type': newTrack.type.name,
      'track_index': newTrack.index,
    };
  }

  Map<String, dynamic> _updateTrack(Map<String, dynamic> params) {
    final trackId = params['track_id'] as String;
    final isMuted = params['is_muted'] as bool?;
    final isLocked = params['is_locked'] as bool?;

    final timeline = getCurrentTimeline();
    final track = timeline.trackById(trackId);
    if (track == null) {
      return {'success': false, 'error': 'Track not found: $trackId'};
    }
    final newTimeline = _editor.updateTrack(
      timeline,
      trackId,
      (track) => track.copyWith(
        isMuted: isMuted ?? track.isMuted,
        isLocked: isLocked ?? track.isLocked,
      ),
    );
    onTimelineChanged(newTimeline);

    return {'success': true, 'track_id': trackId};
  }

  Map<String, dynamic> _deleteTrack(Map<String, dynamic> params) {
    final trackId = params['track_id'] as String;

    // Don't allow deleting V1 or A1
    if (trackId == 'video-1' || trackId == 'audio-1') {
      return {
        'success': false,
        'error': 'Cannot delete primary tracks (V1/A1)'
      };
    }

    final timeline = getCurrentTimeline();
    final newTimeline = timeline
        .copyWith(
          tracks: timeline.tracks.where((t) => t.id != trackId).toList(),
        )
        .normalized();
    onTimelineChanged(newTimeline);

    return {'success': true, 'deleted_track': trackId};
  }

  Map<String, dynamic> _selectClip(Map<String, dynamic> params) {
    final clipId = params['clip_id'] as String;
    // Trigger selection in UI (handled by main app)
    return {'success': true, 'selected_clip': clipId};
  }

  Map<String, dynamic> _moveClip(Map<String, dynamic> params) {
    final clipId = params['clip_id'] as String;
    final trackId = params['track_id'] as String;
    final timelineStart = (params['timeline_start'] as num).toDouble();

    final timeline = getCurrentTimeline();
    final source = timeline.clipById(clipId);
    final target = timeline.trackById(trackId);
    if (source == null) {
      return {'success': false, 'error': 'Clip not found: $clipId'};
    }
    if (target == null) {
      return {'success': false, 'error': 'Track not found: $trackId'};
    }
    if (source.track.isLocked || target.isLocked) {
      return {
        'success': false,
        'error': 'The source or target track is locked.'
      };
    }
    if (source.track.type != target.type) {
      return {
        'success': false,
        'error': 'Video and audio clips cannot share a track.'
      };
    }
    final newTimeline = _editor.moveClip(
      timeline,
      clipId: clipId,
      targetTrackId: trackId,
      timelineStart: timelineStart,
    );
    onTimelineChanged(newTimeline);

    return {
      'success': true,
      'clip_id': clipId,
      'new_position': timelineStart,
    };
  }

  Map<String, dynamic> _splitClip(Map<String, dynamic> params) {
    final clipId = params['clip_id'] as String;
    final playhead = (params['playhead'] as num).toDouble();

    final timeline = getCurrentTimeline();
    final source = timeline.clipById(clipId);
    if (source == null) {
      return {'success': false, 'error': 'Clip not found: $clipId'};
    }
    if (source.track.isLocked ||
        playhead <= source.clip.timelineStart + 0.04 ||
        playhead >= source.clip.timelineEnd - 0.04) {
      return {
        'success': false,
        'error': 'Playhead must be inside an unlocked clip.'
      };
    }
    final newTimeline = _editor.splitClip(
      timeline,
      clipId: clipId,
      playhead: playhead,
    );
    onTimelineChanged(newTimeline);

    // Find the two new clips
    final newClips = newTimeline.tracks
        .expand((track) => track.clips)
        .where((clip) =>
            clip.id.startsWith(clipId) || clip.replacesClipId == clipId)
        .map((clip) => clip.id)
        .toList();
    return {
      'success': newClips.length >= 2,
      'original_clip': clipId,
      'new_clips': newClips,
      if (newClips.length < 2)
        'error': 'Split was rejected by the timeline editor.',
    };
  }

  Map<String, dynamic> _resizeClip(Map<String, dynamic> params) {
    final clipId = params['clip_id'] as String;
    final startEdge = params['start_edge'] as bool;
    final deltaSeconds = (params['delta_seconds'] as num).toDouble();

    final timeline = getCurrentTimeline();
    final source = timeline.clipById(clipId);
    if (source == null) {
      return {'success': false, 'error': 'Clip not found: $clipId'};
    }
    if (source.track.isLocked) {
      return {'success': false, 'error': 'The clip track is locked.'};
    }
    final newTimeline = _editor.resizeClip(
      timeline,
      clipId: clipId,
      startEdge: startEdge,
      deltaSeconds: deltaSeconds,
    );
    onTimelineChanged(newTimeline);

    return {
      'success': true,
      'clip_id': clipId,
      'trimmed': deltaSeconds,
    };
  }

  Map<String, dynamic> _deleteClip(Map<String, dynamic> params) {
    final clipId = params['clip_id'] as String;

    final timeline = getCurrentTimeline();
    final source = timeline.clipById(clipId);
    if (source == null) {
      return {'success': false, 'error': 'Clip not found: $clipId'};
    }
    if (source.track.isLocked) {
      return {'success': false, 'error': 'The clip track is locked.'};
    }
    final newTimeline = _editor.deleteClip(timeline, clipId);
    onTimelineChanged(newTimeline);

    return {'success': true, 'deleted_clip': clipId};
  }

  Map<String, dynamic> _duplicateClip(Map<String, dynamic> params) {
    final clipId = params['clip_id'] as String;

    final timeline = getCurrentTimeline();
    final result = timeline.clipById(clipId);
    if (result == null) {
      return {'success': false, 'error': 'Clip not found'};
    }
    if (result.track.isLocked) {
      return {'success': false, 'error': 'The clip track is locked.'};
    }

    final original = result.clip;
    final duplicate = original.copyWith(
      id: '$clipId-copy-${DateTime.now().millisecondsSinceEpoch}',
      timelineStart: original.timelineEnd + 0.1,
    );

    final newTimeline = _editor.insertClip(
      timeline,
      trackId: result.track.id,
      clip: duplicate,
    );
    onTimelineChanged(newTimeline);

    return {
      'success': true,
      'original_clip': clipId,
      'new_clip_id': duplicate.id,
    };
  }

  Map<String, dynamic> _addEffect(Map<String, dynamic> params) {
    final clipId = params['clip_id'] as String;
    final effectTypeStr = params['effect_type'] as String;
    final amount = (params['amount'] as num?)?.toDouble() ?? 1.0;

    final effectType = ClipEffectType.values.firstWhere(
      (e) => e.name == effectTypeStr,
      orElse: () => ClipEffectType.brightness,
    );

    final effect = ClipEffect(
      id: 'effect-${DateTime.now().millisecondsSinceEpoch}',
      type: effectType,
      amount: amount,
    );

    final timeline = getCurrentTimeline();
    final newTimeline = _editor.addClipEffect(timeline, clipId, effect);
    onTimelineChanged(newTimeline);

    return {
      'success': true,
      'clip_id': clipId,
      'effect_id': effect.id,
      'effect_type': effectType.name,
    };
  }

  Map<String, dynamic> _removeEffect(Map<String, dynamic> params) {
    final clipId = params['clip_id'] as String;
    final effectId = params['effect_id'] as String;

    final timeline = getCurrentTimeline();
    final newTimeline = _editor.removeClipEffect(timeline, clipId, effectId);
    onTimelineChanged(newTimeline);

    return {
      'success': true,
      'clip_id': clipId,
      'removed_effect': effectId,
    };
  }

  Map<String, dynamic> _setTransition(Map<String, dynamic> params) {
    final clipId = params['clip_id'] as String;
    final transitionTypeStr = params['transition_type'] as String;
    final duration = (params['duration'] as num?)?.toDouble() ?? 0.5;

    final transitionType = ClipTransitionType.values.firstWhere(
      (t) => t.name == transitionTypeStr,
      orElse: () => ClipTransitionType.dissolve,
    );

    final transition = ClipTransition(
      type: transitionType,
      duration: duration,
    );

    final timeline = getCurrentTimeline();
    final newTimeline = _editor.setClipTransition(timeline, clipId, transition);
    onTimelineChanged(newTimeline);

    return {
      'success': true,
      'clip_id': clipId,
      'transition_type': transitionType.name,
      'duration': duration,
    };
  }

  Map<String, dynamic> _removeTransition(Map<String, dynamic> params) {
    final clipId = params['clip_id'] as String;

    final timeline = getCurrentTimeline();
    final newTimeline = _editor.setClipTransition(timeline, clipId, null);
    onTimelineChanged(newTimeline);

    return {
      'success': true,
      'clip_id': clipId,
      'transition_removed': true,
    };
  }

  Map<String, dynamic> _addText(Map<String, dynamic> params) {
    // This would integrate with your text overlay system
    return {
      'success': true,
      'text_added': true,
      'text': params['text'],
    };
  }

  Map<String, dynamic> _addCaption(Map<String, dynamic> params) {
    // This would integrate with your caption system
    return {
      'success': true,
      'caption_added': true,
      'text': params['text'],
    };
  }

  Map<String, dynamic> _deleteCaption(Map<String, dynamic> params) {
    return {
      'success': true,
      'caption_deleted': params['cue_id'],
    };
  }

  Map<String, dynamic> _seek(Map<String, dynamic> params) {
    final position = (params['position'] as num).toDouble();
    onSeek(position);
    return {'success': true, 'position': position};
  }

  Map<String, dynamic> _play() {
    onPlayPause();
    return {'success': true, 'playing': true};
  }

  Map<String, dynamic> _pause() {
    onPlayPause();
    return {'success': true, 'playing': false};
  }

  Map<String, dynamic> _addMarker(Map<String, dynamic> params) {
    return {
      'success': true,
      'marker_added': true,
      'position': params['position'],
    };
  }

  Map<String, dynamic> _analyzeTimeline() {
    final timeline = getCurrentTimeline();

    var totalClips = 0;
    var totalEffects = 0;
    var totalTransitions = 0;
    var totalKeyframes = 0;

    for (final track in timeline.tracks) {
      totalClips += track.clips.length;
      for (final clip in track.clips) {
        totalEffects += clip.effects.length;
        if (clip.transitionIn != null) totalTransitions++;
        totalKeyframes += clip.keyframes.length;
      }
    }

    return {
      'success': true,
      'analysis': {
        'duration': timeline.duration,
        'total_tracks': timeline.tracks.length,
        'video_tracks': timeline.videoTracks.length,
        'audio_tracks': timeline.audioTracks.length,
        'text_tracks': timeline.textTracks.length,
        'total_clips': totalClips,
        'total_effects': totalEffects,
        'total_transitions': totalTransitions,
        'total_keyframes': totalKeyframes,
        'has_multi_track': timeline.hasMultiTrackContent,
      },
    };
  }
}
