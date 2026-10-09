import SwiftUI

/// A reusable debug section for testing Onboarding completion states and relaunching flows.
public struct DebugOnboardingSection<OnboardingContent: View>: View {
    public let onboardingStorageKey: String
    public let onboardingView: (() -> OnboardingContent)?
    
    @State private var showingOnboardingSheet = false
    @State private var hasCompleted: Bool = false
    
    public init(
        onboardingStorageKey: String = OnboardingManager.defaultStorageKey,
        onboardingView: (() -> OnboardingContent)? = nil
    ) {
        self.onboardingStorageKey = onboardingStorageKey
        self.onboardingView = onboardingView
        self._hasCompleted = State(initialValue: OnboardingManager.hasCompletedOnboarding(key: onboardingStorageKey))
    }
    
    public var body: some View {
        Section(header: Text("Onboarding Flow")) {
            HStack {
                Text("Onboarding Status")
                Spacer()
                DebugStatusBadge(hasCompleted ? "Completed" : "Pending", isActive: hasCompleted)
            }
            
            if let onboardingView = onboardingView {
                Button {
                    showingOnboardingSheet = true
                } label: {
                    Label("Relaunch Onboarding Flow", systemImage: "play.circle")
                }
                .sheet(isPresented: $showingOnboardingSheet, onDismiss: {
                    hasCompleted = OnboardingManager.hasCompletedOnboarding(key: onboardingStorageKey)
                }) {
                    onboardingView()
                }
            }
            
            Button {
                OnboardingManager.reset(completionKey: onboardingStorageKey)
                hasCompleted = false
            } label: {
                Label("Reset Onboarding Status", systemImage: "arrow.counterclockwise")
            }
        }
        .onAppear {
            hasCompleted = OnboardingManager.hasCompletedOnboarding(key: onboardingStorageKey)
        }
    }
}
