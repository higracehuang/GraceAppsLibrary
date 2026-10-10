#!/usr/bin/env python3
"""
List all applications using GraceAppsLibrary (GAL) and their used versions.

This script scans sibling app directories (or a specified directory) to detect:
1. Resolved package versions in Package.resolved
2. Dependency requirement rules in Xcode project files (*.pbxproj)
3. Direct local workspace references in *.xcworkspacedata
4. Swift import statements

Usage:
    python3 scripts/list_apps_using_gal.py
    python3 scripts/list_apps_using_gal.py --outdated
    python3 scripts/list_apps_using_gal.py --json
    python3 scripts/list_apps_using_gal.py --dir /path/to/apps
"""

import argparse
import glob
import json
import os
import re
import subprocess
import sys


def get_latest_gal_tag(gal_root):
    """Retrieve the latest release tag from the GAL git repository."""
    try:
        result = subprocess.run(
            ["git", "tag", "--sort=-v:refname"],
            cwd=gal_root,
            capture_output=True,
            text=True,
            check=True
        )
        tags = [t.strip() for t in result.stdout.strip().splitlines() if t.strip()]
        return tags[0] if tags else None
    except Exception:
        return None


def parse_pbx_requirement(pbx_content):
    """Extract requirements for GraceAppsLibrary from a pbxproj file content."""
    requirements = set()
    matches = re.finditer(
        r'isa\s*=\s*XCRemoteSwiftPackageReference;\s*repositoryURL\s*=\s*\"[^\"]*GraceAppsLibrary[^\"]*\";\s*requirement\s*=\s*\{([^}]+)\};',
        pbx_content
    )
    for m in matches:
        req_block = m.group(1)
        kind_m = re.search(r'kind\s*=\s*([^;]+);', req_block)
        min_m = re.search(r'minimumVersion\s*=\s*([^;]+);', req_block)
        ver_m = re.search(r'version\s*=\s*([^;]+);', req_block)
        branch_m = re.search(r'branch\s*=\s*([^;]+);', req_block)

        kind = kind_m.group(1).strip() if kind_m else ''
        min_ver = min_m.group(1).strip() if min_m else ''
        exact_ver = ver_m.group(1).strip() if ver_m else ''
        branch = branch_m.group(1).strip() if branch_m else ''

        if kind == 'upToNextMajorVersion' and min_ver:
            requirements.add(f">={min_ver}")
        elif kind == 'upToNextMinorVersion' and min_ver:
            requirements.add(f"~>{min_ver}")
        elif kind == 'exactVersion' and exact_ver:
            requirements.add(f"=={exact_ver}")
        elif kind == 'branch' and branch:
            requirements.add(f"branch:{branch}")
        else:
            cleaned = " ".join(req_block.strip().split())
            requirements.add(cleaned)
    return requirements


def scan_apps(apps_dir, gal_dir_name="GraceAppsLibrary"):
    """Scan all sibling directories in apps_dir for GraceAppsLibrary references."""
    apps_data = []

    if not os.path.exists(apps_dir):
        print(f"Error: Directory not found: {apps_dir}", file=sys.stderr)
        return []

    for item in sorted(os.listdir(apps_dir)):
        app_path = os.path.join(apps_dir, item)
        if not os.path.isdir(app_path) or item.startswith('.') or item == gal_dir_name:
            continue

        resolved_files = glob.glob(f"{app_path}/**/Package.resolved", recursive=True)
        pbx_files = glob.glob(f"{app_path}/**/*.pbxproj", recursive=True)
        workspace_files = glob.glob(f"{app_path}/**/contents.xcworkspacedata", recursive=True)

        resolved_versions = set()
        resolved_details = []
        requirements = set()
        has_local_link = False
        has_swift_import = False

        # 1. Parse Package.resolved
        for r_path in resolved_files:
            try:
                with open(r_path, 'r', encoding='utf-8') as f:
                    data = json.load(f)
                    pins = data.get('pins', [])
                    if isinstance(pins, list):
                        for pin in pins:
                            loc = (pin.get('location') or pin.get('repositoryURL') or '').lower()
                            ident = (pin.get('identity') or '').lower()
                            if 'graceappslibrary' in loc or 'graceappslibrary' in ident:
                                state = pin.get('state', {})
                                ver = state.get('version')
                                branch = state.get('branch')
                                rev = state.get('revision')
                                display_ver = ver or (f"branch:{branch}" if branch else (rev[:7] if rev else "unknown"))
                                resolved_versions.add(display_ver)
                                resolved_details.append({
                                    "file": os.path.relpath(r_path, apps_dir),
                                    "version": ver,
                                    "branch": branch,
                                    "revision": rev
                                })
            except Exception:
                pass

        # 2. Parse project.pbxproj
        for p_path in pbx_files:
            try:
                with open(p_path, 'r', encoding='utf-8', errors='ignore') as f:
                    content = f.read()
                    if 'GraceAppsLibrary' in content:
                        parsed = parse_pbx_requirement(content)
                        requirements.update(parsed)
            except Exception:
                pass

        # 3. Check workspace links
        for w_path in workspace_files:
            try:
                with open(w_path, 'r', encoding='utf-8', errors='ignore') as f:
                    if 'GraceAppsLibrary' in f.read():
                        has_local_link = True
                        break
            except Exception:
                pass

        # 4. Check for Swift import
        swift_files = glob.glob(f"{app_path}/**/*.swift", recursive=True)
        for s_path in swift_files:
            try:
                with open(s_path, 'r', encoding='utf-8', errors='ignore') as f:
                    for line in f:
                        if 'import GraceAppsLibrary' in line:
                            has_swift_import = True
                            break
                if has_swift_import:
                    break
            except Exception:
                pass

        if resolved_versions or requirements or has_local_link or has_swift_import:
            apps_data.append({
                "app": item,
                "path": app_path,
                "resolved_versions": sorted(list(resolved_versions)),
                "requirements": sorted(list(requirements)),
                "local_link": has_local_link,
                "swift_import": has_swift_import,
                "details": resolved_details
            })

    return apps_data


def compare_version(resolved, latest):
    """Simple semver-style comparison returning True if resolved == latest."""
    if not resolved or not latest:
        return False
    return resolved.strip().lstrip('v') == latest.strip().lstrip('v')


def generate_markdown(apps, latest_tag, target_apps_dir):
    """Generate GitHub-flavored Markdown report."""
    lines = []
    lines.append("# Apps Using GraceAppsLibrary (GAL)\n")
    if latest_tag:
        lines.append(f"**Latest GAL Release:** `v{latest_tag}`  ")
    lines.append(f"**Scanned Directory:** `{target_apps_dir}`  ")
    lines.append(f"**Total Apps Found:** `{len(apps)}`\n")

    up_to_date_count = sum(1 for a in apps if a["status"].startswith("Up-to-date"))
    behind_count = sum(1 for a in apps if a["status"].startswith("Behind"))
    branch_count = sum(1 for a in apps if "Branch" in a["status"])

    lines.append("## Summary\n")
    lines.append(f"- **Up-to-date (`v{latest_tag}`):** {up_to_date_count}")
    lines.append(f"- **Behind latest:** {behind_count}")
    if branch_count:
        lines.append(f"- **Tracking branch:** {branch_count}")
    lines.append("")

    lines.append("## Applications Overview\n")
    lines.append("| App Name | Resolved Pin | SPM Requirement | Local Dev Link | Status |")
    lines.append("| :--- | :--- | :--- | :---: | :--- |")

    for a in apps:
        app_name = f"**{a['app']}**"
        resolved = f"`{', '.join(a['resolved_versions'])}`" if a["resolved_versions"] else "*(none)*"
        req = f"`{', '.join(a['requirements'])}`" if a["requirements"] else "*(none)*"
        local = "Yes" if a["local_link"] else "No"
        status = a["status"]

        if status.startswith("Up-to-date"):
            status_display = f"✅ **Up-to-date** (`{latest_tag}`)"
        elif status.startswith("Behind"):
            vers = ", ".join(a["resolved_versions"])
            status_display = f"⚠️ Behind (`{vers}`)"
        elif "Branch" in status:
            status_display = "🌿 Tracking `main` branch"
        else:
            status_display = f"❓ {status}"

        lines.append(f"| {app_name} | {resolved} | {req} | {local} | {status_display} |")

    lines.append("")
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(
        description="List all applications using GraceAppsLibrary and their versions."
    )
    parser.add_argument(
        "--dir", "-d",
        default=None,
        help="Path to apps directory to scan (default: parent directory of GraceAppsLibrary)"
    )
    parser.add_argument(
        "--json", "-j",
        action="store_true",
        help="Output results in JSON format"
    )
    parser.add_argument(
        "--md", "--markdown",
        action="store_true",
        dest="markdown",
        help="Output results in Markdown format"
    )
    parser.add_argument(
        "--output", "-save",
        default=None,
        help="Save output to specified file path (e.g. APPS_USING_GAL.md)"
    )
    parser.add_argument(
        "--outdated",
        action="store_true",
        help="Only display apps that are not on the latest GAL version"
    )

    args = parser.parse_args()

    # Determine paths
    script_dir = os.path.dirname(os.path.abspath(__file__))
    gal_root = os.path.dirname(script_dir)
    default_apps_dir = os.path.abspath(os.path.join(gal_root, ".."))

    target_apps_dir = os.path.abspath(args.dir) if args.dir else default_apps_dir

    latest_tag = get_latest_gal_tag(gal_root)
    apps = scan_apps(target_apps_dir, gal_dir_name=os.path.basename(gal_root))

    # Calculate status
    for app in apps:
        vers = app["resolved_versions"]
        if not vers:
            app["status"] = "Unresolved"
        elif any(v == f"branch:main" or v == "main" for v in vers):
            app["status"] = "Branch (main)"
        elif any(compare_version(v, latest_tag) for v in vers):
            app["status"] = f"Up-to-date ({latest_tag})"
        else:
            app["status"] = f"Behind ({', '.join(vers)})"

    if args.outdated:
        apps = [a for a in apps if not a["status"].startswith("Up-to-date")]

    if args.json:
        output_data = json.dumps({
            "latest_gal_tag": latest_tag,
            "scanned_directory": target_apps_dir,
            "total_apps_using_gal": len(apps),
            "apps": apps
        }, indent=2)
        if args.output:
            with open(args.output, "w", encoding="utf-8") as f:
                f.write(output_data)
            print(f"JSON output written to {args.output}")
        else:
            print(output_data)
        return

    if args.markdown:
        md_content = generate_markdown(apps, latest_tag, target_apps_dir)
        if args.output:
            with open(args.output, "w", encoding="utf-8") as f:
                f.write(md_content)
            print(f"Markdown output written to {args.output}")
        else:
            print(md_content)
        return

    # Formatted Terminal Output
    print("=" * 86)
    print(f"  GraceAppsLibrary (GAL) - Dependent Apps & Versions")
    if latest_tag:
        print(f"  Latest GAL Release: v{latest_tag}")
    print(f"  Scanned Directory:  {target_apps_dir}")
    print("=" * 86)

    col_app = 22
    col_resolved = 18
    col_req = 14
    col_local = 10
    col_status = 20

    header = (
        f"{'App Name':<{col_app}} "
        f"{'Resolved Pin':<{col_resolved}} "
        f"{'Requirement':<{col_req}} "
        f"{'Local Dev':<{col_local}} "
        f"{'Status':<{col_status}}"
    )
    print(header)
    print("-" * 86)

    up_to_date_count = 0
    behind_count = 0
    branch_count = 0

    for a in apps:
        app_name = a["app"]
        resolved = ", ".join(a["resolved_versions"]) or "(none)"
        req = ", ".join(a["requirements"]) or "(none)"
        local = "Yes" if a["local_link"] else "No"
        status = a["status"]

        if status.startswith("Up-to-date"):
            up_to_date_count += 1
            status_display = f"✅ {status}"
        elif status.startswith("Behind"):
            behind_count += 1
            status_display = f"⚠️  {status}"
        elif "Branch" in status:
            branch_count += 1
            status_display = f"🌿 {status}"
        else:
            status_display = f"❓ {status}"

        print(
            f"{app_name:<{col_app}} "
            f"{resolved:<{col_resolved}} "
            f"{req:<{col_req}} "
            f"{local:<{col_local}} "
            f"{status_display}"
        )

    print("-" * 86)
    print(f"Total Apps Using GAL: {len(apps)}")
    if latest_tag:
        print(f"  • Up-to-date (v{latest_tag}): {up_to_date_count}")
        print(f"  • Behind latest:          {behind_count}")
        if branch_count:
            print(f"  • Tracking branch:        {branch_count}")
    print("=" * 86)


if __name__ == "__main__":
    main()
