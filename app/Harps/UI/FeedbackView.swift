import AppKit
import SwiftUI

/// Just a textbox and a button — the app's own hotkey already dictates into
/// any focused text field system-wide, so a bespoke record button here
/// would be a second, worse way to do something Harps already does
/// everywhere else. Per direct request: "should be able to use the tool
/// itself to dictate if someone wants to."
@MainActor
final class FeedbackViewModel: ObservableObject {
    @Published var text = ""
    @Published var didSend = false

    /// A `mailto:` link, not an in-app send — this hands the message to
    /// whatever mail client is already configured rather than the app
    /// needing to hold real mail credentials just for a feedback form.
    func send() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = "ztwalsh@gmail.com"
        components.queryItems = [
            URLQueryItem(name: "subject", value: "Harps feedback"),
            URLQueryItem(name: "body", value: trimmed),
        ]
        guard let url = components.url else { return }
        NSWorkspace.shared.open(url)
        didSend = true
        text = ""
    }
}

/// design.md's centered-column pattern (Document/Settings) — one focused
/// task per screen, nothing competing with it.
struct FeedbackView: View {
    let theme: WindowTheme
    @StateObject private var model = FeedbackViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("We want your feedback to make this a better product. What do you like? What could be better?")
                    .font(.custom("Geist-Regular", size: 16))
                    .foregroundColor(theme.textSubtle)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 34)

                EditableTextBox(
                    text: $model.text,
                    font: .init(name: "GeistMono-Regular", size: 13.5) ?? .systemFont(ofSize: 13.5),
                    textColor: NSColor(theme.text)
                )
                    .padding(10)
                    .frame(height: 220)
                    .background(theme.trough, in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(theme.hairline))

                HStack {
                    if model.didSend {
                        Text("Opened in Mail — send it from there.")
                            .font(.custom("Geist-Regular", size: 12))
                            .foregroundColor(theme.up)
                    }
                    Spacer()
                    Button("Send Feedback", action: model.send)
                        .buttonStyle(HarpsPrimaryButtonStyle(theme: theme))
                        .disabled(model.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 22)
            .padding(.bottom, 60)
            .background(ScrollbarHider())
        }
        .scrollIndicators(.hidden)
    }
}
