# Harps — Phase 2 walking skeleton

The full loop from `../PLAN.md`: hold a hotkey, speak, release, the text lands
at your caret, and a line is appended to today's Markdown file. Deliberately
ugly — a plain rectangle, one hardcoded hotkey, no settings. Its only job is to
answer PLAN.md's Phase 2 question: does this actually work?

**This was written without a Mac available to build or run it on.** Expect to
fix a signature or two on first build — normal for code that has never been
compiled, and far cheaper to find here than to have designed around blind.

## What this reuses from Phase 0

Every technique here is one the spikes in `../spikes/` test in isolation,
combined into one real path:

| File | Reuses |
| --- | --- |
| `Capture/HotkeyMonitor.swift` | Spike A's global-monitor approach |
| `UI/CapsulePanel.swift` | Spike A's non-activating panel |
| `Capture/AudioRecorder.swift` | Spike C's 16kHz mono recording path |
| `Capture/Transcriber.swift` | Spike C's `SFSpeechRecognizer` engine, behind a protocol |
| `Capture/TextInserter.swift` | Spike B's paste strategy, behind a protocol |
| `Storage/TranscriptStore.swift` | New — the Markdown-per-day format from `PLAN.md` §2 |

Two things are simplified relative to the full plan on purpose, both in
`TextInserter.swift`: insertion is paste-only rather than the documented
three-strategy chain, because PLAN.md already calls paste the strategy that
"works nearly everywhere" — of the three, it's the one not actually waiting on
Spike B's matrix to be worth building. Fill in that matrix and the other two
strategies slot in behind the same protocol without touching the controller.

**Still worth running Spike B and C properly.** This skeleton tells you the
loop works end to end. It does not tell you paste fails in some app you rely
on, or that `SFSpeechRecognizer`'s accuracy on your voice is worse than
Whisper's — only the spikes' full matrices answer those.

## Set up the Xcode project

This is source files, not a `.xcodeproj` — generating that file by hand
without Xcode produces something more likely to be subtly broken than useful.
Five minutes in Xcode's wizard is more reliable:

1. **File → New → Project → macOS → App.** Name it `Harps`. Interface:
   doesn't matter, you'll delete the generated one. Uncheck "Use Core Data"
   and "Include Tests."
2. **Delete** the generated `HarpsApp.swift` and `ContentView.swift` — this
   app has no SwiftUI lifecycle and no views.
3. **Add the files in this directory** to the target: `main.swift`, everything
   under `Capture/`, `UI/`, `Storage/`, and `HarpsController.swift`. Keep the
   groups matching the folders; nothing here depends on Xcode's group
   structure, but it'll read the same as this repo.
4. **Info.plist** — merge the three keys from the `Info.plist` in this
   directory into the target's generated one (Xcode's "Info" tab under target
   settings is easier than editing the file directly): `LSUIElement`,
   `NSMicrophoneUsageDescription`, `NSSpeechRecognitionUsageDescription`.
5. **Signing & Capabilities tab** — leave **App Sandbox off**. That's the
   default for a new target; just don't add the capability. This matches
   `PLAN.md`: the sandbox and the Accessibility API needed for global hotkeys
   don't coexist usefully.
6. **Build Phases → Link Binary With Libraries** — add `Speech.framework`
   and `Carbon.framework` (`AppKit`, `AVFoundation`, and `ApplicationServices`
   are linked automatically for a macOS app target).
7. **Build and run once from Xcode**, then quit it. This is what registers
   the binary with the system so the next step's permission prompt is for the
   right process.

## Grant permissions

Do this after step 7, and expect to redo it once — see the note below.

1. **System Settings › Privacy & Security › Accessibility** — add `Harps`
   (found under `~/Library/Developer/Xcode/DerivedData/.../Build/Products/Debug/`,
   or just search for it in the picker; Xcode-built apps show up there).
2. Run it again. It will prompt for **Microphone** and **Speech Recognition**
   the first time it actually tries to record — accept both.

**The permission trap that will cost you an afternoon otherwise:** Xcode
re-signs the binary on every build, and the *Accessibility* grant above is
tied to that signature. It will silently stop working after your second
build. When the hotkey stops doing anything, this is almost always why —
remove and re-add Harps in the Accessibility list rather than debugging the
code. (Microphone and Speech Recognition grants aren't affected the same way;
it's specifically Accessibility that's this fragile.)

## Run it

Hold **Right Option**, speak a full sentence, release, watch it land wherever
your cursor was. The terminal running Xcode's console prints the release-to-
text latency on every successful capture — that number against the 1.5s
budget in `PLAN.md` is the other half of Phase 2's exit criteria, alongside
"a real sentence lands in a real app."

Transcripts land in `~/Library/Application Support/Harps/transcripts/`, one
`.md` file per day.

## What's known-incomplete, on purpose

Phase 2's scope, not bugs:

- **One hotkey, hardcoded.** Right Option, push-to-talk only. No menu bar
  item yet — that's `capture-v2.html`'s design, and it's Phase 3.
- **The panel is a rectangle.** The real capsule — states, motion, the
  waveform — is `design.md` and `motion.md`, built in Phase 3.
- **No settings, no history window.** Phase 4 and 5.
- **Errors print to the console**, they don't show a friendly message beyond
  the plain-text state the rectangle already carries.
- **`SFSpeechRecognizer`, not `SpeechAnalyzer`.** Same reasoning as Spike C:
  a stable API that produces a real result today. `Transcriber.swift`'s
  protocol is the seam for swapping it in.
- **Concurrency is hand-verified, not compiler-verified.** `HarpsController`
  explicitly hops to `@MainActor` for the one `Task` that touches the panel
  and the pasteboard, which is correct under any Swift concurrency mode. What
  it does *not* do is chase full Swift 6 strict-concurrency `Sendable`
  conformance across every type — annotating that correctly without a
  compiler in front of me would mean guessing, and a wrong guess produces
  more confusing errors than none at all. If Xcode's new-project wizard
  defaults to the Swift 6 language mode and complains, the fix is almost
  certainly adding `Sendable` (or `@unchecked Sendable`, since these types
  are only ever touched from `HarpsController`'s single call site) to
  `AudioRecorder`, `OnDeviceTranscriber`, `PasteTextInserter`, and
  `TranscriptStore` — not a redesign.
