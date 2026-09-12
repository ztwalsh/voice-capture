import SwiftUI

/// design.md §7 refined to match `prototype/library-v2.html`: four stat
/// blocks separated by hairlines, a captures-per-day chart with a real
/// hover tooltip (this week solid, last week dashed), then the most recent
/// captures in the same chip-tagged, outline-free style Transcripts uses.
struct OverviewView: View {
    @ObservedObject var model: HistoryViewModel
    let theme: WindowTheme

    private var stats: Stats { Stats(captures: model.captures) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                statRow
                    .overlay(Rectangle().frame(height: 1).foregroundColor(theme.hairline), alignment: .bottom)

                VStack(alignment: .leading, spacing: 20) {
                    chartHeader
                    CapturesChart(thisWeek: stats.thisWeekCounts, lastWeek: stats.lastWeekCounts,
                                  dayLabels: stats.dayLabels, theme: theme)
                        .frame(height: 190)
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 24)
                .overlay(Rectangle().frame(height: 1).foregroundColor(theme.hairline), alignment: .bottom)

                VStack(alignment: .leading, spacing: 2) {
                    Text("RECENT CAPTURES")
                        .harpsType(HarpsType.section)
                        .foregroundColor(theme.textFaint)
                        .padding(.top, 22)
                        .padding(.bottom, 10)
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
                            .harpsType(HarpsType.bodySmall)
                            .foregroundColor(theme.textFaint)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 56)
            }
            .background(ScrollbarHider())
        }
        .scrollIndicators(.hidden)
    }

    private func toggleExpand(_ capture: Capture) {
        model.expandedCaptureID = model.expandedCaptureID == capture.id ? nil : capture.id
    }

    private var statRow: some View {
        HStack(spacing: 0) {
            statBlock("Captures this week", value: "\(stats.capturesThisWeek)",
                      delta: stats.delta(current: stats.capturesThisWeek, previous: stats.capturesLastWeek),
                      comparison: "vs last week")
            divider
            statBlock("Words dictated", value: stats.wordsThisWeekFormatted,
                      delta: stats.delta(current: stats.wordsThisWeek, previous: stats.wordsLastWeek),
                      comparison: "vs last week")
            divider
            statBlock("Time speaking", value: stats.timeSpeakingFormatted, delta: nil, comparison: "this week")
            divider
            statBlock("Median capture", value: stats.medianCaptureFormatted, delta: nil,
                      comparison: "across \(stats.totalCaptures) captures")
        }
    }

    private var divider: some View {
        Rectangle().frame(width: 1).foregroundColor(theme.hairline).padding(.vertical, 4)
    }

    private func statBlock(_ label: String, value: String, delta: Double?, comparison: String?) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(label)
                .font(.custom("Geist-Regular", size: 12.5))
                .foregroundColor(theme.textSubtle)
            Text(value)
                .harpsType(HarpsType.display)
                .foregroundColor(theme.text)
            HStack(spacing: 7) {
                if let delta, delta > 0 {
                    HStack(spacing: 3) {
                        CentralIconView(svg: CentralIcons.arrowUpRight, color: theme.up)
                            .frame(width: 11, height: 11)
                        Text("\(Int(delta.rounded()))%")
                    }
                    .font(.custom("Geist-Medium", size: 12))
                    .foregroundColor(theme.up)
                }
                if let comparison {
                    Text(comparison)
                        .font(.custom("Geist-Regular", size: 12))
                        .foregroundColor(theme.textFaint)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 22)
        .padding(.vertical, 24)
    }

    private var chartHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Captures per day")
                    .font(.custom("Geist-Regular", size: 12.5))
                    .foregroundColor(theme.textSubtle)
                Text("\(stats.capturesThisWeek) this week")
                    .font(.custom("Geist-SemiBold", size: 22))
                    .tracking(-0.025 * 22)
                    .foregroundColor(theme.text)
            }
            Spacer()
            HStack(spacing: 16) {
                legendSwatch(dashed: false, label: "This week")
                legendSwatch(dashed: true, label: "Last week")
            }
        }
    }

    private func legendSwatch(dashed: Bool, label: String) -> some View {
        HStack(spacing: 7) {
            Path { path in
                path.move(to: CGPoint(x: 0, y: 3))
                path.addLine(to: CGPoint(x: 18, y: 3))
            }
            .stroke(dashed ? theme.textFaint : theme.text, style: StrokeStyle(lineWidth: 2, dash: dashed ? [4, 3] : []))
            .frame(width: 18, height: 6)
            Text(label)
                .font(.custom("Geist-Regular", size: 11.5))
                .foregroundColor(theme.textMuted)
        }
    }
}

/// One measure across two consecutive periods — captures per day, last
/// week's shape drawn dashed rather than in a second hue, per design.md's
/// accessibility note that the distinction has to survive without color.
/// Hover shows a crosshair, both series' dots, and a tooltip, matching
/// `library-v2.html`'s chart interaction.
private struct CapturesChart: View {
    let thisWeek: [Int]
    let lastWeek: [Int]
    let dayLabels: [String]
    let theme: WindowTheme

    @State private var hoverIndex: Int?

    private let padL: CGFloat = 34
    private let padR: CGFloat = 4
    private let padT: CGFloat = 4
    private let padB: CGFloat = 22

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let maxValue = niceMax
            ZStack(alignment: .topLeading) {
                gridAndAxes(size: size, maxValue: maxValue)
                line(lastWeek, size: size, maxValue: maxValue, dashed: true, color: theme.textFaint)
                line(thisWeek, size: size, maxValue: maxValue, dashed: false, color: theme.text)

                // Rendered only while actually hovering, with no fade
                // transition on appear/disappear — two different fade-based
                // approaches (an animated `.opacity()`, then a
                // `.compositingGroup()` on top of that) both still showed
                // the tooltip's text arriving before its own background
                // fill. Since the two elements never fade at all now,
                // there's no cross-fade for them to visibly desync during;
                // `.animation(value: i)` still glides the position and
                // content smoothly *while* hovering across days, which is
                // the part of this that was already working well.
                if let hoverIndex, thisWeek.indices.contains(hoverIndex) {
                    crosshair(at: hoverIndex, size: size, maxValue: maxValue)
                        .animation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.35), value: hoverIndex)
                    tooltip(at: hoverIndex, size: size, maxValue: maxValue)
                        .animation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.35), value: hoverIndex)
                }
            }
            .contentShape(Rectangle())
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    hoverIndex = index(forX: location.x, width: size.width)
                case .ended:
                    hoverIndex = nil
                }
            }
        }
    }

    private var niceMax: Int {
        let raw = max(1, (thisWeek + lastWeek).max() ?? 1)
        let step = 4
        return ((raw + step - 1) / step) * step
    }

    private func x(_ i: Int, width: CGFloat) -> CGFloat {
        let inner = width - padL - padR
        guard thisWeek.count > 1 else { return padL }
        return padL + inner * CGFloat(i) / CGFloat(thisWeek.count - 1)
    }

    private func y(_ value: Int, height: CGFloat, maxValue: Int) -> CGFloat {
        let inner = height - padT - padB
        return padT + inner - inner * CGFloat(value) / CGFloat(maxValue)
    }

    private func index(forX px: CGFloat, width: CGFloat) -> Int {
        let inner = width - padL - padR
        guard inner > 0, thisWeek.count > 1 else { return 0 }
        let ratio = (px - padL) / inner
        let i = Int((ratio * CGFloat(thisWeek.count - 1)).rounded())
        return min(max(i, 0), thisWeek.count - 1)
    }

    private func gridAndAxes(size: CGSize, maxValue: Int) -> some View {
        let ticks = [0, maxValue / 2, maxValue]
        return ZStack(alignment: .topLeading) {
            ForEach(ticks, id: \.self) { tick in
                Path { p in
                    p.move(to: CGPoint(x: padL, y: y(tick, height: size.height, maxValue: maxValue)))
                    p.addLine(to: CGPoint(x: size.width - padR, y: y(tick, height: size.height, maxValue: maxValue)))
                }
                .stroke(theme.hairline, style: StrokeStyle(lineWidth: 1, dash: [2, 4]))
                Text("\(tick)")
                    .font(.custom("GeistMono-Regular", size: 10))
                    .foregroundColor(theme.textFaint)
                    .position(x: padL - 14, y: y(tick, height: size.height, maxValue: maxValue))
            }
            ForEach(Array(dayLabels.enumerated()), id: \.offset) { i, label in
                Text(label)
                    .font(.custom("GeistMono-Regular", size: 10))
                    .foregroundColor(theme.textFaint)
                    .position(x: x(i, width: size.width), y: size.height - padB / 2)
            }
        }
    }

    private func line(_ values: [Int], size: CGSize, maxValue: Int, dashed: Bool, color: Color) -> some View {
        Path { path in
            guard values.count > 1 else { return }
            for (index, value) in values.enumerated() {
                let point = CGPoint(x: x(index, width: size.width), y: y(value, height: size.height, maxValue: maxValue))
                if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
        }
        .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round,
                                           dash: dashed ? [5, 4] : []))
    }

    private func crosshair(at i: Int, size: CGSize, maxValue: Int) -> some View {
        let cx = x(i, width: size.width)
        return ZStack {
            Path { p in
                p.move(to: CGPoint(x: cx, y: padT))
                p.addLine(to: CGPoint(x: cx, y: size.height - padB))
            }
            .stroke(theme.hairline, lineWidth: 1)
            Circle().fill(theme.text).frame(width: 8, height: 8)
                .position(x: cx, y: y(thisWeek[i], height: size.height, maxValue: maxValue))
            Circle().fill(theme.textFaint).frame(width: 7, height: 7)
                .position(x: cx, y: y(lastWeek[i], height: size.height, maxValue: maxValue))
        }
    }

    private func tooltip(at i: Int, size: CGSize, maxValue: Int) -> some View {
        let cx = x(i, width: size.width)
        let topY = min(y(thisWeek[i], height: size.height, maxValue: maxValue),
                        y(lastWeek[i], height: size.height, maxValue: maxValue))
        let label = i < dayLabels.count ? dayLabels[i] : ""
        // An explicit ZStack with the shape as a true sibling, rather than
        // `.background(_, in:)` — that convenience modifier was letting the
        // fill and the text content fade in at visibly different rates, as
        // if they were on separate layers rather than one animated unit.
        // The muted row labels blend toward the tooltip's own fill color
        // instead of using `.opacity()`, for the same reason: a second,
        // independent alpha value in the subtree is exactly what caused
        // the mismatch in the first place.
        // A fixed neutral gray rather than `theme.bg.opacity(...)` — the
        // tooltip's fill is always the inverse of the window's own
        // foreground/background pair, so a solid mid-gray reads as "muted"
        // against it in both appearances without needing an alpha value.
        let mutedLabel = Color(white: 0.5)
        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 8).fill(theme.text)
            VStack(alignment: .leading, spacing: 3) {
                Text(label).font(.custom("Geist-SemiBold", size: 11.5))
                HStack(spacing: 10) {
                    Text("This week").foregroundColor(mutedLabel)
                    Spacer()
                    Text("\(thisWeek[i])")
                }
                HStack(spacing: 10) {
                    Text("Last week").foregroundColor(mutedLabel)
                    Spacer()
                    Text("\(lastWeek[i])")
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
        }
        .font(.custom("GeistMono-Regular", size: 11))
        .foregroundColor(theme.bg)
        .frame(width: 128, height: 78, alignment: .topLeading)
        // Forces the whole tooltip to rasterize as a single flattened
        // bitmap in one pass, rather than compositing the fill and the
        // text as separate layers — `.compositingGroup()` alone (a weaker
        // guarantee than this) did not stop the text and the background
        // from visibly committing to screen at different moments.
        .drawingGroup()
        .position(x: min(max(cx, 66), size.width - 66), y: max(topY - 58, 38))
        .allowsHitTesting(false)
    }
}

private struct Stats {
    let capturesThisWeek: Int
    let capturesLastWeek: Int
    let wordsThisWeek: Int
    let wordsLastWeek: Int
    let thisWeekCounts: [Int]
    let lastWeekCounts: [Int]
    let dayLabels: [String]
    let totalCaptures: Int
    let timeSpeakingSecondsThisWeek: Int
    let medianCaptureSeconds: Int

    init(captures: [Capture]) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        func day(offsetFromToday offset: Int) -> Date {
            calendar.date(byAdding: .day, value: -offset, to: today) ?? today
        }
        func capturesOn(_ day: Date) -> [Capture] { captures.filter { $0.day == day } }

        let thisWeekDays = (0..<7).map { day(offsetFromToday: $0) }.reversed().map { $0 }
        let lastWeekDays = (7..<14).map { day(offsetFromToday: $0) }.reversed().map { $0 }
        thisWeekCounts = thisWeekDays.map { capturesOn($0).count }
        lastWeekCounts = lastWeekDays.map { capturesOn($0).count }
        capturesThisWeek = thisWeekCounts.reduce(0, +)
        capturesLastWeek = lastWeekCounts.reduce(0, +)

        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEE"
        dayLabels = thisWeekDays.map { dayFormatter.string(from: $0) }

        wordsThisWeek = thisWeekDays.reduce(0) { $0 + capturesOn($1).reduce(0) { $0 + $1.wordCount } }
        wordsLastWeek = lastWeekDays.reduce(0) { $0 + capturesOn($1).reduce(0) { $0 + $1.wordCount } }

        timeSpeakingSecondsThisWeek = thisWeekDays.reduce(0) { $0 + capturesOn($1).reduce(0) { $0 + $1.durationSeconds } }

        totalCaptures = captures.count
        let durations = captures.map(\.durationSeconds).sorted()
        if durations.isEmpty {
            medianCaptureSeconds = 0
        } else if durations.count % 2 == 1 {
            medianCaptureSeconds = durations[durations.count / 2]
        } else {
            medianCaptureSeconds = (durations[durations.count / 2 - 1] + durations[durations.count / 2]) / 2
        }
    }

    var wordsThisWeekFormatted: String {
        wordsThisWeek.formatted(.number.grouping(.automatic))
    }

    var timeSpeakingFormatted: String {
        let minutes = timeSpeakingSecondsThisWeek / 60
        let seconds = timeSpeakingSecondsThisWeek % 60
        return minutes > 0 ? "\(minutes)m \(seconds)s" : "\(seconds)s"
    }

    var medianCaptureFormatted: String { "\(medianCaptureSeconds)s" }

    func delta(current: Int, previous: Int) -> Double? {
        guard previous > 0 else { return nil }
        return (Double(current - previous) / Double(previous)) * 100
    }
}
