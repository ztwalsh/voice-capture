# Voice Capture — Design

> **Note on the reference.** The Threads link you shared
> (`threads.com/share/BABG2xtgV8`) is blocked by this environment's network
> proxy, and I could not reach it through any mirror. So this document is **not**
> derived from that reference. It is a direction reasoned from the product's own
> constraints, written to be concrete enough to build and specific enough to
> argue with. Send me a screenshot, a paste of the post, or a description of what
> caught your eye and I will reconcile this against it. The token layer is
> structured so a change of aesthetic is a change of values, not a rewrite.

---

## 1. The premise

Almost every design decision here follows from one fact:

**This interface appears on top of someone else's app, in the middle of someone's
sentence, and its job is to leave.**

That is unusual. Most software wants attention. This wants the opposite. It is
closer to the macOS volume overlay than to an app — a momentary confirmation that
the system heard you, floating over work that continues underneath.

Which means the design is not asked to be memorable. It is asked to be *legible
in peripheral vision, at a glance, while your attention is on a sentence you are
composing*. Anything that requires you to look directly at it has failed.

## 2. Principles

**Invisible until invoked.** There is no idle window, no persistent overlay, no
resting state on screen. Before you press the key there is nothing. The menu bar
item is the only permanent surface, and it is a template glyph that disappears
into the bar.

**One object, not a screen.** The whole interface is a single capsule that
changes shape. It does not navigate, stack, or open panels. Every state is a
transformation of the same object, which is what lets it be read peripherally —
you learn one silhouette, and its shape tells you the state.

**The voice is the only ornament.** There is exactly one thing moving, and it is
driven by your actual audio. No spinners, no gradients breathing on a timer, no
decorative motion. If something is animating, it means something.

**Status has one color.** The accent exists to say "you are live" and says
nothing else. Borrowed from the tally light on a camera: a single warm point
that means recording, understood instantly, used nowhere else in the app.

**Confidence over reassurance.** Success is not celebrated. When it works, the
text appears and the capsule leaves. A checkmark would be the app congratulating
itself for doing its job. The interface only speaks up when something is wrong.

**The history is a document, not a feed.** The second surface, where you go back
through what you said, follows the opposite rules: system-native, calm, dense,
comfortable to sit in. It is a text app. It should feel like Notes, not like the
capsule.

---

## 3. Tokens

### Color

The capsule is dark in both light and dark system appearance. This is deliberate
and matches macOS convention for heads-up overlays — a HUD that inverts with the
system reads as a window, and this is not a window.

```
/* Capsule surface — always dark */
--surface            rgba(22, 22, 24, 0.72)   /* over a blurred backdrop */
--surface-solid      #1C1C1E                  /* Reduce Transparency fallback */
--hairline-top       rgba(255, 255, 255, 0.14) /* 0.5px inner top edge */
--hairline-edge      rgba(255, 255, 255, 0.08) /* 0.5px inner full border */
--shadow             0 10px 36px rgba(0, 0, 0, 0.46)

/* Content on the capsule */
--text-primary       rgba(255, 255, 255, 0.95)
--text-secondary     rgba(255, 255, 255, 0.56)
--text-tertiary      rgba(255, 255, 255, 0.32)

/* The one accent — live only */
--accent             #FF6B4A   /* signal coral, the tally light */
--accent-dim         #B84A33   /* accent at rest inside the waveform floor */

/* The one negative */
--negative           #FF8A80   /* error text, muted for a dark surface */
```

The waveform interpolates from `--text-secondary` at silence to `--accent` at
peak. Loudness becomes warmth. That single mapping is the app's whole visual
signature, and it costs nothing because it is data you already have.

Backdrop for the capsule: 32px blur with saturation pushed to 180%, so the
colors of the app underneath bleed through faintly. The capsule should feel like
it is made of the desktop behind it, not pasted on top.

### Type

SF Pro throughout, which is free, native, and already tuned for exactly this
size range.

| Role | Size / line | Weight | Tracking | Used for |
| --- | --- | --- | --- | --- |
| Label | 11 / 14 | Medium | +0.02em | Capsule status, timers, timestamps |
| Body | 13 / 19 | Regular | 0 | Transcript text |
| Title | 15 / 20 | Semibold | 0 | History row headers |
| Display | 22 / 26 | Semibold | -0.01em | History window header |
| Mono | 12 / 18 | Regular | 0 | Raw log view, SF Mono |

The capsule uses Label and nothing else. If a state needs Body on the capsule,
that state is saying too much.

### Space

4pt base unit. Permitted values: 4, 8, 12, 16, 24, 32, 48. Nothing between them.

### Radius

| Token | Value |
| --- | --- |
| `--r-capsule` | fully rounded, height ÷ 2 |
| `--r-card` | 10 |
| `--r-window` | 12 |
| `--r-bar` | 1.5 (waveform bars) |

---

## 4. The capsule

Horizontally centered on the screen containing the cursor, with its bottom edge
96px above the screen bottom. That clears the Dock in its default size and sits
below the natural center of attention, which is where a status readout belongs.

Fixed placement rather than following the caret. Caret position is not reliably
available across apps, and a capsule that lands in the wrong place is worse than
one that lands consistently.

### States

There are five, and each has a distinct silhouette.

**Dormant.** Nothing on screen. The menu bar glyph is a thin waveform in
template style, following the menu bar's own color.

**Listening** — the primary state.

```
┌──────────────────────────────────────────┐
│  ●   ▁▃▅█▆▃▂▁▂▄▆█▅▃▁▂▃▅▄▂▁▂▃▁      0:04  │   240 × 44
└──────────────────────────────────────────┘
```

- Height 44, width 240, fully rounded.
- Tally dot, 6px, `--accent`, at 16px from the left edge. Solid, not pulsing —
  it is a state indicator, and a pulse would be decoration competing with the
  waveform.
- Waveform occupies the center, 148px wide. 32 bars, 3px wide, 2px gap,
  center-mirrored vertically, 3px minimum height, 24px maximum.
- Elapsed timer in Label, `--text-secondary`, right-aligned at 16px inset.
  Appears only after 3 seconds, so short captures stay clean.

**Transcribing.** The capsule contracts to 132 × 44. The waveform is replaced by
the last-captured waveform frozen and desaturated to `--text-tertiary`, with a
narrow highlight sweeping left to right across it. The tally dot goes dark. The
frozen waveform matters: it shows you *what it is working on*, which is more
informative and more honest than a spinner.

**Inserted.** No visual state. The capsule leaves. The text appearing in your
app is the confirmation.

**Error.** The capsule expands to fit one line of Label text in `--negative`,
maximum 320px wide, and stays for 4 seconds or until the hotkey is pressed
again. The tally dot becomes a 6px `--negative` dot.

The error messages are part of the design, because they are the only sentences
this interface ever writes:

| Condition | Message |
| --- | --- |
| Secure input active | `Can't type into a password field` |
| No speech detected | `Didn't catch anything` |
| Microphone unavailable | `No microphone` |
| Accessibility not granted | `Needs Accessibility access` |
| Transcription failed | `Couldn't transcribe that` |
| Insertion failed | `Copied to clipboard instead` |

Each is lowercase-bodied, under six words, and describes the situation rather
than blaming. The last one is the important one: when insertion fails, the text
is never lost, it goes to the clipboard, and the message says so.

---

## 5. The history window

A standard macOS window, following system appearance in both light and dark. It
is the opposite of the capsule on purpose: this is where you sit and read.

- Minimum 720 × 520, remembers its size and position.
- Single column, reverse chronological. No sidebar. "Basic" means one list.
- Search field in the toolbar, focused by Command-F, filtering live as you type.
- Rows are 
  a relative timestamp in Label `--text-secondary`,
  the transcript in Body clamped to three lines,
  and the icon of the app it was inserted into at 16px, right-aligned.
- Clicking a row expands it in place to full text. No detail pane, no modal.
- Row actions on hover: copy, delete. Both also on the context menu.
- Day separators as sticky Label headers: `Today`, `Yesterday`, then dates.
- Empty state: one line of Body in `--text-secondary` naming the hotkey. It is
  the only place in the app that teaches, and it is where a new user will look.
- A footer link reveals `transcripts.jsonl` in Finder. Say plainly where the
  data lives; that is the whole promise of a local-first tool.

---

## 6. Accessibility

Not a checklist item here. A dark translucent overlay is exactly the pattern
that breaks for people, so it gets handled explicitly.

- **Reduce Transparency.** Swap `--surface` for `--surface-solid` and drop the
  backdrop blur. Strengthen `--hairline-edge` to 0.16 so the shape stays defined
  against a busy desktop.
- **Increase Contrast.** Raise `--text-secondary` to 0.72, `--text-tertiary` to
  0.5, and give the capsule a full 1px `--hairline-edge` border.
- **Reduce Motion.** Covered in `motion.md`, with full functional parity.
- **Contrast ratios.** `--text-primary` and `--text-secondary` clear 4.5:1
  against `--surface-solid`. `--text-tertiary` is decorative only and never
  carries meaning alone. `--accent` on `--surface-solid` clears 3:1, which is
  the bar for a non-text indicator.
- **Color is never the only signal.** The tally dot is reinforced by the
  waveform being live and by the capsule's shape. Listening and transcribing
  differ in silhouette, not just color.
- **VoiceOver.** The capsule announces its state changes through a live region:
  "Listening", "Transcribing", "Inserted", or the error text. The history window
  is a standard accessible list.
- **Keyboard.** The history window is fully operable without a mouse. The
  capsule has no controls by design.

---

## 7. What this deliberately does not have

Stated so it stays absent.

No logo or wordmark in the capsule. No settings gear on the overlay. No
waveform when there is no audio. No progress bar with a fake percentage. No
onboarding tooltips over other people's apps. No sound. No badge counts. No
theme options.

Every one of these is a thing this category of app commonly adds, and every one
of them makes the object heavier than what it does.
