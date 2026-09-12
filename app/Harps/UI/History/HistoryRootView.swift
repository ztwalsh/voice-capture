import SwiftUI

/// design.md §7: the window's overall shape. A 236px sidebar plus whichever
/// destination's content is selected.
struct HistoryRootView: View {
    @ObservedObject var model: HistoryViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = WindowTheme(colorScheme)
        HStack(spacing: 0) {
            SidebarView(model: model, theme: theme)
                .frame(width: 236)
                .background(theme.side)

            Divider().overlay(theme.hairline)

            content(theme: theme)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(theme.bg)
        }
        .background(theme.bg)
        .frame(minWidth: 760, minHeight: 480)
    }

    @ViewBuilder
    private func content(theme: WindowTheme) -> some View {
        switch model.destination {
        case .overview:
            OverviewView(model: model, theme: theme)
        case .transcripts:
            TranscriptsView(model: model, theme: theme)
        case .settings:
            SettingsView(model: model, theme: theme)
        }
    }
}

/// design.md §7: mark+wordmark, three destinations, then a `RECENT` day
/// list with ⌘1–⌘9 shortcuts, then a hairline footer with the current file
/// path and a settings gear.
private struct SidebarView: View {
    @ObservedObject var model: HistoryViewModel
    let theme: WindowTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            VStack(alignment: .leading, spacing: 2) {
                ForEach(Destination.allCases) { destination in
                    destinationRow(destination)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)

            Text("RECENT")
                .harpsType(HarpsType.section)
                .foregroundColor(theme.textFaint)
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 6)

            ScrollView {
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(Array(model.days.prefix(9).enumerated()), id: \.element) { index, day in
                        dayRow(day: day, shortcutIndex: index + 1)
                    }
                }
                .padding(.horizontal, 12)
            }

            Spacer(minLength: 0)
            footer
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            CaretMark()
                .frame(width: 14, height: 14)
                .padding(5)
                .background(theme.text, in: RoundedRectangle(cornerRadius: 7))
                .foregroundColor(theme.bg)
            Text("Harps")
                .font(.custom("Geist-SemiBold", size: 13.5))
                .tracking(-0.02 * 13.5)
                .foregroundColor(theme.text)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 8)
    }

    private func destinationRow(_ destination: Destination) -> some View {
        let selected = model.destination == destination
        return Button {
            model.destination = destination
        } label: {
            HStack(spacing: 9) {
                Image(systemName: destination.symbolName)
                    .font(.system(size: 12.5))
                    .frame(width: 16)
                    .opacity(selected ? 1 : 0.62)
                Text(destination.rawValue)
                    .font(.custom(selected ? "Geist-Medium" : "Geist-Regular", size: 13))
                Spacer()
            }
            .foregroundColor(selected ? theme.text : theme.textMuted)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(selected ? theme.sel : Color.clear, in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private func dayRow(day: Date, shortcutIndex: Int) -> some View {
        Button {
            model.destination = .transcripts
            model.transcriptsLayout = .document
            model.selectedDayFileURL = model.dayFileURL(for: day)
        } label: {
            HStack(spacing: 6) {
                Text("→").foregroundColor(theme.textFaint)
                Text(Self.dayFormatter.string(from: day))
                    .harpsType(HarpsType.bodySmall)
                    .foregroundColor(theme.textMuted)
                Spacer()
                if shortcutIndex <= 9 {
                    Text("⌘\(shortcutIndex)")
                        .harpsType(HarpsType.metaSmall)
                        .foregroundColor(theme.textFaint)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
        }
        .buttonStyle(.plain)
        .keyboardShortcut(KeyEquivalent(Character("\(shortcutIndex)")), modifiers: .command)
    }

    private var footer: some View {
        HStack(spacing: 6) {
            Text(model.transcriptsDirectory.path)
                .harpsType(HarpsType.metaSmall)
                .foregroundColor(theme.textFaint)
                .lineLimit(1)
                .truncationMode(.head)
            Spacer()
            Button {
                model.destination = .settings
            } label: {
                Image(systemName: "gearshape")
                    .foregroundColor(theme.textFaint)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .overlay(Rectangle().frame(height: 1).foregroundColor(theme.hairline), alignment: .top)
    }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE"
        return f
    }()
}
