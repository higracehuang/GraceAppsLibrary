import SwiftUI

/// A reusable debug section for testing RevenueCat paywalls and dynamic offerings.
public struct DebugOfferingsSection: View {
    public let loadOfferings: (() async -> [String])?
    public let onSelectOffering: (String?) -> Void
    
    @State private var offerings: [String] = []
    @State private var isLoading: Bool = false
    @State private var hasLoaded: Bool = false
    
    public init(
        loadOfferings: (() async -> [String])? = nil,
        onSelectOffering: @escaping (String?) -> Void
    ) {
        self.loadOfferings = loadOfferings
        self.onSelectOffering = onSelectOffering
    }
    
    public var body: some View {
        Section(
            header: Text("RevenueCat Offerings"),
            footer: Text("Select an offering to preview its configured paywall UI.")
        ) {
            Button {
                onSelectOffering(nil)
            } label: {
                Label("Test Default Offering", systemImage: "sparkles")
            }
            
            ForEach(offerings, id: \.self) { offeringId in
                Button {
                    onSelectOffering(offeringId)
                } label: {
                    Label("Test Offering: \(offeringId)", systemImage: "tag")
                }
            }
            
            if let loadOfferings = loadOfferings {
                Button {
                    fetchOfferings(loadOfferings)
                } label: {
                    HStack {
                        Label("Reload Offerings from RevenueCat", systemImage: "arrow.clockwise")
                        if isLoading {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(isLoading)
            }
        }
        .onAppear {
            if let loadOfferings = loadOfferings, !hasLoaded {
                fetchOfferings(loadOfferings)
            }
        }
    }
    
    private func fetchOfferings(_ loader: @escaping () async -> [String]) {
        isLoading = true
        Task {
            let loaded = await loader()
            await MainActor.run {
                self.offerings = loaded
                self.isLoading = false
                self.hasLoaded = true
            }
        }
    }
}
