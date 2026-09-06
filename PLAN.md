# Voice Capture — Execution Plan

A local-first push-to-talk dictation utility for macOS. Hold a key, speak, release,
and the transcribed text lands in whatever text field you were already focused on.
Every transcript is saved locally and browsable.

Status: planning. Nothing is built yet.

---

## 1. What we are building

### The one-sentence product

Press and hold a global hotkey anywhere in macOS, speak, release, and your words
appear as text at the cursor — transcribed entirely on-device, and kept in a local
history you own.

### The core loop

1. You are in any app with a cursor in a text field.
2. You hold the hotkey. A small heads-up display appears. **Your focus does not move.**
3. You speak. The display shows live audio so you know it is hearing you.
4. You release. The display shows it is working.
5. Text is inserted at the cursor in the app you were already in.
6. The transcript is appended to local history.

### What "basic" means — v1 scope

**In:**

| Capability | Detail |
| --- | --- |
| Trigger | One global push-to-talk hotkey, user-configurable |
| Capture | Mono 16 kHz from the default input device |
| Transcription | On-device Whisper, English, no network |
| Insertion | Text at the caret of the previously focused app |
| History | Append-only local log with a browsable window |
| Presence | Menu bar item, no Dock icon |

**Out of scope for v1**, deliberately:

- Streaming or partial results while you speak. Batch on release only.
- Voice commands, punctuation dictation, custom vocabulary, text replacements.
- Any language other than English. Swap the model later if you want more.
- Any cloud call, account, telemetry, or auto-update.
- An AI cleanup pass over the transcript.
- Distribution to anyone but you. No notarization, no installer.

### Success criteria

The product is good if these hold. They are the acceptance tests for v1.

| Measure | Target |
| --- | --- |
| Release-to-text latency, 10s utterance | under 1.5s on Apple Silicon |
| Hotkey-to-listening latency | under 120ms, feels instant |
| Focus stolen from the host app | never |
| Insertion success across the 8 target apps | 8 of 8 |
| Word error rate, quiet room, native speaker | comparable to Apple dictation or better |
| Idle CPU | effectively zero, no audio engine running when not recording |

The eight target apps to test insertion against: Notes, Safari, Chrome, Slack,
Xcode, Terminal or iTerm, Notion, and Messages. That spread covers native
AppKit, WebKit, Chromium/Electron, and terminal emulators, which is where the
insertion strategies diverge.

---

## 2. Technical approach

### Stack

| Layer | Choice | Why |
| --- | --- | --- |
| Language | Swift 6, strict concurrency | Native access to every API this needs |
| UI | SwiftUI inside an AppKit `NSPanel` | SwiftUI for layout, AppKit for window behavior SwiftUI cannot express |
| Packaging | Xcode project, agent app (`LSUIElement`) | Entitlements and signing are painful outside Xcode |
| Audio | `AVAudioEngine` + `AVAudioConverter` | Standard, low-latency, gives raw float buffers |
| Transcription | `whisper.cpp` with Metal, via its Swift package | Small, auditable, ships a plain C API, no framework lock-in |
| Storage | One Markdown file per day | Readable and editable without the app, opens in any editor, zero schema migration |
| Sandbox | Off | The App Sandbox and the Accessibility API do not coexist usefully |

On transcription there is a real alternative worth naming: **WhisperKit** is a
Swift-native package that compiles Whisper to Core ML and runs it on the Neural
Engine, and it is a smaller integration than bridging C++. The tradeoff is that
whisper.cpp gives more direct control over threading and model files, which
matters when tuning the latency budget. Both are viable. The plan assumes
whisper.cpp and treats swapping in WhisperKit as a contained change behind one
protocol, decided during the Phase 0 spike on measured latency.

### The four hard problems

Everything else in this app is ordinary. These four are where it succeeds or fails,
and each gets de-risked before any real UI is written.

**Focus must not move.** This is the defining constraint. If showing the display
steals focus, the caret is lost and the whole product collapses. The window has to
be an `NSPanel` with the non-activating style mask, floating above other windows,
in an app marked as a UI element so it has no Dock presence. `NSApp.activate` must
never be called anywhere in the codebase. This is worth an explicit lint rule.

**Getting text into someone else's app.** macOS offers no supported "type this
into the frontmost app" call, so this needs a fallback chain, tried in order:

1. Set the selected-text attribute on the focused element through the
   Accessibility API. Cleanest when it works, and it fails silently on many web
   apps that do not use native text controls.
2. Save the pasteboard, write the transcript, synthesize Command-V, restore the
   pasteboard after a short delay. Works nearly everywhere. Clobbering the
   user's clipboard is unacceptable, so the save-and-restore has to be correct
   including multiple pasteboard types.
3. Synthesize the characters directly as keyboard events carrying a Unicode
   string. Slowest, and the last resort for apps that reject the other two.

The frontmost app and focused element must be captured **before** the display
appears, not after, and insertion targets that captured reference.

**Permissions.** The app needs microphone access, Accessibility access, and
possibly Input Monitoring depending on how the hotkey is captured. Accessibility
in particular cannot be requested with a normal dialog; it requires sending the
user to System Settings and detecting the grant afterward. Every one of these
tools that feels broken feels broken here. Onboarding is a first-class feature,
not a polish item.

**Secure input mode.** When the focus is a password field, macOS enables secure
input, which blocks event taps and text insertion entirely. The app must detect
this and say so plainly rather than appearing to work and silently dropping the
text. This is the single most common bug report in this category of app.

### Hotkey choice

Right-Option is the recommendation: it is a modifier almost nobody uses on a US
layout, it is comfortable to hold, and it is unambiguous as push-to-talk. The Fn
key is tempting and should be avoided — macOS handles it specially and
intercepting it reliably is disproportionate work. A chord like
Command-Shift-Space is the fallback if a modifier-only trigger proves flaky.

Push-to-talk is the default because it has no failure mode where the app is
silently recording.

**The menu bar item forces a second mode.** A button cannot be held, so clicking
it means toggle: click to start, click again to stop. That reintroduces exactly
the failure push-to-talk avoids — a capture left running while you walk away —
so toggle mode has to carry its own safeguards, and they are part of the design
rather than polish:

- The menu bar icon turns red for the whole capture, so the state is visible
  even with every window covered.
- The capsule shows its timer from the first tick rather than after three
  seconds, since a toggle can run long and unattended.
- The capsule carries an explicit stop control, and the menu bar item itself
  becomes a stop while a capture is running.

The two triggers are therefore two interactions, not one interaction with two
entry points, and `prototype/capture-v2.html` keeps them distinct.

### Audio and latency

Tap the input node, convert to 16 kHz mono 32-bit float, which is exactly what
Whisper wants. Buffer in memory; a dictation utterance is short and there is no
reason to touch disk. Run a voice-activity or amplitude gate only to drive the
visualization, not to trim audio — trimming risks eating the first word.

The audio engine starts on hotkey-down and stops on release. It must not run at
idle, both for the microphone indicator in the menu bar and for battery.

Model choice drives the latency budget directly. Start with `base.en`, roughly
150 MB, which runs many times faster than real time on Apple Silicon. Move to
`small.en` if accuracy disappoints and the budget allows. Download the model on
first launch rather than bundling it, so the app stays small.

### Storage

Everything lives in `~/Library/Application Support/VoiceCapture/`.

- `transcripts/YYYY-MM-DD.md` — one file per day. YAML frontmatter carries the
  day's date, capture count and word count; each capture is a section whose
  heading is its time, the app it landed in, and its duration:

  ```md
  ---
  date: 2026-09-05
  captures: 5
  words: 110
  ---

  ## 09:14 · Notes · 6s

  Let's push the launch to the week after next so the docs land first.
  ```
- `settings.json` — hotkey, model, insertion preference, retention.
- `models/` — downloaded Whisper weights.

Audio is **not** retained by default. It is the most sensitive artifact the app
touches and it has no use after transcription. A debug setting can keep the last
few recordings for troubleshooting, off by default.

**Why Markdown, and what it costs.** The point of a local-first tool is that
your data outlives the app, and a folder of dated Markdown files is the most
durable form that takes. It opens in Obsidian, iA Writer, BBEdit, or `cat`. It
diffs and versions in git. Search is `rg` over a few hundred small files, which
is instant well past any personal volume.

The costs are real and worth naming:

- **One file per day, not one per capture.** Per-capture files are more
  atomic and more Obsidian-native, but at thirty captures a day that is roughly
  ten thousand files a year, which is unpleasant in Finder and noisy for
  Spotlight. Per-day is a few hundred files a year and reads as a journal.
- **Markdown is not a database.** Appending is cheap; editing or deleting a
  capture means rewriting the file. At day-file size, a few kilobytes, that is
  free — but it must be a write to a temporary file followed by an atomic
  rename, or a crash mid-write loses the day rather than one line. An
  append-only log gets that property for nothing; this does not.
- **The user can edit these files, and that is the whole point.** Which means
  the app must re-read before it appends, must watch for external changes, and
  must never assume it was the last writer.
- **Human-editable metadata is fragile metadata.** The heading is both prose
  and schema. If a heading is edited by hand the parse degrades, so parse
  leniently and treat the transcript text as the only thing that truly matters.
  Counts and durations are a convenience, and the app should survive losing them.

A SQLite index can be built over the folder later as a pure cache if search
ever gets slow. The files stay the source of truth.

### Privacy posture

No network access at all after the one-time model download. That is a
verifiable claim, not a promise: the app makes no other outbound request, and
the model download can be a separate, visible, user-initiated step.

---

## 3. Phases

Each phase ends in something demonstrable. Phases 0 and 1 can run in parallel.

### Phase 0 — De-risk the hard parts

Three throwaway spikes, each answering one question. Nothing here survives into
the product; the point is to buy certainty before committing to a design.

- **Spike A, focus.** A non-activating panel that appears over the frontmost app
  while a hotkey is held. Prove the caret never moves in Notes, Chrome, and Slack.
- **Spike B, insertion.** A command-line tool that inserts a fixed string into
  the focused field using each of the three strategies. Build the compatibility
  matrix across all eight target apps. This tells us which strategy is the
  default and which are fallbacks.
- **Spike C, latency.** Feed a 10-second WAV to whisper.cpp with `base.en` and
  `small.en` and to WhisperKit. Measure wall-clock on the target machine. This
  decides the transcription engine and the default model.

**Exit criteria:** the insertion matrix is filled in, measured latency for a
10-second clip is under 1.5s with a named model and engine, and focus provably
never moves. If Spike C misses the budget, the fallback is a smaller model or
Apple's on-device speech APIs, and that decision happens here rather than late.

### Phase 1 — HTML prototype

A single self-contained HTML file that runs the visual and motion design of the
heads-up display through every state, driven by keyboard, with fake transcripts.
It is a design artifact, not a foundation.

The point is to settle how the thing feels before any of it is expensive to
change in Swift. Motion decided here becomes the spec the app implements.

This phase builds directly on [transitions.dev](https://transitions.dev), the
reference behind `design.md` and `motion.md`. Install the library first so the
prototype uses the real snippets rather than approximations:

```bash
npx skills add Jakubantalik/transitions.dev
```

The transitions this app needs are card-resize, text-states-swap, toast,
error-state-shake, thinking-states, texts-reveal, and streaming-text. Paste
`_root.css` once for the shared token scale, then wire each state to its mapped
transition from the table in `motion.md`.

Scope: the capsule's listening, transcribing, and error states, the transitions
between them, entry and exit, and a rough pass at the history window. Drive the
waveform from a real microphone through the Web Audio API rather than synthetic
levels — the amplitude smoothing coefficients are the one thing that cannot be
tuned against fake data, and they are what make it feel alive.

**Exit criteria:** you look at it and want to use it.

### Phase 2 — Walking skeleton

The full loop, end to end, deliberately ugly. Hotkey to recording to
transcription to insertion to a line appended in the log. A plain rectangle for
the display. No settings, one hardcoded hotkey, one hardcoded model.

This is the moment the product either works or does not, and it should arrive
early. Everything after it is refinement.

**Exit criteria:** you dictate a real sentence into a real app and the text
appears. Latency measured against the budget.

### Phase 3 — The real interface

Replace the placeholder display with the design from `design.md` and the
motion from `motion.md`. Build the state machine properly. Handle the
degenerate cases visibly: no speech detected, microphone busy, secure input
active, transcription failed.

**Exit criteria:** the app matches the prototype, including motion under
Reduce Motion.

### Phase 4 — History

The window you open to get your transcripts back. A reverse-chronological list,
search, copy, delete, and reveal-in-Finder for the underlying file. Reads the
Markdown files directly.

**Exit criteria:** you can find something you dictated last week in a few seconds.

### Phase 5 — Make it real software

The unglamorous work that separates a demo from something you use daily.

- Onboarding that walks through microphone and Accessibility permission with
  live state detection, and recovers gracefully if permission is revoked later.
- Settings: hotkey, model, insertion strategy, retention, launch at login.
- Launch at login via `SMAppService`.
- Error handling and logging through `OSLog` with a way to see recent errors.
- Ad-hoc code signing and a build script that produces a runnable app bundle.
- A README covering permissions, the file layout, and how to get your data out.

**Exit criteria:** you install it fresh on a clean account and it works without
you remembering anything.

### Sequencing

Phase 0 gates everything, because its answers can change the architecture.
Phase 1 is independent and can run alongside it. Phase 2 needs Phase 0. Phase 3
needs 1 and 2. Phases 4 and 5 are independent of each other.

---

## 4. Risks

| Risk | Impact | Response |
| --- | --- | --- |
| Insertion fails in a must-have app | High | Phase 0 Spike B measures this before commitment; three-strategy fallback chain with per-app overrides |
| Latency lands above the budget | High | Measured in Spike C; fall back to a smaller model, a different engine, or Apple's on-device speech APIs |
| Right-Option push-to-talk proves unreliable | Medium | Fall back to a chord hotkey; the trigger sits behind one protocol |
| Secure input silently swallows text | Medium | Detect and surface it explicitly as an error state, designed in Phase 3 |
| Accessibility permission confuses onboarding | Medium | Treat onboarding as a real feature in Phase 5 with live permission state |
| Whisper hallucinates on silence | Low | Gate on a minimum duration and amplitude; discard empty or degenerate results rather than inserting them |
| Model download is large and slow | Low | User-initiated, visible progress, resumable |

The two that can actually change the plan are insertion compatibility and
latency. Both are answered in Phase 0, which is why Phase 0 exists.

---

## 5. Open decisions

These need your input; none of them block Phase 0 or Phase 1.

1. **Name.** The docs use "Voice Capture" as a placeholder.
2. **Hotkey.** Right-Option is the recommendation. It is your muscle memory.
3. **Push-to-talk versus toggle** as the default. Push-to-talk is safer.
4. **Model size** — accuracy against latency. Decided in part by Spike C.
5. **Where the display appears** — anchored near the caret, or fixed near the
   bottom of the screen. Near the caret is more elegant and much harder to get
   right, since caret position is not reliably available. Fixed placement is
   the pragmatic default and what the design assumes.
