#!/usr/bin/env python3
"""
render_screenshots.py (GraceAppsLibrary Universal Renderer)

Config-driven App Store marketing screenshot generator and exporter.
Supports:
  - Slide Types:
      * standard-device  (Device frame + raw screenshot + header + ambient glow)
      * artwork-hero     (Full-bleed background artwork + localized text overlay)
      * feature-grid     (Bento-style frosted-glass feature cards with icons + copy)
      * scene-composite  (Background scene + positioned/rotated device mockup)
      * static-asset     (Passthrough for pre-rendered assets)
  - Typography: SF Pro Rounded, SF Pro Display, PingFang SC/TC, Hiragino Sans, Apple SD Gothic Neo
  - Multi-language localization matrix: en, zh-Hans, zh-Hant, de, es, ja, ko, fr
  - Per-slide theme overrides & custom Marketing/theme.css injection
  - Headless Chrome Retina export directly to target directories
"""

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional

# Supported standard App Store canvas resolutions (1:1 native pixels)
DEVICE_SPECS = {
    "iphone": {
        "name": "iPhone",
        "folder": "iPhone",
        "width": 1179,
        "height": 2556,
        "scale": 1,
    },
    "ipad": {
        "name": "iPad Pro",
        "folder": "iPad",
        "width": 2048,
        "height": 2732,
        "scale": 1,
    },
}

DEFAULT_LANGUAGES = [
    {"code": "English", "name": "English", "lang_tag": "en"},
    {"code": "Simplified Chinese", "name": "简体中文", "lang_tag": "zh-Hans"},
    {"code": "Traditional Chinese", "name": "繁體中文", "lang_tag": "zh-Hant"},
    {"code": "German", "name": "Deutsch", "lang_tag": "de"},
    {"code": "Spanish", "name": "Español", "lang_tag": "es"},
    {"code": "Japanese", "name": "日本語", "lang_tag": "ja"},
    {"code": "Korean", "name": "한국어", "lang_tag": "ko"},
    {"code": "French", "name": "Français", "lang_tag": "fr"},
]


def format_accent_text(text: str) -> str:
    """Converts markdown *accent* syntax into <span class='accent-text'>accent</span>."""
    if not text:
        return ""
    if "<span class=\"accent-text\">" in text or "<span class='accent-text'>" in text:
        return text
    # Convert *word* or *phrase* to accent-text
    return re.sub(r"\*([^*]+)\*", r'<span class="accent-text">\1</span>', text)


def build_html(config: Dict[str, Any], project_root: Path, out_html_path: Path) -> str:
    app_name = config.get("appName", "App")
    app_icon = config.get("appIcon", "../Assets.xcassets/AppIcon.appiconset/1024.png")
    bundle_id = config.get("bundleId", "")
    languages = config.get("languages", DEFAULT_LANGUAGES)
    slides = config.get("slides", [])
    default_theme = config.get("defaultTheme", {})
    themes = config.get("themes", {})

    # Check for custom CSS file in project
    custom_css = ""
    candidate_css = project_root / "Marketing" / "theme.css"
    if candidate_css.is_file():
        custom_css = candidate_css.read_text(encoding="utf-8")

    # Generate CSS themes
    theme_css_rules = []
    for theme_name, theme_data in themes.items():
        accent_grad = theme_data.get("accentGradient", "linear-gradient(135deg, #0284C7 0%, #0D9488 100%)")
        glow = theme_data.get("glow", "radial-gradient(circle, rgba(14, 165, 233, 0.35) 0%, rgba(13, 148, 136, 0.20) 45%, transparent 70%)")
        shadow_tint = theme_data.get("shadowTint", "rgba(13, 148, 136, 0.32)")
        bg = theme_data.get("background", "")
        bg_rule = f"background: {bg};" if bg else ""
        theme_css_rules.append(f"""
    .theme-{theme_name} {{
      --slide-accent-gradient: {accent_grad};
      --slide-glow-color: {glow};
      --slide-shadow-tint: {shadow_tint};
      {bg_rule}
    }}""")

    # Fallback default theme vars
    default_bg = default_theme.get("background", "linear-gradient(180deg, #EAF6FA 0%, #E4F5EC 100%)")
    default_accent = default_theme.get("accentGradient", "linear-gradient(135deg, #0284C7 0%, #0D9488 100%)")
    default_title_color = default_theme.get("titleColor", "#133440")
    default_subtitle_color = default_theme.get("subtitleColor", "#3B6978")

    # Typography configuration with robust defaults matching GraceApps visual standard
    typography_cfg = config.get("typography", {})
    iphone_typo = typography_cfg.get("iphone", {})
    ipad_typo = typography_cfg.get("ipad", {})

    iphone_title_size = iphone_typo.get("titleSize", "132px")
    iphone_sub_size = iphone_typo.get("subtitleSize", "76px")
    iphone_gap = iphone_typo.get("titleGap", "50px")
    iphone_pad_top = iphone_typo.get("paddingTop", "135px")
    iphone_mockup_top = iphone_typo.get("mockupTop", "740px")
    iphone_mockup_width = iphone_typo.get("mockupWidth", "968px")

    ipad_title_size = ipad_typo.get("titleSize", "140px")
    ipad_sub_size = ipad_typo.get("subtitleSize", "74px")
    ipad_gap = ipad_typo.get("titleGap", "22px")
    ipad_pad_top = ipad_typo.get("paddingTop", "116px")
    ipad_mockup_top = ipad_typo.get("mockupTop", "430px")
    ipad_mockup_width = ipad_typo.get("mockupWidth", "1480px")

    # Preprocess titles and subtitles to handle markdown *accents*
    processed_slides = []
    for s in slides:
        s_copy = dict(s)
        titles = s.get("titles", {})
        processed_titles = {}
        for lk, tv in titles.items():
            if isinstance(tv, dict):
                processed_titles[lk] = {
                    "iphone": format_accent_text(tv.get("iphone", "")),
                    "ipad": format_accent_text(tv.get("ipad", "")),
                }
            else:
                formatted = format_accent_text(str(tv))
                processed_titles[lk] = {"iphone": formatted, "ipad": formatted}
        s_copy["titles"] = processed_titles

        # Subtitles (can also contain markdown breaks/accents)
        subtitles = s.get("subtitles", {})
        processed_subs = {}
        for lk, sv in subtitles.items():
            if isinstance(sv, dict):
                processed_subs[lk] = {
                    "iphone": format_accent_text(sv.get("iphone", "")),
                    "ipad": format_accent_text(sv.get("ipad", "")),
                }
            else:
                formatted = format_accent_text(str(sv))
                processed_subs[lk] = {"iphone": formatted, "ipad": formatted}
        s_copy["subtitles"] = processed_subs
        processed_slides.append(s_copy)

    slides_json = json.dumps(processed_slides, ensure_ascii=False)
    languages_json = json.dumps(languages, ensure_ascii=False)

    themes_block = "\n".join(theme_css_rules)

    return f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>{app_name} App Store Screenshots</title>
  <style>
    /* ========================================================
       TYPOGRAPHY & ROOT VARIABLES (GraceApps Standard)
       ======================================================== */
    :root {{
      --font-rounded: ui-rounded, "SF Pro Rounded", -apple-system, BlinkMacSystemFont, "Plus Jakarta Sans", sans-serif;
      --font-display: -apple-system, BlinkMacSystemFont, "SF Pro Display", "Plus Jakarta Sans", sans-serif;
      --font-mono: "SF Mono", ui-monospace, Menlo, Consolas, monospace;
      --font-zh: "PingFang SC", "Noto Sans SC", ui-rounded, -apple-system, BlinkMacSystemFont, sans-serif;
      --font-zh-hant: "PingFang TC", "PingFang HK", "Noto Sans TC", ui-rounded, -apple-system, BlinkMacSystemFont, sans-serif;
      --font-ja: "Hiragino Sans", "Hiragino Kaku Gothic ProN", "Noto Sans JP", ui-rounded, -apple-system, BlinkMacSystemFont, sans-serif;
      --font-ko: "Apple SD Gothic Neo", "Pretendard", "Noto Sans KR", ui-rounded, -apple-system, BlinkMacSystemFont, sans-serif;

      --bg-gradient: {default_bg};
      --default-accent-gradient: {default_accent};
      --title-color: {default_title_color};
      --subtitle-color: {default_subtitle_color};
    }}

    * {{
      box-sizing: border-box;
      margin: 0;
      padding: 0;
      -webkit-font-smoothing: antialiased;
    }}

    body {{
      font-family: var(--font-display);
      background: #0B161B;
      color: #F0F6F8;
      padding: 32px 24px 80px;
      display: flex;
      flex-direction: column;
      align-items: center;
      gap: 36px;
    }}

    /* ========================================================
       THEMATIC PALETTES
       ======================================================== */
{themes_block}

    /* ========================================================
       PREVIEW TOOLBAR HEADER
       ======================================================== */
    .preview-header {{
      width: 100%;
      max-width: 1600px;
      display: flex;
      justify-content: space-between;
      align-items: center;
      background: #112027;
      padding: 16px 24px;
      border-radius: 16px;
      border: 1px solid #1E3742;
      box-shadow: 0 10px 30px rgba(0, 0, 0, 0.3);
      flex-wrap: wrap;
      gap: 16px;
    }}

    .header-left {{
      display: flex;
      align-items: center;
      gap: 16px;
    }}

    .app-icon {{
      width: 44px;
      height: 44px;
      border-radius: 10px;
      box-shadow: 0 4px 12px rgba(0, 0, 0, 0.3);
    }}

    .header-titles h1 {{
      font-size: 18px;
      font-weight: 700;
      color: #FFFFFF;
      letter-spacing: -0.01em;
    }}

    .header-titles p {{
      font-size: 13px;
      color: #79D4F2;
      margin-top: 2px;
    }}

    .controls {{
      display: flex;
      gap: 16px;
      align-items: center;
      flex-wrap: wrap;
    }}

    .control-group {{
      display: flex;
      align-items: center;
      gap: 8px;
      background: #091318;
      padding: 4px;
      border-radius: 10px;
      border: 1px solid #182B33;
    }}

    .control-label {{
      font-size: 11px;
      text-transform: uppercase;
      letter-spacing: 0.06em;
      color: #6C8B99;
      padding-left: 8px;
      font-weight: 600;
    }}

    .pill-btn {{
      background: transparent;
      border: none;
      color: #9EC0CF;
      padding: 6px 14px;
      border-radius: 7px;
      font-size: 12.5px;
      font-weight: 600;
      cursor: pointer;
      transition: all 0.15s ease;
    }}

    .pill-btn.active {{
      background: #53B8DA;
      color: #08212C;
      box-shadow: 0 2px 8px rgba(83, 184, 218, 0.35);
    }}

    .pill-btn:hover:not(.active) {{
      color: #FFFFFF;
    }}

    /* ========================================================
       ORIGINAL 1 COLUMN VIEW (Default)
       ======================================================== */
    .gallery {{
      display: flex;
      flex-direction: column;
      align-items: center;
      gap: 36px;
      max-width: 1700px;
      width: 100%;
    }}

    .slide-wrapper {{
      display: flex;
      flex-direction: column;
      align-items: center;
      gap: 12px;
    }}

    .slide-meta {{
      display: flex;
      align-items: center;
      gap: 10px;
      font-size: 12px;
      color: #88A6B2;
      font-family: var(--font-mono);
    }}

    .slide-meta .badge {{
      background: rgba(83, 184, 218, 0.2);
      color: #79D4F2;
      padding: 2px 8px;
      border-radius: 4px;
      font-weight: 600;
    }}

    /* ========================================================
       APPLE APP STORE VIEW (Side-by-side in a row)
       ======================================================== */
    body[data-view="appstore"]:not(.capture-mode) {{
      padding: 24px 24px 60px;
      align-items: center;
      background: #0B161B;
      overflow-x: hidden;
    }}

    body[data-view="appstore"]:not(.capture-mode) .preview-header {{
      max-width: 1750px;
      width: 100%;
      margin-bottom: 20px;
    }}

    body[data-view="appstore"]:not(.capture-mode) .gallery {{
      display: flex !important;
      flex-direction: row !important;
      flex-wrap: nowrap !important;
      justify-content: flex-start !important;
      align-items: center !important;
      gap: 14px !important;
      width: 100% !important;
      max-width: 100% !important;
      overflow-x: auto !important;
      overflow-y: hidden !important;
      padding: 10px 32px 30px !important;
      scroll-behavior: smooth;
      -webkit-overflow-scrolling: touch;
    }}

    body[data-view="appstore"]:not(.capture-mode) .slide-meta {{
      display: none !important;
    }}

    body[data-view="appstore"]:not(.capture-mode) .slide-wrapper {{
      flex: 0 0 auto !important;
      display: flex;
      flex-direction: column;
      align-items: center;
      zoom: 0.28;
    }}

    body[data-view="appstore"]:not(.capture-mode)[data-device="ipad"] .slide-wrapper {{
      zoom: 0.24;
    }}

    body[data-view="appstore"]:not(.capture-mode) .canvas {{
      border-radius: 40px !important;
      box-shadow: 0 14px 40px rgba(0, 0, 0, 0.45) !important;
    }}

    body.capture-mode .slide-wrapper {{
      zoom: 1 !important;
    }}

    .slide-wrapper {{
      display: flex;
      flex-direction: column;
      align-items: center;
      gap: 12px;
    }}

    .slide-meta {{
      display: flex;
      align-items: center;
      gap: 10px;
      font-size: 12px;
      color: #88A6B2;
      font-family: var(--font-mono);
    }}

    .slide-meta .badge {{
      background: rgba(83, 184, 218, 0.2);
      color: #79D4F2;
      padding: 2px 8px;
      border-radius: 4px;
      font-weight: 600;
    }}

    /* ========================================================
       CANVAS STYLING (Native 1:1 Pixel Dimensions)
       ======================================================== */
    .canvas {{
      position: relative;
      overflow: hidden;
      background: var(--bg-gradient);
      display: flex;
      flex-direction: column;
      align-items: center;
      box-shadow: 0 24px 60px rgba(0, 0, 0, 0.45);
      border-radius: 20px;
    }}

    .canvas.device-iphone {{
      width: 1179px;
      height: 2556px;
      padding-top: {iphone_pad_top};
    }}

    .canvas.device-ipad {{
      width: 2048px;
      height: 2732px;
      padding-top: {ipad_pad_top};
    }}

    /* Interactive preview scaling */
    .slide-wrapper .canvas.device-iphone {{
      transform: scale(0.33);
      transform-origin: top center;
      margin-bottom: calc(-2556px * 0.67 + 24px);
    }}

    .slide-wrapper .canvas.device-ipad {{
      transform: scale(0.33);
      transform-origin: top center;
      margin-bottom: calc(-2732px * 0.67 + 24px);
    }}

    /* Ambient Radial Glow */
    .ambient-glow {{
      position: absolute;
      left: 50%;
      transform: translateX(-50%);
      border-radius: 50%;
      pointer-events: none;
      z-index: 1;
      background: var(--slide-glow-color);
    }}

    .device-iphone .ambient-glow {{
      top: 660px;
      width: 1100px;
      height: 1100px;
      filter: blur(90px);
      opacity: 0.65;
    }}

    .device-ipad .ambient-glow {{
      top: 420px;
      width: 1800px;
      height: 1800px;
      filter: blur(120px);
      opacity: 0.65;
    }}

    /* Typographic Hierarchy */
    .caption-header {{
      text-align: center;
      position: relative;
      z-index: 10;
      width: 100%;
      padding: 0 40px;
    }}

    .caption-title {{
      font-family: var(--font-rounded);
      font-weight: 700;
      color: var(--title-color);
    }}

    .caption-subtitle {{
      font-family: var(--font-rounded);
      font-weight: 600;
      color: var(--subtitle-color);
    }}

    .accent-text {{
      background: var(--slide-accent-gradient, var(--default-accent-gradient));
      -webkit-background-clip: text;
      -webkit-text-fill-color: transparent;
      display: inline;
    }}

    .device-iphone .caption-title {{
      font-size: {iphone_title_size};
      line-height: 1.15;
      letter-spacing: -0.022em;
      margin-bottom: {iphone_gap};
    }}

    .device-iphone .caption-subtitle {{
      font-size: {iphone_sub_size};
      line-height: 1.34;
      letter-spacing: -0.01em;
    }}

    .device-ipad .caption-title {{
      font-size: {ipad_title_size};
      line-height: 1.15;
      letter-spacing: -0.02em;
      margin-bottom: {ipad_gap};
      white-space: nowrap;
    }}

    .device-ipad .caption-subtitle {{
      font-size: {ipad_sub_size};
      line-height: 1.26;
      letter-spacing: -0.01em;
      white-space: nowrap;
    }}

    /* Language specific font mappings */
    body[data-lang="Simplified Chinese"] .caption-title,
    body[data-lang="Simplified Chinese"] .caption-subtitle {{
      font-family: var(--font-zh);
    }}
    body[data-lang="Simplified Chinese"] .caption-title {{
      font-weight: 600;
      letter-spacing: 0.02em;
    }}
    body[data-lang="Traditional Chinese"] .caption-title,
    body[data-lang="Traditional Chinese"] .caption-subtitle {{
      font-family: var(--font-zh-hant);
    }}
    body[data-lang="Traditional Chinese"] .caption-title {{
      font-weight: 600;
      letter-spacing: 0.02em;
    }}
    body[data-lang="Japanese"] .caption-title,
    body[data-lang="Japanese"] .caption-subtitle {{
      font-family: var(--font-ja);
    }}
    body[data-lang="Japanese"] .caption-title {{
      font-weight: 700;
      letter-spacing: 0.01em;
    }}
    body[data-lang="Korean"] .caption-title,
    body[data-lang="Korean"] .caption-subtitle {{
      font-family: var(--font-ko);
    }}
    body[data-lang="Korean"] .caption-title {{
      font-weight: 700;
      letter-spacing: -0.01em;
    }}

    /* ========================================================
       SLIDE TYPE 1: STANDARD DEVICE FRAMES
       ======================================================== */
    .mockup-container {{
      position: absolute;
      left: 50%;
      transform: translateX(-50%);
      z-index: 10;
    }}

    .device-iphone .mockup-container {{
      top: {iphone_mockup_top};
      width: {iphone_mockup_width};
      min-height: calc(2556px - {iphone_mockup_top} + 40px);
      background: #0D0F11;
      padding: 14px 14px 40px 14px;
      border: 4px solid #C4C9CE;
      outline: 1px solid rgba(0, 0, 0, 0.28);
      border-radius: 114px 114px 0 0;
      box-shadow:
        0 4px 10px rgba(0, 0, 0, 0.12),
        0 20px 42px -8px rgba(19, 52, 64, 0.22),
        0 42px 95px -15px rgba(19, 52, 64, 0.32),
        0 0 110px -10px var(--slide-shadow-tint, rgba(0,0,0,0.2));
    }}

    .device-iphone .mockup-screen {{
      width: 100%;
      border-radius: 100px 100px 0 0;
      overflow: hidden;
      background: #000000;
    }}

    .device-iphone .mockup-img {{
      width: 100%;
      display: block;
      height: auto;
    }}

    .device-ipad .mockup-container {{
      top: {ipad_mockup_top};
      width: {ipad_mockup_width};
      background: #111315;
      padding: 44px;
      border: 4px solid #BAC0C4;
      outline: 1px solid rgba(0, 0, 0, 0.22);
      border-radius: 48px;
      box-shadow:
        0 4px 12px rgba(0, 0, 0, 0.10),
        0 24px 50px -10px rgba(19, 52, 64, 0.20),
        0 52px 115px -18px rgba(19, 52, 64, 0.28),
        0 0 130px -15px var(--slide-shadow-tint, rgba(0,0,0,0.2));
    }}

    .device-ipad .mockup-screen {{
      width: 100%;
      border-radius: 8px;
      overflow: hidden;
      background: #000000;
    }}

    .device-ipad .mockup-img {{
      width: 100%;
      display: block;
      height: auto;
    }}

    /* ========================================================
       SLIDE TYPE 2: ARTWORK HERO (Full-bleed Art + Localized Text)
       ======================================================== */
    .slide-artwork-hero {{
      position: relative;
      width: 100%;
      height: 100%;
      overflow: hidden;
    }}

    .artwork-bg-img {{
      position: absolute;
      inset: 0;
      width: 100%;
      height: 100%;
      object-fit: cover;
      z-index: 1;
    }}

    .artwork-hero-overlay {{
      position: relative;
      z-index: 10;
      width: 100%;
      height: 100%;
      display: flex;
      flex-direction: column;
      justify-content: flex-start;
      align-items: center;
      padding-top: 140px;
      text-align: center;
      background: linear-gradient(180deg, rgba(0,0,0,0.45) 0%, transparent 45%);
    }}

    .artwork-hero-overlay .caption-title {{
      color: #FFFFFF !important;
      text-shadow: 0 4px 24px rgba(0,0,0,0.85);
    }}

    .artwork-hero-overlay .caption-subtitle {{
      color: rgba(255,255,255,0.9) !important;
      text-shadow: 0 2px 16px rgba(0,0,0,0.85);
    }}

    /* ========================================================
       SLIDE TYPE 3: FEATURE GRID (Bento Cards with Icons)
       ======================================================== */
    .feature-grid-container {{
      position: absolute;
      top: 600px;
      left: 50%;
      transform: translateX(-50%);
      width: 960px;
      display: flex;
      flex-direction: column;
      gap: 24px;
      z-index: 10;
    }}

    /* ========================================================
       SLIDE TYPE 4: HERO POSTER (Pure HTML Cover Screen)
       ======================================================== */
    .slide-hero {{
      position: relative;
      width: 100%;
      height: 100%;
      overflow: hidden;
      background: var(--bg-gradient);
    }}

    .hero-identity {{
      position: absolute;
      top: 140px;
      left: 80px;
      display: flex;
      align-items: center;
      gap: 24px;
      z-index: 10;
    }}

    .hero-app-icon {{
      width: 92px;
      height: 92px;
      border-radius: 22px;
      box-shadow: 0 10px 28px rgba(0, 0, 0, 0.12), 0 2px 6px rgba(0, 0, 0, 0.06);
      display: block;
    }}

    .hero-app-name {{
      font-family: var(--font-rounded);
      font-size: 52px;
      font-weight: 700;
      color: var(--title-color, #204D36);
      letter-spacing: -0.01em;
    }}

    .hero-headline-container {{
      position: absolute;
      top: 290px;
      left: 80px;
      right: 80px;
      z-index: 10;
    }}

    .hero-headline {{
      font-family: var(--font-rounded);
      font-size: 116px;
      line-height: 1.14;
      font-weight: 800;
      letter-spacing: -0.025em;
      color: #56B87D;
      text-align: left;
    }}

    body[data-lang="Simplified Chinese"] .hero-headline,
    body[data-lang="Traditional Chinese"] .hero-headline {{
      font-family: var(--font-zh);
      font-size: 106px;
      line-height: 1.22;
      font-weight: 700;
      letter-spacing: -0.01em;
    }}

    body[data-lang="Japanese"] .hero-headline {{
      font-family: var(--font-ja);
      font-size: 88px;
      line-height: 1.25;
      font-weight: 700;
    }}

    body[data-lang="Korean"] .hero-headline {{
      font-family: var(--font-ko);
      font-size: 96px;
      line-height: 1.25;
      font-weight: 700;
    }}

    /* 3D Flashcards Stage */
    .hero-cards-stage {{
      position: absolute;
      top: 690px;
      left: 50%;
      transform: translateX(-50%);
      width: 1040px;
      height: 980px;
      perspective: 1200px;
      z-index: 10;
    }}

    .hero-flashcard {{
      position: absolute;
      border-radius: 34px;
      background: #FFFFFF;
      box-sizing: border-box;
      padding: 34px 42px;
      box-shadow: 0 32px 75px rgba(32, 77, 54, 0.16), 0 10px 24px rgba(0, 0, 0, 0.05);
      border: 1.5px solid rgba(41, 86, 65, 0.08);
    }}

    .hero-flashcard-1 {{
      top: 0px;
      left: 20px;
      width: 780px;
      height: 350px;
      transform: rotate(-5deg);
      z-index: 12;
    }}

    .hero-flashcard-2 {{
      top: 310px;
      right: 15px;
      width: 800px;
      height: 360px;
      transform: rotate(5deg);
      z-index: 14;
      box-shadow: 0 36px 85px rgba(32, 77, 54, 0.20), 0 12px 28px rgba(0, 0, 0, 0.06);
    }}

    .hero-flashcard-3 {{
      top: 610px;
      left: 35px;
      width: 790px;
      height: 350px;
      transform: rotate(-3deg);
      z-index: 16;
      box-shadow: 0 40px 92px rgba(32, 77, 54, 0.22), 0 14px 32px rgba(0, 0, 0, 0.06);
    }}

    .card-header {{
      display: flex;
      align-items: center;
      justify-content: space-between;
      margin-bottom: 12px;
    }}

    .card-badge {{
      font-family: var(--font-rounded);
      font-size: 21px;
      font-weight: 800;
      letter-spacing: 0.06em;
      padding: 6px 18px;
      border-radius: 12px;
      text-transform: uppercase;
    }}

    .badge-prefix {{
      background: #E6F4ED;
      color: #204D36;
    }}

    .badge-root {{
      background: #E2F1E8;
      color: #1A4630;
    }}

    .badge-suffix {{
      background: #EAF4EE;
      color: #23523B;
    }}

    .card-category {{
      font-family: var(--font-rounded);
      font-size: 21px;
      font-weight: 700;
      color: #7A9F8D;
      letter-spacing: 0.06em;
      text-transform: uppercase;
    }}

    .card-term {{
      font-family: var(--font-rounded);
      font-size: 74px;
      font-weight: 800;
      color: #1A3E2C;
      line-height: 1.05;
      letter-spacing: -0.02em;
    }}

    .card-meaning {{
      font-family: var(--font-rounded);
      font-size: 28px;
      font-weight: 600;
      color: #3E6B54;
      margin-top: 8px;
      line-height: 1.25;
    }}

    .card-ipa {{
      font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", sans-serif;
      font-weight: 400;
      color: #6C9380;
      margin-right: 8px;
    }}

    .card-examples {{
      display: flex;
      flex-wrap: wrap;
      gap: 12px;
      margin-top: 20px;
    }}

    .hero-flashcard-1 .card-examples {{
      max-width: 380px;
    }}

    .example-pill {{
      font-family: var(--font-rounded);
      font-size: 22px;
      font-weight: 600;
      color: #2F5943;
      background: #F1F6F2;
      padding: 8px 18px;
      border-radius: 12px;
      border: 1px solid rgba(41, 86, 65, 0.06);
    }}

    /* Curriculum Bento / Stat Chips */
    .hero-stats-row {{
      position: absolute;
      top: 1740px;
      left: 50%;
      transform: translateX(-50%);
      width: 1020px;
      display: flex;
      gap: 22px;
      justify-content: center;
      z-index: 10;
    }}

    .hero-stat-chip {{
      flex: 1;
      background: rgba(255, 255, 255, 0.90);
      backdrop-filter: blur(24px);
      -webkit-backdrop-filter: blur(24px);
      border: 1.5px solid rgba(41, 86, 65, 0.12);
      border-radius: 26px;
      padding: 22px 18px;
      text-align: center;
      box-shadow: 0 14px 34px rgba(32, 77, 54, 0.08);
    }}

    .stat-number {{
      font-family: var(--font-rounded);
      font-size: 54px;
      font-weight: 800;
      color: #204D36;
      line-height: 1;
      letter-spacing: -0.02em;
    }}

    .stat-label {{
      font-family: var(--font-rounded);
      font-size: 22px;
      font-weight: 700;
      color: #4D7661;
      margin-top: 8px;
      text-transform: uppercase;
      letter-spacing: 0.05em;
    }}

    body[data-lang="Simplified Chinese"] .stat-label,
    body[data-lang="Traditional Chinese"] .stat-label {{
      font-family: var(--font-zh);
      font-size: 22px;
    }}

    body[data-lang="Japanese"] .stat-label {{
      font-family: var(--font-ja);
      font-size: 20px;
    }}

    body[data-lang="Korean"] .stat-label {{
      font-family: var(--font-ko);
      font-size: 20px;
    }}

    /* Learning Methodology Feature Capsules */
    .hero-features-row {{
      position: absolute;
      top: 1910px;
      left: 50%;
      transform: translateX(-50%);
      width: 1020px;
      display: flex;
      gap: 18px;
      justify-content: center;
      z-index: 10;
    }}

    .hero-feature-capsule {{
      display: flex;
      align-items: center;
      gap: 12px;
      background: rgba(255, 255, 255, 0.90);
      backdrop-filter: blur(20px);
      -webkit-backdrop-filter: blur(20px);
      border: 1.5px solid rgba(41, 86, 65, 0.12);
      border-radius: 40px;
      padding: 16px 28px;
      box-shadow: 0 10px 28px rgba(32, 77, 54, 0.06);
    }}

    .feature-capsule-icon {{
      font-size: 26px;
      line-height: 1;
    }}

    .feature-capsule-text {{
      font-family: var(--font-rounded);
      font-size: 25px;
      font-weight: 700;
      color: var(--title-color, #204D36);
      letter-spacing: 0.02em;
      white-space: nowrap;
    }}

    body[data-lang="Simplified Chinese"] .feature-capsule-text,
    body[data-lang="Traditional Chinese"] .feature-capsule-text {{
      font-family: var(--font-zh);
      font-size: 25px;
    }}

    body[data-lang="Japanese"] .feature-capsule-text {{
      font-family: var(--font-ja);
      font-size: 23px;
    }}

    body[data-lang="Korean"] .feature-capsule-text {{
      font-family: var(--font-ko);
      font-size: 23px;
    }}

    /* Prestige Laurel Wreath Social Proof */
    .hero-laurel-badge {{
      position: absolute;
      top: 2070px;
      left: 50%;
      transform: translateX(-50%);
      width: 860px;
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 20px;
      z-index: 10;
    }}

    .laurel-branch {{
      height: 300px;
      width: auto;
      object-fit: contain;
      user-select: none;
      flex-shrink: 0;
    }}

    .laurel-center {{
      display: flex;
      flex-direction: column;
      align-items: center;
      text-align: center;
      gap: 10px;
    }}

    .laurel-title {{
      font-family: var(--font-rounded);
      font-size: 52px;
      font-weight: 800;
      color: #1E4D34;
      letter-spacing: 0.06em;
      text-transform: uppercase;
      line-height: 1.12;
      white-space: nowrap;
    }}

    body[data-lang="Simplified Chinese"] .laurel-title,
    body[data-lang="Traditional Chinese"] .laurel-title {{
      font-family: var(--font-zh);
      font-size: 52px;
      letter-spacing: 0.08em;
    }}

    body[data-lang="Japanese"] .laurel-title {{
      font-family: var(--font-ja);
      font-size: 44px;
      letter-spacing: 0.04em;
    }}

    body[data-lang="Korean"] .laurel-title {{
      font-family: var(--font-ko);
      font-size: 46px;
      letter-spacing: 0.04em;
    }}

    .laurel-stars {{
      color: #2D6A48;
      font-size: 36px;
      letter-spacing: 0.20em;
      line-height: 1;
    }}

    .laurel-sub {{
      font-family: var(--font-rounded);
      font-size: 22px;
      font-weight: 700;
      color: #55876E;
      letter-spacing: 0.08em;
      text-transform: uppercase;
      margin-top: 2px;
    }}

    body[data-lang="Simplified Chinese"] .laurel-sub,
    body[data-lang="Traditional Chinese"] .laurel-sub {{
      font-family: var(--font-zh);
      font-size: 22px;
    }}

    body[data-lang="Japanese"] .laurel-sub {{
      font-family: var(--font-ja);
      font-size: 20px;
    }}

    body[data-lang="Korean"] .laurel-sub {{
      font-family: var(--font-ko);
      font-size: 20px;
    }}

    body[data-lang="Simplified Chinese"] .hero-footer-text,
    body[data-lang="Traditional Chinese"] .hero-footer-text {{
      font-family: var(--font-zh);
      font-size: 56px;
      letter-spacing: 0.15em;
    }}

    body[data-lang="Japanese"] .hero-footer-text {{
      font-family: var(--font-ja);
      font-size: 54px;
      letter-spacing: 0.15em;
    }}

    body[data-lang="Korean"] .hero-footer-text {{
      font-family: var(--font-ko);
      font-size: 56px;
      letter-spacing: 0.15em;
    }}

    /* ========================================================
       HERO POSTER: iPad Specific Rules (2048 x 2732 px)
       ======================================================== */
    .device-ipad.slide-hero .hero-identity {{
      top: 140px;
      left: 140px;
      gap: 32px;
    }}

    .device-ipad.slide-hero .hero-app-icon {{
      width: 128px;
      height: 128px;
      border-radius: 30px;
      box-shadow: 0 14px 38px rgba(0, 0, 0, 0.14), 0 4px 10px rgba(0, 0, 0, 0.08);
    }}

    .device-ipad.slide-hero .hero-app-name {{
      font-size: 68px;
    }}

    .device-ipad.slide-hero .hero-headline-container {{
      top: 310px;
      left: 140px;
      right: 140px;
    }}

    .device-ipad.slide-hero .hero-headline {{
      font-size: 118px;
      line-height: 1.15;
    }}

    body[data-lang="Simplified Chinese"] .device-ipad.slide-hero .hero-headline,
    body[data-lang="Traditional Chinese"] .device-ipad.slide-hero .hero-headline {{
      font-size: 110px;
      line-height: 1.20;
    }}

    body[data-lang="Japanese"] .device-ipad.slide-hero .hero-headline {{
      font-size: 96px;
      line-height: 1.25;
    }}

    body[data-lang="Korean"] .device-ipad.slide-hero .hero-headline {{
      font-size: 104px;
      line-height: 1.25;
    }}

    /* iPad Cards Stage */
    .device-ipad.slide-hero .hero-cards-stage {{
      top: 670px;
      width: 1720px;
      height: 1080px;
    }}

    .device-ipad.slide-hero .hero-flashcard {{
      border-radius: 44px;
      padding: 42px 54px;
      box-shadow: 0 40px 95px rgba(32, 77, 54, 0.16), 0 14px 34px rgba(0, 0, 0, 0.05);
    }}

    .device-ipad.slide-hero .hero-flashcard-1 {{
      top: 0px;
      left: 40px;
      width: 1140px;
      height: 430px;
      transform: rotate(-4.5deg);
    }}

    .device-ipad.slide-hero .hero-flashcard-2 {{
      top: 310px;
      right: 40px;
      width: 1180px;
      height: 450px;
      transform: rotate(4.5deg);
      box-shadow: 0 46px 110px rgba(32, 77, 54, 0.20), 0 16px 40px rgba(0, 0, 0, 0.06);
    }}

    .device-ipad.slide-hero .hero-flashcard-3 {{
      top: 630px;
      left: 80px;
      width: 1160px;
      height: 440px;
      transform: rotate(-2.5deg);
      box-shadow: 0 50px 120px rgba(32, 77, 54, 0.22), 0 18px 44px rgba(0, 0, 0, 0.06);
    }}

    .device-ipad.slide-hero .card-badge {{
      font-size: 26px;
      padding: 8px 22px;
      border-radius: 14px;
    }}

    .device-ipad.slide-hero .card-category {{
      font-size: 26px;
    }}

    .device-ipad.slide-hero .card-term {{
      font-size: 92px;
    }}

    .device-ipad.slide-hero .card-meaning {{
      font-size: 34px;
      margin-top: 12px;
    }}

    .device-ipad.slide-hero .card-examples {{
      gap: 16px;
      margin-top: 26px;
    }}

    .device-ipad.slide-hero .hero-flashcard-1 .card-examples {{
      max-width: 540px;
    }}

    .device-ipad.slide-hero .example-pill {{
      font-size: 26px;
      padding: 10px 22px;
      border-radius: 16px;
    }}

    /* iPad Curriculum Stats */
    .device-ipad.slide-hero .hero-stats-row {{
      top: 1820px;
      width: 1680px;
      gap: 32px;
    }}

    .device-ipad.slide-hero .hero-stat-chip {{
      padding: 28px 24px;
      border-radius: 32px;
      box-shadow: 0 18px 44px rgba(32, 77, 54, 0.08);
    }}

    .device-ipad.slide-hero .stat-number {{
      font-size: 68px;
    }}

    .device-ipad.slide-hero .stat-label {{
      font-size: 26px;
      margin-top: 10px;
    }}

    /* iPad Methodology Capsules */
    .device-ipad.slide-hero .hero-features-row {{
      top: 2010px;
      width: 1540px;
      gap: 30px;
    }}

    .device-ipad.slide-hero .hero-feature-capsule {{
      padding: 24px 44px;
      border-radius: 50px;
      gap: 16px;
    }}

    .device-ipad.slide-hero .feature-capsule-icon {{
      font-size: 36px;
    }}

    .device-ipad.slide-hero .feature-capsule-text {{
      font-size: 32px;
    }}

    body[data-lang="Simplified Chinese"] .device-ipad.slide-hero .feature-capsule-text,
    body[data-lang="Traditional Chinese"] .device-ipad.slide-hero .feature-capsule-text {{
      font-size: 32px;
    }}

    body[data-lang="Japanese"] .device-ipad.slide-hero .feature-capsule-text {{
      font-size: 30px;
    }}

    body[data-lang="Korean"] .device-ipad.slide-hero .feature-capsule-text {{
      font-size: 30px;
    }}

    /* iPad Laurel Wreath Social Proof */
    .device-ipad.slide-hero .hero-laurel-badge {{
      top: 2190px;
      width: 1060px;
      gap: 24px;
    }}

    .device-ipad.slide-hero .laurel-branch {{
      height: 340px;
    }}

    .device-ipad.slide-hero .laurel-title {{
      font-size: 64px;
    }}

    body[data-lang="Simplified Chinese"] .device-ipad.slide-hero .laurel-title,
    body[data-lang="Traditional Chinese"] .device-ipad.slide-hero .laurel-title {{
      font-size: 64px;
    }}

    body[data-lang="Japanese"] .device-ipad.slide-hero .laurel-title {{
      font-size: 54px;
    }}

    body[data-lang="Korean"] .device-ipad.slide-hero .laurel-title {{
      font-size: 56px;
    }}

    .device-ipad.slide-hero .laurel-stars {{
      font-size: 44px;
      margin-top: 10px;
    }}

    .device-ipad.slide-hero .laurel-sub {{
      font-size: 26px;
      margin-top: 6px;
    }}

    .feature-card {{
      background: rgba(255, 255, 255, 0.72);
      backdrop-filter: blur(40px);
      -webkit-backdrop-filter: blur(40px);
      border: 2px solid rgba(255, 255, 255, 0.85);
      border-radius: 28px;
      padding: 32px 36px;
      display: flex;
      align-items: center;
      gap: 28px;
      box-shadow: 0 16px 40px rgba(19, 52, 64, 0.12);
    }}

    .feature-card-icon {{
      font-size: 48px;
      width: 72px;
      height: 72px;
      border-radius: 18px;
      background: var(--slide-accent-gradient, var(--default-accent-gradient));
      display: flex;
      align-items: center;
      justify-content: center;
      color: #FFFFFF;
      flex-shrink: 0;
      box-shadow: 0 6px 16px rgba(0,0,0,0.12);
    }}

    .feature-card-content {{
      display: flex;
      flex-direction: column;
      gap: 6px;
    }}

    .feature-card-title {{
      font-family: var(--font-rounded);
      font-size: 38px;
      font-weight: 700;
      color: var(--title-color);
      letter-spacing: -0.01em;
    }}

    .feature-card-desc {{
      font-family: var(--font-display);
      font-size: 24px;
      color: var(--subtitle-color);
      font-weight: 500;
    }}

    /* ========================================================
       CAPTURE MODE (used by Headless Google Chrome)
       ======================================================== */
    body.capture-mode {{
      padding: 0 !important;
      margin: 0 !important;
      background: transparent !important;
      display: block !important;
      overflow: hidden !important;
      width: 100% !important;
      height: 100% !important;
    }}

    body.capture-mode .preview-header,
    body.capture-mode .slide-meta {{
      display: none !important;
    }}

    body.capture-mode .gallery {{
      display: block !important;
      margin: 0 !important;
      padding: 0 !important;
      max-width: none !important;
      width: 100% !important;
      gap: 0 !important;
    }}

    body.capture-mode .slide-wrapper {{
      display: none !important;
    }}

    body.capture-mode .slide-wrapper.active-slide {{
      display: block !important;
      margin: 0 !important;
      padding: 0 !important;
      width: 100% !important;
      height: 100% !important;
    }}

    body.capture-mode .canvas {{
      border-radius: 0 !important;
      box-shadow: none !important;
      transform: none !important;
      margin: 0 !important;
    }}

    /* Custom CSS Overrides */
    {custom_css}
  </style>
</head>
<body data-lang="English" data-device="iphone">

  <header class="preview-header">
    <div class="header-left">
      <img src="{app_icon}" alt="App Icon" class="app-icon" onerror="this.style.display='none'" />
      <div class="header-titles">
        <h1>{app_name} Screenshots</h1>
        <p>GraceApps Universal Screenshot Engine</p>
      </div>
    </div>

    <div class="controls">
      <div class="control-group" id="device-selector">
        <span class="control-label">Device</span>
        <button class="pill-btn active" data-device="iphone">iPhone (1179 × 2556)</button>
        <button class="pill-btn" data-device="ipad">iPad Pro (2048 × 2732)</button>
      </div>

      <div class="control-group" id="lang-selector">
        <span class="control-label">Language</span>
        <!-- Populated dynamically -->
      </div>

      <div class="control-group" id="view-selector">
        <span class="control-label">View</span>
        <button class="pill-btn active" data-view="column">1 Column</button>
        <button class="pill-btn" data-view="appstore">Apple App Store</button>
      </div>
    </div>
  </header>

  <main class="gallery" id="gallery"></main>

  <script>
    const SLIDES = {slides_json};
    const LANGUAGES = {languages_json};

    let currentDevice = "iphone";
    let currentLang = "English";

    const params = new URLSearchParams(window.location.search);
    if (params.get("device")) currentDevice = params.get("device");
    if (params.get("lang")) currentLang = params.get("lang");
    const slideParam = params.get("slide");

    let currentView = params.get("view") || "column";

    if (slideParam) {{
      document.body.classList.add("capture-mode");
    }}

    document.body.setAttribute("data-lang", currentLang);
    document.body.setAttribute("data-device", currentDevice);
    document.body.setAttribute("data-view", currentView);

    function getRawImagePath(device, lang, filename) {{
      const folderDevice = device === "ipad" ? "iPad" : "iPhone";
      return `../Screenshots/Raw/${{folderDevice}}/${{encodeURIComponent(lang)}}/${{encodeURIComponent(filename)}}`;
    }}

    function renderGallery() {{
      const gallery = document.getElementById("gallery");
      gallery.innerHTML = "";

      SLIDES.forEach(slide => {{
        // Filter by device if slide defines specific devices
        if (slide.devices && !slide.devices.includes(currentDevice)) {{
          return;
        }}

        const slideType = slide.type || "standard-device";
        const titleObj = slide.titles ? (slide.titles[currentLang] || slide.titles["English"]) : null;
        const subObj = slide.subtitles ? (slide.subtitles[currentLang] || slide.subtitles["English"]) : null;

        const titleText = titleObj ? (currentDevice === "ipad" ? titleObj.ipad : titleObj.iphone) : "";
        const subText = subObj ? (currentDevice === "ipad" ? subObj.ipad : subObj.iphone) : "";

        const wrapper = document.createElement("div");
        wrapper.className = "slide-wrapper";
        wrapper.id = `slide-${{slide.id}}`;

        if (slideParam && slideParam === slide.id) {{
          wrapper.classList.add("active-slide");
        }}

        let slideContent = "";

        if (slideType === "artwork-hero") {{
          const artSrc = slide.artwork || "";
          slideContent = `
            <div class="canvas device-${{currentDevice}} slide-artwork-hero">
              <img src="${{artSrc}}" alt="Hero Artwork" class="artwork-bg-img" />
              <div class="artwork-hero-overlay">
                <div class="caption-header">
                  <h2 class="caption-title">${{titleText}}</h2>
                  <p class="caption-subtitle">${{subText}}</p>
                </div>
              </div>
            </div>
          `;
        }} else if (slideType === "feature-grid") {{
          const features = slide.features || [];
          const featureCards = features.map(f => {{
            const fTitle = typeof f.title === "object" ? (f.title[currentLang] || f.title["English"]) : f.title;
            const fDesc = f.description ? (typeof f.description === "object" ? (f.description[currentLang] || f.description["English"]) : f.description) : "";
            return `
              <div class="feature-card">
                <div class="feature-card-icon">${{f.icon || "✦"}}</div>
                <div class="feature-card-content">
                  <div class="feature-card-title">${{fTitle}}</div>
                  ${{fDesc ? `<div class="feature-card-desc">${{fDesc}}</div>` : ""}}
                </div>
              </div>
            `;
          }}).join("");

          slideContent = `
            <div class="canvas device-${{currentDevice}} theme-${{slide.theme || "default"}}">
              <div class="ambient-glow"></div>
              <div class="caption-header">
                <h2 class="caption-title">${{titleText}}</h2>
                <p class="caption-subtitle">${{subText}}</p>
              </div>
              <div class="feature-grid-container">
                ${{featureCards}}
              </div>
            </div>
          `;
        }} else if (slideType === "hero") {{
          const brandIcon = (slide.brand && slide.brand.icon) ? slide.brand.icon : '{app_icon}';
          const brandName = (slide.brand && slide.brand.name) ? (typeof slide.brand.name === "object" ? (slide.brand.name[currentLang] || slide.brand.name["English"]) : slide.brand.name) : '{app_name}';
          const heroTitle = titleObj ? (currentDevice === "ipad" ? titleObj.ipad : titleObj.iphone) : "";
          const quoteObj = slide.quote ? (typeof slide.quote === "object" ? (slide.quote[currentLang] || slide.quote["English"]) : slide.quote) : "";
          const quoteSubObj = slide.quoteSub ? (typeof slide.quoteSub === "object" ? (slide.quoteSub[currentLang] || slide.quoteSub["English"]) : slide.quoteSub) : "";

          // Flashcards (universal English learning content)
          const cardsData = slide.cards || [
            {{
              type: "prefix",
              category: "GREEK",
              term: "meta-",
              phonetic: "[ˈmɛtə]",
              badge: "PREFIX",
              meaning: "beyond · change",
              examples: ["metaphor", "metabolism", "metamorphosis"]
            }},
            {{
              type: "root",
              category: "LATIN",
              term: "struct",
              phonetic: "[strʌkt]",
              badge: "ROOT",
              meaning: "to build · form",
              examples: ["structure", "construct", "destruct"]
            }},
            {{
              type: "suffix",
              category: "GREEK",
              term: "-ology",
              phonetic: "[ˈɑːlədʒi]",
              badge: "SUFFIX",
              meaning: "study of · science",
              examples: ["biology", "psychology", "mythology"]
            }}
          ];

          const cardsHtml = cardsData.map((c, idx) => {{
            const badge = typeof c.badge === "object" ? (c.badge[currentLang] || c.badge["English"]) : (c.badge || "");
            const meaning = typeof c.meaning === "object" ? (c.meaning[currentLang] || c.meaning["English"]) : (c.meaning || "");
            const examplesHtml = (c.examples || []).map(ex => `<span class="example-pill">${{ex}}</span>`).join("");
            const badgeClass = c.type === "root" ? "badge-root" : (c.type === "suffix" ? "badge-suffix" : "badge-prefix");
            return `
              <div class="hero-flashcard hero-flashcard-${{idx + 1}}">
                <div class="card-header">
                  <span class="card-badge ${{badgeClass}}">${{badge}}</span>
                  <span class="card-category">${{c.category || ""}}</span>
                </div>
                <div class="card-term">${{c.term}}</div>
                <div class="card-meaning"><span class="card-ipa">${{c.phonetic || ""}}</span>${{meaning}}</div>
                <div class="card-examples">
                  ${{examplesHtml}}
                </div>
              </div>
            `;
          }}).join("");

          // Stats
          const statsData = slide.stats || [
            {{ count: "290", label: {{ "English": "Roots", "Simplified Chinese": "核心词根", "Traditional Chinese": "核心字根", "Japanese": "重要語根", "Korean": "핵심 어원" }} }},
            {{ count: "91", label: {{ "English": "Prefixes", "Simplified Chinese": "常用前缀", "Traditional Chinese": "常用前綴", "Japanese": "頻出接頭辞", "Korean": "빈출 접두사" }} }},
            {{ count: "60", label: {{ "English": "Suffixes", "Simplified Chinese": "构词后缀", "Traditional Chinese": "構詞後綴", "Japanese": "重要接尾辞", "Korean": "조어 접미사" }} }}
          ];

          const statsHtml = statsData.map(s => {{
            const label = typeof s.label === "object" ? (s.label[currentLang] || s.label["English"]) : (s.label || "");
            return `
              <div class="hero-stat-chip">
                <div class="stat-number">${{s.count}}</div>
                <div class="stat-label">${{label}}</div>
              </div>
            `;
          }}).join("");

          // Feature Capsules
          const featuresData = slide.features || [
            {{ icon: "⚡", title: {{ "English": "Active Recall", "Simplified Chinese": "主动回忆", "Traditional Chinese": "主動回想", "Japanese": "想起学習", "Korean": "능동 회상" }} }},
            {{ icon: "🔁", title: {{ "English": "Spaced Repetition", "Simplified Chinese": "间隔复习", "Traditional Chinese": "間隔複習", "Japanese": "分散学習", "Korean": "간격 반복" }} }},
            {{ icon: "🎯", title: {{ "English": "Daily Quizzes", "Simplified Chinese": "智能测验", "Traditional Chinese": "智能測驗", "Japanese": "実力クイズ", "Korean": "실전 퀴즈" }} }}
          ];

          const featuresHtml = featuresData.map(f => {{
            const fTitle = typeof f.title === "object" ? (f.title[currentLang] || f.title["English"]) : (f.title || "");
            return `
              <div class="hero-feature-capsule">
                <span class="feature-capsule-icon">${{f.icon || "✦"}}</span>
                <span class="feature-capsule-text">${{fTitle}}</span>
              </div>
            `;
          }}).join("");

          slideContent = `
            <div class="canvas device-${{currentDevice}} slide-hero">
              <div class="hero-identity">
                <img src="${{brandIcon}}" alt="App Icon" class="hero-app-icon" onerror="this.style.display='none'" />
                <span class="hero-app-name">${{brandName}}</span>
              </div>
              <div class="hero-headline-container">
                <h1 class="hero-headline">${{heroTitle}}</h1>
              </div>
              <div class="hero-cards-stage">
                ${{cardsHtml}}
              </div>
              <div class="hero-stats-row">
                ${{statsHtml}}
              </div>
              <div class="hero-features-row">
                ${{featuresHtml}}
              </div>
              <div class="hero-laurel-badge">
                <img src="laurel_branch_left.png" class="laurel-branch" alt="Laurel Left" onerror="this.style.display='none'" />
                <div class="laurel-center">
                  <div class="laurel-title">${{quoteObj}}</div>
                  <div class="laurel-stars">★★★★★</div>
                  ${{quoteSubObj ? `<div class="laurel-sub">${{quoteSubObj}}</div>` : ""}}
                </div>
                <img src="laurel_branch_right.png" class="laurel-branch" alt="Laurel Right" onerror="this.style.display='none'" />
              </div>
            </div>
          `;
        }} else {{
          // Default: standard-device
          const rawFilename = (typeof slide.rawFilename === 'object' ? slide.rawFilename[currentDevice] : slide.rawFilename) ||
                              (typeof slide.raw === 'object' ? slide.raw[currentDevice] : slide.raw) ||
                              (typeof slide.filename === 'object' ? slide.filename[currentDevice] : slide.filename);
          const imgSrc = getRawImagePath(currentDevice, currentLang, rawFilename);
          const subHtml = subText ? `<p class="caption-subtitle">${{subText}}</p>` : "";
          slideContent = `
            <div class="canvas device-${{currentDevice}} theme-${{slide.theme || "default"}}">
              <div class="ambient-glow"></div>
              <div class="caption-header">
                <h2 class="caption-title">${{titleText}}</h2>
                ${{subHtml}}
              </div>
              <div class="mockup-container">
                <div class="mockup-screen">
                  <img src="${{imgSrc}}" alt="${{rawFilename}}" class="mockup-img" loading="eager" />
                </div>
              </div>
            </div>
          `;
        }}

        const displayFn = typeof slide.filename === 'object' ? (slide.filename[currentDevice] || slide.id) : (slide.filename || slide.id);
        wrapper.innerHTML = `
          <div class="slide-meta">
            <span class="badge">Slide ${{slide.id}}</span>
            <span>${{displayFn}} (${{slideType}})</span>
          </div>
          ${{slideContent}}
        `;

        gallery.appendChild(wrapper);
      }});
    }}

    // Render language buttons
    const langSelector = document.getElementById("lang-selector");
    LANGUAGES.forEach(lang => {{
      const btn = document.createElement("button");
      btn.className = `pill-btn ${{lang.code === currentLang ? "active" : ""}}`;
      btn.setAttribute("data-lang", lang.code);
      btn.textContent = lang.name;
      btn.addEventListener("click", () => {{
        document.querySelectorAll("#lang-selector .pill-btn").forEach(b => b.classList.remove("active"));
        btn.classList.add("active");
        currentLang = lang.code;
        document.body.setAttribute("data-lang", currentLang);
        renderGallery();
      }});
      langSelector.appendChild(btn);
    }});

    // Device selector events
    document.querySelectorAll("#device-selector .pill-btn").forEach(btn => {{
      btn.addEventListener("click", () => {{
        document.querySelectorAll("#device-selector .pill-btn").forEach(b => b.classList.remove("active"));
        btn.classList.add("active");
        currentDevice = btn.getAttribute("data-device");
        document.body.setAttribute("data-device", currentDevice);
        renderGallery();
      }});
    }});

    // View selector events (1 Column vs Apple App Store)
    const viewButtons = document.querySelectorAll("#view-selector .pill-btn");
    viewButtons.forEach(btn => {{
      const bView = btn.getAttribute("data-view");
      if (bView === currentView) {{
        viewButtons.forEach(b => b.classList.remove("active"));
        btn.classList.add("active");
      }}
      btn.addEventListener("click", () => {{
        viewButtons.forEach(b => b.classList.remove("active"));
        btn.classList.add("active");
        currentView = btn.getAttribute("data-view");
        document.body.setAttribute("data-view", currentView);
      }});
    }});

    // Horizontal wheel scrolling for App Store carousel
    const galleryEl = document.getElementById("gallery");
    galleryEl.addEventListener("wheel", (evt) => {{
      if (evt.deltaY !== 0 && evt.deltaX === 0) {{
        evt.preventDefault();
        galleryEl.scrollLeft += evt.deltaY;
      }}
    }}, {{ passive: false }});

    renderGallery();
  </script>
</body>
</html>
"""


def find_chrome() -> str:
    env_bin = os.environ.get("CHROME_BIN")
    if env_bin and os.path.isfile(env_bin) and os.access(env_bin, os.X_OK):
        return env_bin
    default_mac = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
    if os.path.isfile(default_mac) and os.access(default_mac, os.X_OK):
        return default_mac
    which_chrome = shutil.which("google-chrome") or shutil.which("chromium")
    if which_chrome:
        return which_chrome
    raise FileNotFoundError("Google Chrome not found. Please install Chrome or set CHROME_BIN.")


def export_screenshots(
    html_file: Path,
    config: Dict[str, Any],
    out_dir: Path,
    target_devices: List[str],
    target_languages: List[str],
    chrome_bin: str,
):
    slides = config.get("slides", [])
    languages = config.get("languages", DEFAULT_LANGUAGES)
    lang_codes = [l["code"] for l in languages]

    file_url = f"file://{html_file.resolve().as_posix()}"

    for dev_key in target_devices:
        dev_spec = DEVICE_SPECS[dev_key]
        dev_folder = dev_spec["folder"]
        w = dev_spec["width"]
        h = dev_spec["height"]

        print(f"\n========================================================")
        print(f"🚀 Exporting App Store Screenshots for {dev_spec['name']} ({w} × {h} px)")
        print(f"========================================================")

        for lang in target_languages:
            if lang not in lang_codes:
                continue

            lang_dir = out_dir / dev_folder / lang
            lang_dir.mkdir(parents=True, exist_ok=True)
            print(f"\n🌐 Language: {lang}")

            for slide in slides:
                # Check device filtering
                if slide.get("devices") and dev_key not in slide["devices"]:
                    continue

                slide_id = slide["id"]
                stype = slide.get("type", "standard-device")
                fn_val = slide.get("filename", f"Slide-{slide_id}.png")
                filename = fn_val.get(dev_key, f"Slide-{slide_id}.png") if isinstance(fn_val, dict) else fn_val
                target_path = lang_dir / filename

                # Handle static-asset passthrough
                if stype == "static-asset":
                    assets = slide.get("assets", {})
                    src_asset = assets.get(lang) or assets.get("universal") or slide.get("asset")
                    if src_asset and Path(src_asset).is_file():
                        src_path = Path(src_asset)
                        if src_path.suffix.lower() == target_path.suffix.lower():
                            shutil.copyfile(src_path, target_path)
                        else:
                            try:
                                from PIL import Image
                                im = Image.open(src_path)
                                im.save(target_path)
                            except Exception:
                                shutil.copyfile(src_path, target_path)
                        print(f"  ✅ [static-asset] {filename}")
                        continue

                # Headless Chrome export
                target_url = f"{file_url}?device={dev_key}&lang={lang}&slide={slide_id}"

                cmd = [
                    chrome_bin,
                    "--headless=new",
                    "--disable-gpu",
                    "--hide-scrollbars",
                    f"--window-size={w},{h}",
                    f"--screenshot={target_path}",
                    target_url,
                ]

                proc = subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                if proc.returncode == 0 and target_path.is_file():
                    print(f"  ✅ [{slide_id}] {filename}")
                else:
                    print(f"  ❌ Failed to render [{slide_id}] {filename}")


def main():
    parser = argparse.ArgumentParser(description="GraceAppsLibrary Universal Screenshot Renderer")
    parser.add_argument("--config", help="Path to screenshots.json config file")
    parser.add_argument("--project-root", help="Root directory of the app project")
    parser.add_argument("--output-dir", help="Output directory (default: Screenshots/AppStore)")
    parser.add_argument("--html-out", help="Path to write generated HTML (default: Marketing/screenshots.html)")
    parser.add_argument("--device", default="all", choices=["iphone", "ipad", "all"], help="Device filter")
    parser.add_argument("--lang", default="all", help="Language filter (e.g. English, all, or comma-separated)")
    parser.add_argument("--html-only", action="store_true", help="Only rebuild HTML, skip Chrome export")
    parser.add_argument("--chrome-bin", help="Path to Google Chrome binary")

    args = parser.parse_args()

    project_root = Path(args.project_root or os.getcwd()).resolve()

    # Discover config file
    config_path = None
    if args.config:
        config_path = Path(args.config).resolve()
    else:
        for candidate in ["screenshots.json", "Marketing/screenshots.json"]:
            p = project_root / candidate
            if p.is_file():
                config_path = p
                break

    if not config_path or not config_path.is_file():
        print(f"❌ Error: screenshots.json not found in {project_root}")
        sys.exit(1)

    print(f"📄 Loaded configuration: {config_path}")
    with open(config_path, "r", encoding="utf-8") as f:
        config = json.load(f)

    # Determine HTML output path
    html_out = Path(args.html_out).resolve() if args.html_out else (project_root / "Marketing" / "screenshots.html")
    html_out.parent.mkdir(parents=True, exist_ok=True)

    # Generate HTML
    html_content = build_html(config, project_root, html_out)
    with open(html_out, "w", encoding="utf-8") as f:
        f.write(html_content)
    print(f"✅ Generated template: {html_out} ({len(html_content):,} bytes)")

    if args.html_only:
        print("🎉 HTML build complete (--html-only specified).")
        return

    # Find Chrome
    chrome_bin = args.chrome_bin or find_chrome()

    # Determine devices
    devices = ["iphone", "ipad"] if args.device == "all" else [args.device]

    # Determine languages
    all_config_langs = [l["code"] for l in config.get("languages", DEFAULT_LANGUAGES)]
    if args.lang == "all":
        languages = all_config_langs
    else:
        languages = [l.strip() for l in args.lang.split(",") if l.strip()]

    out_dir = Path(args.output_dir).resolve() if args.output_dir else (project_root / "Screenshots" / "AppStore")
    export_screenshots(html_out, config, out_dir, devices, languages, chrome_bin)
    print(f"\n🎉 All screenshots rendered successfully to: {out_dir}")


if __name__ == "__main__":
    main()
