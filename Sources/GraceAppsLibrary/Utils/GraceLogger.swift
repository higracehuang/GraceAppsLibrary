//
//  GraceLogger.swift
//  GraceAppsLibrary
//

import Foundation
import os

public struct GraceLogger {
    private static let subsystem = "com.graceapps.library"

    public enum Category: String {
        case review = "⭐️ Review"
        case feedback = "📧 Feedback"
        case debug = "🛠️ Debug"
        case app = "📱 App"

        var logger: Logger {
            Logger(subsystem: GraceLogger.subsystem, category: rawValue)
        }
    }

    public enum Level {
        case info, success, warning, error

        var emoji: String {
            switch self {
            case .info: return "ℹ️"
            case .success: return "✅"
            case .warning: return "⚠️"
            case .error: return "🚨"
            }
        }

        var logType: OSLogType {
            switch self {
            case .info, .success: return .info
            case .warning: return .default
            case .error: return .error
            }
        }
    }

    /// Core logging method using Apple's os.Logger
    public static func log(_ message: String, level: Level = .info, category: Category = .app) {
        let formatted = "\(level.emoji) \(message)"
        category.logger.log(level: level.logType, "\(formatted, privacy: .public)")
    }

    // MARK: - Convenience Methods by Level

    public static func info(_ message: String, category: Category = .app) {
        log(message, level: .info, category: category)
    }

    public static func success(_ message: String, category: Category = .app) {
        log(message, level: .success, category: category)
    }

    public static func warning(_ message: String, category: Category = .app) {
        log(message, level: .warning, category: category)
    }

    // MARK: - Category Express Methods

    public static func review(_ message: String, level: Level = .info) {
        log(message, level: level, category: .review)
    }

    public static func feedback(_ message: String, level: Level = .info) {
        log(message, level: level, category: .feedback)
    }

    public static func debug(_ message: String) {
        log(message, level: .info, category: .debug)
    }
}
