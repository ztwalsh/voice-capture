import Foundation

/// One Markdown file per day, per PLAN.md — readable and editable without
/// the app, and it stays that way because this store treats the words a
/// person typed as the only thing that truly matters. Frontmatter counts are
/// a convenience it recomputes on every write, never a value it trusts.
final class TranscriptStore {
    private let directory: URL

    init(directory: URL? = nil) {
        if let directory {
            self.directory = directory
        } else {
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            self.directory = support.appendingPathComponent("Harps/transcripts", isDirectory: true)
        }
    }

    /// Appends one capture to today's file and returns the path written to.
    ///
    /// Read-modify-write, not append-only: the user is expected to edit these
    /// files by hand, so this always re-reads before writing rather than
    /// trusting anything it wrote a moment ago. The write itself uses
    /// `.atomic`, which writes to a temporary file and renames it into place
    /// — a crash mid-write loses nothing, it just leaves the previous
    /// version on disk.
    @discardableResult
    func append(text: String, appName: String, duration: TimeInterval, at date: Date = Date()) throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let url = fileURL(for: date)
        let existingBody = Self.body(of: (try? String(contentsOf: url, encoding: .utf8)) ?? "")

        let time = Self.timeFormatter.string(from: date)
        let entry = "## \(time) · \(appName) · \(Int(duration.rounded()))s\n\n\(text)\n"
        let newBody = existingBody.isEmpty ? entry : existingBody + "\n" + entry

        let captures = newBody.components(separatedBy: "\n")
            .filter { $0.hasPrefix("## ") }
            .count
        let words = Self.wordCount(ofBodyExcludingHeaders: newBody)

        let frontmatter = """
        ---
        date: \(Self.dateFormatter.string(from: date))
        captures: \(captures)
        words: \(words)
        ---


        """
        let content = frontmatter + newBody

        try content.data(using: .utf8)?.write(to: url, options: .atomic)
        return url
    }

    private func fileURL(for date: Date) -> URL {
        directory.appendingPathComponent("\(Self.dateFormatter.string(from: date)).md")
    }

    /// Strips frontmatter if present. Lenient on purpose — a hand-edited file
    /// with malformed frontmatter should still be appendable, not rejected.
    private static func body(of content: String) -> String {
        guard content.hasPrefix("---") else { return content }
        let lines = content.components(separatedBy: "\n")
        guard let closingIndex = lines.dropFirst().firstIndex(where: { $0 == "---" }) else { return content }
        return lines[(closingIndex + 1)...].joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func wordCount(ofBodyExcludingHeaders body: String) -> Int {
        body.components(separatedBy: "\n")
            .filter { !$0.hasPrefix("## ") && !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .flatMap { $0.split(separator: " ") }
            .count
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}
