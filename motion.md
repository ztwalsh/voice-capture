# Voice Capture — Motion Principles

**Reference:** [transitions.dev](https://transitions.dev) by Jakub Antalík
([source](https://github.com/Jakubantalik/transitions.dev)). A collection of
thirty-two portable CSS transitions built on one shared scale of motion tokens,
published both as copy-ready snippets and as an installable agent skill.

This document does not invent a motion scale. It **adopts theirs** and maps each
state of the app onto a named transition from the library, so the motion is
consistent with a system that has already been tuned, and so the HTML prototype
can use the real snippets rather than approximations of them.

> This replaces an earlier draft with a parallel set of hand-rolled springs. The
> principles largely survived; the numbers are now inherited rather than
> invented, and two states changed shape because the library had a better answer
> than the one I had written.

---

## The premise

Motion carries almost the entire status channel here. There is no text
explaining what is happening, because the point is that you are not looking at
it. Whether the app is hearing you, working, or finished has to be readable in
peripheral vision as a change in shape.

That raises the standard. Motion is not decoration to be tuned down later. It is
the interface. The reference is a good fit precisely because it treats transitions
as components with specifications rather than as flourishes.

---

## Six principles

### 1. It emerges where it lives

Nothing travels across the screen. The capsule rises sixteen pixels into the
place it will occupy and settles. Travel implies the object came from somewhere
and has a home elsewhere. This object has no elsewhere.

### 2. Motion tracks the voice, not the clock

The waveform is driven by measured amplitude, never by a timer. This is the
difference between an interface that is listening and one that is pretending.
When you stop talking it goes flat, not to an idle shimmer. Silence should look
like silence.

The corollary: **your voice draws the line.** The only free-running motion in the
listening state is the motion you are personally causing.

### 3. One object, resized

There are no cross-fades between states, because there are no separate views to
cross-fade. The capsule changes width and its contents change. You should watch
a whole session and never see two objects at once.

This is the library's card-resize pattern doing the structural work, and it is
what makes peripheral reading possible: one silhouette, whose proportions tell
you where you are.

### 4. Arriving is deliberate, leaving is snappy

Entry runs on a 350ms clock, exit on 250ms. This asymmetry is the reference's
own, built into the toast transition, and it matches what this app needs
exactly. Getting out of the way is the feature, and an exit that lingers is the
app asking for attention on its way out.

**Recording starts at key-down, not when the animation settles.** The arrival is
cosmetic and never costs you a word. If you start speaking at 100ms the bars are
already responding while the capsule is still settling, which is correct.

### 5. Narrate the work, do not spin

While transcription runs, the status line shimmers and can swap to name what is
happening. A shimmering label that could say `Transcribing` and then `Inserting`
tells you more than a spinner, and unlike a progress bar it never has to lie
about a percentage.

This is the one looping animation in the app, and it loops because work is
genuinely ongoing and its duration is genuinely unknown.

### 6. The inserted text never animates

The moment the transcript lands in your app it appears. No fade, no typewriter,
no highlight. This is the one place the app touches your actual work, and any
animation there puts the app between you and your sentence.

---

## The inherited token scale

Straight from the reference. Match on **usage**, not on the raw number.

**Durations**

| Token | Value | Usage |
| --- | --- | --- |
| `--duration-stagger` | 40ms | per-item stagger offset |
| `--duration-micro` | 80ms | tooltip/path delay, shake segment |
| `--duration-quick` | 150ms | modal/dropdown close, text swap |
| `--duration-fast` | 250ms | icon swap, dropdown/modal open, page slide |
| `--duration-medium` | 350ms | panel close, toast close |
| `--duration-slow` | 400ms | panel open, skeleton reveal, input clear |
| `--duration-very-slow` | 500ms | emphasis moments, badge appear, text reveal |

**Easings**

| Token | Value | Usage |
| --- | --- | --- |
| `--ease-smooth-out` | `cubic-bezier(0.22, 1, 0.36, 1)` | open and close, resize, position change |
| `--ease-in-out` | `ease-in-out` | icon swap, text swap, text reveal |
| `--ease-out` | `ease-out` | tooltip open and close |
| `--ease-linear` | `linear` | shimmer, skeleton pulse, spinner |
| `--ease-bounce` | `cubic-bezier(0.34, 1.36, 0.64, 1)` | badge pop |
| `--ease-bounce-strong` | `cubic-bezier(0.34, 3.85, 0.64, 1)` | bouncy hover-out |

**Distances, scales, blur**

| Token | Value |
| --- | --- |
| `--distance-micro` / `-small` / `-base` / `-medium` / `-large` | 4 / 6 / 8 / 12 / 30 px |
| `--scale-large` / `-medium` / `-small` / `-tiny` | 0.96 / 0.97 / 0.98 / 0.99 |
| `--blur-small` / `-medium` / `-large` | 2 / 3 / 8 px |

Note the ceiling: the largest scale change in the whole system is four percent,
and the largest blur used in a transition is eight pixels. The reference is
consistently restrained, and staying inside its range is most of what keeps the
app from feeling animated-at.

---

## State transitions

Each row names the library transition to use, so the prototype pulls the real
snippet rather than reimplementing it.

| Transition | Library pattern | Specification |
| --- | --- | --- |
| Dormant → Listening | **Toast** (22) | Rise 16px, fade, cross-blur 2px, scale 0.97 → 1. 350ms, `--ease-smooth-out` |
| Listening | *custom* | Waveform only. Dot solid, timer fades in at `--duration-quick` after 3s |
| Listening → Transcribing | **Card resize** (01) + **Text states swap** (04) | Width 240 → 132 over 300ms `--ease-smooth-out`; center content swaps over 150ms, out up through 2px blur, in from 4px below |
| Transcribing, holding | **Thinking states** (28) | Shimmer sweeps the label on a 2000ms linear loop; any state change swaps at 150ms |
| Transcribing → Dormant | **Toast** close (22) | 250ms, reverse of entry |
| Any → Error | **Card resize** + **Error state shake** (12) | Width morphs to fit; shake 6px with 4px overshoot in 80ms then 60ms segments; holds 3000ms; reverts over 280ms |
| Error → Dormant | **Toast** close (22) | 250ms |
| History rows on open | **Texts reveal** (18) | Staggered blurred rise, 40ms per row, first eight rows only |
| Expanding a history row | **Card resize** (01) | 300ms, `--ease-smooth-out` |
| A transcript arriving in an open history window | **Streaming text** (30) | Words resolve through 1px cross-blur, 60ms apart, 350ms each |

Two of these are worth calling out as changes the reference caused.

**Transcribing was a custom sweep over a frozen waveform.** The library's
thinking-states pattern is better: it is designed for exactly this, an agent
status line narrating work, and it composes shimmer with the text swap so the
label can change mid-flight without a hard cut. The frozen waveform is dropped.

**Errors now shake.** The earlier draft only changed color and width, which is
easy to miss in peripheral vision. The library's shake with an auto-reverting
hold is percussive enough to catch attention without an alert, and its 3000ms
hold is already tuned to be long enough to read the message.

The last row is a deliberate exception to principle 6. Text inserted into *your*
app never animates. Text arriving in *our* history window resolves through the
streaming transition, which distinguishes what just landed from what was already
there.

---

## The waveform

The one piece with no counterpart in the library, because it is data-driven
rather than state-driven. It is specified here in the reference's idiom and
tuned to sit inside its restraint.

**Sampling.** RMS over 20ms windows, delivered at 50 Hz.

**Normalization.** Convert to dB, clamp to a −50 dB floor and −6 dB ceiling, map
to 0…1. Absolute amplitude is useless; the range that matters is a person
speaking a few feet from a laptop.

**Asymmetric smoothing.** What separates a waveform that feels alive from one
that feels like a graph.

```
value += (target - value) * (target > value ? 0.60 : 0.12)
```

Fast attack so consonants punch through, slow release so it does not strobe
between syllables. The asymmetry is the whole trick, and it echoes the
reference's own open-slow, close-fast asymmetry at a different timescale.

**Height.** `height = 3 + pow(value, 0.7) * 21`, giving the 3px to 24px range
from `design.md`. The exponent lifts quiet speech into visibility, since normal
talking sits low in the range and a linear map makes the app look deaf.

**Color.** Interpolate `--text-faint` → `--text` across the same 0…1. Neutral,
per the design principle that motion carries state rather than color. Loudness
becomes weight instead of hue.

**History.** The array shifts one bar per sample. 32 bars at 50 Hz is 640ms of
visible history, roughly a phrase — long enough to show the shape of what you
said, short enough to feel immediate.

**Silence.** Flat at 3px. No jitter, no floor animation, no idle life. It is the
clearest possible signal that the microphone is not picking you up.

---

## Departures from the library

Stated so they are choices rather than drift.

1. **The waveform is ours.** Nothing in the library is driven by live data.
2. **No success check.** The library ships a good one (10). We do not use it,
   because our success is the text landing in your app, and a checkmark would be
   the app congratulating itself.
3. **The shadow is heavier.** Covered in `design.md`. Their material shadow is
   tuned for a card on a near-white page; ours floats over unknown content.
4. **Toast motion, centered anchor.** We use the toast transition for a
   centered overlay rather than a corner notification. Same motion, different
   position, and the rise still reads correctly.
5. **The record dot never pulses.** No library pattern pushes us here; it is
   listed because a pulsing record dot is the obvious thing to add and it would
   compete with the waveform for the same attention.

---

## Reduce Motion

Every snippet in the library ships a `prefers-reduced-motion: reduce` guard, so
the baseline is inherited rather than written. These are the app-specific
additions.

| Element | Behavior |
| --- | --- |
| Capsule enter and exit | Opacity only, 100ms. No rise, no scale, no blur. |
| Width morph | Instant. The silhouette still changes, it just does not tween. |
| Shimmer | Replaced by a static label. Text instead of motion. |
| Error shake | Removed. The message and the hold remain. |
| Waveform | Kept, with the horizontal scroll removed. Bars change height in place, so nothing translates. |
| History reveal and streaming | Removed. Content appears at rest. |

The waveform survives because Reduce Motion targets large-scale movement that
provokes vestibular discomfort, not small in-place data display, and because it
is the only feedback that the microphone is working. Removing it would make the
app unusable rather than calmer.

---

## Performance

The reference's own rule, which is also the right one here: stick to
compositor-friendly properties, meaning `transform`, `opacity`, and `filter`,
and use `will-change` sparingly.

App-specific additions:

- Render the waveform on a display-link-driven canvas, not by pushing SwiftUI
  state fifty times a second. State churn at that rate drops frames.
- Never transition `backdrop-filter`. Animating the blur is the single most
  expensive mistake available on this surface.
- Warm the audio engine, the panel, and the model at launch, not at key-down.
  Everything on the hot path between the hotkey and the first frame must already
  exist. First frame within **120ms**; the 350ms settle runs after.
- If a frame budget must be missed, miss it while transcribing, never while
  listening. Listening is the state under direct observation.

---

## Pulling the library in

The reference publishes itself as an installable skill, so the prototype can use
the real snippets:

```bash
npx skills add Jakubantalik/transitions.dev
```

That installs `SKILL.md`, a reference file per transition, and `_root.css`, the
token block above as a single paste. Individual transitions are also available
through the CLI:

```bash
npx transitions-pro add card-resize
npx transitions-pro list
```

The ones this app needs are card-resize, text-states-swap, toast,
error-state-shake, thinking-states, texts-reveal, and streaming-text.
