import SwiftUI

/// A reusable debug section for testing Light Mode and Dark Mode across the host application.
public struct DebugAppearanceSection: View {
    @State private var selectedMode: DebugAppearanceManager.Mode = DebugAppearanceManager.currentMode()

    public init() {}

    private var modeBinding: Binding<DebugAppearanceManager.Mode> {
        Binding(
            get: { selectedMode },
            set: { newMode in
                selectedMode = newMode
                DebugAppearanceManager.apply(mode: newMode)
            }
        )
    }

    public var body: some View {
        Section(
            header: Text("Appearance"),
            footer: Text("Forces the app into Light or Dark mode for testing without altering iOS device settings.")
        ) {
            HStack {
                Label("Current Theme", systemImage: themeSystemImage)
                Spacer()
                DebugStatusBadge(
                    LocalizedStringKey(selectedMode.rawValue),
                    color: statusBadgeColor
                )
            }

            Picker("Appearance", selection: modeBinding) {
                ForEach(DebugAppearanceManager.Mode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
        }
        .onAppear {
            selectedMode = DebugAppearanceManager.currentMode()
        }
    }

    private var themeSystemImage: String {
        switch selectedMode {
        case .light:
            return "sun.max.fill"
        case .dark:
            return "moon.fill"
        case .system:
            return "circle.lefthalf.fill"
        }
    }

    private var statusBadgeColor: Color {
        switch selectedMode {
        case .light:
            return .orange
        case .dark:
            return .purple
        case .system:
            return .blue
        }
    }
}
