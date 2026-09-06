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
| Notes | | | |
| Chrome | | | |
| Slack | | | |

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

| App | AX | Paste | Type | Default should be |
| --- | --- | --- | --- | --- |
| Notes | | | | |
| Safari | | | | |
| Chrome | | | | |
| Slack | | | | |
| Xcode | | | | |
| Terminal / iTerm | | | | |
| Notion | | | | |
| Messages | | | | |

`UNVERIFIED` means the app does not expose its field value over accessibility,
so the spike cannot self-check — look at the app and record what you saw.

Also worth doing once: focus a **password field** and run it. Secure input
should be detected and reported. That path has to fail loudly in the real app
rather than silently dropping your words.

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

- The insertion matrix above is filled in, and at least one strategy lands in
  all eight apps.
- A 10-second utterance transcribes inside the budget, with a named engine.
- Focus provably never moves in all three Spike A apps.

If Spike C misses the budget, the fallback is a smaller Whisper model or a
different engine — and that decision happens here, not in Phase 3.
