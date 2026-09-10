# Harps — Phase 2 walking skeleton

The full loop from `../PLAN.md`: hold a hotkey, speak, release, the text lands
at your caret, and a line is appended to today's Markdown file. Deliberately
ugly — a plain rectangle, one hardcoded hotkey, no settings. Its only job is to
answer PLAN.md's Phase 2 question: does this actually work?

**Status: compiles clean and links.** Built against the macOS 26 SDK with
Swift 6 language mode and `-strict-concurrency=complete`, both from `swiftc`
directly and through the generated Xcode project. Not yet *run* — that needs
the permission grants below and a person holding the hotkey.

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

The `.xcodeproj` is generated from `project.yml` by [XcodeGen], so the pbxproj
never has to be hand-edited or committed. `project.yml` already carries every
setting the old manual wizard steps used to spell out: the two extra frameworks
(`Speech`, `Carbon`), App Sandbox off, `Info.plist` and entitlements wired in,
ad-hoc signing, Swift 6 with complete strict concurrency.

```bash
brew install xcodegen        # once
cd app && xcodegen generate  # writes Harps.xcodeproj (gitignored)
```

Then either open `Harps.xcodeproj` and build, or from the command line:

```bash
xcodebuild -project app/Harps.xcodeproj -scheme Harps -configuration Debug build
```

Re-run `xcodegen generate` after adding or removing source files. Editing the
existing `.swift` files needs no regeneration.

[XcodeGen]: https://github.com/yonaskolb/XcodeGen

## Grant permissions

Build and run once from Xcode first, then quit it — that registers the binary
so the prompts below are for the right process. Expect to redo the
Accessibility grant once — see the note below.

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
- **Concurrency is compiler-verified now, but not stress-tested.** The control
  plane — `HarpsController`, `HotkeyMonitor`, `CapsulePanel` — is `@MainActor`.
  The off-main types (`AudioRecorder`, `OnDeviceTranscriber`) carry
  `@unchecked Sendable` with a comment saying why it holds: `HarpsController`
  is their only owner and the audio tap never overlaps the start/stop calls.
  That is sound under the current single-call-site design; a second caller, or
  concurrent captures in Phase 3, would need it revisited rather than trusted.
