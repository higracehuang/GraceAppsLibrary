import SwiftUI

/// A reusable debug section for testing, diagnosing, and resetting ReviewPromptManager states.
public struct DebugReviewPromptSection: View {
    @State private var alertMessage: String?
    @State private var showingAlert = false
    
    public init() {}
    
    public var body: some View {
        Section(
            header: Text("App Reviews & Prompts"),
            footer: Text("Direct StoreKit is recommended for production. Quota protection requires 90 days between prompts.")
        ) {
            // MARK: - Diagnostics
            HStack {
                Text("Configured Style")
                Spacer()
                Text(ReviewPromptManager.shared.config.style == .directNative ? "Direct Native" : "Intermediate Alert")
                    .foregroundColor(.secondary)
            }

            HStack {
                Text("Prompted This Version")
                Spacer()
                Text(ReviewPromptManager.shared.hasPromptedForCurrentVersion ? "Yes" : "No")
                    .foregroundColor(ReviewPromptManager.shared.hasPromptedForCurrentVersion ? .orange : .green)
            }

            HStack {
                Text("Cooldown Passed (90d)")
                Spacer()
                Text(ReviewPromptManager.shared.hasPassedCooldown() ? "Yes" : "No")
                    .foregroundColor(ReviewPromptManager.shared.hasPassedCooldown() ? .green : .orange)
            }

            HStack {
                Text("Active Days / Milestones")
                Spacer()
                Text("\(ReviewPromptManager.shared.activeDaysCount)d / \(ReviewPromptManager.shared.milestoneCount)m")
                    .foregroundColor(.secondary)
            }

            HStack {
                Text("Last Milestone")
                Spacer()
                if let name = ReviewPromptManager.shared.lastMilestoneName {
                    if let date = ReviewPromptManager.shared.lastMilestoneDate {
                        Text("\(name) (\(date.formatted(date: .omitted, time: .shortened)))")
                            .foregroundColor(.secondary)
                    } else {
                        Text(name)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("None")
                        .foregroundColor(.secondary)
                }
            }

            // MARK: - Actions
            Button {
                let shown = ReviewPromptManager.shared.requestReviewIfEligible()
                alertMessage = shown
                    ? "Review prompt was eligible and triggered!"
                    : "Review prompt suppressed: conditions not met (check cooldown or version status)."
                showingAlert = true
            } label: {
                Label("Evaluate & Trigger If Eligible", systemImage: "sparkles")
            }

            Button {
                ReviewPromptManager.shared.recordMilestoneEvent("debug_simulation")
                alertMessage = "Recorded milestone event (total: \(ReviewPromptManager.shared.milestoneCount))."
                showingAlert = true
            } label: {
                Label("Simulate Milestone Event (+1)", systemImage: "flag.checkered")
            }

            Button {
                ReviewPromptManager.shared.requestDirectNativeReview()
            } label: {
                Label("Force Native StoreKit Prompt", systemImage: "star.bubble")
            }

            Button {
                ReviewPromptManager.shared.debugPresentReviewPrompt()
            } label: {
                Label("Trigger GAL 2-Step Review Prompt", systemImage: "heart.text.square")
            }

            Button {
                ReviewPromptManager.debugResetReviewState()
                alertMessage = "Review prompt counter, active days, and version history have been reset."
                showingAlert = true
            } label: {
                Label("Reset Review State & Cooldown", systemImage: "star.slash")
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
