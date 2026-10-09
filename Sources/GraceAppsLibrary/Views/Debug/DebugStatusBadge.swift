import SwiftUI

/// A styled status badge capsule used across debug views.
public struct DebugStatusBadge: View {
    public let text: LocalizedStringKey
    public let isActive: Bool
    public let color: Color
    
    public init(_ text: LocalizedStringKey, isActive: Bool) {
        self.text = text
        self.isActive = isActive
        self.color = isActive ? .green : .secondary
    }

    public init(_ text: LocalizedStringKey, color: Color) {
        self.text = text
        self.isActive = true
        self.color = color
    }
    
    public var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }
}
