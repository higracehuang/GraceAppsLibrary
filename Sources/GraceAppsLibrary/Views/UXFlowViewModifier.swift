//
//  UXFlowViewModifier.swift
//  GraceAppsLibrary
//
//  Created by Grace Huang on 11/11/26.
//

import SwiftUI

/// View modifier binding `UXFlowOrchestrator`'s presentation items to a single presentation container.
public struct UXFlowViewModifier: ViewModifier {
    @ObservedObject var orchestrator: UXFlowOrchestrator
    
    public init(orchestrator: UXFlowOrchestrator = .shared) {
        self.orchestrator = orchestrator
    }
    
    public func body(content: Content) -> some View {
        content
            .sheet(item: Binding<UXActionItem?>(
                get: { orchestrator.activeSheetItem },
                set: { _ in }
            ), onDismiss: {
                if let item = orchestrator.activeSheetItem {
                    orchestrator.onModalDismissed(actionId: item.id)
                }
            }) { item in
                if let builder = item.action.viewBuilder {
                    builder()
                } else {
                    EmptyView()
                }
            }
            .fullScreenCover(item: Binding<UXActionItem?>(
                get: { orchestrator.activeCoverItem },
                set: { _ in }
            ), onDismiss: {
                if let item = orchestrator.activeCoverItem {
                    orchestrator.onModalDismissed(actionId: item.id)
                }
            }) { item in
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
    func withUXFlowOrchestrator(_ orchestrator: UXFlowOrchestrator = .shared) -> some View {
        self.modifier(UXFlowViewModifier(orchestrator: orchestrator))
    }
}
