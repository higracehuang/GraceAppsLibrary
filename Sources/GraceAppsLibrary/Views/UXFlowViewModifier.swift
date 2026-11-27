//
//  UXFlowViewModifier.swift
//  GraceAppsLibrary
//
//  Created by Grace Huang on 11/11/26.
//

import SwiftUI

/// View modifier binding `UXFlowOrchestrator`'s presentation items to a single presentation container.
@MainActor
internal struct UXFlowViewModifier: ViewModifier {
    @ObservedObject var orchestrator: UXFlowOrchestrator
    @State private var hostId = UUID()
    
    internal init(orchestrator: UXFlowOrchestrator = .shared) {
        self.orchestrator = orchestrator
    }
    
    func body(content: Content) -> some View {
        let isTopmostHost = orchestrator.activeHostId == nil || orchestrator.activeHostId == hostId
        content
            .sheet(item: Binding<UXActionItem?>(
                get: { isTopmostHost ? orchestrator.activeSheetItem : nil },
                set: { newValue in
                    guard isTopmostHost else { return }
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
                get: { isTopmostHost ? orchestrator.activeCoverItem : nil },
                set: { newValue in
                    guard isTopmostHost else { return }
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
            .onAppear {
                orchestrator.mountHost(hostId)
            }
            .onDisappear {
                orchestrator.unmountHost(hostId)
            }
    }
}

public extension View {
    /// Mounts the single-slot presentation container and binds its lifecycle to the view.
    /// Automatically resets idle flow state when appearing/disappearing so stale flow tags never leak.
    @MainActor
    func scopedUXFlow(orchestrator: UXFlowOrchestrator = .shared) -> some View {
        self
            .modifier(UXFlowViewModifier(orchestrator: orchestrator))
            .onAppear {
                if !orchestrator.isBusy {
                    orchestrator.resetFlowState()
                }
                let manager = ReleaseNotesManager.shared
                if !manager.configuredReleaseNotes.isEmpty, !manager.hasEvaluatedLaunchReleaseNotes {
                    orchestrator.requestAction(
                        .releaseNotes(
                            releaseNotes: manager.configuredReleaseNotes,
                            isPaidUser: manager.configuredIsPaidUser(),
                            tierName: manager.configuredTierName,
                            suppressOnFirstInstall: manager.configuredSuppressOnFirstInstall,
                            paywallAction: manager.configuredPaywallAction
                        )
                    )
                }
            }
            .onDisappear {
                if !orchestrator.isBusy {
                    orchestrator.resetFlowState()
                }
            }
    }
}
