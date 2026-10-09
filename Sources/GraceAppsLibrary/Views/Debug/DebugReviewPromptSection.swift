import SwiftUI

/// A reusable debug section for testing and resetting ReviewPromptManager states.
public struct DebugReviewPromptSection: View {
    @State private var alertMessage: String?
    @State private var showingAlert = false
    
    public init() {}
    
    public var body: some View {
        Section(header: Text("App Reviews & Prompts")) {
            Button {
                ReviewPromptManager.shared.debugPresentReviewPrompt()
            } label: {
                Label("Trigger GAL 2-Step Review Prompt", systemImage: "heart.text.square")
            }

            Button {
                ReviewPromptManager.shared.requestDirectNativeReview()
            } label: {
                Label("Trigger Native Review Prompt", systemImage: "star.bubble")
            }

            Button {
                ReviewPromptManager.debugResetReviewState()
                alertMessage = "Review prompt counter and version history have been reset."
                showingAlert = true
            } label: {
                Label("Reset Review State", systemImage: "star.slash")
            }
        }
        .alert(isPresented: $showingAlert) {
            Alert(
                title: Text("Debug"),
                message: Text(alertMessage ?? ""),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}
