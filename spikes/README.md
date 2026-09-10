# Phase 0 — spikes

Three throwaway programs that answer the questions that could change Harps'
architecture. Nothing here survives into the app. The point is to buy certainty
before committing, per `../PLAN.md`.

**These need a Mac.** They were written on Linux and have never been compiled —
expect to fix a signature or two on the first build. That is normal for a spike
and much cheaper than discovering the answers in Phase 2.

## Before you start

Grant Accessibility to **the terminal you run from**, not to the spike binaries.

System Settings › Privacy & Security › Accessibility › `+` › Terminal (or iTerm).

A command-line tool inherits its parent's permission. Granting it to the binary
instead looks like it works, then silently breaks on the next build, because
SwiftPM writes a new binary at a new path and the grant is per-path. This is the
single most confusing thing about building this kind of app, and it is worth
getting right on day one.

Spike C will also ask for Microphone and Speech Recognition the first time.

## Spike A — does the panel steal focus?

The defining constraint. If showing the capsule moves focus, the caret is gone
and there is nothing to insert into.

```bash
swift run SpikeAFocus
```

Click into a text field in another app, hold Right Option for a second, release.
It captures the frontmost app and the focused element *before* the panel appears
and compares them after, so the verdict is measured rather than eyeballed.

Test at minimum: **Notes, Chrome, Slack.** They cover native AppKit, WebKit and
Electron, which is where behaviour diverges.

| App | Verdict | Shown in | Notes |
| --- | --- | --- | --- |
| Notes | PASS | ~1–3 ms (24 ms cold) | `AXTextArea` held before/after, every hold |
| Dia (Chromium) | PASS | ~1–2 ms | `AXTextField` held; tested in the address bar. Stands in for Chrome |
| Slack | PASS* | ~1 ms | Reported `PARTIAL` only because `AXFocusedUIElement` was `none` both before *and* after — Electron doesn't expose it system-wide. Caret verified visually: stayed put, typing continued uninterrupted |

Run on macOS 26.6, Apple Silicon, 2026-09-07.

**Verdict: focus provably never moves.** `.nonactivatingPanel` + `.accessory`
policy + `orderFrontRegardless()` holds in AppKit, Chromium and Electron. The
Slack `PARTIAL` is a read-back limitation of Electron's accessibility, not a
focus failure — the Spike B question of whether text can be *inserted* there is
where that limitation actually bites.

A `PARTIAL` result means the app held but the focused element changed — some
apps rebuild their accessibility tree constantly. Check the caret visually
before calling it a failure.

## Spike B — can we get text into someone else's field?

macOS has no supported "type into the frontmost app" call, so Harps needs a
fallback chain. This tries all three against whatever you have focused.

```bash
swift run SpikeBInsert                          # all three, 5s to focus
swift run SpikeBInsert --strategy ax --delay 8  # one at a time
```

Run it once per app and fill this in. This table decides the default strategy
and the fallback order, and it is the main output of Phase 0.

Run on macOS 26.6, Apple Silicon, 2026-09-07. `✓` = verified landed (read back
from the field), `eye` = confirmed visually where the app hides its value from
accessibility, `✗ silent` = strategy reported success but no text appeared.

| App | Kind | AX | Paste | Type | Default |
| --- | --- | --- | --- | --- | --- |
| Notes | AppKit | ✓ | ✓ | ✓ | **ax** |
| Safari | WebKit | ✓ | ✓ | ✓ | **ax** |
| Dia (≈ Chrome) | Chromium | ✓ | ✓ | ✓ | **ax** |
| Xcode | AppKit | ✓ | ✓ | ✓ | **ax** — tested in a field, not the source editor |
| Slack | Electron | ✗ no element | eye | eye | **paste** |
| Notion | Electron | ✗ no element | eye | eye | **paste** |
| Ghostty | GPU term | ✗ no element | eye | eye | **paste** |
| Terminal.app | AppKit | ✗ silent (`AXError 0`, nothing lands) | ✓ | ✓ | **paste** |
| Messages | Catalyst | ✗ nothing lands | ✓ | ✓ | **paste** |

**Default strategy: paste.** It landed in every app where insertion is possible
at all. `type` also worked everywhere but is slower and less predictable.
`ax` is the cleanest *when it works* — native AppKit, WebKit and Chromium — but
it is unusable in Electron (no focused element to write to) and, worse, in
Terminal.app it returns `.success` while inserting nothing. So `ax` is a
verified-only optimisation: try it only where the focused element exposes an
editable value, and only trust it after reading the text back.

### Password and secure fields

| Field | `SECURE INPUT IS ACTIVE`? | Text landed? |
| --- | --- | --- |
| `sudo` at a shell `Password:` prompt | **yes** | no — correctly blocked |
| System Settings auth sheet (add fingerprint) | no | no — all three strategies silently rejected |
| Web password (`<input type=password>` in Dia) | no | **yes** — dots appeared; AX value masked so the spike couldn't self-verify |

The `IsSecureEventInputEnabled()` guard **works** — `sudo` tripped it and the
spike reported the field unusable instead of pretending to type into it. That is
Phase 0's secure-input exit criterion met.

But it is necessary, not sufficient. It did not fire for a browser password
box, which then **accepted synthetic text** — dots and all. And the System
Settings auth sheet neither flagged nor accepted, failing silently. Two
consequences for Harps:

1. **Verify every insertion by reading it back.** A success code means nothing —
   Terminal.app's `ax` returned `.success` into the void, and the System
   Settings sheet swallowed all three. When the text can't be confirmed in the
   field afterward, surface "couldn't insert," never assume it worked.
2. **Actively avoid password fields**, including web ones the OS guard misses.
   Check the AX subrole (`AXSecureTextField`) and skip it — a browser password
   box taking dictated text is a privacy problem, not a feature.

## Spike C — is on-device transcription fast enough?

Records from the real microphone through the same `AVAudioEngine` path the app
will use, converts to 16 kHz mono, then transcribes and times it.

```bash
swift run SpikeCTranscribe                # record 10s and transcribe
swift run SpikeCTranscribe --seconds 15
swift run SpikeCTranscribe --file take.wav
```

Budget: **release to text under 1.5s for a 10-second utterance.**

| Engine | Audio | Transcribe | Realtime | Accuracy, by eye |
| --- | --- | --- | --- | --- |
| SFSpeechRecognizer (on-device) | | | | |
| SpeechAnalyzer | | | | |
| whisper.cpp base.en | | | | |

It keeps the recording so you can run the same file through whisper.cpp and
compare like for like:

```bash
brew install whisper-cpp
whisper-cli -m ggml-base.en.bin -f /tmp/harps-spike-*.wav
```

**Read the transcripts, do not just compare numbers.** Published benchmarks use
read speech; you dictate in half sentences with your own vocabulary. Accuracy on
your voice is the thing that matters and only you can judge it.

The spike deliberately ships with `SFSpeechRecognizer` rather than
`SpeechAnalyzer`, which is what `../PLAN.md` recommends. The reason is that this
should produce a number on the first run, and a speculative API call that fails
to compile produces nothing. The engine sits behind a protocol — adding
SpeechAnalyzer is one new struct and one changed line once the harness is
proven.

## Exit criteria

Phase 0 is done when:

- ~~The insertion matrix above is filled in, and at least one strategy lands in
  all eight apps.~~ **Done.** `paste` lands in all eight; it is the default,
  `ax` is a verified-only optimisation, `type` the last resort. Secure input is
  detected. Harps must read back every insertion rather than trust a result code.
- A 10-second utterance transcribes inside the budget, with a named engine.
  **Spike C still outstanding** — needs Speech Recognition granted to the
  terminal and a live run.
- ~~Focus provably never moves in all three Spike A apps.~~ **Done.** PASS in
  AppKit, Chromium and Electron; the Slack `PARTIAL` was an AX read-back limit,
  not a focus move (caret verified by eye).

If Spike C misses the budget, the fallback is a smaller Whisper model or a
different engine — and that decision happens here, not in Phase 3.
