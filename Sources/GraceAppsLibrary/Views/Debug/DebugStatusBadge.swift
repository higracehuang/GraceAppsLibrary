import SwiftUI

/// A styled status badge capsule used across debug views.
public struct DebugStatusBadge: View {
    public let text: LocalizedStringKey
    public let isActive: Bool
    
    public init(_ text: LocalizedStringKey, isActive: Bool) {
        self.text = text
        self.isActive = isActive
    }
    
    public var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundColor(isActive ? .green : .secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background((isActive ? Color.green : Color.secondary).opacity(0.12))
            .clipShape(Capsule())
    }
}
