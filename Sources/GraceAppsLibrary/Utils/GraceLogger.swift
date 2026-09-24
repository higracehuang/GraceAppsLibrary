//
//  GraceLogger.swift
//  GraceAppsLibrary
//

import Foundation

public enum GraceLogger {
    public enum Category: String {
        case review = "⭐️ Review"
        case feedback = "📧 Feedback"
        case debug = "🛠️ Debug"
        case app = "📱 App"
    }

    public static func info(_ message: String, category: Category = .app) {
        #if DEBUG
        print("[GraceApps | \(category.rawValue)] ℹ️  \(message)")
        #endif
    }

    public static func success(_ message: String, category: Category = .app) {
        #if DEBUG
        print("[GraceApps | \(category.rawValue)] ✅ \(message)")
        #endif
    }

    public static func warning(_ message: String, category: Category = .app) {
        #if DEBUG
        print("[GraceApps | \(category.rawValue)] ⚠️  \(message)")
        #endif
    }
}
