import Foundation

/// One dictated capture, read back from a day file. Parsed leniently from
/// the same `## HH:mm · App · Ns` heading `TranscriptStore.append` writes —
/// design.md's own principle applies to reading it back too: the transcript
/// text is the only thing that truly matters, the rest is a convenience.
struct Capture: Identifiable, Equatable, Hashable {
    let id: String
    let dayFileURL: URL
    let day: Date
    let time: String
    let appName: String
    let durationSeconds: Int
    let text: String

    var wordCount: Int { text.split(separator: " ").count }
}

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

    /// The folder itself, for a "reveal the folder" affordance and for the
    /// settings row that names where transcripts live.
    var directoryURL: URL { directory }

    /// Every capture across every day file, newest day first and newest
    /// capture within a day first — the history window's whole reason to
    /// exist. Re-reads from disk each call rather than caching, since the
    /// user is expected to edit these files by hand at any time.
    func listCaptures() -> [Capture] {
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil
        ) else { return [] }

        let dayFiles = urls
            .filter { $0.pathExtension == "md" }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }

        return dayFiles.flatMap { url -> [Capture] in
            guard let content = try? String(contentsOf: url, encoding: .utf8),
                  let day = Self.dateFormatter.date(from: url.deletingPathExtension().lastPathComponent)
            else { return [] }
            return Self.parseCaptures(from: content, dayFileURL: url, day: day).reversed()
        }
    }

    /// The raw file content, frontmatter included — what the Document view
    /// and the `.md` panel show, since design.md wants the real file on
    /// screen rather than a re-rendering of it.
    func rawContent(at url: URL) -> String? {
        try? String(contentsOf: url, encoding: .utf8)
    }

    /// Removes one capture from its day file, re-deriving frontmatter
    /// exactly as `append` does. If that was the day's last capture, the
    /// file itself is removed rather than left as an empty frontmatter
    /// husk.
    func delete(_ capture: Capture) throws {
        guard let content = try? String(contentsOf: capture.dayFileURL, encoding: .utf8) else { return }
        let lines = Self.body(of: content).components(separatedBy: "\n")

        var newLines: [String] = []
        var removed = false
        var i = 0
        while i < lines.count {
            let line = lines[i]
            if !removed, let heading = Self.parseHeading(line), heading == (capture.time, capture.appName, capture.durationSeconds) {
                removed = true
                i += 1
                while i < lines.count && !lines[i].hasPrefix("## ") { i += 1 }
                continue
            }
            newLines.append(line)
            i += 1
        }

        let newBody = newLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newBody.isEmpty else {
            try FileManager.default.removeItem(at: capture.dayFileURL)
            return
        }

        let captures = newBody.components(separatedBy: "\n").filter { $0.hasPrefix("## ") }.count
        let words = Self.wordCount(ofBodyExcludingHeaders: newBody)
        let frontmatter = """
        ---
        date: \(Self.dateFormatter.string(from: capture.day))
        captures: \(captures)
        words: \(words)
        ---


        """
        try (frontmatter + newBody + "\n").data(using: .utf8)?.write(to: capture.dayFileURL, options: .atomic)
    }

    /// "## 09:14 · Notes · 6s" → ("09:14", "Notes", 6). `nil` for anything
    /// that isn't a well-formed heading — hand-edited files are expected to
    /// drift, and a malformed heading should just be skipped, not crash the
    /// history window.
    private static func parseHeading(_ line: String) -> (String, String, Int)? {
        guard line.hasPrefix("## ") else { return nil }
        let parts = line.dropFirst(3).components(separatedBy: " · ")
        guard parts.count == 3, parts[2].hasSuffix("s"),
              let seconds = Int(parts[2].dropLast())
        else { return nil }
        return (parts[0], parts[1], seconds)
    }

    private static func parseCaptures(from content: String, dayFileURL: URL, day: Date) -> [Capture] {
        let lines = body(of: content).components(separatedBy: "\n")
        var captures: [Capture] = []
        var i = 0
        // The id needs to be unique per *row*, not per (time, app) — two
        // captures in the same minute in the same app (easy to hit when
        // testing, or just dictating twice back to back) previously
        // collided on id, which made SwiftUI treat the two rows as one
        // identity: hovering one visually highlighted the other, since
        // per-row @State (like CaptureCardView's isHovering) got attributed
        // to whichever view SwiftUI thought "this identity" currently was.
        // The parse position is trivially unique and stable across
        // re-parses of the same unchanged file.
        var index = 0
        while i < lines.count {
            guard let (time, appName, seconds) = parseHeading(lines[i]) else { i += 1; continue }
            i += 1
            var bodyLines: [String] = []
            while i < lines.count && !lines[i].hasPrefix("## ") {
                bodyLines.append(lines[i])
                i += 1
            }
            let text = bodyLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }
            captures.append(Capture(id: "\(dayFileURL.lastPathComponent)#\(index)",
                                     dayFileURL: dayFileURL, day: day, time: time,
                                     appName: appName, durationSeconds: seconds, text: text))
            index += 1
        }
        return captures
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
