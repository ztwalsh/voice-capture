import Foundation
import OSLog

/// PLAN.md Phase 5: "Error handling and logging through OSLog with a way to
/// see recent errors." Every entry goes to the unified log (visible in
/// Console.app or `log show --predicate 'subsystem == "dev.harps.Harps"'`)
/// and is kept in a small in-memory ring buffer so the Settings page can
/// show recent errors without the user needing Console.app at all.
@MainActor
final class AppLog: ObservableObject {
    struct Entry: Identifiable {
        let id = UUID()
        let date: Date
        let level: Level
        let message: String
    }

    enum Level: String {
        case info = "Info"
        case error = "Error"
    }

    static let shared = AppLog()

    @Published private(set) var recentEntries: [Entry] = []
    private let maxEntries = 50
    private let logger = Logger(subsystem: "dev.harps.Harps", category: "general")

    private init() {}

    func info(_ message: String) {
        logger.info("\(message, privacy: .public)")
        record(.info, message)
    }

    func error(_ message: String) {
        logger.error("\(message, privacy: .public)")
        record(.error, message)
    }

    private func record(_ level: Level, _ message: String) {
        recentEntries.insert(Entry(date: Date(), level: level, message: message), at: 0)
        if recentEntries.count > maxEntries {
            recentEntries.removeLast(recentEntries.count - maxEntries)
        }
    }
}
