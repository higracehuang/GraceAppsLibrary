# Grace Apps App Store Screenshot Playbook & Standards

A standardized playbook and design system for crafting high-converting, realistic, and polished App Store screenshots across all Grace Apps (`ReadingClock`, `DialInPourOver`, `DialInEspresso`, `FastingGirls`, etc.).

---

## 🧭 1. The 5–6 Screen Framework

Every App Store screenshot set across Grace Apps collects 5–6 screens showing:

1. **Your app’s main benefit**
   * *Purpose:* The hook that answers "What immediate transformation or daily value do I get?"
   * *Content:* The hero screen in active use (e.g. active timer with live goal ring, active fasting window, primary brew assistant).
   * *Preset Slot:* `Slot #1 • Main Benefit` (`StandardScreenshotPreset.slot1Benefit`).

2. **Its most important feature**
   * *Purpose:* The primary tool or flagship mechanic the user interacts with daily.
   * *Content:* The core tracking or calculation interface (e.g. daily streaks dashboard, grind calculator, daily habit tracker).
   * *Preset Slot:* `Slot #2 • Top Feature` (`StandardScreenshotPreset.slot2Feature`).

3. **A second useful feature**
   * *Purpose:* Demonstrates depth and utility beyond the single primary feature to increase perceived value.
   * *Content:* Session history, searchable logs, book/brew notes, comparative trends, or recipe logs.
   * *Preset Slot:* `Slot #3 • Second Feature` (`StandardScreenshotPreset.slot3SecondFeature`).

4. **A realistic example of the result users get**
   * *Purpose:* Proof of progress, consistency, and transformation after using the app for weeks/months.
   * *Content:* Full month consistency calendar, milestone celebration modal, earned badge collection, or long-term trend chart.
   * *Preset Slot:* `Slot #4A • Realistic Result` / `Slot #4B • Celebration Modal` (`StandardScreenshotPreset.slot4Result` / `slot4Celebration`).

5. **Customization or another differentiator**
   * *Purpose:* Proves the app adapts to the user's personal routine, separating it from generic competitors.
   * *Content:* Custom goal setting, personalized brew/recipe parameters, theme options, or Pro feature overview.
   * *Preset Slot:* `Slot #5A • Differentiator` / `Slot #5B • Settings & Pro Overview` (`StandardScreenshotPreset.slot5Customization` / `slot5Settings`).

---

## 🎨 2. Caption Formula: Problem (Title) + Feature (Subtitle)

Always structure captions with a two-part hierarchy:
* **Title (Bold / Top):** The emotional benefit or problem solved (e.g. *Stay Focused While Reading*, *Never Miss a Day*, *Dial In Repeatable Espresso*).
* **Subtitle (Regular / Bottom):** The specific tangible feature delivering that benefit (e.g. *One-Tap Reading Timer & Live Goal Ring*, *Daily Streaks & Weekly Charts*).

### Two-Line Rhythm vs No-Break Rules
* **iPhone (6.9" / 6.5" / 5.5"):** Keep titles to a balanced 2-line rhythm with zero orphaned words (e.g., using explicit `<br>` breaks in templates). Subtitles should also break cleanly into 2 lines.
* **iPad (13" / 11"):** Titles and subtitles fit cleanly on 1 line across the wider aspect ratio.

---

## 📐 3. Typography, Canvas Sizes & Figma Specifications

### Canvas Dimensions
* **iPhone (Full Size):** `1290 × 2796 px` (Apple 6.9" / 6.5" App Store display).
* **iPad Pro (13" / 12.9" Portrait):** In Figma, design on a **1/2 size canvas (`1024 × 1366 px`)** and export at **`@2x`** for the required `2048 × 2732 px`.

### Font Hierarchy & Sizing

#### iPhone Specifications (`1290 × 2796 px`)

| Role | Font Family | Weight | Size *(for 1290×2796)* | Line Height | Letter Spacing |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Title (EN / DE / ES / FR)** | **SF Pro Rounded** *(fallback: Plus Jakarta Sans)* | `Bold` (`700`) | `88 px` – `96 px` | `115%` | `-1%` |
| **Subtitle (EN / DE / ES / FR)** | **SF Pro Display** *(fallback: Plus Jakarta Sans)* | `Medium` (`500`) | `46 px` – `52 px` | `130%` | `0%` |
| **Title (Simplified Chinese)** | **PingFang SC** *(fallback: Noto Sans SC)* | `Semibold` (`600`) | `88 px` – `96 px` | `120%` | `0%` |
| **Subtitle (Simplified Chinese)** | **PingFang SC** *(fallback: Noto Sans SC)* | `Medium` (`500`) | `46 px` – `52 px` | `135%` | `2%` |
| **Title (Japanese)** | **Hiragino Sans** *(fallback: Noto Sans JP)* | `Bold` (`W6` / `700`) | `88 px` – `96 px` | `120%` | `0%` |
| **Subtitle (Japanese)** | **Hiragino Sans** *(fallback: Noto Sans JP)* | `Medium` (`W4` / `500`) | `46 px` – `52 px` | `135%` | `1%` |

#### iPad Pro Specifications (Working Size: `1024 × 1366 px` ➔ Export `@2x` for `2048 × 2732 px`)

| Role | Font Family | Weight | Size in Figma *(1/2)* | Export Size (`@2x`) | Line Height |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Title (EN / DE / ES / FR)** | **SF Pro Rounded** | `Bold` (`700`) | **`64 px` – `68 px`** | `128 – 136 px` | `115%` |
| **Subtitle (EN / DE / ES / FR)** | **SF Pro Display** | `Medium` (`500`) | **`32 px` – `36 px`** | `64 – 72 px` | `130%` |
| **Title (Simplified Chinese)** | **PingFang SC** | `Semibold` (`600`) | **`64 px` – `68 px`** | `128 – 136 px` | `120%` |
| **Subtitle (Simplified Chinese)** | **PingFang SC** | `Medium` (`500`) | **`32 px` – `35 px`** | `64 – 70 px` | `135%` |
| **Title (Japanese)** | **Hiragino Sans** | `Bold` (`W6`) | **`64 px` – `68 px`** | `128 – 136 px` | `120%` |
| **Subtitle (Japanese)** | **Hiragino Sans** | `Medium` (`W4`) | **`32 px` – `35 px`** | `64 – 70 px` | `135%` |

### iPad Layout & Spacing Rules (at `1024 × 1366 px`)
* **Top Margin** *(Frame top ➔ Title)*: `80 px` – `90 px`
* **Title to Subtitle Gap**: `16 px`
* **Subtitle to Device Gap**: `40 px` – `50 px`
* **iPad Screen / Mockup Width**: `840 px` – `860 px` (centered, ~`85 px`–`90 px` side margins)
* **Corner Radius on Device Mockup**: `22 px` – `24 px` (becomes `44 – 48 px` on 2x export)
* **Drop Shadow**: `X: 0`, `Y: 14`, `Blur: 30`, `Spread: 0`, Color: `#133440` at `10%` to `12%` opacity

---

## 🎨 4. Background & Color Palette Guidelines

* **Brand Linear Gradient:** All screenshots for an app should use a single vertical linear gradient (`180°`, Top $\to$ Bottom) derived from the app's icon or brand accents (e.g., Soft Ice $\to$ Soft Mint).
* **Search Results Cohesion:** When users search the App Store on iPhone, they see the first 3 portrait screenshots side by side. A shared background gradient ensures the first 3 screenshots look unified and intentional.
* **Text Contrast:** Ensure high contrast against the top gradient stop (WCAG AAA minimum).

---

## 🌐 5. Multi-Language Localization Rules

* **English (`en`):** 2-line title + 2-line subtitle on iPhone; 1-line on iPad.
* **Simplified Chinese (`zh`):** Compact characters. Title stays on 1 punchy line. Subtitles break at conjunctions like `与` or `、`.
* **Traditional Chinese (`zh-Hant`):** Authentic Traditional Chinese terminology for Taiwan/Hong Kong markets.
* **German (`de`):** Longer compound words. Structure line breaks to avoid awkward mid-word hyphens on iPhone.
* **Spanish (`es`):** Keep phrasing natural; break after prepositions or verbs.
* **Japanese (`ja`):** Break at grammatical particles (`の`, `を`, `に`) or sentence clauses for clean readability.
* **Korean (`ko`):** Hangul phrasing with natural spacing; keyword emphasis via Apple SD Gothic Neo.
* **French (`fr`):** Preserve French non-breaking spaces before punctuation marks (` : `, ` ! `).

---

## ⚙️ 6. Universal Automation Architecture (GAL Shared Engine)

GraceAppsLibrary provides a centralized, reusable screenshot pipeline across all Grace apps:

### Architecture Overview

1. **`screenshots.json` (App Repo)**: Declarative definition of theme colors, localized copy, badges, and slides.
2. **`capture_screenshots.sh` (GAL)**: Universal simulator runner that auto-detects latest iOS runtimes, enforces sequential execution with intermediate shutdown to avoid system process limits, and captures raw simulator screens into `Screenshots/Raw/`.
3. **`render_screenshots.py` (GAL)**: Parameterized template generator and headless Chrome Retina exporter that produces pixel-perfect final marketing frames in `Screenshots/AppStore/`.
4. **`screenshots.sh` (GAL)**: Unified single CLI entrypoint:
   ```bash
   # Run full pipeline:
   ./scripts/screenshots.sh all
   # Or run individually:
   ./scripts/screenshots.sh capture
   ./scripts/screenshots.sh export
   ```

### Supported Slide Types (`type`)

- **`standard-device`** (Default): Centered iPhone/iPad frame with raw capture, ambient radial light bloom, volumetric 3D drop shadow, and two-tier typography.
- **`artwork-hero`**: Full-bleed lifestyle photo or 3D artwork (e.g. coffee setup in DialInEspresso) with localized headlines automatically stamped on top.
- **`feature-grid`**: Bento-style frosted glass cards with SF Symbols and localized feature items for closer/summary slides.
- **`scene-composite`**: Background environment scene with a floating, positioned, or angled device mockup.
- **`static-asset`**: Passthrough for pre-rendered or legacy assets.

### The `screenshots.json` Schema

```json
{
  "bundleId": "com.deelightfullabs.ReadingLog",
  "appName": "ReadingClock",
  "defaultTheme": {
    "background": "linear-gradient(180deg, #EAF6FA 0%, #E4F5EC 100%)",
    "accentGradient": "linear-gradient(135deg, #0284C7 0%, #0D9488 100%)",
    "titleColor": "#133440",
    "subtitleColor": "#3B6978"
  },
  "themes": {
    "focus": { "accentGradient": "linear-gradient(135deg, #0284C7 0%, #0D9488 100%)" },
    "streak": { "accentGradient": "linear-gradient(135deg, #EA580C 0%, #D97706 100%)" }
  },
  "slides": [
    {
      "id": "1",
      "preset": "1",
      "theme": "focus",
      "filename": "01 - Main Benefit.png",
      "titles": {
        "en": { "iphone": "Stay *Focused*<br>While Reading", "ipad": "Stay *Focused* While Reading" }
      },
      "subtitles": {
        "en": { "iphone": "One-Tap Reading Timer<br>& Live Goal Ring", "ipad": "One-Tap Reading Timer & Live Goal Ring" }
      }
    }
  ]
}
```

---

## 🔒 7. Production Encapsulation

1. **In-Memory Store Isolation:** Screenshot seeders must only mutate mock in-memory stores via:
   ```swift
   guard ScreenshotEngine.isInMemoryStore(context: viewContext) else { return }
   ```
2. **Zero Production Leakage:** All screenshot demo managers, debug settings sections, and preset seeders must be wrapped in `#if DEBUG ... #endif`.

---

## 📦 8. App Store Delivery & Directory Standards (Fastlane)

To eliminate manual copy-pasting of 98 screenshots and localized texts into App Store Connect, adopt the standardized **Fastlane** directory structure:

```text
fastlane/
├── Appfile                           # Bundle ID, Apple ID & Team ID
├── Deliverfile                       # Deliver configuration (safe release settings)
├── Fastfile                          # Automation lanes (upload_marketing)
├── metadata/                         # Localized App Store metadata
│   ├── en-US/
│   │   ├── name.txt                  # App Title (≤ 30 characters)
│   │   ├── subtitle.txt              # Subtitle (≤ 30 characters)
│   │   ├── keywords.txt              # Comma-separated keywords (≤ 100 characters)
│   │   ├── promotional_text.txt      # Promo hook (≤ 170 characters)
│   │   ├── description.txt           # Full formatted description
│   │   ├── release_notes.txt         # Version release notes (What's New)
│   │   ├── support_url.txt           # Support URL
│   │   ├── marketing_url.txt         # Marketing URL
│   │   └── privacy_url.txt           # Privacy Policy URL
│   ├── zh-Hans/
│   ├── zh-Hant/
│   ├── de-DE/
│   ├── es-ES/
│   ├── ja/
│   └── ko/
└── screenshots/                      # Standardized screenshot assets
    ├── en-US/
    │   ├── 01_iPhone_6.7.png
    │   ├── 01_iPad_12.9.png
    │   ├── 02_iPhone_6.7.png
    │   ├── 02_iPad_12.9.png
    │   └── ... (14 per locale)
    ├── zh-Hans/
    └── ...
```

### Naming & Ordering Rules
- **Locale Folder Codes**: Must use Apple BCP 47 codes (`en-US`, `zh-Hans`, `zh-Hant`, `de-DE`, `es-ES`, `ja`, `ko`).
- **File Names**: `<slide_order>_<device_type>.png` (e.g. `01_iPhone_6.7.png`, `01_iPad_12.9.png`).
- **Ordering**: Fastlane sorts alphabetically. The `01_`, `02_`, `03_`, `04A_`, `04B_`, `05A_`, `05B_` prefix guarantees the exact App Store carousel sequence.
- **Resolution Detection**: Fastlane automatically assigns device slots based on pixel dimensions (`1179 × 2556` for `APP_IPHONE_67`, `2048 × 2732` for `APP_IPAD_PRO_3GEN_129`).

### Automated Export Script (`export_to_fastlane.py`)
Apps should include `Scripts/export_to_fastlane.py` to bridge raw markdown documentation (`AppInfo/README.md`, `AppInfo/RELEASE_NOTES.md`) and render outputs (`Screenshots/AppStore/`) into `fastlane/`:
1. **Dynamic Version Detection**: Reads `MARKETING_VERSION` from `project.pbxproj` and locates the matching `### Release X.Y.Z` notes section.
2. **Pre-flight Character Validation**: Enforces Apple's strict limits (Title ≤ 30, Subtitle ≤ 30, Keywords ≤ 100, Promo ≤ 170) before export.
3. **Selective Runs**: Supports `--metadata-only`, `--screenshots-only`, or explicit `--version X.Y.Z`.

---

## 🚀 9. CI/CD Integration: Xcode Cloud & GitHub Actions

### Architecture: Decoupled Automation Model

```mermaid
flowchart TD
    subgraph Binary Track (Xcode Cloud)
        A["Git Tag / Push"] --> B["Xcode Cloud"]
        B -->|"Auto-signs & compiles"| C["Uploads .ipa to TestFlight"]
    end

    subgraph Marketing Track (GitHub Actions)
        D["Actions: 'Run workflow'"] --> E["GitHub Actions (macos-14)"]
        F["GitHub Secrets<br/>ASC_KEY_ID, ASC_ISSUER_ID, ASC_PRIVATE_KEY"] --> E
        E -->|"export_to_fastlane.py"| G["Refreshes metadata & screenshots"]
        E -->|"fastlane deliver"| H["App Store Connect API"]
        H -->|"Uploads metadata & screenshots"| I["Release in 'Prepare for Submission'"]
    end

    C --> I
    I --> J["Submit for App Review"]
```

### Advantages
- **Zero Certificate Management in CI**: Xcode Cloud manages signing certificates, provisioning profiles, and binary builds securely within Apple's infrastructure.
- **No Ruby/Fastlane on Developer Mac**: GitHub Actions macOS runners come with Fastlane pre-installed. Developers run simple Python scripts locally.

### Fastfile Configuration
```ruby
default_platform(:ios)

platform :ios do
  desc "Sync localized screenshots and metadata to App Store Connect"
  lane :upload_marketing do |options|
    api_key = app_store_connect_api_key(
      key_id: ENV["ASC_KEY_ID"],
      issuer_id: ENV["ASC_ISSUER_ID"],
      key_content: ENV["ASC_PRIVATE_KEY"],
      is_key_content_base64: false
    )

    deliver(
      api_key: api_key,
      force: true,
      skip_binary_upload: true,
      overwrite_screenshots: true,
      skip_screenshots: options[:skip_screenshots] || false,
      skip_metadata: options[:skip_metadata] || false,
      app_version: options[:version]
    )
  end
end
```

### GitHub Actions Workflow (`.github/workflows/sync-appstore.yml`)
- Triggered manually via `workflow_dispatch` with toggle inputs (`skip_screenshots`, `skip_metadata`, `version`).
- Uses 3 repository secrets:
  - `ASC_KEY_ID`: 10-character API Key ID.
  - `ASC_ISSUER_ID`: Apple Issuer UUID.
  - `ASC_PRIVATE_KEY`: Content of the `.p8` private key.

