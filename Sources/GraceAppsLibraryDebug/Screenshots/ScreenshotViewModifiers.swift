//
//  ScreenshotViewModifiers.swift
//  GraceAppsLibrary
//
//  Created by Antigravity on 11/26/26.
//

import Combine
import SwiftUI

#if DEBUG
private struct ScreenshotTabCoordinationModifier<Preset: ScreenshotPresetProvider, Tab: Hashable>: ViewModifier {
    @ObservedObject var engine: ScreenshotEngine<Preset>
    @Binding var selectedTab: Tab
    let tabForPreset: @MainActor (Preset) -> Tab?

    func body(content: Content) -> some View {
        content
            .onAppear {
                syncTab(for: engine.activePreset)
            }
            .onReceive(engine.$navigationTriggerId) { _ in
                syncTab(for: engine.activePreset)
            }
            .onReceive(engine.$activePreset) { newPreset in
                syncTab(for: newPreset)
            }
    }

    @MainActor
    private func syncTab(for preset: Preset?) {
        guard let preset = preset,
              let targetTab = tabForPreset(preset),
              selectedTab != targetTab else {
            return
        }
        selectedTab = targetTab
    }
}
#endif

public extension View {
    /// Coordinates a `Tab: Hashable` SwiftUI `TabView` selection with `ScreenshotEngine`
    /// preset updates and launch navigation triggers.
    /// In Release builds (`DEBUG` unset), returns `self` with zero runtime overhead.
    func screenshotTabCoordination<Preset: ScreenshotPresetProvider, Tab: Hashable>(
        engine: ScreenshotEngine<Preset>,
        selectedTab: Binding<Tab>,
        tabForPreset: @MainActor @escaping (Preset) -> Tab?
    ) -> some View {
        #if DEBUG
        modifier(
            ScreenshotTabCoordinationModifier(
                engine: engine,
                selectedTab: selectedTab,
                tabForPreset: tabForPreset
            )
        )
        #else
        self
        #endif
    }

    /// Coordinates an `Int`-indexed SwiftUI `TabView` selection with `ScreenshotEngine`
    /// preset updates and launch navigation triggers.
    /// Resolves target tab using `tabForPreset`, falling back to `engine.tabIndexForPreset` and `preset.targetTabIndex`.
    /// In Release builds (`DEBUG` unset), returns `self` with zero runtime overhead.
    func screenshotTabCoordination<Preset: ScreenshotPresetProvider>(
        engine: ScreenshotEngine<Preset>,
        selectedTab: Binding<Int>,
        tabForPreset: (@MainActor (Preset) -> Int?)? = nil
    ) -> some View {
        #if DEBUG
        screenshotTabCoordination(
            engine: engine,
            selectedTab: selectedTab,
            tabForPreset: { preset in
                if let tabForPreset {
                    return tabForPreset(preset)
                }
                return engine.tabIndexForPreset?(preset) ?? preset.targetTabIndex
            }
        )
        #else
        self
        #endif
    }
}
