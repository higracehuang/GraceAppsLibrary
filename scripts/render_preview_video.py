#!/usr/bin/env python3
"""
render_preview_video.py (GraceAppsLibrary Universal Video Compositor)

Composites professional multi-language title overlays onto App Store Preview videos
and encodes strictly compliant Apple App Store Preview videos:
  - Canonical resolution: 886 × 1920 px (iPhone 6.7"/6.5" portrait)
  - Strict Constant Framerate: 30 fps (Apple rejects > 30 fps)
  - Mandatory Stereo AAC 48 kHz Audio Track (App Store Connect requirement)
  - H.264 / yuv420p / CRF 19
  - Safe Area alignment below Dynamic Island / status bar
  - Multi-language support: en, es, zh-Hans, de, fr, ja, etc.
  - Optional Fastlane export (--fastlane) into fastlane/app-previews/<locale>/

Usage:
    python3 render_preview_video.py [options]

Options:
    --config, -c      Path to storyboard JSON (default: Marketing/preview_storyboard.json)
    --input, -i       Input video file (defaults to newest in Screenshots/Video/)
    --lang, -l        Language code (default: en, or 'all')
    --output, -o      Output video path
    --fastlane        Also export directly into fastlane/app-previews/<locale>/
    --width           Output video width (default: 886)
    --height          Output video height (default: 1920)
"""

import argparse
import glob
import json
import math
import os
import shutil
import subprocess
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

# Canonical App Store Video Specs (iPhone 6.7" / 6.5" Portrait)
CANONICAL_WIDTH = 886
CANONICAL_HEIGHT = 1920
CANONICAL_FPS = 30

DEFAULT_THEME = {
    "style": "pill",
    "pill_bg": [20, 14, 22, 225],
    "pill_outline": [255, 180, 210, 140],
    "accent_dot": [255, 77, 121, 255],
    "text_color": [255, 255, 255, 255],
    "top_percent": 0.082,  # Positioned safely below Dynamic Island
}

DEFAULT_STORYBOARD = {
    "en": [
        {"start": 0.5, "end": 4.0, "title": "Welcome to the App"},
        {"start": 4.5, "end": 10.0, "title": "Track Your Daily Goals"},
        {"start": 10.5, "end": 18.0, "title": "Personalized Insights"},
        {"start": 18.5, "end": 27.5, "title": "Built for Your Rhythm"},
    ]
}


def hex_to_rgba(val, default_alpha=255):
    if isinstance(val, (list, tuple)):
        return tuple(val)
    if isinstance(val, str) and val.startswith("#"):
        val = val.lstrip("#")
        if len(val) == 6:
            r, g, b = int(val[0:2], 16), int(val[2:4], 16), int(val[4:6], 16)
            return (r, g, b, default_alpha)
        elif len(val) == 8:
            r, g, b, a = int(val[0:2], 16), int(val[2:4], 16), int(val[4:6], 16), int(val[6:8], 16)
            return (r, g, b, a)
    return (255, 255, 255, default_alpha)


def find_system_font(lang="en", bold=True, rounded=False):
    if rounded and lang != "zh-Hans":
        candidates = [
            "/System/Library/Fonts/Supplemental/Arial Rounded Bold.ttf",
            "/System/Library/Fonts/SFCompact.ttf",
            "/System/Library/Fonts/SFNS.ttf",
        ]
        for c in candidates:
            if os.path.exists(c):
                return c

    if lang.startswith("zh"):
        candidates = [
            "/System/Library/Fonts/PingFang.ttc",
            "/System/Library/Fonts/Hiragino Sans GB.ttc",
            "/System/Library/Fonts/STHeiti Medium.ttc",
            "/System/Library/Fonts/Supplemental/Arial Bold.ttf" if bold else "/System/Library/Fonts/Supplemental/Arial.ttf",
        ]
    elif lang in ("ja", "jp"):
        candidates = [
            "/System/Library/Fonts/Hiragino Sans W6.ttc",
            "/System/Library/Fonts/Hiragino Sans W3.ttc",
        ]
    elif lang in ("ko", "kr"):
        candidates = [
            "/System/Library/Fonts/AppleSDGothicNeo.ttc",
        ]
    else:
        candidates = [
            "/System/Library/Fonts/SFNS.ttf",
            "/System/Library/Fonts/HelveticaNeue.ttc",
            "/System/Library/Fonts/Supplemental/Arial Bold.ttf" if bold else "/System/Library/Fonts/Supplemental/Arial.ttf",
            "/Library/Fonts/Arial Bold.ttf" if bold else "/Library/Fonts/Arial.ttf",
        ]

    for c in candidates:
        if os.path.exists(c):
            return c
    return None


def get_video_info(video_path: Path):
    cmd = [
        "ffprobe", "-v", "error",
        "-select_streams", "v:0",
        "-show_entries", "stream=width,height",
        "-of", "csv=s=,:p=0",
        str(video_path)
    ]
    res = subprocess.run(cmd, capture_output=True, text=True)
    w, h = 0, 0
    if res.returncode == 0 and "," in res.stdout:
        parts = res.stdout.strip().split(",")
        w = int(parts[0]) if len(parts) > 0 and parts[0].isdigit() else 0
        h = int(parts[1]) if len(parts) > 1 and parts[1].isdigit() else 0

    cmd_dur = [
        "ffprobe", "-v", "error",
        "-show_entries", "format=duration",
        "-of", "default=noprint_wrappers=1:nokey=1",
        str(video_path)
    ]
    res_dur = subprocess.run(cmd_dur, capture_output=True, text=True)
    dur = 0.0
    if res_dur.returncode == 0:
        try:
            dur = float(res_dur.stdout.strip())
        except ValueError:
            dur = 0.0

    return w, h, dur


def create_pill_overlay(width: int, height: int, item: dict, font_path: str, output_path: str, theme: dict, lang: str):
    """Draws a premium frosted glass pill badge with indicator dot and localized typography."""
    img = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    scale = width / 1080.0
    title_text = item.get("title", "")
    show_dot = item.get("show_dot", True)

    font_size = int(item.get("font_size", 42) * scale)
    try:
        font = ImageFont.truetype(font_path, font_size) if font_path else ImageFont.load_default()
    except Exception:
        font = ImageFont.load_default()

    is_cjk = any("\u4e00" <= ch <= "\u9fff" for ch in title_text)
    display_text = title_text if (is_cjk or item.get("keep_case", False)) else title_text.upper()
    tracking = int(4 * scale) if not is_cjk else int(2 * scale)

    chars = list(display_text)
    char_widths = [draw.textbbox((0, 0), c, font=font)[2] - draw.textbbox((0, 0), c, font=font)[0] for c in chars]
    tw = sum(char_widths) + (len(chars) - 1) * tracking
    sample_bbox = draw.textbbox((0, 0), "Hg", font=font)
    th = sample_bbox[3] - sample_bbox[1]

    dot_radius = int(5 * scale)
    dot_margin = int(16 * scale)
    has_dot = show_dot and not item.get("is_outro", False)
    content_w = tw + (dot_radius * 2 + dot_margin if has_dot else 0)

    pad_x = int(44 * scale)
    pad_y = int(18 * scale)

    card_w = content_w + (pad_x * 2)
    card_h = th + (pad_y * 2)

    card_x0 = (width - card_w) // 2
    top_percent = theme.get("top_percent", 0.082)
    card_y0 = int(height * top_percent)
    card_x1 = card_x0 + card_w
    card_y1 = card_y0 + card_h
    radius = card_h // 2

    # 1. Multi-layer diffused shadow
    draw.rounded_rectangle(
        [card_x0, card_y0 + int(8 * scale), card_x1, card_y1 + int(8 * scale)],
        radius=radius,
        fill=(0, 0, 0, 50)
    )
    draw.rounded_rectangle(
        [card_x0, card_y0 + int(4 * scale), card_x1, card_y1 + int(4 * scale)],
        radius=radius,
        fill=(0, 0, 0, 85)
    )

    # 2. Pill background & border
    pill_bg = hex_to_rgba(theme.get("pill_bg", DEFAULT_THEME["pill_bg"]))
    pill_outline = hex_to_rgba(theme.get("pill_outline", DEFAULT_THEME["pill_outline"]))
    border_w = max(1, int(1.5 * scale))

    draw.rounded_rectangle(
        [card_x0, card_y0, card_x1, card_y1],
        radius=radius,
        fill=pill_bg,
        outline=pill_outline,
        width=border_w
    )

    # 3. Content
    curr_x = card_x0 + pad_x
    text_y = card_y0 + pad_y - int(3 * scale)

    if has_dot:
        dot_center_y = card_y0 + (card_h // 2)
        dot_center_x = curr_x + dot_radius
        accent_color = hex_to_rgba(theme.get("accent_dot", DEFAULT_THEME["accent_dot"]))
        draw.ellipse(
            [dot_center_x - dot_radius, dot_center_y - dot_radius, dot_center_x + dot_radius, dot_center_y + dot_radius],
            fill=accent_color
        )
        curr_x += dot_radius * 2 + dot_margin

    text_color = hex_to_rgba(theme.get("text_color", DEFAULT_THEME["text_color"]))
    for c, cw in zip(chars, char_widths):
        draw.text((curr_x, text_y), c, font=font, fill=text_color)
        curr_x += cw + tracking

    img.save(output_path, "PNG")


def render_video_for_locale(
    input_video: Path,
    output_video: Path,
    storyboard: list,
    theme: dict,
    lang: str,
    target_w: int,
    target_h: int
):
    print(f"\n🎨 Rendering App Store Preview for [{lang}]...")
    temp_dir = output_video.parent / f".temp_overlays_{lang}"
    temp_dir.mkdir(parents=True, exist_ok=True)

    font_path = find_system_font(lang=lang, bold=True)
    overlay_files = []

    # Render transparent PNG overlays for each storyboard segment
    for idx, item in enumerate(storyboard):
        png_path = temp_dir / f"overlay_{idx:02d}.png"
        create_pill_overlay(target_w, target_h, item, font_path, str(png_path), theme, lang)
        overlay_files.append((str(png_path), float(item["start"]), float(item["end"])))

    # Build FFmpeg filter chain
    filter_chains = []
    # 1. Scale base video to canonical dimensions and force 30 fps CFR
    filter_chains.append(f"[0:v]scale={target_w}:{target_h}:flags=lanczos,fps=30,setpts=PTS-STARTPTS[base]")
    current_label = "base"

    _, _, dur = get_video_info(input_video)
    target_dur = min(dur, 30.0) if dur > 0 else 28.0

    fade_d = 0.35  # Smooth crossfade duration (seconds)
    cmd = ["ffmpeg", "-y", "-i", str(input_video)]

    for idx, (png_path, start, end) in enumerate(overlay_files):
        cmd.extend(["-framerate", "30", "-loop", "1", "-i", png_path])
        input_idx = idx + 1
        faded_label = f"faded_{idx}"
        next_label = f"v_{idx}"
        fade_out_start = max(start, end - fade_d)

        filter_chains.append(
            f"[{input_idx}:v]format=rgba,fade=in:st={start}:d={fade_d}:alpha=1,fade=out:st={fade_out_start}:d={fade_d}:alpha=1[{faded_label}]"
        )
        filter_chains.append(
            f"[{current_label}][{faded_label}]overlay=0:0:shortest=1[{next_label}]"
        )
        current_label = next_label

    full_filter = ";".join(filter_chains)
    audio_input_idx = len(overlay_files) + 1

    # Mandatory silent stereo AAC audio track (App Store Connect strictly requires an audio stream!)
    cmd.extend([
        "-f", "lavfi", "-i", "anullsrc=channel_layout=stereo:sample_rate=48000",
        "-filter_complex", full_filter,
        "-map", f"[{current_label}]",
        "-map", f"{audio_input_idx}:a",
        "-c:v", "libx264",
        "-preset", "fast",
        "-crf", "19",
        "-pix_fmt", "yuv420p",
        "-r", "30",
        "-c:a", "aac",
        "-b:a", "160k",
        "-ar", "48000",
        "-t", f"{target_dur:.2f}",
        "-shortest",
        str(output_video)
    ])

    print("⚡ Encoding canonical 30fps Apple App Store Preview video...")
    res = subprocess.run(cmd, capture_output=True, text=True)
    shutil.rmtree(temp_dir, ignore_errors=True)

    if res.returncode != 0:
        print(f"❌ FFmpeg failed: {res.stderr}")
        return False

    w, h, dur = get_video_info(output_video)
    size_mb = output_video.stat().st_size / (1024 * 1024)
    print(f"✅ Success! Generated [{lang}] App Preview:")
    print(f"   Dimensions: {w}x{h} px @ 30 fps")
    print(f"   Duration:   {dur:.1f}s (Apple required: 15-30s)")
    print(f"   File Size:  {size_mb:.2f} MB")
    print(f"   Path:       {output_video}")
    return True


def main():
    parser = argparse.ArgumentParser(description="GraceAppsLibrary App Store Preview Video Compositor & Encoder")
    parser.add_argument("--config", "-c", type=str, help="Path to preview_storyboard.json")
    parser.add_argument("--input", "-i", type=str, help="Input video file path")
    parser.add_argument("--lang", "-l", type=str, default="en", help="Language code (e.g. en, es, zh-Hans, or 'all')")
    parser.add_argument("--output", "-o", type=str, help="Output video file path")
    parser.add_argument("--fastlane", action="store_true", help="Export directly into fastlane/app-previews/<locale>/")
    parser.add_argument("--width", type=int, default=CANONICAL_WIDTH, help="Output width (default: 886)")
    parser.add_argument("--height", type=int, default=CANONICAL_HEIGHT, help="Output height (default: 1920)")

    args = parser.parse_args()

    project_root = Path.cwd()

    # Load configuration
    config_data = {}
    config_paths = [
        Path(args.config) if args.config else None,
        project_root / "Marketing" / "preview_storyboard.json",
        project_root / "preview_storyboard.json",
        project_root / "Marketing" / "video.json",
    ]
    for cp in config_paths:
        if cp and cp.is_file():
            try:
                config_data = json.loads(cp.read_text(encoding="utf-8"))
                print(f"📖 Loaded storyboard config from: {cp}")
                break
            except Exception as e:
                print(f"⚠️ Error reading config {cp}: {e}")

    theme = config_data.get("theme", DEFAULT_THEME)
    storyboards = config_data.get("storyboard", DEFAULT_STORYBOARD)

    # Determine languages to render
    target_langs = list(storyboards.keys()) if args.lang == "all" else [args.lang]

    video_dir = project_root / "Screenshots" / "Video"
    video_dir.mkdir(parents=True, exist_ok=True)

    for lang in target_langs:
        storyboard = storyboards.get(lang, storyboards.get("en", []))
        if not storyboard:
            print(f"⚠️ No storyboard entries found for [{lang}], skipping.")
            continue

        # Resolve input video
        if args.input:
            input_video = Path(args.input)
        else:
            candidates = sorted(
                list(video_dir.glob(f"promo_recording_{lang}_*.mp4")) or
                list(video_dir.glob(f"*_{lang}_*.mp4")) or
                list(video_dir.glob("promo_recording_*.mp4")) or
                list(video_dir.glob("*.mp4")),
                key=lambda p: p.stat().st_mtime,
                reverse=True
            )
            # Exclude already processed AppPreview or with_text files
            clean_candidates = [
                c for c in candidates
                if not c.name.startswith("AppPreview_")
                and not c.name.startswith("01_")
                and "_with_text" not in c.name
            ]
            input_video = clean_candidates[0] if clean_candidates else (candidates[0] if candidates else None)

        if not input_video or not input_video.is_file():
            print(f"❌ Error: No source video found for [{lang}] in {video_dir}. Run record_promo_video.sh first.")
            continue

        output_video = Path(args.output) if args.output else video_dir / f"AppPreview_{lang}.mp4"

        success = render_video_for_locale(
            input_video=input_video,
            output_video=output_video,
            storyboard=storyboard,
            theme=theme,
            lang=lang,
            target_w=args.width,
            target_h=args.height
        )

        if success and args.fastlane:
            # Map language to fastlane locales
            locale_map = {
                "en": ["en-US"],
                "es": ["es-ES", "es-MX"],
                "zh-Hans": ["zh-Hans"],
                "de": ["de-DE"],
                "fr": ["fr-FR"],
                "ja": ["ja"],
            }
            locales = locale_map.get(lang, [lang])
            fastlane_previews = project_root / "fastlane" / "app-previews"
            for loc in locales:
                dest_dir = fastlane_previews / loc
                dest_dir.mkdir(parents=True, exist_ok=True)
                dest_file = dest_dir / "01_IPHONE_67.mp4"
                shutil.copy2(output_video, dest_file)
                print(f"  🚀 Fastlane: Copied to {dest_file}")


if __name__ == "__main__":
    main()
