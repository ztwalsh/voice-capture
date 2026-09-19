import SwiftUI

/// PLAN.md Phase 6. Matches the approved clickable prototype
/// (`prototype/transforms-list.html`) exactly: a bordered list, "New
/// Transform" above the table (not below), a hover-reveal delete icon per
/// row, and both "new" and "edit existing" opening as their own page. The
/// breadcrumb back to the list now lives in the shared window header
/// ("Transforms / General Clean-up") rather than a second one repeated
/// in-page — per direct feedback, that was redundant.
struct TransformsView: View {
    @ObservedObject var model: HistoryViewModel
    let theme: WindowTheme
    @ObservedObject private var store = TransformStore.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                switch model.transformsDestination {
                case .list:
                    listView
                case .editor(let transform):
                    TransformEditorView(theme: theme, transform: transform) {
                        withAnimation(.easeOut(duration: 0.15)) { model.transformsDestination = .list }
                    }
                }
            }
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
            .padding(.top, 26)
            .padding(.bottom, 60)
            .padding(.horizontal, 22)
            .background(ScrollbarHider())
        }
        .scrollIndicators(.hidden)
    }

    private var listView: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !TransformEngine.isAvailable {
                availabilityNotice
            }
            HStack {
                Spacer()
                Button {
                    withAnimation(.easeOut(duration: 0.15)) { model.transformsDestination = .editor(nil) }
                } label: {
                    HStack(spacing: 7) {
                        CentralIconView(svg: CentralIcons.plus, color: theme.bg)
                            .frame(width: 12, height: 12)
                        Text("New Transform")
                    }
                }
                .buttonStyle(HarpsPrimaryButtonStyle(theme: theme))
            }

            // Matches SettingsView's own row pattern: a flat, uncarded list
            // separated by a bottom hairline on every row (including the
            // last) — not the bordered `theme.trough` card this used to be,
            // per direct feedback that Transforms and Settings should share
            // one list style.
            VStack(spacing: 0) {
                ForEach(store.transforms) { transform in
                    row(for: transform)
                }
            }
        }
    }

    /// PLAN.md Phase 6: this feature must never be a new way for dictation
    /// itself to break — enabled transforms are silently skipped
    /// (`TransformEngine.apply` just passes text through) whenever this
    /// notice is showing, rather than erroring or blocking insertion.
    private var availabilityNotice: some View {
        HStack(spacing: 10) {
            CentralIconView(svg: CentralIcons.exclamationCircle, color: theme.live)
                .frame(width: 15, height: 15)
            Text(TransformEngine.availabilityDescription())
                .font(.custom("Geist-Regular", size: 12.5))
                .foregroundColor(theme.textSubtle)
            Spacer()
        }
        .padding(12)
        .background(theme.trough, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(theme.hairline))
    }

    private func row(for transform: Transform) -> some View {
        TransformRow(
            theme: theme, transform: transform,
            onOpen: { withAnimation(.easeOut(duration: 0.15)) { model.transformsDestination = .editor(transform) } },
            onToggle: { store.toggle(id: transform.id) },
            onDelete: { store.delete(id: transform.id) }
        )
    }
}

private struct TransformRow: View {
    let theme: WindowTheme
    let transform: Transform
    let onOpen: () -> Void
    let onToggle: () -> Void
    let onDelete: () -> Void
    @State private var isHovering = false
    @State private var confirmingDelete = false

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(transform.name)
                        .font(.custom("Geist-Medium", size: 14))
                        .foregroundColor(theme.text)
                    if transform.isBuiltIn {
                        Text("DEFAULT")
                            .font(.custom("GeistMono-Regular", size: 9.5))
                            .foregroundColor(theme.textFaint)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1.5)
                            .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(theme.hairline))
                    }
                }
                Text(transform.instructions)
                    .font(.custom("Geist-Regular", size: 12.5))
                    .foregroundColor(theme.textSubtle)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            Spacer(minLength: 8)
            if !transform.isBuiltIn {
                // Trash-morphs-into-Cancel/Delete, same pattern as the
                // editor page's own delete control and the Document view's
                // floating toolbar — per direct request, this used to
                // delete immediately on click with no confirmation at all.
                if confirmingDelete {
                    HStack(spacing: 4) {
                        ToolbarTextButton(title: "Cancel", theme: theme, restingColor: theme.textFaint, hoverColor: theme.text) {
                            withAnimation(.easeOut(duration: 0.15)) { confirmingDelete = false }
                        }
                        ToolbarTextButton(title: "Delete", theme: theme, restingColor: theme.danger, hoverColor: theme.danger) {
                            onDelete()
                        }
                    }
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
                } else {
                    HarpsActionIcon(svg: CentralIcons.trash, tooltip: "Delete", theme: theme) {
                        withAnimation(.easeOut(duration: 0.15)) { confirmingDelete = true }
                    }
                    .opacity(isHovering ? 1 : 0)
                }
            }
            Toggle("", isOn: Binding(get: { transform.isEnabled }, set: { _ in onToggle() }))
                .labelsHidden()
                .toggleStyle(HarpsToggleStyle(theme: theme))
            CentralIconView(svg: CentralIcons.chevronDown, color: theme.textFaint)
                .frame(width: 10, height: 10)
                .rotationEffect(.degrees(-90))
        }
        .padding(.vertical, 15)
        .overlay(Rectangle().frame(height: 1).foregroundColor(theme.hairline), alignment: .bottom)
        .contentShape(Rectangle())
        .onTapGesture(perform: onOpen)
        .onHover { hovering in
            isHovering = hovering
            // Leaving the row also dismisses an armed confirmation — it
            // shouldn't stay waiting for a click days later on a row you've
            // moved on from.
            if !hovering { confirmingDelete = false }
        }
        .animation(.easeInOut(duration: 0.15), value: isHovering)
    }
}

private struct TransformEditorView: View {
    let theme: WindowTheme
    let transform: Transform?
    let onDone: () -> Void

    @ObservedObject private var store = TransformStore.shared
    @State private var name: String
    @State private var instructions: String
    @State private var confirmingDelete = false

    private var isBuiltIn: Bool { transform?.isBuiltIn ?? false }
    private var isNew: Bool { transform == nil }
    private var canDelete: Bool { !isBuiltIn && !isNew }

    init(theme: WindowTheme, transform: Transform?, onDone: @escaping () -> Void) {
        self.theme = theme
        self.transform = transform
        self.onDone = onDone
        _name = State(initialValue: transform?.name ?? "")
        _instructions = State(initialValue: transform?.instructions ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                // A disabled `TextField` renders dimmed no matter what
                // `foregroundColor` says — macOS overrides it for disabled
                // controls. A built-in's name is never editable anyway, so
                // render it as plain `Text` instead of fighting that dimming.
                if isBuiltIn {
                    Text(name)
                        .font(.custom("Geist-SemiBold", size: 22))
                        .foregroundColor(theme.text)
                } else {
                    TextField("Transform name", text: $name)
                        .textFieldStyle(.plain)
                        .font(.custom("Geist-SemiBold", size: 22))
                        .foregroundColor(theme.text)
                }

                Spacer(minLength: 8)

                // Trash-morphs-into-Cancel/Delete, same pattern as the
                // Document view's floating toolbar — per direct request,
                // clicking Delete here used to remove the transform
                // immediately with no confirmation at all.
                if canDelete {
                    if confirmingDelete {
                        HStack(spacing: 4) {
                            ToolbarTextButton(title: "Cancel", theme: theme, restingColor: theme.textFaint, hoverColor: theme.text) {
                                withAnimation(.easeOut(duration: 0.15)) { confirmingDelete = false }
                            }
                            ToolbarTextButton(title: "Delete", theme: theme, restingColor: theme.danger, hoverColor: theme.danger) {
                                delete()
                            }
                        }
                        .transition(.scale(scale: 0.9).combined(with: .opacity))
                    } else {
                        ToolbarIconButton(tooltip: "Delete", theme: theme) {
                            withAnimation(.easeOut(duration: 0.15)) { confirmingDelete = true }
                        } icon: { color in
                            CentralIconView(svg: CentralIcons.trash, color: color)
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("INSTRUCTIONS")
                    .font(.custom("GeistMono-Regular", size: 11))
                    .foregroundColor(theme.textFaint)

                // `MarkdownEditor` per direct request: a minimal formatting
                // toolbar over plain Markdown (never a separate rich-text
                // format — `instructions` stays exactly what's saved), a
                // Markdown/Preview toggle, and a box that grows with its
                // content instead of scrolling inside a fixed height.
                MarkdownEditor(
                    text: $instructions,
                    font: .init(name: "Geist-Regular", size: 13.5) ?? .systemFont(ofSize: 13.5),
                    textColor: isBuiltIn ? NSColor(theme.textSubtle) : NSColor(theme.text),
                    theme: theme,
                    isEditable: !isBuiltIn
                )

                if isBuiltIn {
                    HStack(spacing: 7) {
                        CentralIconView(svg: CentralIcons.stopCircle, color: theme.textFaint)
                            .frame(width: 12, height: 12)
                        Text("Built-in default — you can turn it off, but not edit its wording.")
                            .font(.custom("Geist-Regular", size: 12))
                            .foregroundColor(theme.textFaint)
                    }
                }
            }

            HStack {
                Spacer()
                Button("Save", action: save)
                    .buttonStyle(HarpsPrimaryButtonStyle(theme: theme))
            }
            .padding(.top, 4)
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !isBuiltIn, !trimmedName.isEmpty else { onDone(); return }
        if let transform {
            store.update(id: transform.id, name: trimmedName, instructions: instructions)
        } else {
            store.add(name: trimmedName, instructions: instructions)
        }
        onDone()
    }

    private func delete() {
        guard let transform else { return }
        store.delete(id: transform.id)
        onDone()
    }
}
