import SwiftUI

/// design.md §7: four stat blocks separated by hairlines, a captures-per-day
/// chart (this week solid, last week dashed — one measure across
/// consecutive periods, so the two series separate by lightness and dash
/// pattern rather than hue), then the most recent captures.
struct OverviewView: View {
    @ObservedObject var model: HistoryViewModel
    let theme: WindowTheme

    private var stats: Stats { Stats(captures: model.captures) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Text("Overview")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(theme.text)

                statRow

                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 14) {
                        legendSwatch(dashed: false, label: "This week")
                        legendSwatch(dashed: true, label: "Last week")
                    }
                    CapturesChart(thisWeek: stats.thisWeekCounts, lastWeek: stats.lastWeekCounts, theme: theme)
                        .frame(height: 140)
                }
                .padding(16)
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(theme.hairline))

                VStack(alignment: .leading, spacing: 10) {
                    Text("RECENT CAPTURES")
                        .font(.system(size: 9.5, design: .monospaced))
                        .tracking(1.2)
                        .foregroundColor(theme.textFaint)
                    ForEach(model.captures.prefix(4)) { capture in
                        CaptureCardView(
                            capture: capture, theme: theme,
                            expanded: model.expandedCaptureID == capture.id,
                            onToggleExpand: { toggleExpand(capture) },
                            onCopy: { model.copy(capture) },
                            onDelete: { model.delete(capture) },
                            onReveal: { model.reveal(capture) }
                        )
                    }
                    if model.captures.isEmpty {
                        Text("Nothing dictated yet. Hold the hotkey anywhere to start.")
                            .font(.system(size: 13))
                            .foregroundColor(theme.textFaint)
                    }
                }
            }
            .padding(28)
        }
    }

    private func toggleExpand(_ capture: Capture) {
        model.expandedCaptureID = model.expandedCaptureID == capture.id ? nil : capture.id
    }

    private var statRow: some View {
        HStack(spacing: 0) {
            statBlock("Captures today", value: "\(stats.capturesToday)",
                      delta: stats.delta(current: stats.capturesToday, previous: stats.capturesYesterday), comparison: "vs yesterday")
            divider
            statBlock("Words today", value: "\(stats.wordsToday)",
                      delta: nil, comparison: nil)
            divider
            statBlock("Captures this week", value: "\(stats.capturesThisWeek)",
                      delta: stats.delta(current: stats.capturesThisWeek, previous: stats.capturesLastWeek), comparison: "vs last week")
            divider
            statBlock("Avg words / capture", value: stats.avgWordsThisWeek, delta: nil, comparison: nil)
        }
    }

    private var divider: some View {
        Rectangle().frame(width: 1).foregroundColor(theme.hairline).padding(.vertical, 4)
    }

    private func statBlock(_ label: String, value: String, delta: Double?, comparison: String?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(theme.textSubtle)
            Text(value)
                .font(.system(size: 27, weight: .semibold))
                .tracking(-0.3)
                .foregroundColor(theme.text)
            if let delta, let comparison {
                HStack(spacing: 4) {
                    if delta > 0 {
                        Image(systemName: "arrow.up.right")
                        Text("\(Int(delta))%")
                            .font(.system(size: 11, weight: .medium))
                    } else {
                        Text("—")
                            .font(.system(size: 11, weight: .medium))
                    }
                    Text(comparison)
                        .font(.system(size: 11))
                        .foregroundColor(theme.textFaint)
                }
                .foregroundColor(delta > 0 ? theme.up : theme.textFaint)
            } else {
                Text(" ")
                    .font(.system(size: 11))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
    }

    private func legendSwatch(dashed: Bool, label: String) -> some View {
        HStack(spacing: 6) {
            Path { path in
                path.move(to: CGPoint(x: 0, y: 4))
                path.addLine(to: CGPoint(x: 16, y: 4))
            }
            .stroke(theme.textMuted, style: StrokeStyle(lineWidth: 1.5, dash: dashed ? [3, 3] : []))
            .frame(width: 16, height: 8)
            Text(label)
                .font(.system(size: 10.5))
                .foregroundColor(theme.textSubtle)
        }
    }
}

/// One measure across two consecutive periods — captures per day, last
/// week's shape drawn dashed rather than in a second hue, per design.md's
/// accessibility note that the distinction has to survive without color.
private struct CapturesChart: View {
    let thisWeek: [Int]
    let lastWeek: [Int]
    let theme: WindowTheme

    var body: some View {
        GeometryReader { geo in
            let maxValue = max(1, (thisWeek + lastWeek).max() ?? 1)
            line(thisWeek, in: geo.size, maxValue: maxValue, dashed: false)
            line(lastWeek, in: geo.size, maxValue: maxValue, dashed: true)
        }
    }

    private func line(_ values: [Int], in size: CGSize, maxValue: Int, dashed: Bool) -> some View {
        Path { path in
            guard values.count > 1 else { return }
            let stepX = size.width / CGFloat(values.count - 1)
            for (index, value) in values.enumerated() {
                let x = CGFloat(index) * stepX
                let y = size.height - (CGFloat(value) / CGFloat(maxValue)) * size.height
                if index == 0 { path.move(to: CGPoint(x: x, y: y)) }
                else { path.addLine(to: CGPoint(x: x, y: y)) }
            }
        }
        .stroke(theme.textMuted, style: StrokeStyle(lineWidth: 1.75, lineCap: .round, lineJoin: .round,
                                                      dash: dashed ? [4, 4] : []))
    }
}

private struct Stats {
    let capturesToday: Int
    let capturesYesterday: Int
    let wordsToday: Int
    let capturesThisWeek: Int
    let capturesLastWeek: Int
    let thisWeekCounts: [Int]
    let lastWeekCounts: [Int]
    let avgWordsThisWeek: String

    init(captures: [Capture]) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        func day(offsetFromToday offset: Int) -> Date {
            calendar.date(byAdding: .day, value: -offset, to: today) ?? today
        }
        func capturesOn(_ day: Date) -> [Capture] { captures.filter { $0.day == day } }

        capturesToday = capturesOn(today).count
        capturesYesterday = capturesOn(day(offsetFromToday: 1)).count
        wordsToday = capturesOn(today).reduce(0) { $0 + $1.wordCount }

        let thisWeekDays = (0..<7).map { day(offsetFromToday: $0) }.reversed()
        let lastWeekDays = (7..<14).map { day(offsetFromToday: $0) }.reversed()
        thisWeekCounts = thisWeekDays.map { capturesOn($0).count }
        lastWeekCounts = lastWeekDays.map { capturesOn($0).count }
        capturesThisWeek = thisWeekCounts.reduce(0, +)
        capturesLastWeek = lastWeekCounts.reduce(0, +)

        let wordsThisWeek = thisWeekDays.reduce(0) { $0 + capturesOn($1).reduce(0) { $0 + $1.wordCount } }
        avgWordsThisWeek = capturesThisWeek > 0 ? "\(wordsThisWeek / capturesThisWeek)" : "—"
    }

    func delta(current: Int, previous: Int) -> Double? {
        guard previous > 0 else { return nil }
        return (Double(current - previous) / Double(previous)) * 100
    }
}
