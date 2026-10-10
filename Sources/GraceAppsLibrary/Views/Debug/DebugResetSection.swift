import SwiftUI

/// A reusable debug section for resetting all GAL and app-specific debug overrides to defaults.
public struct DebugResetSection: View {
    public let unlimitedAccess: Binding<Bool>?
    public let onReset: (() -> Void)?

    @State private var showingConfirmation = false
    @State private var showingSuccessAlert = false

    public init(
        unlimitedAccess: Binding<Bool>? = nil,
        onReset: (() -> Void)? = nil
    ) {
        self.unlimitedAccess = unlimitedAccess
        self.onReset = onReset
    }

    public var body: some View {
        Section(
            footer: Text("Restores all entitlements, appearance, review counters, and app-specific debug overrides to default behavior.")
        ) {
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
                message: Text("All subscription, appearance, review counters, and custom debug overrides will be reset to defaults."),
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
    }

    private func performReset() {
        unlimitedAccess?.wrappedValue = false
        DebugAppearanceManager.apply(mode: .system)
        ReviewPromptManager.debugResetReviewState()
        onReset?()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        showingSuccessAlert = true
    }
}
