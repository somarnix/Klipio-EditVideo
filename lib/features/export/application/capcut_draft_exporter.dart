import '../../../services/capcut/capcut_draft_service.dart';

/// Application boundary for CapCut draft generation.
class CapCutDraftExporter {
  const CapCutDraftExporter();

  Future<CapCutDraftResult> export({
    required String projectName,
    required List<CapCutDraftClip> clips,
    String? outputRoot,
    bool launchCapCut = true,
    bool includeCaptions = true,
    bool exportCaptionSrt = false,
  }) =>
      createCapCutDraft(
        projectName: projectName,
        clips: clips,
        outputRoot: outputRoot,
        launchCapCut: launchCapCut,
        includeCaptionsInDraft: includeCaptions,
        exportCaptionSrt: exportCaptionSrt,
      );
}
