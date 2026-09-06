# Capsule prototype

Phase 1 of `../PLAN.md`. Design artifacts for settling how the capsule feels,
not a foundation for the app.

| File | What it is |
| --- | --- |
| `index.html` | The adopted direction, full loop: capture, insert, history |
| `versions.html` | Three directions for the capsule side by side, live on the same audio |
| `dim.html` | What happens to everything else while you dictate — five background treatments |
| `library.html` | The main window, first pass — two layouts over one set of transcripts |
| `library-v2.html` | Second pass, after the MonRize reference — sidebar, Overview, settings |
| `capture-v2.html` | Capture in that same language, invoked from the menu bar or the hotkey |

## Run it

```bash
python3 -m http.server 8000
```

Then open <http://127.0.0.1:8000/> for the full prototype, or
<http://127.0.0.1:8000/versions.html> to compare directions, or
<http://127.0.0.1:8000/dim.html> to compare background treatments, or
<http://127.0.0.1:8000/library.html> or
<http://127.0.0.1:8000/library-v2.html> for the main window, or
<http://127.0.0.1:8000/capture-v2.html> for capture.

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

## The three directions

`versions.html` runs all three at once off one microphone, so they can be judged
on the same audio at the same moment rather than from memory.

| | Geometry | The question it asks |
| --- | --- | --- |
| **Pill** | 248 × 44, fully rounded, dot + waveform + timer | The current spec, as the control |
| **Bar** | 320 × 40, radius 10, no indicator at all | Can motion alone carry "you are live", with the red dot gone and the timer as the only left anchor? |
| **Mono** | 208 × 36, radius 8, committed dark, all Geist Mono | Does a technical instrument beat soft OS chrome? `REC` replaces the dot, and leaves entirely once recording stops |

Mono is deliberately the same in light and dark, which `design.md` allows for a
design that commits to one look. Its distinctness is strongest in light mode; in
dark it converges with the other two.

## The main window

`library.html` is the window you open to get your transcripts back. Two
directions over the same five days of data, switchable in the toolbar.

| | What it is | Built for |
| --- | --- | --- |
| **Library** | Days in a rail, captures as cards with time, app, duration and word count | Finding a thing |
| **Document** | The selected day rendered as one continuous piece, wide measure, quiet type | Reading a day back |

Search filters across every day at once and groups the hits, in both layouts.
`⌘F` focuses it. Cards expand in place on click rather than opening a detail
pane, because a dictated sentence is short enough not to need one.

### Second pass — `library-v2.html`

Reworked against two references: a fintech dashboard (MonRize) and a markdown
notes app.

**From MonRize.** A persistent left sidebar with a selected pill, an Overview
built from big numerals over small muted labels, hairline separators instead of
cards, pill tab rows, deep near-black in dark rather than the softer grey, and
green reserved strictly for deltas.

**From the notes app.** Command-number shortcuts set in mono beside each day, and
a Document view that leaves the `##` markers visible but dimmed — so the file
still reads as a file rather than as rendered output. Put it beside the `.md`
panel and the two agree, which is the point.

Three decisions worth arguing with:

**Green is a second chromatic value.** `design.md` says one accent, the record
dot, and that motion carries state rather than colour. MonRize uses green
functionally for direction, and that is defensible here because it never appears
alone — always with an arrow and a "vs last week". But it is a real amendment to
the principle, not a free addition.

**Three nav items, not eight.** MonRize is a platform with eight destinations.
This is a basic app with three, and padding the sidebar to match the reference's
density would be borrowing the look without the substance.

**The Overview is new scope.** `../PLAN.md` Phase 4 is a history window and
nothing else. Stats and a chart are genuinely useful and make the app feel like
somewhere you would go, but they are work that is not currently in the plan.

The chart's two series are the same measure across consecutive weeks, so they
are separated by lightness and dash pattern rather than hue. There is no
categorical palette to validate, and the distinction survives any colour vision.
Two series means a legend, and it has one, plus a crosshair and tooltip on hover.

### The .md toggle

The `.md` button in the toolbar slides in the actual file behind whatever you
are looking at. It is generated from the same objects the UI renders, so the
panel is not a mock-up of the format — it is the format, and the round trip can
be checked rather than imagined. The status bar shows the real path.

### Audio

**Keep audio** in the prototype bar toggles a play control onto every capture.
It is off by default and matches `../PLAN.md`, which does not retain audio: it
is the most sensitive thing the app touches and it has no use after
transcription. The toggle exists so the cost of changing that decision is
visible — turning it on is what adds playback, and it is a privacy and disk
decision before it is a UI one.

## Capture, second pass

`capture-v2.html` puts the capsule in the window's language and adds the menu
bar. Both ways in are live: click the item in the mock menu bar, or hold Right
Option.

**They are two interactions, not one with two triggers.** A button cannot be
held, so the menu bar means toggle, and toggle can be left running — the exact
failure push-to-talk was chosen to avoid. So the two behave differently on
purpose:

| | Hotkey | Menu bar |
| --- | --- | --- |
| Mode | Push-to-talk | Toggle |
| Capsule sits | Bottom centre, near your work | Under the icon it came from |
| Stop | Release the key | A stop control, or the menu bar item again |
| Timer | Appears after three seconds | Visible from the first tick |
| Menu bar icon | Red while recording | Red while recording |

The capsule emerges from wherever it was invoked — upward from the bottom of the
screen, downward from the menu bar — so the object always comes from the thing
that summoned it.

The popover is the discoverable path: a record button, the last three captures,
and a way into the window. The hotkey is the fast path and needs none of it.

### Marks

Four options in the prototype bar, and they change the menu bar item live. That
is the only size that matters — a mark for this app has to survive at 16px,
monochrome, and in red while recording.

| | Reads as | Verdict |
| --- | --- | --- |
| **bars** | An audio waveform | The current mark. Clear, but every audio app has one |
| **caret** | A text I-beam | The most apt idea — text lands at a caret — but at 16px it reads as a text-tool cursor |
| **arc** | Sound leaving a point | Distinctive at 16px without being generic. The recommendation |
| **ring** | The record symbol | Instantly legible, and instantly anonymous |

## Background treatments

`dim.html` asks what the rest of the screen does while you are capturing. Five
treatments, one intensity control mapped so the same number means a comparable
amount of interference across all of them, and a **Pin listening** toggle so a
state can be held still and compared.

| | What it does |
| --- | --- |
| **None** | Control |
| **Scrim** | A flat dark veil. Reads as modal — the app is busy |
| **Fade** | The UI drops its own opacity toward the desktop |
| **Blur** | Background blurs and desaturates. Depth-of-field, not a curtain |
| **Vignette** | Dark at the edges, clear around the capsule |

The treatment runs on the same toast clock as the capsule, 350ms in and 250ms
out, so the two arrive and leave together. A background that lags the capsule
reads as broken.

Three things this exercise settled:

**Fade keeps colour, scrim destroys it.** A black veil greys the whole desktop;
dropping the windows' own opacity lets the wallpaper through, so the UI reads as
receding rather than as covered. They are not the same effect at different
strengths, they are different effects.

**Blur breaks the one thing you need to see.** You are dictating into a text
field and want to watch the insertion point. At any blur strong enough to read
as a treatment, that field is illegible.

**Every treatment dims the field you are dictating into.** That is the core
tension, and it is not solvable by tuning. Vignette is the only one that can
protect a region, and even it protects the area around the capsule rather than
around the caret, which are rarely the same place.

Animate the scrim's **opacity**, never its blur radius. `motion.md`'s rule about
never transitioning `backdrop-filter` applies with more force at full-screen
size, and fading a layer that already carries a static blur gets the same result
for almost nothing.

### What this would cost in the app

Worth weighing before adopting any of these. The current design is one small
panel. A background treatment means a full-screen transparent window per display
that must be click-through, must never take focus, must follow display
configuration changes, and will dim other applications' menu bars along with
everything else.

It also sits in real tension with the app's own first principle, that it is
invisible until invoked and leaves quickly. Taking over the whole screen for the
duration of a two-second utterance is the opposite of getting out of the way.

## Type

Geist and Geist Mono, from <https://vercel.com/font>, self-hosted in `fonts/` so
the prototype needs no network. Both are SIL Open Font License, so the same files
can be bundled in the shipped app.

## Motion

Every transition comes from [transitions.dev](https://transitions.dev), pasted
as published: toast (22), card-resize (01), text-states-swap (04),
error-state-shake (12), thinking-states (28), texts-reveal (18), and
streaming-text (30). The token block at the top of the `<style>` is their
`_root.css`, trimmed to what this page uses.

The waveform is the one piece with no counterpart in the library, because it is
driven by live data rather than by state.
