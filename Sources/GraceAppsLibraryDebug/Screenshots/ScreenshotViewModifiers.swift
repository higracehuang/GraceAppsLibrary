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

@available(iOS 17, watchOS 10, *)
private struct ScreenshotDestinationModifier<Preset: ScreenshotPresetProvider, Item: Hashable, Destination: View>: ViewModifier {
    @ObservedObject var engine: ScreenshotEngine<Preset>
    let items: [Item]
    let selector: @MainActor (Preset, [Item]) -> Item?
    let destination: (Item) -> Destination

    @State private var selectedItem: Item? = nil

    func body(content: Content) -> some View {
        content
            .navigationDestination(item: $selectedItem, destination: destination)
            .onAppear {
                syncDestination(for: engine.activePreset)
            }
            .onReceive(engine.$navigationTriggerId) { _ in
                syncDestination(for: engine.activePreset)
            }
            .onReceive(engine.$activePreset) { newPreset in
                syncDestination(for: newPreset)
            }
    }

    @MainActor
    private func syncDestination(for preset: Preset?) {
        guard let preset else {
            if selectedItem != nil {
                selectedItem = nil
            }
            return
        }
        let target = selector(preset, items)
        if selectedItem != target {
            selectedItem = target
        }
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

    /// Pushes a SwiftUI `.navigationDestination(item:)` whenever the active screenshot preset
    /// matches an item in `items`, clearing the destination when `reset()` is called.
    /// In Release builds (`DEBUG` unset), returns `self` with zero runtime overhead.
    @available(iOS 17, watchOS 10, *)
    func screenshotDestination<Preset: ScreenshotPresetProvider, Item: Hashable, Destination: View>(
        engine: ScreenshotEngine<Preset>,
        items: [Item],
        matching selector: @MainActor @escaping (Preset, [Item]) -> Item?,
        @ViewBuilder destination: @escaping (Item) -> Destination
    ) -> some View {
        #if DEBUG
        modifier(
            ScreenshotDestinationModifier(
                engine: engine,
                items: items,
                selector: selector,
                destination: destination
            )
        )
        #else
        self
        #endif
    }
}
