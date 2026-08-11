import SwiftUI

public extension LocalizedStringKey {
    /// Resolves this key to a localized `String` via the main bundle.
    /// Use this when a `LocalizedStringKey` constant needs to appear inside a
    /// plain-`String` interpolation (e.g. Stepper labels, FAQ answers).
    var localized: String {
        // LocalizedStringKey stores its raw key in a child labelled "key".
        // Mirror is the standard community workaround — there is no public API.
        guard let key = Mirror(reflecting: self)
            .children
            .first(where: { $0.label == "key" })?
            .value as? String
        else { return "" }
        return NSLocalizedString(key, comment: "")
    }
}
