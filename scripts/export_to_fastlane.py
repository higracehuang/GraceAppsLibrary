#!/usr/bin/env python3
"""
export_to_fastlane.py (GraceAppsLibrary Shared Fastlane Exporter)

Transforms an app's AppInfo markdown (APP_INFO.md, RELEASE_NOTES.md) and rendered
App Store screenshots (Screenshots/AppStore/) into the Fastlane / App Store Connect
directory structure:
  fastlane/
    metadata/<locale>/
      name.txt, subtitle.txt, description.txt, keywords.txt,
      promotional_text.txt, release_notes.txt, support_url.txt, marketing_url.txt, privacy_url.txt
    screenshots/<locale>/
      01_iPhone_6.7.png, 01_iPad_12.9.png, ...

Auto-detects MARKETING_VERSION from *.xcodeproj/project.pbxproj and discovers
APP_INFO.md / RELEASE_NOTES.md automatically unless explicitly provided.
"""

import argparse
import datetime
import json
import re
import shutil
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple
from urllib.parse import urlsplit, urlunsplit


DEFAULT_LOCALE_CONFIG: Dict[str, Dict[str, Any]] = {
    "en-US": {
        "app_info_headers": ["US Storefront", "English"],
        "release_notes_headers": ["English"],
        "screenshot_folders": ["English", "en-US", "en"],
        "url_prefix": "",
    },
    "zh-Hans": {
        "app_info_headers": ["China Storefront", "Simplified Chinese", "Chinese"],
        "release_notes_headers": ["Chinese", "Simplified Chinese"],
        "screenshot_folders": ["Simplified Chinese", "Chinese", "zh-Hans", "zh"],
        "url_prefix": "zh",
    },
    "zh-Hant": {
        "app_info_headers": ["Taiwan Storefront", "Hong Kong Storefront", "Traditional Chinese"],
        "release_notes_headers": ["Traditional Chinese"],
        "screenshot_folders": ["Traditional Chinese", "zh-Hant"],
        "url_prefix": "zh-hant",
    },
    "de-DE": {
        "app_info_headers": ["German Storefront", "Germany Storefront", "German"],
        "release_notes_headers": ["German"],
        "screenshot_folders": ["German", "de-DE", "de"],
        "url_prefix": "de",
    },
    "es-ES": {
        "app_info_headers": ["Spanish Storefront", "Spain Storefront", "Spanish"],
        "release_notes_headers": ["Spanish"],
        "screenshot_folders": ["Spanish", "es-ES", "es"],
        "url_prefix": "es",
    },
    "ja": {
        "app_info_headers": ["Japan Storefront", "Japanese"],
        "release_notes_headers": ["Japanese"],
        "screenshot_folders": ["Japanese", "ja"],
        "url_prefix": "ja",
    },
    "ko": {
        "app_info_headers": ["Korea Storefront", "Korean"],
        "release_notes_headers": ["Korean"],
        "screenshot_folders": ["Korean", "ko"],
        "url_prefix": "ko",
    },
    "fr-FR": {
        "app_info_headers": ["France Storefront", "French Storefront", "French"],
        "release_notes_headers": ["French"],
        "screenshot_folders": ["French", "fr-FR", "fr"],
        "url_prefix": "fr",
    },
}

LIMITS = {
    "name": 30,
    "subtitle": 30,
    "keywords": 100,
    "promotional_text": 170,
    "description": 4000,
    "release_notes": 4000,
}

DEFAULT_DEVICE_MAPPING = [
    ("iPhone", "iPhone_6.7"),
    ("iPad", "iPad_12.9"),
]


def discover_pbxproj(project_root: Path) -> Path:
    candidates = sorted(project_root.glob("*.xcodeproj/project.pbxproj"))
    if not candidates:
        raise FileNotFoundError(f"Could not locate *.xcodeproj/project.pbxproj under {project_root}")
    return candidates[0]


def discover_doc(project_root: Path, filename: str) -> Path:
    preferred = [
        project_root / project_root.name / "AppInfo" / filename,
        project_root / "AppInfo" / filename,
    ]
    for path in preferred:
        if path.is_file():
            return path
    matches = sorted(
        p for p in project_root.rglob(filename)
        if "DerivedData" not in p.parts and ".build" not in p.parts and "fastlane" not in p.parts
    )
    if matches:
        return matches[0]
    raise FileNotFoundError(f"Could not find {filename} under {project_root}")


def detect_marketing_version(pbxproj_path: Path, bundle_id: Optional[str] = None) -> str:
    if not pbxproj_path.is_file():
        raise FileNotFoundError(f"Could not find {pbxproj_path}")
    content = pbxproj_path.read_text(encoding="utf-8")

    if bundle_id:
        pattern = re.compile(
            rf"MARKETING_VERSION\s*=\s*([0-9]+\.[0-9]+(?:\.[0-9]+)?)\s*;\s*\n\s*PRODUCT_BUNDLE_IDENTIFIER\s*=\s*{re.escape(bundle_id)};"
        )
        match = pattern.search(content)
        if match:
            return match.group(1)

    versions = re.findall(r"MARKETING_VERSION\s*=\s*([0-9]+\.[0-9]+(?:\.[0-9]+)?)\s*;", content)
    non_test = [v for v in versions if v != "1.0"]
    if non_test:
        return non_test[0]
    if versions:
        return versions[0]
    raise ValueError(f"Could not detect MARKETING_VERSION in {pbxproj_path}")


def extract_global_urls(app_info_text: str) -> Tuple[str, str, str]:
    seller_match = re.search(r"\*\*(?:Seller|Marketing) URL\*\*:\s*(\S+)", app_info_text)
    privacy_match = re.search(r"\*\*Privacy Policy URL\*\*:\s*(\S+)", app_info_text)
    support_match = re.search(r"\*\*Support URL\*\*:\s*(\S+)", app_info_text)

    marketing_url = seller_match.group(1).strip() if seller_match else ""
    privacy_url = privacy_match.group(1).strip() if privacy_match else ""
    support_url = support_match.group(1).strip() if support_match else ""
    return marketing_url, privacy_url, support_url


def localized_marketing_url(base_url: str, url_prefix: str) -> str:
    if not base_url or not url_prefix:
        return base_url
    parts = urlsplit(base_url)
    clean_path = parts.path.lstrip("/")
    new_path = f"/{url_prefix}/{clean_path}" if clean_path else f"/{url_prefix}"
    return urlunsplit((parts.scheme, parts.netloc, new_path, parts.query, parts.fragment))


def extract_code_block_after(section_text: str, heading_prefix: str) -> str:
    pattern = re.compile(
        rf"###\s+{re.escape(heading_prefix)}[^\n]*\n(?:(?!###)[\s\S])*?```\w*\n([\s\S]*?)\n```",
        re.MULTILINE,
    )
    match = pattern.search(section_text)
    if not match:
        raise ValueError(f"Could not find code block under '### {heading_prefix}' in section.")
    return match.group(1).strip()


def parse_app_info(
    app_info_path: Path,
    locale_config: Dict[str, Dict[str, Any]],
    explicit_locales: Optional[List[str]] = None,
) -> Tuple[Tuple[str, str, str], Dict[str, Dict[str, str]]]:
    text = app_info_path.read_text(encoding="utf-8")
    urls = extract_global_urls(text)

    sections = re.split(r"^##\s+", text, flags=re.MULTILINE)
    parsed: Dict[str, Dict[str, str]] = {}

    target_locales = explicit_locales or list(locale_config.keys())
    for locale in target_locales:
        cfg = locale_config[locale]
        headers = cfg.get("app_info_headers") or ([cfg["app_info_header"]] if "app_info_header" in cfg else [])
        matching_section = None
        for sec in sections:
            first_line = sec.splitlines()[0] if sec.splitlines() else ""
            if any(h in first_line for h in headers):
                matching_section = sec
                break

        if not matching_section:
            if explicit_locales:
                raise ValueError(f"Missing storefront section {headers} for locale {locale} in {app_info_path}")
            continue

        parsed[locale] = {
            "name": extract_code_block_after(matching_section, "App Title"),
            "subtitle": extract_code_block_after(matching_section, "Subtitle"),
            "keywords": extract_code_block_after(matching_section, "Keywords"),
            "promotional_text": extract_code_block_after(matching_section, "Promotional Text"),
            "description": extract_code_block_after(matching_section, "Description"),
        }

    if not parsed:
        raise ValueError(f"No storefront sections matched in {app_info_path}")

    return urls, parsed


def parse_release_notes(
    release_notes_path: Path,
    version: str,
    locales: List[str],
    locale_config: Dict[str, Dict[str, Any]],
) -> Dict[str, str]:
    text = release_notes_path.read_text(encoding="utf-8")
    version_pattern = re.compile(
        rf"^##+\s+(?:Release\s+)?{re.escape(version)}\s*$([\s\S]*?)(?=^##\s+[0-9]|\Z)",
        re.MULTILINE,
    )
    match = version_pattern.search(text)
    if not match:
        raise ValueError(f"Could not find release notes section for version {version} in {release_notes_path}")

    version_block = match.group(1)
    notes_by_locale: Dict[str, str] = {}

    for locale in locales:
        cfg = locale_config[locale]
        headers = cfg.get("release_notes_headers") or ([cfg["release_notes_header"]] if "release_notes_header" in cfg else [])
        lang_match = None
        for lang_header in headers:
            lang_pattern = re.compile(
                rf"^###\s+{re.escape(lang_header)}\s*$([\s\S]*?)(?=^###\s+|\Z)",
                re.MULTILINE,
            )
            lang_match = lang_pattern.search(version_block)
            if lang_match:
                break
        if not lang_match:
            raise ValueError(
                f"Could not find release notes header {headers} under version {version} in {release_notes_path}"
            )
        notes_by_locale[locale] = lang_match.group(1).strip()

    return notes_by_locale


def validate_and_write_metadata(
    project_root: Path,
    app_info_path: Path,
    release_notes_path: Path,
    metadata_dir: Path,
    version: str,
    locale_config: Dict[str, Dict[str, Any]],
    explicit_locales: Optional[List[str]],
    url_overrides: Dict[str, str],
    marketing_url_overrides: Dict[str, str],
    copyright_text: str,
    dry_run: bool,
) -> List[str]:
    print(f"📋 Parsing metadata from {app_info_path.relative_to(project_root)} and {release_notes_path.relative_to(project_root)} (v{version})...")
    (parsed_marketing_url, parsed_privacy_url, parsed_support_url), app_info_by_locale = parse_app_info(
        app_info_path, locale_config, explicit_locales
    )
    active_locales = list(app_info_by_locale.keys())
    release_notes_by_locale = parse_release_notes(release_notes_path, version, active_locales, locale_config)

    base_marketing_url = url_overrides.get("marketing_url") or parsed_marketing_url
    privacy_url = url_overrides.get("privacy_url") or parsed_privacy_url
    support_url = url_overrides.get("support_url") or parsed_support_url

    errors: List[str] = []
    for locale, fields in app_info_by_locale.items():
        cfg = locale_config[locale]
        fields["release_notes"] = release_notes_by_locale[locale]
        if support_url:
            fields["support_url"] = support_url
        if privacy_url:
            fields["privacy_url"] = privacy_url
        m_url = (
            marketing_url_overrides.get(locale)
            or cfg.get("marketing_url")
            or localized_marketing_url(base_marketing_url, cfg.get("url_prefix", ""))
        )
        if m_url:
            fields["marketing_url"] = m_url

        print(f"\n🌐 [{locale}] Character count validation:")
        for field_name, limit in LIMITS.items():
            val = fields[field_name]
            char_len = len(val)
            status = "✅" if 0 < char_len <= limit else "❌"
            print(f"  {status} {field_name}.txt: {char_len} / {limit} chars")
            if char_len > limit:
                errors.append(f"[{locale}] {field_name}.txt exceeds limit ({char_len} > {limit})")
            if char_len == 0:
                errors.append(f"[{locale}] {field_name}.txt is empty")

    if errors:
        print("\n❌ Pre-flight validation failed:")
        for err in errors:
            print(f"  - {err}")
        sys.exit(1)

    if dry_run:
        print(f"\n🏃 [dry-run] Validated metadata for {len(active_locales)} locale(s); skipping disk writes.")
        return active_locales

    for locale, fields in app_info_by_locale.items():
        locale_dir = metadata_dir / locale
        locale_dir.mkdir(parents=True, exist_ok=True)
        for field_name, value in fields.items():
            out_file = locale_dir / f"{field_name}.txt"
            out_file.write_text(value.strip() + "\n", encoding="utf-8")

    metadata_dir.mkdir(parents=True, exist_ok=True)
    (metadata_dir / "copyright.txt").write_text(copyright_text.strip() + "\n", encoding="utf-8")
    print(f"\n✅ Successfully exported Fastlane metadata to {metadata_dir.relative_to(project_root)}/")
    return active_locales


def resolve_screenshot_source_dir(
    screenshots_src_dir: Path,
    device_folder: str,
    folder_candidates: List[str],
) -> Optional[Path]:
    for name in folder_candidates:
        candidate = screenshots_src_dir / device_folder / name
        if candidate.is_dir():
            return candidate
    return None


def export_screenshots(
    project_root: Path,
    screenshots_src_dir: Path,
    screenshots_dst_dir: Path,
    locales: List[str],
    locale_config: Dict[str, Dict[str, Any]],
    device_mapping: List[Tuple[str, str]],
    dry_run: bool,
) -> None:
    print(f"\n🖼️  Exporting screenshots from {screenshots_src_dir.relative_to(project_root)}/ to {screenshots_dst_dir.relative_to(project_root)}/...")

    total_copied = 0
    for locale in locales:
        cfg = locale_config[locale]
        folder_candidates = cfg.get("screenshot_folders") or (
            [cfg["screenshot_folder"]] if "screenshot_folder" in cfg else [locale]
        )

        locale_entries: List[Tuple[Path, str]] = []
        for src_device_folder, dst_device_tag in device_mapping:
            src_dir = resolve_screenshot_source_dir(screenshots_src_dir, src_device_folder, folder_candidates)
            if src_dir is None:
                raise FileNotFoundError(
                    f"Missing screenshot source directory under {screenshots_src_dir / src_device_folder} for locale {locale} (tried {folder_candidates})"
                )

            png_files = sorted(src_dir.glob("*.png"))
            if not png_files:
                raise FileNotFoundError(f"No PNG screenshots found in {src_dir}")

            for idx, png_path in enumerate(png_files, start=1):
                prefix_match = re.match(r"^(\d+[A-Za-z]?)\b", png_path.stem)
                slide_order = prefix_match.group(1) if prefix_match else f"{idx:02d}"
                dst_name = f"{slide_order}_{dst_device_tag}.png"
                locale_entries.append((png_path, dst_name))

        if not dry_run:
            dst_locale_dir = screenshots_dst_dir / locale
            if dst_locale_dir.exists():
                shutil.rmtree(dst_locale_dir)
            dst_locale_dir.mkdir(parents=True, exist_ok=True)
            for src_path, dst_name in locale_entries:
                shutil.copy2(src_path, dst_locale_dir / dst_name)

        total_copied += len(locale_entries)
        print(f"  ✅ [{locale}] {'Validated' if dry_run else 'Exported'} {len(locale_entries)} screenshots")

    verb = "Validated" if dry_run else "Successfully exported"
    print(f"\n✅ {verb} {total_copied} total screenshots to {screenshots_dst_dir.relative_to(project_root)}/")


def load_config(project_root: Path, config_arg: Optional[str]) -> Dict[str, Any]:
    if config_arg:
        config_path = Path(config_arg)
        if not config_path.is_absolute():
            config_path = project_root / config_path
        if not config_path.is_file():
            raise FileNotFoundError(f"Config file not found: {config_path}")
        loaded = json.loads(config_path.read_text(encoding="utf-8"))
        # If invoked via screenshots.sh with screenshots.json, extract optional "fastlane" block.
        if "slides" in loaded:
            return loaded.get("fastlane", {})
        return loaded

    for default_rel in ("fastlane/export_config.json", "Marketing/fastlane_export.json"):
        candidate = project_root / default_rel
        if candidate.is_file():
            return json.loads(candidate.read_text(encoding="utf-8"))
    return {}


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Export AppInfo markdown and rendered screenshots to Fastlane format."
    )
    parser.add_argument("--project-root", default=".", help="Path to the app project root (default: .)")
    parser.add_argument("--config", help="Optional JSON config overriding locales, URLs, or paths")
    parser.add_argument("--version", help="Explicit app version (defaults to MARKETING_VERSION in project.pbxproj)")
    parser.add_argument("--bundle-id", help="Optional bundle identifier to disambiguate MARKETING_VERSION")
    parser.add_argument("--app-info", help="Path to APP_INFO.md")
    parser.add_argument("--release-notes", help="Path to RELEASE_NOTES.md")
    parser.add_argument("--screenshots-dir", help="Rendered screenshots root (default: Screenshots/AppStore)")
    parser.add_argument("--fastlane-dir", help="Fastlane output directory (default: fastlane)")
    parser.add_argument("--copyright", help="Copyright notice for fastlane/metadata/copyright.txt")
    parser.add_argument("--metadata-only", action="store_true", help="Only export metadata")
    parser.add_argument("--screenshots-only", action="store_true", help="Only export screenshots")
    parser.add_argument("--dry-run", action="store_true", help="Validate inputs without writing output files")
    args = parser.parse_args()

    project_root = Path(args.project_root).resolve()
    config = load_config(project_root, args.config)

    pbxproj_rel = config.get("pbxproj_path")
    pbxproj_path = (project_root / pbxproj_rel) if pbxproj_rel else discover_pbxproj(project_root)

    bundle_id = args.bundle_id or config.get("bundle_id")
    version = args.version or detect_marketing_version(pbxproj_path, bundle_id=bundle_id)
    print(f"🚀 Target App Version: {version}")

    app_info_rel = args.app_info or config.get("app_info_path")
    app_info_path = (project_root / app_info_rel) if app_info_rel else discover_doc(project_root, "APP_INFO.md")

    release_notes_rel = args.release_notes or config.get("release_notes_path")
    release_notes_path = (
        (project_root / release_notes_rel) if release_notes_rel else discover_doc(project_root, "RELEASE_NOTES.md")
    )

    fastlane_dir = project_root / (args.fastlane_dir or config.get("fastlane_dir", "fastlane"))
    metadata_dir = fastlane_dir / "metadata"
    screenshots_src_dir = project_root / (args.screenshots_dir or config.get("screenshots_dir", "Screenshots/AppStore"))
    screenshots_dst_dir = fastlane_dir / "screenshots"

    locale_config: Dict[str, Dict[str, Any]] = {k: dict(v) for k, v in DEFAULT_LOCALE_CONFIG.items()}
    for loc, override in config.get("locales", {}).items():
        merged = dict(locale_config.get(loc, {}))
        merged.update(override)
        locale_config[loc] = merged

    explicit_locales: Optional[List[str]] = config.get("active_locales")

    existing_copyright = metadata_dir / "copyright.txt"
    default_copyright = (
        existing_copyright.read_text(encoding="utf-8").strip()
        if existing_copyright.is_file()
        else f"© {datetime.date.today().year} Le Huang. All rights reserved."
    )
    copyright_text = args.copyright or config.get("copyright") or default_copyright

    url_overrides = {
        k: v for k, v in {
            "marketing_url": config.get("marketing_url"),
            "privacy_url": config.get("privacy_url"),
            "support_url": config.get("support_url"),
        }.items() if v
    }
    marketing_url_overrides = config.get("marketing_urls", {})

    active_locales: Optional[List[str]] = None
    if not args.screenshots_only:
        active_locales = validate_and_write_metadata(
            project_root=project_root,
            app_info_path=app_info_path,
            release_notes_path=release_notes_path,
            metadata_dir=metadata_dir,
            version=version,
            locale_config=locale_config,
            explicit_locales=explicit_locales,
            url_overrides=url_overrides,
            marketing_url_overrides=marketing_url_overrides,
            copyright_text=copyright_text,
            dry_run=args.dry_run,
        )

    if not args.metadata_only:
        if active_locales is None:
            _, parsed_app_info = parse_app_info(app_info_path, locale_config, explicit_locales)
            active_locales = list(parsed_app_info.keys())
        raw_devices = config.get("devices")
        device_mapping = [(d[0], d[1]) for d in raw_devices] if raw_devices else DEFAULT_DEVICE_MAPPING
        export_screenshots(
            project_root=project_root,
            screenshots_src_dir=screenshots_src_dir,
            screenshots_dst_dir=screenshots_dst_dir,
            locales=active_locales,
            locale_config=locale_config,
            device_mapping=device_mapping,
            dry_run=args.dry_run,
        )

    print("\n🎉 Fastlane export completed cleanly!")


if __name__ == "__main__":
    main()
