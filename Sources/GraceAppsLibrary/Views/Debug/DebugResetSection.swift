import SwiftUI

/// A reusable debug section for resetting all GAL and app-specific debug overrides to defaults.
public struct DebugResetSection: View {
    public let entitlementOverride: Binding<DebugEntitlementOverride>?
    public let unlimitedAccess: Binding<Bool>?
    public let includeReleaseNotes: Bool
    public let onReset: (() -> Void)?

    @State private var showingConfirmation = false
    @State private var showingSuccessAlert = false
    @State private var showingReleaseNotesResetAlert = false

    public init(
        entitlementOverride: Binding<DebugEntitlementOverride>? = nil,
        unlimitedAccess: Binding<Bool>? = nil,
        includeReleaseNotes: Bool = true,
        onReset: (() -> Void)? = nil
    ) {
        self.entitlementOverride = entitlementOverride
        self.unlimitedAccess = unlimitedAccess
        self.includeReleaseNotes = includeReleaseNotes
        self.onReset = onReset
    }

    public var body: some View {
        Section(
            footer: Text(includeReleaseNotes ? "Restores all entitlements, appearance, review counters, release notes, and app-specific debug overrides to default behavior." : "Restores all entitlements, appearance, review counters, and app-specific debug overrides to default behavior.")
        ) {
            if includeReleaseNotes {
                Button {
                    ReleaseNotesManager.shared.resetReleaseNotesState()
                    showingReleaseNotesResetAlert = true
                } label: {
                    Label("Reset Release Notes State", systemImage: "sparkles")
                }
            }

            Button(action: {
                showingConfirmation = true
            }) {
                Label("Reset All Debug Overrides to Defaults", systemImage: "arrow.triangle.2.circlepath")
                    .foregroundColor(.red)
            }
        }
        .actionSheet(isPresented: $showingConfirmation) {
            ActionSheet(
                title: Text("Reset All Overrides?"),
                message: Text(includeReleaseNotes ? "All subscription, appearance, review counters, release notes, and custom debug overrides will be reset to defaults." : "All subscription, appearance, review counters, and custom debug overrides will be reset to defaults."),
                buttons: [
                    .destructive(Text("Reset to Defaults")) {
                        performReset()
                    },
                    .cancel()
                ]
            )
        }
        .alert(isPresented: $showingSuccessAlert) {
            Alert(
                title: Text("Overrides Reset"),
                message: Text("All debug overrides have been restored to default system values."),
                dismissButton: .default(Text("OK"))
            )
        }
        .alert(isPresented: $showingReleaseNotesResetAlert) {
            Alert(
                title: Text("Release Notes Reset"),
                message: Text("Release notes viewed history and session state have been cleared."),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private func performReset() {
        entitlementOverride?.wrappedValue = .automatic
        unlimitedAccess?.wrappedValue = false
        DebugAppearanceManager.apply(mode: .system)
        ReviewPromptManager.debugResetReviewState()
        ReleaseNotesManager.shared.resetReleaseNotesState()
        onReset?()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        showingSuccessAlert = true
    }
}
