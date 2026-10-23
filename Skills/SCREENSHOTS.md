# Grace Apps Screenshot Principles & Standards

A standardized playbook for crafting high-converting, realistic, and polished App Store screenshots across all Grace Apps (`ReadingClock`, `DialInPourOver`, `DialInEspresso`, `FastingGirls`, etc.).

---

## 🧭 The 5–6 Screen Framework

Every App Store screenshot set across Grace Apps collects 5–6 screens showing:

1. **Your app’s main benefit**
   * *Purpose:* The hook that answers "What transformation or immediate value do I get?"
   * *Content:* The hero screen in active use (e.g. active timer with goal ring, active fasting window, primary brewing assistant).
   * *Preset Slot:* `Slot #1 • Main Benefit` (`StandardScreenshotPreset.slot1Benefit`).

2. **Its most important feature**
   * *Purpose:* The primary tool or flagship mechanic the user will open every day.
   * *Content:* The core tracking or generation interface (e.g. streaks dashboard, dial-in grind calculator, daily habit tracker).
   * *Preset Slot:* `Slot #2 • Top Feature` (`StandardScreenshotPreset.slot2Feature`).

3. **A second useful feature**
   * *Purpose:* Shows depth and utility beyond the single primary feature to increase perceived value.
   * *Content:* Session history, searchable logs, custom notes, comparative trends, or recipe logs.
   * *Preset Slot:* `Slot #3 • Second Feature` (`StandardScreenshotPreset.slot3SecondFeature`).

4. **A realistic example of the result users get**
   * *Purpose:* Proof of progress, consistency, and transformation after using the app for weeks/months.
   * *Content:* Full month consistency calendar, milestone celebration modal, earned badge collection, or long-term trend chart.
   * *Preset Slot:* `Slot #4A • Realistic Result` / `Slot #4B • Celebration Modal` (`StandardScreenshotPreset.slot4Result` / `slot4Celebration`).

5. **Customization or another differentiator**
   * *Purpose:* Proves the app adapts to the user's personal routine, separating it from generic competitors.
   * *Content:* Custom goal setting, personalized recipe parameters, theme options, or Pro feature overview.
   * *Preset Slot:* `Slot #5A • Differentiator` / `Slot #5B • Settings & Pro Overview` (`StandardScreenshotPreset.slot5Customization` / `slot5Settings`).

---

## 🎨 Caption Formula: Problem + Feature

Always structure captions with a two-part hierarchy:
* **Title (Bold / Top):** The emotional benefit or problem solved (e.g. *Stay Focused While Reading*, *Never Miss a Day*, *Dial In Repeatable Espresso*).
* **Subtitle (Regular / Bottom):** The specific tangible feature delivering that benefit (e.g. *One-Tap Reading Timer & Live Goal Ring*, *Daily Streaks & Weekly Charts*).

### Canvas Sizing Guidelines
* **iPhone (6.9" / 6.5" / 5.5"):** Keep titles to 2 balanced lines with zero orphaned words (e.g., using explicit `<br>` breaks in graphics templates).
* **iPad (13" / 11"):** Titles and subtitles fit cleanly on 1 line across the wider aspect ratio.

---

## 🛠️ Automation & QA Standards

* **In-Memory Store Only:** Demo presets must only mutate in-memory CoreData stores (`NSInMemoryStoreType` or `/dev/null`) via `ScreenshotEngine.isInMemoryStore(context:)`.
* **Zero Production Overhead:** All screenshot demo managers, debug navigation sections, and mock seeders must reside under `#if DEBUG ... #endif`.
* **Language Detection:** The universal runner `capture_screenshots.sh` defaults to `--lang auto`, capturing only the languages the app bundle actually localizes.
