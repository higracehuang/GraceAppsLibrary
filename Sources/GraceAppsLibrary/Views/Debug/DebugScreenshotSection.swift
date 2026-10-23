//
//  DebugScreenshotSection.swift
//  GraceAppsLibrary
//
//  Created by Antigravity on 10/23/26.
//

import SwiftUI

/// A reusable debug section for testing and previewing App Store screenshot presets directly inside the app.
public struct DebugScreenshotSection<Preset: ScreenshotPresetProvider>: View {

    @ObservedObject public var engine: ScreenshotEngine<Preset>
    public let onApplyPreset: ((Preset) -> Void)?
    public let onReset: (() -> Void)?

    @State private var selectedPresetId: String = ""

    public init(
        engine: ScreenshotEngine<Preset>,
        onApplyPreset: ((Preset) -> Void)? = nil,
        onReset: (() -> Void)? = nil
    ) {
        self.engine = engine
        self.onApplyPreset = onApplyPreset
        self.onReset = onReset
        _selectedPresetId = State(initialValue: engine.activePreset?.id ?? Preset.allCases.first?.id ?? "")
    }

    public var body: some View {
        Section(
            header: Text("App Store Marketing & Screenshots"),
            footer: Text("Select a preset to seed marketing data and jump to the exact App Store screenshot view. Use CLI arguments like '-SCREENSHOT_PRESET 1 -SCREENSHOT_LANG zh' for automation.")
        ) {
            // MARK: - Preset Selector
            Picker("Screenshot Preset", selection: $selectedPresetId) {
                ForEach(Array(Preset.allCases), id: \.id) { preset in
                    Label(preset.slotLabel, systemImage: preset.systemImage)
                        .tag(preset.id)
                }
            }
            .onChange(of: selectedPresetId) { newId in
                if let preset = Preset.from(token: newId) {
                    applyPreset(preset)
                }
            }

            // MARK: - Language Selector
            Picker("Language", selection: $engine.selectedLanguage) {
                ForEach(ScreenshotLanguage.allCases) { lang in
                    Text(lang.displayName).tag(lang)
                }
            }

            // MARK: - Current Status
            if let active = engine.activePreset {
                HStack {
                    Text("Active Preset")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(active.title)
                        .bold()
                }

                HStack {
                    Text("File Name")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(active.suggestedFilename).png")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // MARK: - Action Buttons
            HStack(spacing: 12) {
                Button(action: {
                    if let preset = Preset.from(token: selectedPresetId) {
                        applyPreset(preset)
                    }
                }) {
                    Label("Apply Preset", systemImage: "sparkles")
                }

                Spacer()

                if engine.activePreset != nil {
                    Button(action: {
                        engine.reset()
                        onReset?()
                    }) {
                        Text("Reset")
                            .foregroundColor(.red)
                    }
                }
            }
        }
    }

    private func applyPreset(_ preset: Preset) {
        engine.apply(preset: preset)
        onApplyPreset?(preset)
    }
}
