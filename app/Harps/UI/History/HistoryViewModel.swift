import AppKit

/// The three destinations design.md §7 names: "Three destinations, not
/// eight." Overview, Transcripts, Settings.
enum Destination: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case transcripts = "Transcripts"
    case settings = "Settings"
    var id: String { rawValue }
}

/// A search-results date filter — deliberately coarse (no calendar picker):
/// design.md's own posture is that a day file is the real unit of browsing,
/// so this only ever narrows to whole-day buckets already implied by the
/// sidebar's `RECENT` list.
enum DateRangeFilter: String, CaseIterable, Identifiable {
    case anyTime, today, thisWeek, thisMonth
    var id: String { rawValue }

    var label: String {
        switch self {
        case .anyTime: return "Any time"
        case .today: return "Today"
        case .thisWeek: return "This week"
        case .thisMonth: return "This month"
        }
    }

    func contains(_ day: Date, calendar: Calendar = .current) -> Bool {
        switch self {
        case .anyTime: return true
        case .today: return calendar.isDateInToday(day)
        case .thisWeek: return calendar.isDate(day, equalTo: Date(), toGranularity: .weekOfYear)
        case .thisMonth: return calendar.isDate(day, equalTo: Date(), toGranularity: .month)
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
///
/// Browsing model matches `prototype/library-v2.html`: Transcripts shows
/// *one selected day* at a time (in both Library and Document layouts) —
/// picked from the sidebar's `RECENT` list — and typing a search expands
/// that to every day at once, grouped by day, until the search is cleared.
@MainActor
final class HistoryViewModel: ObservableObject {
    @Published var destination: Destination = .overview
    /// Feedback sits outside the three-destination model on purpose — a
    /// permanent bottom-of-sidebar row, not a fourth "real" destination
    /// design.md's "three destinations, not eight" would have to answer for.
    @Published var showingFeedback = false
    @Published var transcriptsLayout: TranscriptsLayout = .library
    @Published var searchText = "" {
        didSet {
            // library-v2.html: typing into search while on Overview jumps
            // to Transcripts, since search only means something there.
            if !searchText.trimmingCharacters(in: .whitespaces).isEmpty, destination == .overview {
                destination = .transcripts
            }
        }
    }
    /// `nil` means "all apps" — both only ever apply while `isSearching`,
    /// since browsing a single selected day already implies one day and
    /// isn't itself filterable by app.
    @Published var filterApp: String?
    @Published var filterDateRange: DateRangeFilter = .anyTime
    @Published var selectedDay: Date?
    @Published var expandedCaptureID: String?
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
        if selectedDay == nil {
            selectedDay = captures.first?.day
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

    func dayFileURL(for day: Date?) -> URL? {
        guard let day else { return nil }
        return captures.first { $0.day == day }?.dayFileURL
    }

    var selectedDayFileURL: URL? { dayFileURL(for: selectedDay) }

    /// The selected day's captures in the order they actually appear in the
    /// file — oldest first, top to bottom — unlike `captures`/`visibleCaptures`,
    /// which are newest-first for Library browsing.
    var documentCaptures: [Capture] {
        captures.filter { $0.day == selectedDay }.reversed()
    }

    var isSearching: Bool { !searchText.trimmingCharacters(in: .whitespaces).isEmpty }

    /// The distinct app names seen across all captures, for the search
    /// filter bar's app menu — sorted for a stable, predictable menu order.
    var availableApps: [String] {
        Array(Set(captures.map(\.appName))).sorted()
    }

    /// The captures the Library layout should show right now: just the
    /// selected day, or every matching capture across all days (narrowed by
    /// the app/date filters) while searching.
    var visibleCaptures: [Capture] {
        guard isSearching else {
            return captures.filter { $0.day == selectedDay }
        }
        let needle = searchText.lowercased()
        return captures.filter {
            ($0.text.lowercased().contains(needle) || $0.appName.lowercased().contains(needle))
                && (filterApp == nil || $0.appName == filterApp)
                && filterDateRange.contains($0.day)
        }
    }

    func selectDay(_ day: Date) {
        selectedDay = day
        destination = .transcripts
        searchText = ""
    }

    func delete(_ capture: Capture) {
        try? store.delete(capture)
        reload()
    }

    func copy(_ capture: Capture) {
        copyText(capture.text)
    }

    /// Document view's selection toolbar copies just the highlighted
    /// substring rather than the whole capture.
    func copyText(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    func reveal(_ capture: Capture) {
        NSWorkspace.shared.activateFileViewerSelecting([capture.dayFileURL])
    }

    func rawContent(at url: URL) -> String? {
        store.rawContent(at: url)
    }

    var transcriptsDirectory: URL { store.directoryURL }
}
