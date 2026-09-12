# Harps

The full loop from `../PLAN.md`: hold a hotkey, speak, release, the text lands
at your caret, and a line is appended to today's Markdown file. Phase 2 proved
that loop works with a placeholder rectangle; Phase 3 replaced it with the
real capsule from `design.md`/`motion.md`; Phase 4 added the window you open
to get your transcripts back; Phase 5 makes it something you'd actually
install and use daily rather than run from Xcode.

**Status: all five of PLAN.md's phases have a working first pass**, all
confirmed on real hardware. What follows is written phase-by-phase as it was
built, oldest first — treat the top of the file as current and the sections
below it as the history of how it got there.

## Phase 5 — onboarding, real settings, logging, and a build script

- **Onboarding** (`UI/Onboarding/`) checks Microphone, Speech Recognition,
  and Accessibility live — polled every second, not cached — and offers the
  right action for each: the two that use a normal system prompt get a
  "Grant" button, Accessibility (which can't be requested with a dialog) gets
  "Open Settings". Reachable from the menu bar's "Permissions…" or
  automatically whenever `HarpsController` notices Accessibility isn't
  granted.
- **`HarpsController` now polls Accessibility every 2s instead of checking
  once at launch.** PLAN.md's onboarding requirement is to "recover
  gracefully if permission is revoked later," which only means something if
  the app also *starts* working the moment permission is granted without a
  relaunch — confirmed both directions on real hardware: toggling
  Accessibility off mid-session stops capture and reopens onboarding;
  toggling it back on resumes the hotkey with no relaunch.
- **Real settings**, backed by `Storage/SettingsStore.swift`: launch at login
  (`SMAppService`) and keep-audio-for-debugging are genuine, working
  controls. Hotkey/model/insertion-strategy stay informational text in
  Settings — each has exactly one implementation, so a picker with one
  option would be UI theater.
- **Logging through `OSLog`** (`Storage/AppLog.swift`) replaces every
  `print()`. Errors and key events also land in a small in-memory ring
  buffer shown as "Recent Activity" on the Settings page, so seeing what
  went wrong doesn't require Console.app.
- **`build.sh`** regenerates the Xcode project and produces an ad-hoc-signed,
  runnable `Harps.app` in `app/build/` without opening Xcode.

## Phase 4 — the history window

**Status: the full design.md §7 window, not just PLAN.md's narrower Phase 4
exit criteria.** Sidebar with Overview/Transcripts/Settings, a captures-per-
day chart, Library and Document layouts, search across both (including
match highlighting and day-filtering in Document mode), a `.md` panel, copy/
delete/reveal-in-Finder on every capture, and a Settings page. Confirmed
functionally working on real hardware, 2026-09-12 — search, both layouts,
and all three card actions tested directly. Visual fidelity to design.md's
exact type/spacing/hover-state spec is a known gap, not yet a priority pass:
this uses system fonts (not Geist/Geist Mono, which the window doesn't
bundle), approximate spacing, no hover-revealed actions, and a chart with no
crosshair/tooltip. That polish is intentionally deferred rather than done.

There was no way to open this window before now — the hotkey alone can't do
it — so this also adds a minimal `NSStatusItem` menu bar icon
(`UI/StatusItemController.swift`) with "Open Harps" and "Quit", pulled
forward from Phase 5's fuller menu bar item/popover out of necessity.

## Phase 3 — the real capsule

**Status: the capsule and state machine are in and working on real
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

Or skip both steps with `./build.sh`, which regenerates the project and
produces an ad-hoc-signed, runnable `Harps.app` in `app/build/` — PLAN.md
Phase 5's build script.

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

## Using Harps

Hold **Right Option** anywhere, speak, release — the text lands wherever
your cursor was. Click the caret icon in the menu bar for **Open Harps**
(the history window: search, browse, copy, delete, reveal in Finder),
**Permissions…** (live status for all three grants), or **Quit Harps**.

**Your data.** Everything lives in
`~/Library/Application Support/Harps/`: `transcripts/YYYY-MM-DD.md`, one
plain Markdown file per day, readable and editable in any text editor —
there is no database and no export step, because the file *is* the export.
Delete a day file to delete that day's history; nothing else references it.

**Permissions.** Accessibility, Microphone, and Speech Recognition. None of
it leaves the Mac — Speech Recognition here means on-device transcription,
not a network call. Revoking any of them is detected live and stops capture
until it's granted again; no relaunch needed either direction.

## What's known-incomplete, on purpose

- **One hotkey, hardcoded.** Right Option, push-to-talk only — no toggle
  mode or the fuller menu-bar popover from `capture-v2.html` (record button,
  recent captures inline). The current menu bar item is deliberately minimal.
- **Hotkey/model/insertion strategy aren't switchable.** Each has exactly one
  implementation, shown as informational text in Settings rather than a
  picker with one option.
- **Concurrency is compiler-verified, but not stress-tested.** The control
  plane — `HarpsController`, `HotkeyMonitor`, `CapsulePanel` — is `@MainActor`.
  The off-main types (`AudioRecorder`, `SpeechAnalyzerTranscriber`) carry
  `@unchecked Sendable` with a comment saying why it holds: `HarpsController`
  is their only owner and the audio tap never overlaps the start/stop calls.
  That is sound under the current single-call-site design; a second caller,
  or concurrent captures, would need it revisited rather than trusted.
