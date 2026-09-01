#!/usr/bin/env python3
"""Generate cached Faster-Whisper transcripts and CapCut-style ASS captions."""

from __future__ import annotations

import argparse
import ctypes
import hashlib
import json
import os
import sys
import time
from pathlib import Path
from typing import Any


CAPTION_STYLES: dict[str, dict[str, Any]] = {
    "capcut": {
        "primary": "&H0000FFFF", "secondary": "&H00FFFFFF",
        "outline_color": "&H00000000", "back": "&H78000000",
        "bold": -1, "italic": 0, "border": 1, "outline": 6,
        "shadow": 3, "margin": 0.13, "uppercase": True, "tag": "kf",
    },
    "orange_pop": {
        "primary": "&H00008AFF", "secondary": "&H00FFFFFF",
        "outline_color": "&H00000000", "back": "&H78000000",
        "bold": -1, "italic": 0, "border": 1, "outline": 6,
        "shadow": 3, "margin": 0.13, "uppercase": True, "tag": "kf",
    },
    "clean": {
        "primary": "&H00FFFFFF", "secondary": "&H00FFFFFF",
        "outline_color": "&H00000000", "back": "&H68000000",
        "bold": -1, "italic": 0, "border": 1, "outline": 4,
        "shadow": 2, "margin": 0.13, "uppercase": False, "tag": "k",
    },
    "minimal": {
        "primary": "&H00FFFFFF", "secondary": "&H00FFFFFF",
        "outline_color": "&H00000000", "back": "&H50000000",
        "bold": 0, "italic": 0, "border": 1, "outline": 1.5,
        "shadow": 1, "margin": 0.11, "uppercase": False, "tag": "k",
    },
    "black_box": {
        "primary": "&H00FFFFFF", "secondary": "&H00FFFFFF",
        "outline_color": "&H90000000", "back": "&H90000000",
        "bold": -1, "italic": 0, "border": 3, "outline": 10,
        "shadow": 0, "margin": 0.11, "uppercase": False, "tag": "k",
    },
    "neon_cyan": {
        "primary": "&H00FFE500", "secondary": "&H00FFFFFF",
        "outline_color": "&H002A2403", "back": "&H90000000",
        "bold": -1, "italic": 0, "border": 1, "outline": 5,
        "shadow": 5, "margin": 0.13, "uppercase": True, "tag": "kf",
    },
    "hot_pink": {
        "primary": "&H00AC3CFF", "secondary": "&H00FFFFFF",
        "outline_color": "&H00000000", "back": "&H78000000",
        "bold": -1, "italic": 0, "border": 1, "outline": 6,
        "shadow": 3, "margin": 0.13, "uppercase": True, "tag": "kf",
    },
    "lime_punch": {
        "primary": "&H0012FFA3", "secondary": "&H00FFFFFF",
        "outline_color": "&H00002517", "back": "&H78000000",
        "bold": -1, "italic": 0, "border": 1, "outline": 6,
        "shadow": 2, "margin": 0.13, "uppercase": True, "tag": "kf",
    },
    "red_alert": {
        "primary": "&H00303BFF", "secondary": "&H00FFFFFF",
        "outline_color": "&H00000000", "back": "&H78000000",
        "bold": -1, "italic": 0, "border": 1, "outline": 7,
        "shadow": 3, "margin": 0.13, "uppercase": True, "tag": "kf",
    },
    "blue_glow": {
        "primary": "&H00F6823B", "secondary": "&H00FFFFFF",
        "outline_color": "&H00411B06", "back": "&H90000000",
        "bold": -1, "italic": 0, "border": 1, "outline": 5,
        "shadow": 6, "margin": 0.13, "uppercase": True, "tag": "kf",
    },
    "documentary": {
        "primary": "&H00FFFFFF", "secondary": "&H00FFFFFF",
        "outline_color": "&H00000000", "back": "&H50000000",
        "bold": 0, "italic": -1, "border": 1, "outline": 2.5,
        "shadow": 1, "margin": 0.07, "uppercase": False, "tag": "k",
    },
    "classic_gold": {
        "primary": "&H0000B0FF", "secondary": "&H00FFFFFF",
        "outline_color": "&H0000223C", "back": "&H78000000",
        "bold": -1, "italic": 0, "border": 1, "outline": 5,
        "shadow": 4, "margin": 0.13, "uppercase": True, "tag": "kf",
    },
}


def _caption_variant(base: str, **changes: Any) -> dict[str, Any]:
    value = dict(CAPTION_STYLES[base])
    value.update(changes)
    return value


CAPTION_STYLES.update(
    {
        "big_word_pop": _caption_variant(
            "capcut", primary="&H0000E5FF", secondary="&H00FFFFFF",
            outline=6, shadow=3
        ),
        "white_impact": _caption_variant(
            "capcut", primary="&H00FFFFFF", secondary="&H00CABEB7", outline=7, shadow=4
        ),
        "cyan_focus": _caption_variant(
            "capcut", primary="&H00EED322", outline=5, shadow=2
        ),
        "red_focus": _caption_variant(
            "capcut", primary="&H00552DFF", outline=6, shadow=3
        ),
        "yellow_box": _caption_variant(
            "black_box", primary="&H00000000", secondary="&H00FFFFFF",
            outline_color="&H0000E5FF", back="&H0000E5FF", outline=10
        ),
        "cyan_box": _caption_variant(
            "black_box", primary="&H00000000", secondary="&H00FFFFFF",
            outline_color="&H00EED322", back="&H00EED322", outline=10
        ),
        "pink_box": _caption_variant(
            "black_box", primary="&H00FFFFFF", secondary="&H00FFFFFF",
            outline_color="&H009A2DFF", back="&H009A2DFF", outline=10
        ),
        "retro_mint": _caption_variant(
            "capcut", primary="&H00674DFF", secondary="&H00F8FFF7",
            outline_color="&H00A0D926", outline=5, shadow=2
        ),
        "violet_glow": _caption_variant(
            "capcut", primary="&H00FC84C0", outline_color="&H00951D4C",
            outline=4, shadow=9
        ),
        "sunset_glow": _caption_variant(
            "capcut", primary="&H00187AFF", outline_color="&H00122D7C",
            outline=4, shadow=8
        ),
        "ice_glow": _caption_variant(
            "capcut", primary="&H00FFF7E0", outline_color="&H00C78402",
            outline=3, shadow=8
        ),
        "comic": _caption_variant(
            "capcut", primary="&H0000F2FF", outline=8, shadow=5
        ),
        "typewriter": _caption_variant(
            "minimal", primary="&H00FFFFFF", secondary="&H00847770",
            outline=1, shadow=1
        ),
        "purple_split": _caption_variant(
            "capcut", primary="&H00F979E8", secondary="&H00FDB5C4",
            outline_color="&H0064073B", outline=5, shadow=3
        ),
        "aqua_split": _caption_variant(
            "capcut", primary="&H00BFD42D", secondary="&H00FEF2E0",
            outline_color="&H002E2F04", outline=5, shadow=3
        ),
        "orange_box": _caption_variant(
            "black_box", primary="&H00000000", secondary="&H00FFFFFF",
            outline_color="&H00008AFF", back="&H00008AFF", outline=10
        ),
        "soft_purple": _caption_variant(
            "clean", primary="&H00FCABF0", secondary="&H00FFFFFF",
            outline_color="&H00871C58", outline=3, shadow=4
        ),
        "news_lower": _caption_variant(
            "black_box", primary="&H0000D4FF", secondary="&H00FFFFFF",
            outline_color="&HCC271811", back="&HCC271811", outline=8,
            margin=0.06
        ),
        "mono_focus": _caption_variant(
            "clean", primary="&H00FFFFFF", secondary="&H008A726B",
            outline=3, shadow=2
        ),
        "gold_box": _caption_variant(
            "black_box", primary="&H00001627", secondary="&H00FFFFFF",
            outline_color="&H0028C9FF", back="&H0028C9FF", outline=10
        ),
    }
)


def _progress(percent: int, message: str) -> None:
    print(f"PROGRESS:{max(0, min(100, percent))}:{message}", flush=True)


def _cache_key(video: Path, model: str, language: str) -> str:
    stat = video.stat()
    payload = json.dumps(
        {
            "path": str(video.resolve()),
            "size": stat.st_size,
            "mtime_ns": stat.st_mtime_ns,
            "model": model,
            "language": language,
            # Bump this whenever speech filtering changes so an older cached
            # transcript cannot reintroduce captions across silent ranges.
            "schema": 3,
        },
        sort_keys=True,
    )
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()


def _select_device(requested: str) -> tuple[str, str]:
    if requested == "cpu":
        return "cpu", "int8"
    if requested == "cuda":
        return "cuda", "float16"
    # "auto" deliberately chooses bounded CPU inference. Klipio's UI and
    # video preview share the display GPU; starting CUDA Whisper while video
    # encoding can exhaust VRAM or hang the Windows display driver on 4 GB
    # laptop GPUs. CUDA remains available as an explicit expert choice.
    return "cpu", "int8"


def _can_load_any(names: tuple[str, ...]) -> bool:
    loader = ctypes.WinDLL if os.name == "nt" else ctypes.CDLL
    for name in names:
        try:
            loader(name)
            return True
        except OSError:
            continue
    return False


def _cuda_runtime_ready() -> bool:
    if os.name == "nt":
        has_cublas = _can_load_any(("cublas64_12.dll", "cublas64_11.dll"))
        has_cudnn = _can_load_any(
            ("cudnn_ops64_9.dll", "cudnn_ops_infer64_8.dll")
        )
    else:
        has_cublas = _can_load_any(("libcublas.so.12", "libcublas.so.11"))
        has_cudnn = _can_load_any(("libcudnn_ops.so.9", "libcudnn_ops_infer.so.8"))
    return has_cublas and has_cudnn


def _transcribe(
    video: Path,
    model_name: str,
    language: str,
    requested_device: str,
) -> dict[str, Any]:
    try:
        from faster_whisper import WhisperModel
    except ImportError as error:
        raise RuntimeError(
            "Faster-Whisper is not installed. Run: "
            "python -m pip install -r tool/requirements-captions.txt"
        ) from error

    device, compute_type = _select_device(requested_device)
    _progress(5, f"Loading {model_name} on {device} ({compute_type})")

    def run(active_device: str, active_compute: str) -> tuple[list[dict[str, Any]], str]:
        model = WhisperModel(
            model_name,
            device=active_device,
            compute_type=active_compute,
            cpu_threads=max(1, min(4, os.cpu_count() or 2)),
            num_workers=1,
        )
        segments, info = model.transcribe(
            str(video),
            beam_size=1,
            language=None if language == "auto" else language,
            word_timestamps=True,
            vad_filter=True,
            vad_parameters={
                "threshold": 0.55,
                "min_silence_duration_ms": 350,
                "speech_pad_ms": 150,
            },
            condition_on_previous_text=False,
            no_speech_threshold=0.55,
            log_prob_threshold=-0.8,
            compression_ratio_threshold=2.4,
        )
        words: list[dict[str, Any]] = []
        segment_count = 0
        media_duration = max(0.01, float(getattr(info, "duration", 0.0) or 0.0))
        for segment in segments:
            segment_count += 1
            no_speech_probability = float(
                getattr(segment, "no_speech_prob", 0.0) or 0.0
            )
            average_log_probability = float(
                getattr(segment, "avg_logprob", 0.0) or 0.0
            )
            compression_ratio = float(
                getattr(segment, "compression_ratio", 0.0) or 0.0
            )
            segment_words = list(segment.words or [])
            word_probabilities = [
                float(word.probability)
                for word in segment_words
                if getattr(word, "probability", None) is not None
            ]
            average_word_probability = (
                sum(word_probabilities) / len(word_probabilities)
                if word_probabilities
                else 1.0
            )
            # Instrumental music and long quiet sections are the most common
            # source of Whisper hallucinations. Require both VAD and usable
            # decoder confidence before accepting a segment as spoken audio.
            reject_segment = (
                average_log_probability < -1.0
                or compression_ratio > 2.4
                or average_word_probability < 0.32
                or (
                    no_speech_probability >= 0.55
                    and average_log_probability < -0.35
                )
            )
            if reject_segment:
                continue
            for word in segment_words:
                text = (word.word or "").strip()
                if text and word.start is not None and word.end is not None:
                    words.append(
                        {
                            "start": round(float(word.start), 3),
                            "end": round(float(word.end), 3),
                            "text": text,
                        }
                    )
            if segment_count % 4 == 0:
                segment_end = float(getattr(segment, "end", 0.0) or 0.0)
                percent = 10 + int(58 * min(1.0, segment_end / media_duration))
                _progress(percent, f"Listening for speech... {len(words)} words")
        detected = getattr(info, "language", None) or language
        return words, detected

    try:
        words, detected_language = run(device, compute_type)
    except Exception as error:
        if device != "cuda" or requested_device == "cuda":
            raise
        _progress(10, f"CUDA unavailable ({error}); retrying on CPU int8")
        device, compute_type = "cpu", "int8"
        words, detected_language = run(device, compute_type)

    return {
        "model": model_name,
        "language": detected_language,
        "device": device,
        "compute_type": compute_type,
        "words": words,
    }


def _load_or_transcribe(args: argparse.Namespace, video: Path) -> dict[str, Any]:
    cache_dir = Path(args.cache_dir)
    cache_dir.mkdir(parents=True, exist_ok=True)
    cache_file = cache_dir / f"{_cache_key(video, args.model, args.language)}.json"
    if cache_file.exists() and not args.no_cache:
        _progress(20, "Using cached transcript")
        return json.loads(cache_file.read_text(encoding="utf-8"))

    transcript = _transcribe(video, args.model, args.language, args.device)
    temporary = cache_file.with_suffix(f".{os.getpid()}.tmp")
    temporary.write_text(
        json.dumps(transcript, ensure_ascii=False, separators=(",", ":")),
        encoding="utf-8",
    )
    os.replace(temporary, cache_file)
    return transcript


def _ass_time(seconds: float) -> str:
    total_cs = max(0, int(round(seconds * 100)))
    hours, remainder = divmod(total_cs, 360000)
    minutes, remainder = divmod(remainder, 6000)
    whole_seconds, centiseconds = divmod(remainder, 100)
    return f"{hours}:{minutes:02d}:{whole_seconds:02d}.{centiseconds:02d}"


def _ass_text(text: str) -> str:
    return (
        text.replace("\\", r"\\")
        .replace("{", r"\{")
        .replace("}", r"\}")
        .replace("\r", " ")
        .replace("\n", " ")
    )


def _hex_to_ass(value: str, fallback: str) -> str:
    raw = value.strip().lstrip("#")
    if len(raw) != 6:
        return fallback
    try:
        red, green, blue = raw[0:2], raw[2:4], raw[4:6]
        int(raw, 16)
    except ValueError:
        return fallback
    return f"&H00{blue}{green}{red}".upper()


def _hex_to_ass_alpha(value: str, opacity: float, fallback: str) -> str:
    color = _hex_to_ass(value, fallback)
    alpha = round((1 - max(0.0, min(1.0, opacity))) * 255)
    return f"&H{alpha:02X}{color[-6:]}"


def _video_size(video: Path) -> tuple[int, int]:
    try:
        import av

        with av.open(str(video)) as container:
            stream = container.streams.video[0]
            width = int(stream.codec_context.width or 1080)
            height = int(stream.codec_context.height or 1920)
            return max(2, width), max(2, height)
    except Exception:
        return 1080, 1920


def _caption_words(
    transcript: dict[str, Any], start: float, end: float, speed: float
) -> list[dict[str, Any]]:
    selected: list[dict[str, Any]] = []
    for item in transcript.get("words", []):
        word_start = float(item["start"])
        word_end = float(item["end"])
        if word_end <= start or (end > start and word_start >= end):
            continue
        local_start = max(0.0, word_start - start) / speed
        local_end = max(word_end - start, word_start - start + 0.01) / speed
        if end > start:
            local_end = min(local_end, (end - start) / speed)
        selected.append(
            {"start": local_start, "end": local_end, "text": str(item["text"])}
        )
    return selected


def _caption_word_groups(
    words: list[dict[str, Any]], words_per_line: int, max_pause: float = 0.85
) -> list[list[dict[str, Any]]]:
    """Group words without ever drawing a caption across a silent gap."""
    groups: list[list[dict[str, Any]]] = []
    current: list[dict[str, Any]] = []
    for word in words:
        if current:
            previous_end = float(current[-1]["end"])
            pause = float(word["start"]) - previous_end
            if len(current) >= words_per_line or pause > max_pause:
                groups.append(current)
                current = []
        current.append(word)
    if current:
        groups.append(current)
    return groups


def _write_ass(
    output: Path,
    video: Path,
    transcript: dict[str, Any],
    start: float,
    end: float,
    words_per_line: int,
    font: str,
    font_size: int,
    style: str,
    speed: float,
    bold: bool,
    underline: bool,
    italic: bool,
    letter_case: str,
    color: str,
    character_spacing: float,
    word_spacing: float,
    line_spacing: float,
    opacity: float,
    stroke_enabled: bool,
    stroke_color: str,
    stroke_width: float,
    background_enabled: bool,
    background_color: str,
    background_opacity: float,
    background_padding: float,
    glow_enabled: bool,
    glow_color: str,
    glow_strength: float,
    shadow_enabled: bool,
    shadow_color: str,
    shadow_strength: float,
    curve: float,
) -> int:
    width, height = _video_size(video)
    safe_font = font.replace(",", " ").strip() or "Arial Black"
    preset = CAPTION_STYLES.get(style, CAPTION_STYLES["capcut"])
    margin_v = max(12, int(height * float(preset["margin"])))
    primary = _hex_to_ass_alpha(color, opacity, str(preset["primary"]))
    outline_color = _hex_to_ass(stroke_color, str(preset["outline_color"]))
    outline_width = stroke_width if stroke_enabled else 0
    back_color = _hex_to_ass(shadow_color, str(preset["back"]))
    shadow_width = shadow_strength if shadow_enabled else 0
    bold_value = -1 if bold else 0
    underline_value = -1 if underline else 0
    italic_value = -1 if italic else 0
    extra_styles = ""
    if background_enabled:
        background_ass = _hex_to_ass_alpha(
            background_color, background_opacity, "&H80000000"
        )
        extra_styles += (
            f"Style: CaptionBackground,{safe_font},{font_size},&HFF000000,&HFF000000,"
            f"{background_ass},{background_ass},0,0,0,0,100,100,{character_spacing},0,"
            f"3,{background_padding},0,2,24,24,{margin_v},1\n"
        )
    if glow_enabled:
        glow_ass = _hex_to_ass_alpha(glow_color, 0.55, "&H7000FFFF")
        extra_styles += (
            f"Style: CaptionGlow,{safe_font},{font_size},&HFF000000,&HFF000000,"
            f"{glow_ass},{glow_ass},{bold_value},{italic_value},0,0,100,100,"
            f"{character_spacing},0,1,{glow_strength},0,2,24,24,{margin_v},1\n"
        )
    # ASS stores colors as &HAABBGGRR. Primary is the completed karaoke color.
    header = f"""[Script Info]
ScriptType: v4.00+
PlayResX: {width}
PlayResY: {height}
ScaledBorderAndShadow: yes
WrapStyle: 2

[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
Style: CapCutPro,{safe_font},{font_size},{primary},{preset['secondary']},{outline_color},{back_color},{bold_value},{italic_value},{underline_value},0,100,100,{character_spacing},0,1,{outline_width},{shadow_width},2,24,24,{margin_v},1
{extra_styles}

[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
"""
    words = _caption_words(transcript, start, end, speed)
    events: list[str] = []
    caption_blocks = 0
    for chunk in _caption_word_groups(words, words_per_line):
        if not chunk:
            continue
        line_start = float(chunk[0]["start"])
        line_end = max(line_start + 0.08, float(chunk[-1]["end"]))
        parts: list[str] = []
        display_words: list[str] = []
        cursor = line_start
        for word_index, item in enumerate(chunk):
            word_start = float(item["start"])
            word_end = float(item["end"])
            gap_cs = max(0, int(round((word_start - cursor) * 100)))
            if gap_cs:
                parts.append(f"{{\\k{gap_cs}}}")
            duration_cs = max(1, int(round((word_end - word_start) * 100)))
            tag = str(preset["tag"])
            text = _ass_text(item["text"])
            if letter_case == "upper":
                text = text.upper()
            elif letter_case == "lower":
                text = text.lower()
            elif letter_case == "title":
                text = text.title()
            display_words.append(text)
            center = (len(chunk) - 1) / 2
            normalized = 0.0 if center <= 0 else (word_index - center) / center
            rotation = -curve / 100 * normalized * 12
            start_ms = max(0, int(round((word_start - line_start) * 1000)))
            end_ms = max(start_ms + 40, int(round((word_end - line_start) * 1000)))
            peak_ms = min(end_ms, start_ms + 90)
            motion = ""
            if style == "big_word_pop":
                motion = (
                    f"\\frz{rotation:.2f}\\fscx100\\fscy100"
                    f"\\t({start_ms},{peak_ms},\\fscx148\\fscy148)"
                    f"\\t({peak_ms},{end_ms},\\fscx100\\fscy100)"
                )
            elif style in {
                "capcut", "lime_punch", "classic_gold", "white_impact",
                "cyan_focus", "red_focus", "purple_split", "aqua_split",
                "mono_focus",
            }:
                motion = (
                    f"\\frz{rotation:.2f}\\fscx100\\fscy100"
                    f"\\t({start_ms},{peak_ms},\\fscx122\\fscy122)"
                    f"\\t({peak_ms},{end_ms},\\fscx100\\fscy100)"
                )
            elif style in {"orange_pop", "red_alert", "retro_mint", "comic"}:
                motion = (
                    f"\\fscx100\\fscy100\\frz{rotation:.2f}"
                    f"\\t({start_ms},{peak_ms},\\fscx124\\fscy124\\frz{rotation - 3:.2f})"
                    f"\\t({peak_ms},{end_ms},\\fscx100\\fscy100\\frz{rotation:.2f})"
                )
            elif style in {
                "neon_cyan", "hot_pink", "blue_glow", "violet_glow",
                "sunset_glow", "ice_glow", "soft_purple",
            }:
                glow_outline = float(preset["outline"]) + 3
                glow_shadow = float(preset["shadow"]) + 2
                motion = (
                    f"\\frz{rotation:.2f}"
                    f"\\t({start_ms},{peak_ms},\\bord{glow_outline}\\shad{glow_shadow})"
                    f"\\t({peak_ms},{end_ms},\\bord{preset['outline']}\\shad{preset['shadow']})"
                )
            else:
                motion = f"\\frz{rotation:.2f}"
            parts.append(f"{{{motion}\\{tag}{duration_cs}}}{text}")
            if word_index < len(chunk) - 1:
                parts.append(
                    f"{{\\fsp{max(0.0, word_spacing):.2f}}}\\h"
                    f"{{\\fsp{character_spacing:.2f}}}"
                )
            cursor = word_end
        plain_text = " ".join(display_words)
        if background_enabled:
            events.append(
                "Dialogue: 0,"
                f"{_ass_time(line_start)},{_ass_time(line_end)},"
                f"CaptionBackground,,0,0,0,,{plain_text}"
            )
        if glow_enabled:
            events.append(
                "Dialogue: 1,"
                f"{_ass_time(line_start)},{_ass_time(line_end)},"
                f"CaptionGlow,,0,0,0,,{plain_text}"
            )
        events.append(
            "Dialogue: 2,"
            f"{_ass_time(line_start)},{_ass_time(line_end)},"
            f"CapCutPro,,0,0,0,,{''.join(parts).rstrip()}"
        )
        caption_blocks += 1

    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(header + "\n".join(events) + "\n", encoding="utf-8-sig")
    return caption_blocks


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("video")
    parser.add_argument("output_ass")
    parser.add_argument("--cache-dir", required=True)
    parser.add_argument("--model", default="base.en")
    parser.add_argument("--language", default="en")
    parser.add_argument("--device", choices=("auto", "cuda", "cpu"), default="auto")
    parser.add_argument("--start", type=float, default=0.0)
    parser.add_argument("--end", type=float, default=0.0)
    parser.add_argument("--words-per-line", type=int, default=4)
    parser.add_argument("--font", default="Arial Black")
    parser.add_argument("--font-size", type=int, default=72)
    parser.add_argument("--style", choices=tuple(CAPTION_STYLES), default="capcut")
    parser.add_argument("--bold", type=int, choices=(0, 1), default=1)
    parser.add_argument("--underline", type=int, choices=(0, 1), default=0)
    parser.add_argument("--italic", type=int, choices=(0, 1), default=0)
    parser.add_argument(
        "--case", choices=("upper", "lower", "title", "original"), default="upper"
    )
    parser.add_argument("--color", default="#FFF000")
    parser.add_argument("--character-spacing", type=float, default=0.0)
    parser.add_argument("--word-spacing", type=float, default=4.0)
    parser.add_argument("--line-spacing", type=float, default=0.0)
    parser.add_argument("--opacity", type=float, default=1.0)
    parser.add_argument("--stroke-enabled", type=int, choices=(0, 1), default=1)
    parser.add_argument("--stroke-color", default="#000000")
    parser.add_argument("--stroke-width", type=float, default=6.0)
    parser.add_argument("--background-enabled", type=int, choices=(0, 1), default=0)
    parser.add_argument("--background-color", default="#000000")
    parser.add_argument("--background-opacity", type=float, default=0.75)
    parser.add_argument("--background-padding", type=float, default=10.0)
    parser.add_argument("--glow-enabled", type=int, choices=(0, 1), default=0)
    parser.add_argument("--glow-color", default="#FFF000")
    parser.add_argument("--glow-strength", type=float, default=8.0)
    parser.add_argument("--shadow-enabled", type=int, choices=(0, 1), default=1)
    parser.add_argument("--shadow-color", default="#000000")
    parser.add_argument("--shadow-strength", type=float, default=3.0)
    parser.add_argument("--curve", type=float, default=0.0)
    parser.add_argument("--speed", type=float, default=1.0)
    parser.add_argument("--no-cache", action="store_true")
    return parser


def main() -> int:
    args = _parser().parse_args()
    started = time.perf_counter()
    video = Path(args.video)
    output = Path(args.output_ass)
    if not video.is_file():
        raise FileNotFoundError(f"Input video not found: {video}")
    args.words_per_line = max(1, min(8, args.words_per_line))
    args.font_size = max(5, min(500, args.font_size))
    args.start = max(0.0, args.start)
    args.end = max(0.0, args.end)
    args.speed = max(0.05, min(20.0, args.speed))

    transcript = _load_or_transcribe(args, video)
    _progress(75, "Building CapCut-style ASS captions")
    event_count = _write_ass(
        output,
        video,
        transcript,
        args.start,
        args.end,
        args.words_per_line,
        args.font,
        args.font_size,
        args.style,
        args.speed,
        bool(args.bold),
        bool(args.underline),
        bool(args.italic),
        args.case,
        args.color,
        args.character_spacing,
        args.word_spacing,
        args.line_spacing,
        args.opacity,
        bool(args.stroke_enabled),
        args.stroke_color,
        args.stroke_width,
        bool(args.background_enabled),
        args.background_color,
        args.background_opacity,
        args.background_padding,
        bool(args.glow_enabled),
        args.glow_color,
        args.glow_strength,
        bool(args.shadow_enabled),
        args.shadow_color,
        args.shadow_strength,
        args.curve,
    )
    elapsed = time.perf_counter() - started
    _progress(100, f"Created {event_count} caption lines in {elapsed:.2f}s")
    print(
        json.dumps(
            {
                "output": str(output),
                "events": event_count,
                "device": transcript.get("device"),
                "compute_type": transcript.get("compute_type"),
                "elapsed_seconds": round(elapsed, 3),
            },
            ensure_ascii=False,
        ),
        flush=True,
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as error:
        print(f"ERROR:{error}", file=sys.stderr, flush=True)
        raise SystemExit(1)
