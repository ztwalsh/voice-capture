# Capsule prototype

Phase 1 of `../PLAN.md`. A design artifact for settling how the capsule feels,
not a foundation for the app.

## Run it

```bash
python3 -m http.server 8000
```

Then open <http://127.0.0.1:8000/>.

**Serve it — do not open the file directly.** `getUserMedia` requires a secure
context, and `file://` is not one, so opening `index.html` from Finder silently
falls back to a synthetic envelope and you never see the waveform respond to
your actual voice. `localhost` counts as secure, so the local server is enough.

## Use it

| Input | Action |
| --- | --- |
| Hold **Right Option** | Capture. Release to transcribe and insert. |
| Hold the **Hold to talk** button | Same, for when the key is inconvenient |
| **H** | Toggle the history window |
| **Esc** | Cancel the capture without inserting |

Put the cursor in the note window first — dictated text lands at the caret,
with no animation, which is the point of principle 6 in `../motion.md`.

The panel on the right switches appearance, forces Reduce Motion, and fires
each error state. It is prototype scaffolding, not part of the design.

## What is real and what is faked

**Real:** every transition, all motion tokens, the microphone input, and the
amplitude mapping — RMS to dB, clamped to −50/−6, asymmetric smoothing at 0.60
attack and 0.12 release, and the 0.7 exponent on bar height.

**Faked:** transcription. Releasing the key waits 900ms and inserts a canned
sentence. Nothing is sent anywhere and nothing is stored.

## Motion

Every transition comes from [transitions.dev](https://transitions.dev), pasted
as published: toast (22), card-resize (01), text-states-swap (04),
error-state-shake (12), thinking-states (28), texts-reveal (18), and
streaming-text (30). The token block at the top of the `<style>` is their
`_root.css`, trimmed to what this page uses.

The waveform is the one piece with no counterpart in the library, because it is
driven by live data rather than by state.
