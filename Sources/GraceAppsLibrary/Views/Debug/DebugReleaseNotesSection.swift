import SwiftUI

/// A reusable debug section for inspecting and resetting Release Notes state.
public struct DebugReleaseNotesSection: View {
    public let releaseNotes: [ReleaseNote]?
    public let isPaidUser: Bool
    public let tierName: LocalizedStringKey
    public let paywallAction: (() -> Void)?

    @State private var lastViewedVersion: String?
    @State private var showingReleaseNotesSheet = false
    @State private var showingResetAlert = false

    public init(
        releaseNotes: [ReleaseNote]? = nil,
        isPaidUser: Bool = false,
        tierName: LocalizedStringKey = "Unlimited Access",
        paywallAction: (() -> Void)? = nil
    ) {
        self.releaseNotes = releaseNotes
        self.isPaidUser = isPaidUser
        self.tierName = tierName
        self.paywallAction = paywallAction
        self._lastViewedVersion = State(initialValue: ReleaseNotesManager.shared.lastViewedVersion)
    }

    public var body: some View {
        Section(header: Text("Release Notes")) {
            HStack {
                Text("Last Viewed Version")
                Spacer()
                Text(lastViewedVersion ?? "None (Fresh Install)")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            if let notes = releaseNotes, !notes.isEmpty {
                Button {
                    showingReleaseNotesSheet = true
                } label: {
                    Label("Preview Release Notes Sheet", systemImage: "play.circle")
                }
                .sheet(isPresented: $showingReleaseNotesSheet) {
                    ReleaseNotesView(
                        releaseNotes: notes,
                        isPaidUser: isPaidUser,
                        tierName: tierName,
                        paywallAction: paywallAction
                    ) {
                        showingReleaseNotesSheet = false
                    }
                }
            }

            Button {
                ReleaseNotesManager.shared.resetReleaseNotesState()
                lastViewedVersion = nil
                showingResetAlert = true
            } label: {
                Label("Reset Release Notes State", systemImage: "arrow.counterclockwise")
            }
        }
        .onAppear {
            lastViewedVersion = ReleaseNotesManager.shared.lastViewedVersion
        }
        .alert(isPresented: $showingResetAlert) {
            Alert(
                title: Text("Release Notes Reset"),
                message: Text("Release notes viewed history and session state have been cleared."),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}
