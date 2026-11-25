import Foundation

public extension Bundle {
    /// Display name for Watch apps and Watch Widget extensions (`CFBundleDisplayName` -> `CFBundleName`).
    var watchDisplayName: String {
        (object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? ""
    }
}
