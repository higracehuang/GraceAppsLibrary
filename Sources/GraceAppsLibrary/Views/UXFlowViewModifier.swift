//
//  UXFlowViewModifier.swift
//  GraceAppsLibrary
//
//  Created by Grace Huang on 11/11/26.
//

import SwiftUI

/// View modifier binding `UXFlowOrchestrator`'s presentation items to a single presentation container.
@MainActor
public struct UXFlowViewModifier: ViewModifier {
    @ObservedObject var orchestrator: UXFlowOrchestrator
    
    public init(orchestrator: UXFlowOrchestrator) {
        self.orchestrator = orchestrator
    }

    public init() {
        self.orchestrator = .shared
    }
    
    public func body(content: Content) -> some View {
        content
            .sheet(item: Binding<UXActionItem?>(
                get: { orchestrator.activeSheetItem },
                set: { newValue in
                    if newValue == nil, let item = orchestrator.activeSheetItem {
                        orchestrator.onModalDismissed(actionId: item.id)
                    }
                }
            )) { item in
                if let builder = item.action.viewBuilder {
                    builder()
                } else {
                    EmptyView()
                }
            }
            .fullScreenCover(item: Binding<UXActionItem?>(
                get: { orchestrator.activeCoverItem },
                set: { newValue in
                    if newValue == nil, let item = orchestrator.activeCoverItem {
                        orchestrator.onModalDismissed(actionId: item.id)
                    }
                }
            )) { item in
                if let builder = item.action.viewBuilder {
                    builder()
                } else {
                    EmptyView()
                }
            }
    }
}

public extension View {
    /// Mounts the single-slot `UXFlowOrchestrator` presentation container to avoid sheet collisions and premature cancel-outs.
    @MainActor
    func withUXFlowOrchestrator(_ orchestrator: UXFlowOrchestrator) -> some View {
        self.modifier(UXFlowViewModifier(orchestrator: orchestrator))
    }

    /// Mounts the single-slot `UXFlowOrchestrator.shared` presentation container to avoid sheet collisions and premature cancel-outs.
    @MainActor
    func withUXFlowOrchestrator() -> some View {
        self.withUXFlowOrchestrator(.shared)
    }
}
