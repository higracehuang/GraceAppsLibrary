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
* **German (`de`):** Longer compound words. Structure line breaks to avoid awkward mid-word hyphens on iPhone.
* **Spanish (`es`):** Keep phrasing natural; break after prepositions or verbs.
* **Japanese (`ja`):** Break at grammatical particles (`の`, `を`, `に`) or sentence clauses for clean readability.
* **French (`fr`):** Preserve French non-breaking spaces before punctuation marks (` : `, ` ! `).

---

## ⚙️ 6. Automation & Production Encapsulation

1. **In-Memory Store Isolation:** Screenshot seeders must only mutate mock in-memory stores via:
   ```swift
   guard ScreenshotEngine.isInMemoryStore(context: viewContext) else { return }
   ```
2. **Zero Production Leakage:** All screenshot demo managers, debug settings sections, and preset seeders must be wrapped in `#if DEBUG ... #endif`.
3. **Automated Capture CLI:** The universal runner script (`scripts/capture_screenshots.sh`) automatically detects supported languages from `.lproj` folders inside the compiled `.app` bundle:
   ```bash
   ./scripts/capture_screenshots.sh --bundle "com.yourcompany.app" --iphone-only
   ```
