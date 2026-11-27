import Foundation
import os
@_exported import GraceAppsLibraryCore

/// Lightweight, self-contained logger for `GraceAppsLibraryWatch` (no dependency on `GraceAppsLibrary`).
public enum GraceWatchLogger {
    private static let subsystem = "com.graceapps.library.watch"

    public enum Category: String {
        case sync = "⌚️ Sync"
        case session = "🔌 WCSession"
        case widget = "🧩 Widget"
        case app = "⌚️ App"
        case debug = "🛠️ Debug"

        var logger: Logger {
            Logger(subsystem: GraceWatchLogger.subsystem, category: rawValue)
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

    public static func log(_ message: String, level: Level = .info, category: Category = .app) {
        let formatted = "\(level.emoji) \(message)"
        category.logger.log(level: level.logType, "\(formatted, privacy: .public)")
        #if DEBUG
        print("[\(category.rawValue)] \(formatted)")
        #endif
    }

    public static func sync(_ message: String, level: Level = .info) {
        log(message, level: level, category: .sync)
    }

    public static func session(_ message: String, level: Level = .info) {
        log(message, level: level, category: .session)
    }

    public static func widget(_ message: String, level: Level = .info) {
        log(message, level: level, category: .widget)
    }

    public static func app(_ message: String, level: Level = .info) {
        log(message, level: level, category: .app)
    }

    public static func debug(_ message: String, level: Level = .info) {
        log(message, level: level, category: .debug)
    }
}
