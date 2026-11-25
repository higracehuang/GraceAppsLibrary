import SwiftUI

private struct WatchActiveModifier: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase
    let action: () -> Void

    func body(content: Content) -> some View {
        content.onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                action()
            }
        }
    }
}

public extension View {
    /// Runs `action` whenever the Watch scene becomes `.active` (e.g., on wrist raise or foregrounding).
    func onWatchActive(_ action: @escaping () -> Void) -> some View {
        modifier(WatchActiveModifier(action: action))
    }
}
