import SwiftUI

/// design.md §7's two layouts over one selected day (or, while searching,
/// every day at once) — the header/pill-tab/`.md` panel now live in
/// `HistoryRootView`, shared across every destination.
struct TranscriptsView: View {
    @ObservedObject var model: HistoryViewModel
    let theme: WindowTheme

    var body: some View {
        Group {
            switch model.transcriptsLayout {
            case .library:
                libraryLayout
            case .document:
                documentLayout
            }
        }
    }

    private var isSearching: Bool { !model.searchText.trimmingCharacters(in: .whitespaces).isEmpty }

    private var libraryLayout: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 4) {
                Color.clear.frame(width: 0, height: 0).background(ScrollbarHider())
                if isSearching {
                    filterBar
                    ForEach(groupedByDay) { group in
                        Text(RelativeDay.label(for: group.day))
                            .harpsType(HarpsType.section)
                            .foregroundColor(theme.textFaint)
                            .padding(.top, 14)
                            .padding(.bottom, 2)
                        ForEach(group.captures) { capture in
                            capturedRow(capture)
                        }
                    }
                    if model.visibleCaptures.isEmpty {
                        Text("No matches for \"\(model.searchText)\".")
                            .harpsType(HarpsType.bodySmall)
                            .foregroundColor(theme.textFaint)
                            .padding(.top, 20)
                    }
                } else {
                    ForEach(model.visibleCaptures) { capture in
                        capturedRow(capture)
                    }
                    if model.visibleCaptures.isEmpty {
                        Text("Nothing dictated this day.")
                            .harpsType(HarpsType.bodySmall)
                            .foregroundColor(theme.textFaint)
                            .padding(.top, 20)
                    }
                }
            }
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 22)
            .padding(.top, 4)
            .padding(.bottom, 56)
        }
        .scrollIndicators(.hidden)
    }

    /// Basic app/date filters over search results — the sidebar's `RECENT`
    /// list already narrows to one day for ordinary browsing, so these only
    /// ever apply once a search widens the view back out across every day.
    private var filterBar: some View {
        HStack(spacing: 8) {
            HarpsDropdown(
                titles: ["All apps"] + model.availableApps,
                selected: model.filterApp ?? "All apps",
                theme: theme, compact: true
            ) { title in
                model.filterApp = title == "All apps" ? nil : title
            }
            .fixedSize()

            HarpsDropdown(
                titles: DateRangeFilter.allCases.map(\.label),
                selected: model.filterDateRange.label,
                theme: theme, compact: true
            ) { title in
                if let match = DateRangeFilter.allCases.first(where: { $0.label == title }) {
                    model.filterDateRange = match
                }
            }
            .fixedSize()

            Spacer()
        }
        .padding(.top, 10)
        .padding(.bottom, 6)
    }

    private func capturedRow(_ capture: Capture) -> some View {
        CaptureCardView(
            capture: capture, theme: theme,
            expanded: model.expandedCaptureID == capture.id,
            highlight: model.searchText,
            onToggleExpand: {
                model.expandedCaptureID = model.expandedCaptureID == capture.id ? nil : capture.id
            },
            onCopy: { model.copy(capture) },
            onDelete: { model.delete(capture) },
            onReveal: { model.reveal(capture) }
        )
    }

    private struct DayGroup: Identifiable {
        let day: Date
        let captures: [Capture]
        var id: Date { day }
    }

    private var groupedByDay: [DayGroup] {
        var order: [Date] = []
        var buckets: [Date: [Capture]] = [:]
        for capture in model.visibleCaptures {
            if buckets[capture.day] == nil { order.append(capture.day) }
            buckets[capture.day, default: []].append(capture)
        }
        return order.map { DayGroup(day: $0, captures: buckets[$0] ?? []) }
    }

    /// design.md §7: Document reads one day back, centered with a measure —
    /// no separate day picker here, since the sidebar's `RECENT` list
    /// already is one.
    private var documentLayout: some View {
        ScrollView {
            Color.clear.frame(width: 0, height: 0).background(ScrollbarHider())
            if let url = model.selectedDayFileURL, let content = model.rawContent(at: url) {
                DocumentBodyView(
                    content: content, captures: model.documentCaptures, theme: theme,
                    highlight: model.searchText,
                    onCopy: { _, text in model.copyText(text) },
                    onDelete: { model.delete($0) }
                )
                    .frame(maxWidth: 700)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 38)
                    .padding(.bottom, 80)
                    .padding(.horizontal, 32)
            } else {
                Text("No day selected.")
                    .foregroundColor(theme.textFaint)
                    .padding(24)
            }
        }
        .scrollIndicators(.hidden)
    }
}
