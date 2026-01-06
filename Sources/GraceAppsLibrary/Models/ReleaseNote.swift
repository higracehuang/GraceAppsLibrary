import SwiftUI

public struct ReleaseNote: Identifiable, Hashable {
    public let id = UUID()
    public let version: String
    public let notes: [String]
    public let heroImageName: String?
    
    public init(version: String, notes: [String], heroImageName: String? = nil) {
        self.version = version
        self.notes = notes
        self.heroImageName = heroImageName
    }
}
