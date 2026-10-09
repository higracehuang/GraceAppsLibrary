import SwiftUI

/// A reusable debug section for testing and resetting ReviewPromptManager states.
public struct DebugReviewPromptSection: View {
    @State private var alertMessage: String?
    @State private var showingAlert = false
    
    public init() {}
    
    public var body: some View {
        Section(header: Text("App Reviews & Prompts")) {
            Button {
                ReviewPromptManager.debugResetReviewState()
                alertMessage = "Review prompt counter and version history have been reset."
                showingAlert = true
            } label: {
                Label("Reset Review State", systemImage: "star.slash")
            }
            
            Button {
                ReviewPromptManager.shared.requestDirectNativeReview()
            } label: {
                Label("Trigger Native Review Prompt", systemImage: "star.bubble")
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
