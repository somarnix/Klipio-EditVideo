"""
Klipio Video Editor - MCP (Model Context Protocol) Server
Allows AI assistants to control the video editor through standardized tools and resources.
"""

from mcp.server.fastmcp import FastMCP
import json
import asyncio
import websockets
from typing import Optional, Dict, List, Any
from datetime import datetime
from pathlib import Path

# Initialize MCP Server
mcp = FastMCP(
    name="Klipio Video Editor",
    version="2.0.7",
    description="Professional video editing controlled by AI"
)

# ==============================================================================
# INTERNAL BRIDGE TO KLIPIO APP
# ==============================================================================

class KlipioBridge:
    """Bridge to communicate with the Klipio Flutter app via WebSocket/IPC"""

    def __init__(self):
        self.ws_uri = "ws://localhost:8765"  # WebSocket server in Klipio
        self.connection = None

    async def connect(self):
        """Connect to Klipio app WebSocket server"""
        try:
            self.connection = await websockets.connect(self.ws_uri)
            return True
        except Exception as e:
            print(f"Failed to connect to Klipio: {e}")
            return False

    async def send_command(self, command: str, params: Dict[str, Any]) -> Dict[str, Any]:
        """Send command to Klipio and get response"""
        if not self.connection:
            await self.connect()

        message = json.dumps({
            "command": command,
            "params": params,
            "timestamp": datetime.now().isoformat()
        })

        await self.connection.send(message)
        response = await self.connection.recv()
        return json.loads(response)

    async def close(self):
        """Close connection"""
        if self.connection:
            await self.connection.close()

# Global bridge instance
bridge = KlipioBridge()

# ==============================================================================
# TIMELINE TOOLS
# ==============================================================================

@mcp.tool()
async def get_timeline_state() -> str:
    """
    Get the current timeline state including all tracks, clips, and duration.
    Returns detailed JSON with track layout, clip positions, and metadata.
    """
    result = await bridge.send_command("get_timeline", {})
    return json.dumps(result, indent=2)

@mcp.tool()
async def add_video_track() -> str:
    """
    Add a new video track to the timeline (V2, V3, etc.).
    Returns the new track ID.
    """
    result = await bridge.send_command("add_track", {"type": "video"})
    return f"Added video track: {result['track_id']}"

@mcp.tool()
async def add_audio_track() -> str:
    """
    Add a new audio track to the timeline (A2, A3, etc.).
    Returns the new track ID.
    """
    result = await bridge.send_command("add_track", {"type": "audio"})
    return f"Added audio track: {result['track_id']}"

@mcp.tool()
async def add_text_track() -> str:
    """
    Add a new text overlay track to the timeline (T2, T3, etc.).
    Returns the new track ID.
    """
    result = await bridge.send_command("add_track", {"type": "text"})
    return f"Added text track: {result['track_id']}"

# ==============================================================================
# CLIP MANIPULATION TOOLS
# ==============================================================================

@mcp.tool()
async def select_clip(clip_id: str) -> str:
    """
    Select a clip on the timeline by its ID.
    Shows cyan selection border in the UI.
    """
    result = await bridge.send_command("select_clip", {"clip_id": clip_id})
    return f"Selected clip: {clip_id}"

@mcp.tool()
async def move_clip(
    clip_id: str,
    track_id: str,
    timeline_start: float
) -> str:
    """
    Move a clip to a different position or track.

    Args:
        clip_id: ID of the clip to move
        track_id: Target track ID (must be same type)
        timeline_start: New start time in seconds
    """
    result = await bridge.send_command("move_clip", {
        "clip_id": clip_id,
        "track_id": track_id,
        "timeline_start": timeline_start
    })
    return f"Moved clip {clip_id} to track {track_id} at {timeline_start}s"

@mcp.tool()
async def split_clip(
    clip_id: str,
    playhead_position: float
) -> str:
    """
    Split a clip at the specified time position.
    Creates two new clips from the original.

    Args:
        clip_id: ID of the clip to split
        playhead_position: Time in seconds where to split
    """
    result = await bridge.send_command("split_clip", {
        "clip_id": clip_id,
        "playhead": playhead_position
    })
    return f"Split clip {clip_id} at {playhead_position}s into {result['new_clips']}"

@mcp.tool()
async def trim_clip(
    clip_id: str,
    start_edge: bool,
    delta_seconds: float
) -> str:
    """
    Trim a clip from start or end edge.

    Args:
        clip_id: ID of the clip to trim
        start_edge: True to trim from start, False to trim from end
        delta_seconds: Amount to trim in seconds (positive or negative)
    """
    result = await bridge.send_command("resize_clip", {
        "clip_id": clip_id,
        "start_edge": start_edge,
        "delta_seconds": delta_seconds
    })
    edge_name = "start" if start_edge else "end"
    return f"Trimmed clip {clip_id} {edge_name} by {delta_seconds}s"

@mcp.tool()
async def delete_clip(clip_id: str) -> str:
    """
    Delete a clip from the timeline.

    Args:
        clip_id: ID of the clip to delete
    """
    result = await bridge.send_command("delete_clip", {"clip_id": clip_id})
    return f"Deleted clip: {clip_id}"

@mcp.tool()
async def duplicate_clip(clip_id: str) -> str:
    """
    Duplicate a clip on the timeline.
    Creates a copy placed immediately after the original.

    Args:
        clip_id: ID of the clip to duplicate
    """
    result = await bridge.send_command("duplicate_clip", {"clip_id": clip_id})
    return f"Duplicated clip {clip_id} as {result['new_clip_id']}"

# ==============================================================================
# EFFECTS & TRANSITIONS TOOLS
# ==============================================================================

@mcp.tool()
async def apply_effect(
    clip_id: str,
    effect_type: str,
    amount: float = 1.0
) -> str:
    """
    Apply a visual effect to a clip.

    Args:
        clip_id: ID of the target clip
        effect_type: Type of effect (brightness, contrast, saturation, blur, etc.)
        amount: Effect intensity (0.0 to 3.0, default 1.0)

    Available effects:
    - temperature, tint, exposure, brightness, contrast
    - highlights, shadows, whites, blacks, brilliance
    - saturation, gamma, clarity, fade
    - grayscale, sepia, blur, sharpen, vignette
    - invert, glitch, hueRotate
    """
    result = await bridge.send_command("add_effect", {
        "clip_id": clip_id,
        "effect_type": effect_type,
        "amount": amount
    })
    return f"Applied {effect_type} effect to clip {clip_id} at {amount * 100}%"

@mcp.tool()
async def remove_effect(clip_id: str, effect_id: str) -> str:
    """
    Remove a specific effect from a clip.

    Args:
        clip_id: ID of the clip
        effect_id: ID of the effect to remove
    """
    result = await bridge.send_command("remove_effect", {
        "clip_id": clip_id,
        "effect_id": effect_id
    })
    return f"Removed effect {effect_id} from clip {clip_id}"

@mcp.tool()
async def apply_transition(
    clip_id: str,
    transition_type: str,
    duration: float = 0.5
) -> str:
    """
    Apply a transition to a clip (overlaps with previous clip).

    Args:
        clip_id: ID of the clip
        transition_type: Type of transition (dissolve, fadeBlack, slideLeft, slideRight, slideUp, slideDown)
        duration: Transition duration in seconds (0.05 to 5.0)
    """
    result = await bridge.send_command("set_transition", {
        "clip_id": clip_id,
        "transition_type": transition_type,
        "duration": duration
    })
    return f"Applied {transition_type} transition to clip {clip_id} ({duration}s)"

@mcp.tool()
async def remove_transition(clip_id: str) -> str:
    """
    Remove the transition from a clip.

    Args:
        clip_id: ID of the clip
    """
    result = await bridge.send_command("remove_transition", {"clip_id": clip_id})
    return f"Removed transition from clip {clip_id}"

# ==============================================================================
# TEXT & CAPTIONS TOOLS
# ==============================================================================

@mcp.tool()
async def add_text_overlay(
    text: str,
    start_time: float,
    duration: float,
    font_size: int = 48,
    position_x: float = 0.5,
    position_y: float = 0.5
) -> str:
    """
    Add a text overlay to the timeline.

    Args:
        text: Text content to display
        start_time: Start time in seconds
        duration: Duration in seconds
        font_size: Font size (5 to 500, default 48)
        position_x: Horizontal position (0.0 = left, 0.5 = center, 1.0 = right)
        position_y: Vertical position (0.0 = top, 0.5 = center, 1.0 = bottom)
    """
    result = await bridge.send_command("add_text", {
        "text": text,
        "start_time": start_time,
        "duration": duration,
        "font_size": font_size,
        "position_x": position_x,
        "position_y": position_y
    })
    return f"Added text '{text}' at {start_time}s for {duration}s"

@mcp.tool()
async def add_caption_cue(
    text: str,
    start_time: float,
    end_time: float
) -> str:
    """
    Add a caption cue to the caption track (T1).

    Args:
        text: Caption text
        start_time: Start time in seconds
        end_time: End time in seconds
    """
    result = await bridge.send_command("add_caption", {
        "text": text,
        "start_time": start_time,
        "end_time": end_time
    })
    return f"Added caption '{text}' from {start_time}s to {end_time}s"

@mcp.tool()
async def generate_auto_captions(
    clip_id: str,
    model: str = "base.en",
    language: str = "en"
) -> str:
    """
    Generate automatic captions for a video clip using AI.

    Args:
        clip_id: ID of the video clip
        model: Whisper model (tiny.en, base.en, small.en, medium, default: base.en)
        language: Language code (en, auto, km, etc.)
    """
    result = await bridge.send_command("generate_captions", {
        "clip_id": clip_id,
        "model": model,
        "language": language
    })
    return f"Generated {result['cue_count']} caption cues for clip {clip_id}"

@mcp.tool()
async def delete_caption(cue_id: str) -> str:
    """
    Delete a caption cue from the timeline.

    Args:
        cue_id: ID of the caption cue
    """
    result = await bridge.send_command("delete_caption", {"cue_id": cue_id})
    return f"Deleted caption: {cue_id}"

# ==============================================================================
# TRACK MANAGEMENT TOOLS
# ==============================================================================

@mcp.tool()
async def mute_track(track_id: str, muted: bool = True) -> str:
    """
    Mute or unmute a track.

    Args:
        track_id: ID of the track
        muted: True to mute, False to unmute
    """
    result = await bridge.send_command("update_track", {
        "track_id": track_id,
        "is_muted": muted
    })
    state = "muted" if muted else "unmuted"
    return f"Track {track_id} {state}"

@mcp.tool()
async def lock_track(track_id: str, locked: bool = True) -> str:
    """
    Lock or unlock a track (prevents editing).

    Args:
        track_id: ID of the track
        locked: True to lock, False to unlock
    """
    result = await bridge.send_command("update_track", {
        "track_id": track_id,
        "is_locked": locked
    })
    state = "locked" if locked else "unlocked"
    return f"Track {track_id} {state}"

@mcp.tool()
async def delete_track(track_id: str) -> str:
    """
    Delete a track from the timeline (cannot delete V1 or A1).

    Args:
        track_id: ID of the track to delete
    """
    result = await bridge.send_command("delete_track", {"track_id": track_id})
    return f"Deleted track: {track_id}"

# ==============================================================================
# PLAYBACK & NAVIGATION TOOLS
# ==============================================================================

@mcp.tool()
async def set_playhead(position_seconds: float) -> str:
    """
    Move the playhead to a specific time position.

    Args:
        position_seconds: Time position in seconds
    """
    result = await bridge.send_command("seek", {"position": position_seconds})
    return f"Playhead moved to {position_seconds}s"

@mcp.tool()
async def play_timeline() -> str:
    """Start playing the timeline from current playhead position."""
    result = await bridge.send_command("play", {})
    return "Timeline playback started"

@mcp.tool()
async def pause_timeline() -> str:
    """Pause timeline playback."""
    result = await bridge.send_command("pause", {})
    return "Timeline playback paused"

@mcp.tool()
async def add_marker(position_seconds: float, label: str = "") -> str:
    """
    Add a timeline marker at the specified position.

    Args:
        position_seconds: Time position in seconds
        label: Optional marker label
    """
    result = await bridge.send_command("add_marker", {
        "position": position_seconds,
        "label": label
    })
    return f"Added marker at {position_seconds}s"

# ==============================================================================
# EXPORT TOOLS
# ==============================================================================

@mcp.tool()
async def export_video(
    output_path: str,
    quality: str = "1080p",
    format: str = "mp4"
) -> str:
    """
    Export the timeline as a video file.

    Args:
        output_path: Full path where to save the video
        quality: Export quality (4k, 1080p, 720p, 480p, low, custom)
        format: Output format (currently only mp4 supported)
    """
    result = await bridge.send_command("export", {
        "output_path": output_path,
        "quality": quality,
        "format": format
    })
    return f"Export started: {output_path} ({quality})"

@mcp.tool()
async def get_export_status() -> str:
    """
    Check the status of current export operation.
    Returns progress percentage and estimated time remaining.
    """
    result = await bridge.send_command("export_status", {})
    return json.dumps(result, indent=2)

# ==============================================================================
# PROJECT MANAGEMENT TOOLS
# ==============================================================================

@mcp.tool()
async def import_media(file_path: str) -> str:
    """
    Import a media file into the project.

    Args:
        file_path: Full path to the video/audio/image file
    """
    result = await bridge.send_command("import_media", {"path": file_path})
    return f"Imported media: {file_path} (ID: {result['media_id']})"

@mcp.tool()
async def save_project(project_path: Optional[str] = None) -> str:
    """
    Save the current project.

    Args:
        project_path: Optional path to save to (defaults to current project)
    """
    params = {}
    if project_path:
        params["path"] = project_path

    result = await bridge.send_command("save_project", params)
    return f"Project saved: {result['path']}"

@mcp.tool()
async def load_project(project_path: str) -> str:
    """
    Load a project from disk.

    Args:
        project_path: Full path to the .klipio.json project file
    """
    result = await bridge.send_command("load_project", {"path": project_path})
    return f"Loaded project: {project_path}"

# ==============================================================================
# RESOURCES (Read-Only State)
# ==============================================================================

@mcp.resource("klipio://timeline/current")
async def timeline_resource() -> str:
    """Current timeline state with all tracks, clips, and timing."""
    result = await bridge.send_command("get_timeline", {})
    return json.dumps(result, indent=2)

@mcp.resource("klipio://project/info")
async def project_info_resource() -> str:
    """Current project information and metadata."""
    result = await bridge.send_command("get_project_info", {})
    return json.dumps(result, indent=2)

@mcp.resource("klipio://media/library")
async def media_library_resource() -> str:
    """List of all imported media files in the project."""
    result = await bridge.send_command("get_media_library", {})
    return json.dumps(result, indent=2)

@mcp.resource("klipio://selection/current")
async def current_selection_resource() -> str:
    """Currently selected clips, text layers, or captions."""
    result = await bridge.send_command("get_selection", {})
    return json.dumps(result, indent=2)

# ==============================================================================
# ADVANCED TOOLS
# ==============================================================================

@mcp.tool()
async def batch_operation(operations: List[Dict[str, Any]]) -> str:
    """
    Execute multiple operations in sequence.
    Useful for complex edits that require multiple steps.

    Args:
        operations: List of operations, each with 'command' and 'params' keys

    Example:
        [{
            "command": "select_clip",
            "params": {"clip_id": "clip-123"}
        }, {
            "command": "apply_effect",
            "params": {"clip_id": "clip-123", "effect_type": "brightness", "amount": 1.5}
        }]
    """
    results = []
    for op in operations:
        result = await bridge.send_command(op["command"], op["params"])
        results.append(result)

    return f"Executed {len(operations)} operations successfully"

@mcp.tool()
async def analyze_timeline() -> str:
    """
    Analyze the timeline and provide insights.
    Returns information about duration, clip count, track usage, effects applied, etc.
    """
    result = await bridge.send_command("analyze_timeline", {})
    return json.dumps(result, indent=2)

# ==============================================================================
# PROMPTS (Common AI Workflows)
# ==============================================================================

@mcp.prompt()
def create_intro_sequence() -> str:
    """Template for creating an intro sequence with text and effects."""
    return """Create a professional intro sequence:
1. Add a black background clip at 0s for 3 seconds
2. Add text "Welcome" centered at 0.5s
3. Apply fade-in animation to the text
4. Add outro text "Let's Begin" at 2s
5. Apply fade-out at 2.8s"""

@mcp.prompt()
def color_grade_clip() -> str:
    """Template for color grading a selected clip."""
    return """Apply professional color grading:
1. Increase brightness by 20%
2. Increase contrast by 15%
3. Adjust saturation to 1.2
4. Add slight vignette effect
5. Apply cinematic color temperature"""

@mcp.prompt()
def create_montage() -> str:
    """Template for creating a quick montage from selected clips."""
    return """Create a montage:
1. Trim each clip to 2-3 seconds
2. Apply cross-dissolve transitions between clips
3. Add upbeat background music
4. Apply consistent color grading to all clips
5. Add title text at the beginning"""

# ==============================================================================
# SERVER STARTUP
# ==============================================================================

if __name__ == "__main__":
    # Run the MCP server
    # Use stdio transport for local Claude Desktop integration
    mcp.run(transport="stdio")

    # For remote access, use SSE transport:
    # mcp.run(transport="sse", port=8080)
