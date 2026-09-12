import AppKit

/// The three destinations design.md §7 names: "Three destinations, not
/// eight." Overview, Transcripts, Settings.
enum Destination: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case transcripts = "Transcripts"
    case settings = "Settings"
    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .overview: return "square.grid.2x2"
        case .transcripts: return "doc.text"
        case .settings: return "gearshape"
        }
    }
}

/// design.md §7's sliding pill tab: "Library is built for finding a thing
/// ... Document is built for reading a day back."
enum TranscriptsLayout: String, CaseIterable, Identifiable {
    case library = "Library"
    case document = "Document"
    var id: String { rawValue }
}

/// Owns the history window's state. Re-reads from disk on `reload()` rather
/// than watching the filesystem — the user is expected to edit these files
/// by hand at any time, and a personal-scale capture history is small
/// enough that re-parsing on every window activation or edit is free.
@MainActor
final class HistoryViewModel: ObservableObject {
    @Published var destination: Destination = .overview
    @Published var transcriptsLayout: TranscriptsLayout = .library
    @Published var searchText = ""
    @Published var selectedDayFileURL: URL?
    @Published var expandedCaptureID: String?
    @Published var showMarkdownPanel = false
    @Published private(set) var captures: [Capture] = []

    private let store: TranscriptStore
    let onOpenSetup: () -> Void

    init(store: TranscriptStore, onOpenSetup: @escaping () -> Void = {}) {
        self.store = store
        self.onOpenSetup = onOpenSetup
        reload()
    }

    func reload() {
        captures = store.listCaptures()
        if selectedDayFileURL == nil {
            selectedDayFileURL = captures.first?.dayFileURL
        }
    }

    /// The distinct days that have captures, newest first — the sidebar's
    /// `RECENT` list and the Document view's day picker both read this.
    var days: [Date] {
        var seen = Set<Date>()
        var ordered: [Date] = []
        for capture in captures where !seen.contains(capture.day) {
            seen.insert(capture.day)
            ordered.append(capture.day)
        }
        return ordered
    }

    func dayFileURL(for day: Date) -> URL? {
        captures.first { $0.day == day }?.dayFileURL
    }

    var filteredCaptures: [Capture] {
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else { return captures }
        let needle = searchText.lowercased()
        return captures.filter {
            $0.text.lowercased().contains(needle) || $0.appName.lowercased().contains(needle)
        }
    }

    func delete(_ capture: Capture) {
        try? store.delete(capture)
        reload()
    }

    func copy(_ capture: Capture) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(capture.text, forType: .string)
    }

    func reveal(_ capture: Capture) {
        NSWorkspace.shared.activateFileViewerSelecting([capture.dayFileURL])
    }

    func rawContent(at url: URL) -> String? {
        store.rawContent(at: url)
    }

    var transcriptsDirectory: URL { store.directoryURL }
}
