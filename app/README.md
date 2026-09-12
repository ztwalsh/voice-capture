# Harps — Phase 3: the real capsule

The full loop from `../PLAN.md`: hold a hotkey, speak, release, the text lands
at your caret, and a line is appended to today's Markdown file. Phase 2 proved
that loop works with a placeholder rectangle; Phase 3 replaces it with the
real capsule from `design.md`/`motion.md` — states, motion, the waveform — and
a proper state machine covering the degenerate cases design.md's error table
lists.

**Status: Phase 3's capsule and state machine are in and working on real
hardware**, macOS 26.6, Apple Silicon, 2026-09-11–12. What changed along the
way, from live testing rather than from reading the spec twice:

- **Engine swapped from `SFSpeechRecognizer` to `SpeechAnalyzer`.**
  `SFSpeechRecognizer` turned out to silently drop everything spoken before a
  mid-recording pause — it appears to treat a pause as an utterance boundary
  and reset its running hypothesis, so only the last segment survived. Not
  caught by Spike C, which only tested unbroken utterances. `SpeechAnalyzer`
  (`Capture/SpeechAnalyzerTranscriber.swift`) is built for long-form,
  non-live transcription and doesn't have that failure mode. This raises the
  deployment target to macOS 26 — see `project.yml`'s comment on why that's a
  non-issue for an app that only ever runs on the one Mac it's built on.
- **Waveform amplitude switched from peak to RMS.** Peak was far too
  sensitive to background hiss — bars sat tall at idle and saturated almost
  immediately once talking. RMS (what motion.md actually specifies) sits much
  lower at rest.
- **A noise gate on top of that.** Even RMS didn't fully collapse to
  design.md's flat 2px "not picking you up" silence signal, so amplitudes
  below a threshold snap to true zero rather than blending through a
  moderate resting height.
- **The waveform's smoothing runs on its own steady 20ms clock**, decoupled
  from the audio tap's own irregular delivery timing. Driving the smoothing
  directly off the tap's callbacks read as "stop motion" — real hardware
  delivers buffers at bursty, uneven intervals, and there was nothing
  interpolating between them.
- **`NSHostingView`'s backing layer needs its background forced transparent**
  explicitly (`hosting.layer?.backgroundColor = .clear`) — it doesn't
  inherit that from the panel's own `isOpaque`/`backgroundColor` settings.
- **`panel.hasShadow = false` is required.** AppKit draws a system drop
  shadow shaped to the whole (mostly invisible) window rectangle by default,
  which shows up as a mismatched rectangular halo layered behind the
  capsule's own SwiftUI shadow on just the pill shape.
- **The capsule's shadow needs real clearance below it**, not just enough
  room for the 16px rise — a 25px-blur, 18px-offset shadow was getting hard-
  clipped by the panel's own frame, reading as a sharp cutoff rather than a
  soft fade.
- **The panel repositions to the cursor's screen before every capture.**
  `NSScreen.main` tracks the key window, which this non-activating panel
  never becomes, so on a multi-monitor setup it stayed pinned to whichever
  screen happened to be main at launch rather than following the user.
- **The timer shows "0:00" immediately** rather than staying hidden for 3
  seconds as design.md's push-to-talk spec calls for — that read as a delay
  in practice, not a deliberate omission, once actually watched during a
  capture.

Release-to-text latency after all of the above: 0.43–0.53s for 13-to-20-word
sentences, well under `PLAN.md`'s 1.5s budget, into both TextEdit and Ghostty.

## What this reuses from Phase 0

Every technique here is one the spikes in `../spikes/` test in isolation,
combined into one real path:

| File | Reuses |
| --- | --- |
| `Capture/HotkeyMonitor.swift` | Spike A's global-monitor approach |
| `UI/CapsulePanel.swift` | Spike A's non-activating panel |
| `Capture/AudioRecorder.swift` | Spike C's 16kHz mono recording path |
| `Capture/Transcriber.swift` | The protocol seam Spike C's engine sits behind — now `SpeechAnalyzerTranscriber`, see Phase 3 notes above |
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

Not Phase 3's scope yet:

- **One hotkey, hardcoded.** Right Option, push-to-talk only. No menu bar
  item or toggle mode yet — that's `capture-v2.html`'s other half, and it's
  Phase 4/5 territory alongside the history window and settings.
- **No settings, no history window.** Phase 4 and 5.
- **Errors print to the console in addition to the capsule.** The capsule
  now shows every error state from design.md's table, but there's no log
  view beyond the raw console for anything that scrolls past.
- **Concurrency is compiler-verified now, but not stress-tested.** The control
  plane — `HarpsController`, `HotkeyMonitor`, `CapsulePanel` — is `@MainActor`.
  The off-main types (`AudioRecorder`, `OnDeviceTranscriber`) carry
  `@unchecked Sendable` with a comment saying why it holds: `HarpsController`
  is their only owner and the audio tap never overlaps the start/stop calls.
  That is sound under the current single-call-site design; a second caller, or
  concurrent captures in Phase 3, would need it revisited rather than trusted.
