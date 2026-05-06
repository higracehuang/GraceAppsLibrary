import SwiftUI

public struct ReleaseNote: Identifiable, Hashable {
    public let id = UUID()
    public let version: String
    public let notes: [LocalizedStringKey]
    public let heroImageName: String?
    
    public init(version: String, notes: [LocalizedStringKey], heroImageName: String? = nil) {
        self.version = version
        self.notes = notes
        self.heroImageName = heroImageName
    }

    public static func == (lhs: ReleaseNote, rhs: ReleaseNote) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
