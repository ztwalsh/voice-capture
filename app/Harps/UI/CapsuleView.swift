import AppKit
import SwiftUI

/// The capsule's states, per design.md §5. `dormant` never actually renders —
/// the panel is ordered out entirely rather than shown empty, per the "no
/// idle overlay" principle — but it is the rest state the view model settles
/// into between captures.
enum CaptureState: Equatable {
    case dormant
    case listening
    case transcribing
    case error(String)
}

/// design.md §5: "Two modes, and they are not the same interaction." A
/// button can't be held, so the menu bar means toggle — start and stop are
/// two separate clicks, which is why toggle mode carries a visible timer
/// from the first tick and a reachable stop control that push-to-talk,
/// bound to a key you're already holding, does not need.
enum CaptureMode: Equatable {
    case pushToTalk
    case toggle
}

/// A colour, its own alpha included, so waveform interpolation can lerp alpha
/// too — dark mode's `--text-faint` is a low-alpha white, and dropping alpha
/// during the lerp collapses the whole bar to solid white. motion.md calls
/// this out explicitly.
private struct RGBA {
    var r, g, b, a: Double
    var color: Color { Color(red: r, green: g, blue: b, opacity: a) }
    func lerp(to other: RGBA, _ t: Double) -> RGBA {
        RGBA(r: r + (other.r - r) * t, g: g + (other.g - g) * t,
             b: b + (other.b - b) * t, a: a + (other.a - a) * t)
    }
}

/// design.md §3's colour tokens, both appearances. Only what the capsule
/// needs — the window's tokens (sidebar, cards, `--up`) live in Phase 4/5.
private struct Theme {
    let isDark: Bool
    let bg: Color
    let hairline: Color
    let textSubtle: Color
    let labelMono: Color
    let live: Color
    fileprivate let textRGBA: RGBA
    fileprivate let textFaintRGBA: RGBA

    var text: Color { textRGBA.color }
    var textFaint: Color { textFaintRGBA.color }

    init(_ colorScheme: ColorScheme) {
        isDark = colorScheme == .dark
        if isDark {
            bg = Color(red: 0x0c / 255, green: 0x0c / 255, blue: 0x0d / 255)
            hairline = Color.white.opacity(0.075)
            textRGBA = RGBA(r: 0xfa / 255, g: 0xfa / 255, b: 0xfa / 255, a: 1)
            textSubtle = Color.white.opacity(0.44)
            textFaintRGBA = RGBA(r: 1, g: 1, b: 1, a: 0.30)
            labelMono = Color.white.opacity(0.48)
            live = Color(red: 0xff / 255, green: 0x63 / 255, blue: 0x69 / 255)
        } else {
            bg = Color.white
            hairline = Color.black.opacity(0.075)
            textRGBA = RGBA(r: 0x0a / 255, g: 0x0a / 255, b: 0x0a / 255, a: 1)
            textSubtle = Color(red: 0x86 / 255, green: 0x86 / 255, blue: 0x8a / 255)
            textFaintRGBA = RGBA(r: 0xa8 / 255, g: 0xa8 / 255, b: 0xac / 255, a: 1)
            labelMono = Color(red: 0x6f / 255, green: 0x71 / 255, blue: 0x80 / 255)
            live = Color(red: 0xe5 / 255, green: 0x48 / 255, blue: 0x4d / 255)
        }
    }

    fileprivate func waveformColor(_ value: Double) -> Color {
        textFaintRGBA.lerp(to: textRGBA, min(1, max(0, value))).color
    }
}

/// Drives the capsule from `HarpsController`. One writer (the main actor,
/// same as everything else in this app), so plain `@Published` state is
/// enough — no need for the actor isolation gymnastics the audio tap needs.
@MainActor
final class CapsuleViewModel: ObservableObject {
    @Published private(set) var state: CaptureState = .dormant
    @Published private(set) var mode: CaptureMode = .pushToTalk
    @Published private(set) var isVisible = false
    @Published private(set) var levels: [Double] = Array(repeating: 0, count: CapsuleViewModel.barCount)
    @Published private(set) var elapsedSeconds = 0
    @Published private(set) var showTimer = false
    @Published private(set) var shakeToken = 0
    /// Read directly from `NSWorkspace` rather than through SwiftUI's
    /// `\.accessibilityReduceMotion` environment key — that key did not
    /// propagate correctly into this view's hosting `NSPanel`, plausibly
    /// because it's a non-activating panel in an accessory-policy app that
    /// never becomes key or main, which is unusual enough that SwiftUI's
    /// normal environment plumbing for this value doesn't reach it.
    /// `NSWorkspace.shared.accessibilityDisplayShouldReduceMotion` was
    /// confirmed correct with a standalone check when the environment value
    /// was not. Refreshed at the start of each capture rather than kept
    /// live via notification, since that's the only point it needs to be
    /// current.
    @Published private(set) var reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion

    static let barCount = 30
    /// motion.md's normalization range: a −50dB floor, a −6dB ceiling. That
    /// window is tuned for a person speaking a few feet from a laptop —
    /// absolute amplitude is not the useful quantity.
    private static let levelFloorDB: Double = -50
    private static let levelCeilingDB: Double = -6

    /// The raw incoming amplitude, updated whenever the audio tap delivers a
    /// buffer. Real hardware delivers those at irregular, sometimes bursty
    /// intervals — driving the smoothing and the bar array directly off this
    /// arrival timing is what produced a "stop motion" feel: no interpolation
    /// happens between arrivals, so any irregularity in delivery reads
    /// directly as jerky motion. `waveformTask` below is the fix — a steady
    /// clock this app controls, decoupled from the hardware's own timing.
    private var targetLevel: Double = 0
    private var smoothedLevel: Double = 0
    private var tickTask: Task<Void, Never>?
    private var waveformTask: Task<Void, Never>?
    private var dismissTask: Task<Void, Never>?
    private var startedAt = Date()

    /// Set once by `CapsulePanel`, forwarded to whichever action ends a
    /// toggle capture — the capsule's own stop control needs a way to reach
    /// back to `HarpsController` without owning capture logic itself.
    var onStopTapped: (() -> Void)?

    func showListening(mode: CaptureMode = .pushToTalk) {
        dismissTask?.cancel()
        reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        self.mode = mode
        levels = Array(repeating: 0, count: Self.barCount)
        targetLevel = 0
        smoothedLevel = 0
        elapsedSeconds = 0
        // design.md calls for a 3s hold before showing the timer at all in
        // push-to-talk mode. In practice that read as a delay rather than a
        // deliberate omission — showing "0:00" immediately and letting the
        // counter itself catch up on its own 200ms cadence feels more
        // honest about what's happening than hiding the clock outright.
        // Toggle mode always showed it immediately regardless, since a
        // toggle can run long and unattended.
        showTimer = true
        startedAt = Date()
        state = .listening
        isVisible = true
        tickTask?.cancel()
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(200))
                guard let self, !Task.isCancelled else { return }
                self.elapsedSeconds = Int(Date().timeIntervalSince(self.startedAt))
            }
        }
        waveformTask?.cancel()
        waveformTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(20))
                guard let self, !Task.isCancelled else { return }
                self.tickWaveform()
            }
        }
    }

    /// RMS amplitude 0...1 from `AudioRecorder`'s tap. Only updates the
    /// smoothing *target* — the actual interpolation happens on
    /// `waveformTask`'s steady 20ms clock, not here, so this can be called
    /// at whatever irregular rate the hardware actually delivers.
    /// Below this, treat it as silence rather than a small positive value.
    /// Room noise and mic self-noise otherwise blend to a moderate, constant
    /// bar height even when nobody is talking — design.md wants true
    /// silence to read as a flat 2px line, the clearest possible "not
    /// picking you up" signal, not a resting hum.
    private static let noiseGate: Double = 0.12

    func pushLevel(_ rms: Float) {
        guard state == .listening else { return }
        let db = rms > 0 ? 20 * log10(Double(rms)) : Self.levelFloorDB
        let normalized = (db - Self.levelFloorDB) / (Self.levelCeilingDB - Self.levelFloorDB)
        let clamped = min(1, max(0, normalized))
        targetLevel = clamped < Self.noiseGate ? 0 : clamped
    }

    /// motion.md's asymmetric attack/release: fast up so consonants punch
    /// through, slow down so it doesn't strobe between syllables. Runs on
    /// `waveformTask`'s fixed 20ms cadence, matching the 50Hz sampling the
    /// spec assumes, regardless of how often `pushLevel` itself is called.
    private func tickWaveform() {
        smoothedLevel += (targetLevel - smoothedLevel) * (targetLevel > smoothedLevel ? 0.60 : 0.12)
        levels.append(smoothedLevel)
        if levels.count > Self.barCount { levels.removeFirst(levels.count - Self.barCount) }
    }

    func showTranscribing() {
        dismissTask?.cancel()
        tickTask?.cancel()
        waveformTask?.cancel()
        showTimer = false
        state = .transcribing
        isVisible = true
    }

    /// Errors and "didn't catch anything" share one visual per design.md:
    /// sized to the message, a shake, a 3s hold, then dismiss.
    func showError(_ message: String) {
        dismissTask?.cancel()
        tickTask?.cancel()
        waveformTask?.cancel()
        reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        showTimer = false
        state = .error(message)
        isVisible = true
        shakeToken += 1
        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard let self, !Task.isCancelled else { return }
            self.hide()
        }
    }

    /// "Inserted" per design.md has no visual state — the text landing is
    /// the confirmation — so a clean success just calls this directly.
    func hide() {
        dismissTask?.cancel()
        tickTask?.cancel()
        waveformTask?.cancel()
        isVisible = false
    }

    /// Called by `CapsulePanel` once the exit animation has had time to
    /// play, so the state resets to `.dormant` after leaving rather than
    /// mid-flight.
    func settleIfHidden() {
        if !isVisible { state = .dormant }
    }

    var timerText: String { "0:" + String(format: "%02d", elapsedSeconds) }
}

/// The whole capsule, per design.md §5: one object, resized. 44px tall,
/// fully rounded, floating in a fixed-size transparent panel so width
/// changes never move the window — only the shape inside it changes.
struct CapsuleRootView: View {
    @ObservedObject var model: CapsuleViewModel
    @Environment(\.colorScheme) private var colorScheme
    private var reduceMotion: Bool { model.reduceMotion }

    /// Extra room around the 44px capsule for its shadow, the 16px rise, and
    /// shake overshoot — none of it should be clipped by the panel's frame.
    /// The heavier shadow (25px blur, 18px y-offset) needs real clearance
    /// below the capsule to fully fade out rather than being hard-clipped
    /// by the panel's own bounds, which read as a sharp cutoff — "falling
    /// behind a transparent box" — rather than a soft shadow.
    static let bottomPadding: CGFloat = 70
    static let contentSize = NSSize(width: 400, height: 180)

    var body: some View {
        let theme = Theme(colorScheme)
        ZStack(alignment: .bottom) {
            Color.clear
            CapsuleShapeView(model: model, theme: theme, reduceMotion: reduceMotion)
                .padding(.bottom, Self.bottomPadding)
                .opacity(model.isVisible ? 1 : 0)
                .offset(y: model.isVisible || reduceMotion ? 0 : 16)
                .blur(radius: model.isVisible || reduceMotion ? 0 : 2)
                .scaleEffect(model.isVisible || reduceMotion ? 1 : 0.97)
                .animation(entryExitAnimation, value: model.isVisible)
        }
        .frame(width: Self.contentSize.width, height: Self.contentSize.height)
        // Click-through everywhere except the toggle mode's stop button —
        // `CapsulePanel` already gates real mouse delivery at the AppKit
        // level via `ignoresMouseEvents`, so this only needs to not
        // additionally block the one control that's ever interactive.
        // An unconditional `false` here was doing exactly that: the stop
        // button never received its tap regardless of the panel's own
        // setting.
        .allowsHitTesting(model.mode == .toggle && model.state == .listening)
    }

    /// Entry is a deliberate 350ms; exit is a snappy 250ms — motion.md's
    /// principle 4, "arriving is deliberate, leaving is snappy." Reduce
    /// Motion drops both to a 100ms opacity-only cross-fade.
    private var entryExitAnimation: Animation {
        if reduceMotion { return .linear(duration: 0.1) }
        let duration = model.isVisible ? 0.35 : 0.25
        return .timingCurve(0.22, 1, 0.36, 1, duration: duration)
    }
}

/// The pill itself: dot, center content, timer. Everything but the shadow
/// and the shake lives here.
private struct CapsuleShapeView: View {
    @ObservedObject var model: CapsuleViewModel
    let theme: Theme
    let reduceMotion: Bool

    var body: some View {
        content
            .modifier(ShakeEffect(trigger: model.shakeToken, reduceMotion: reduceMotion))
    }

    private var content: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(dotColor)
                .frame(width: 6, height: 6)

            centerContent
                .frame(maxWidth: .infinity)

            if case .listening = model.state {
                Text(model.timerText)
                    .font(.system(size: 11, design: .monospaced))
                    .monospacedDigit()
                    .foregroundColor(theme.labelMono)
                    .frame(width: 30, alignment: .trailing)
                    .opacity(model.showTimer ? 1 : 0)
                    .animation(.easeInOut(duration: 0.15), value: model.showTimer)

                if model.mode == .toggle {
                    stopButton
                }
            }
        }
        .padding(.leading, 20)
        .padding(.trailing, trailingPadding)
        .frame(height: 44)
        .frame(width: fixedWidth)
        .frame(minWidth: minWidth, maxWidth: maxWidth)
        .background(theme.bg, in: Capsule())
        .overlay(Capsule().strokeBorder(theme.hairline, lineWidth: 1))
        .shadow(color: shadowColor(opacity: theme.isDark ? 0.60 : 0.16), radius: 25, y: 18)
        .shadow(color: shadowColor(opacity: theme.isDark ? 0 : 0.09), radius: 7, y: 4)
        .animation(reduceMotion ? nil : .timingCurve(0.22, 1, 0.36, 1, duration: 0.30),
                   value: fixedWidth)
    }

    @ViewBuilder private var centerContent: some View {
        switch model.state {
        case .listening:
            WaveformView(levels: model.levels, theme: theme)
        case .transcribing:
            ShimmerLabel(text: "Transcribing", theme: theme, reduceMotion: reduceMotion)
        case .error(let message):
            Text(message)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(theme.textRGBA.color)
                .lineLimit(1)
        case .dormant:
            Color.clear
        }
    }

    private var dotColor: Color {
        if case .listening = model.state { return theme.live }
        return theme.textFaint
    }

    private func shadowColor(opacity: Double) -> Color { Color.black.opacity(opacity) }

    /// design.md §5: 248 listening in push-to-talk, 286 in toggle (room for
    /// the stop control), 176 transcribing, error sized to the message
    /// between 200 and 320. `nil` (error) lets the HStack's own intrinsic
    /// size decide, bounded by `minWidth`/`maxWidth` below.
    private var fixedWidth: CGFloat? {
        switch model.state {
        case .dormant, .transcribing: return 176
        case .listening: return model.mode == .toggle ? 286 : 248
        case .error: return nil
        }
    }
    private var minWidth: CGFloat? { if case .error = model.state { return 200 }; return nil }
    private var maxWidth: CGFloat? { if case .error = model.state { return 320 }; return nil }

    /// design.md's CSS gives the capsule 20px of trailing padding by
    /// default, tightened to 6px in toggle mode while listening — the stop
    /// button carries its own visual margin, so the outer padding shrinks
    /// to keep the whole right edge from looking over-padded.
    private var trailingPadding: CGFloat {
        if case .listening = model.state, model.mode == .toggle { return 6 }
        return 18
    }

    /// design.md §5: a 32px round stop control, the toggle mode's reachable
    /// way out — push-to-talk needs none, since releasing the key already
    /// is one.
    private var stopButton: some View {
        Button {
            model.onStopTapped?()
        } label: {
            Circle()
                .fill(theme.bg)
                .overlay(Circle().strokeBorder(theme.hairline, lineWidth: 1))
                .overlay(
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(theme.textRGBA.color)
                        .frame(width: 9, height: 9)
                )
                .frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
    }
}

/// design.md's waveform: 30 bars, 3px wide with a 2px gap, 2 to 24px tall.
/// Rendered on `Canvas`, redrawn whenever `levels` changes.
///
/// motion.md asks for a display-link-driven canvas, decoupled from
/// per-sample SwiftUI state churn. A `TimelineView`-polled version was
/// tried here and made the stutter worse rather than better — plausibly
/// because it forced a full redraw on every display frame regardless of
/// whether new audio data had actually arrived, and/or interacted badly
/// with this panel's transparent, non-activating, `.statusBar`-level
/// window, which is an unusual enough configuration that its real
/// compositing cost needs to be measured, not assumed. Reverted to the
/// straightforward approach — a plain `Canvas` redrawing on each `levels`
/// change — until that can be profiled properly.
private struct WaveformView: View {
    let levels: [Double]
    let theme: Theme

    var body: some View {
        Canvas { context, size in
            let barWidth: CGFloat = 3
            let gap: CGFloat = 2
            let step = barWidth + gap
            let totalWidth = CGFloat(levels.count) * step - gap
            var x = (size.width - totalWidth) / 2
            let midY = size.height / 2
            for value in levels {
                let clamped = min(1, max(0, value))
                let height = 2 + pow(clamped, 0.7) * 22
                let rect = CGRect(x: x, y: midY - height / 2, width: barWidth, height: height)
                context.fill(Path(roundedRect: rect, cornerRadius: 1.5),
                              with: .color(theme.waveformColor(clamped)))
                x += step
            }
        }
        .frame(height: 24)
    }
}

/// motion.md's "thinking states" pattern: a shimmer sweeps the label on a
/// 2000ms linear loop while work is ongoing. Reduce Motion drops the sweep
/// and leaves a static label — text instead of motion, per the spec's own
/// table.
private struct ShimmerLabel: View {
    let text: String
    let theme: Theme
    let reduceMotion: Bool

    var body: some View {
        if reduceMotion {
            Text(text)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(theme.textSubtle)
        } else {
            TimelineView(.animation) { context in
                let phase = context.date.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: 2.0) / 2.0
                Text(text)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(stops: stops(at: phase), startPoint: .leading, endPoint: .trailing)
                    )
            }
        }
    }

    private func stops(at phase: Double) -> [Gradient.Stop] {
        let center = phase
        return [
            .init(color: theme.textSubtle, location: 0),
            .init(color: theme.textSubtle, location: max(0, center - 0.2)),
            .init(color: theme.textRGBA.color, location: center),
            .init(color: theme.textSubtle, location: min(1, center + 0.2)),
            .init(color: theme.textSubtle, location: 1)
        ]
    }
}

/// motion.md's error-state-shake: 6px with a 4px overshoot, 80ms then two
/// 60ms segments. `keyframeAnimator` fires this fresh every time `trigger`
/// changes, which is exactly the "shake once per error" shape this needs.
private struct ShakeEffect: ViewModifier {
    let trigger: Int
    let reduceMotion: Bool

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content.keyframeAnimator(initialValue: 0.0, trigger: trigger) { view, offset in
                view.offset(x: offset)
            } keyframes: { _ in
                KeyframeTrack(\.self) {
                    LinearKeyframe(0, duration: 0)
                    CubicKeyframe(6, duration: 0.08)
                    CubicKeyframe(-6, duration: 0.08)
                    CubicKeyframe(4, duration: 0.06)
                    CubicKeyframe(0, duration: 0.06)
                }
            }
        }
    }
}
