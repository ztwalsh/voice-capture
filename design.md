# Voice Capture — Design

**Reference:** [transitions.dev](https://transitions.dev) by Jakub Antalík
([source](https://github.com/Jakubantalik/transitions.dev)). The site was
blocked by this environment's proxy, so this is drawn from the repository behind
it: the showcase page's own visual tokens, and the thirty-two transition
specifications it publishes as an installable agent skill.

Two things were taken. The **visual language** — light-first, near-neutral, soft
layered shadows, hairline borders, Inter with a mono companion — informs this
document. The **motion system** informs `motion.md`, which uses its tokens
directly rather than inventing a parallel scale.

> This revises an earlier draft that proposed a dark heads-up display with a warm
> coral accent. The reference is light-first and almost entirely without chroma,
> so the palette, the appearance behavior, and the role of color have all
> changed. What survives is the premise below, which comes from the product
> rather than from any reference.

---

## 1. The premise

**This interface appears on top of someone else's app, in the middle of
someone's sentence, and its job is to leave.**

Most software wants attention. This wants the opposite. It is closer to the
macOS volume overlay than to an app — a momentary confirmation that the system
heard you, floating over work that continues underneath.

So it is not asked to be memorable. It is asked to be legible in peripheral
vision, at a glance, while your attention is on a sentence you are composing.

The reference turns out to suit this unusually well. A library of small,
self-contained transitions for surfaces that appear, do one thing, and dismiss
is a close match for an app that is a single surface appearing, doing one thing,
and dismissing.

## 2. Principles

**Invisible until invoked.** No idle window, no persistent overlay, no resting
state on screen. Before you press the key there is nothing. The menu bar item is
the only permanent surface.

**One object, resized.** The whole interface is a single capsule that changes
width. It does not navigate, stack, or open panels. Every state is the same
object at a different size, which is what makes it readable peripherally: you
learn one silhouette and its proportions tell you the state.

**Motion carries the state, not color.** This is the reference's central lesson
and the biggest change from the earlier draft. The palette is neutral to the
point of being nearly monochrome. What tells you the app is listening is that
the waveform is moving; what tells you it is working is that the status line is
shimmering. Where an earlier version reached for a saturated accent, motion now
does that job. Details are in `motion.md`.

**Soft materials, hairline edges.** Surfaces are defined by layered low-opacity
shadows and a one-pixel border at six percent black, never by heavy strokes or
strong fills. Nothing in the reference has a hard edge, and nothing here should.

**The voice is the only ornament.** Exactly one thing is driven by live data,
and it is your audio. No decorative motion, no gradients breathing on a timer.

**Confidence over reassurance.** Success is not celebrated. When it works, the
text appears and the capsule leaves. The reference ships a success-check
animation and we deliberately do not use it, because a checkmark here would be
the app congratulating itself for doing its job.

**The history is a document, not a feed.** The second surface follows the
opposite rules: native, calm, dense, comfortable to sit in. It is a text app.

---

## 3. Tokens

Values are inherited from the reference where it defines them and marked where
they are adapted.

### Color

Both appearances are defined, and the capsule follows the system. The reference
is light-first with a dark theme, and following it here also means the overlay
matches whatever the user's Mac is already doing.

```
/* ── Light ─────────────────────────────────────────── */
--surface          rgba(255, 255, 255, 0.86)  /* over a 32px backdrop blur */
--surface-solid    #ffffff                    /* Reduce Transparency fallback */
--trough           #f9f9f9                    /* waveform bed — their stage-bg */
--hairline         rgba(0, 0, 0, 0.06)
--text             #0d0d0d
--text-muted       #6c6c6c
--text-subtle      #767676
--text-faint       #8f8f8f
--label-mono       #5e6073

/* ── Dark ──────────────────────────────────────────── */
--surface          rgba(28, 28, 30, 0.82)
--surface-solid    #1c1c1e
--trough           rgba(255, 255, 255, 0.04)
--hairline         rgba(255, 255, 255, 0.08)
--text             #fbfbfb
--text-muted       rgba(255, 255, 255, 0.62)
--text-subtle      rgba(255, 255, 255, 0.48)
--text-faint       rgba(255, 255, 255, 0.34)
--label-mono       rgba(255, 255, 255, 0.52)

/* ── The one chromatic value, both appearances ─────── */
--live             #E5484D   /* light */
--live             #FF6369   /* dark */
```

`--live` is the single deliberate departure from the reference's chroma-free
palette, and it is justified on safety rather than style: you must never be
uncertain whether the microphone is hot. It appears on one six-pixel dot and
nowhere else in the app. Everything else is neutral.

### Elevation

The reference's material shadow, used for cards sitting on a near-white page:

```
0 4px 42px 0 rgba(0, 0, 0, 0.06),
0 2px  6px 0 rgba(0, 0, 0, 0.05),
0 0 0 1px   rgba(0, 0, 0, 0.06)
```

**Adapted** for the capsule, which floats over unknown content rather than a
known page, and needs more separation to stay readable over a photograph or a
dark editor:

```
/* light */
0 8px 48px 0 rgba(0, 0, 0, 0.12),
0 2px  8px 0 rgba(0, 0, 0, 0.08),
0 0 0 1px   rgba(0, 0, 0, 0.06)

/* dark */
0 8px 48px 0 rgba(0, 0, 0, 0.50),
0 0 0 1px   rgba(255, 255, 255, 0.08)
```

The three-layer structure is kept: a wide soft ambient, a tight contact shadow,
and a hairline ring standing in for a border. That layering is what makes the
reference's surfaces feel like material rather than boxes.

### Type

**Geist and Geist Mono** ([vercel.com/font](https://vercel.com/font)), replacing
the reference's own Inter and Roboto Mono pairing. Geist is a tighter, more
geometric neo-grotesque with an unusually strong monospace companion, and the
mono is what earns the choice here: the elapsed timer needs tabular digits so the
readout does not jitter as it counts, and Geist Mono's slashed zero and wide
counters stay legible at 10 and 11px, which is the whole size range this
interface uses.

Both are under the SIL Open Font License, so the same files can be self-hosted in
the prototype and bundled in the shipped app. No system-font substitution, and no
network dependency at runtime.

| Role | Size / line | Weight | Tracking | Used for |
| --- | --- | --- | --- | --- |
| Label | 11 / 14 | Medium | +0.01em | Capsule status |
| Timer | 11 / 14 | Regular, Geist Mono | 0 | Elapsed time, in `--label-mono` |
| Body | 13 / 19 | Regular | 0 | Transcript text |
| Title | 15 / 20 | Semibold | −0.01em | History row headers |
| Display | 22 / 26 | Semibold | −0.01em | History window header |

The negative tracking on the two larger sizes is the reference's, and it is what
keeps larger text from looking loose.

### Space and radius

4pt base. Permitted: 4, 8, 12, 16, 20, 24, 32, 48. The 20 is the reference's own
card inset.

| Token | Value |
| --- | --- |
| `--r-capsule` | fully rounded, height ÷ 2 |
| `--r-card` | 12 |
| `--r-window` | 12 |
| `--r-bar` | 1.5 |

---

## 4. The capsule

Horizontally centered on the screen containing the cursor, bottom edge 96px
above the screen bottom. That clears the Dock and sits below the natural center
of attention, which is where a status readout belongs.

Fixed placement rather than following the caret. Caret position is not reliably
available across apps, and a capsule that lands in the wrong place is worse than
one that lands consistently.

### States

Four, each with a distinct width. Transitions between them are specified in
`motion.md`.

**Dormant.** Nothing on screen. The menu bar glyph is a thin waveform in
template style, following the menu bar's own color.

**Listening** — 248 × 44.

```
┌──────────────────────────────────────────┐
│  ●   ▁▃▅█▆▃▂▁▂▄▆█▅▃▁▂▃▅▄▂▁▂▃▁      0:04  │
└──────────────────────────────────────────┘
```

- Record dot, 6px, `--live`, 20px from the left edge. Solid, not pulsing. It is
  a state indicator, and a pulse would be decoration competing with the waveform.
- Waveform centered, 148px wide. 30 bars, 3px wide, 2px gap, mirrored
  vertically, 2px to 24px tall. Thirty bars at that spacing is exactly 148px,
  which sets the capsule width: 248 is the smallest that fits the waveform
  between the dot and the timer without clipping.
- Elapsed timer in Timer type, right-aligned at 20px inset, appearing only after
  three seconds so short captures stay clean.

**Transcribing** — 176 × 44. The record dot goes dark and the waveform is
replaced by a shimmering status line reading `Transcribing`. Using the
reference's thinking-states pattern here means the app can narrate honestly if
the work has phases, rather than showing an indeterminate spinner.

**Inserted.** No visual state. The capsule leaves. The text appearing in your
app is the confirmation.

**Error** — sized to the message, maximum 320px. The dot goes dark, the message
appears in `--text`, and the capsule shakes once. It holds for three seconds and
then dismisses.

In both states that drop the timer, the centre box carries a mirrored 18px right
margin matching the dot and its gap. Without it the label sits 18px right of the
capsule's true centre line, which is visible.

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

Each is under six words and describes the situation rather than assigning blame.
The last one matters most: when insertion fails the text is never lost, it goes
to the clipboard, and the message says so.

---

## 5. The history window

A standard macOS window following system appearance. Deliberately the opposite
of the capsule: this is where you sit and read.

- Minimum 720 × 520, remembers size and position.
- Single reverse-chronological column. No sidebar. "Basic" means one list.
- Search in the toolbar, focused by Command-F, filtering live.
- Rows carry a relative timestamp in `--text-subtle`, the transcript in Body
  clamped to three lines, and the 16px icon of the destination app right-aligned.
- Rows sit on `--surface-solid` with the reference's original card shadow, not
  the heavier capsule one. These are cards on a page, which is exactly the case
  that shadow was tuned for.
- Clicking a row expands it in place. No detail pane, no modal.
- Hover actions: copy and delete. Both also on the context menu.
- Sticky day separators: `Today`, `Yesterday`, then dates.
- Empty state: one line naming the hotkey. The only place the app teaches, and
  where a new user will look.
- A footer control reveals `transcripts.jsonl` in Finder. Say plainly where the
  data lives; that is the whole promise of a local-first tool.

---

## 6. Accessibility

A translucent floating overlay is exactly the pattern that breaks for people, so
it is handled explicitly.

- **Reduce Transparency.** Swap in `--surface-solid`, drop the backdrop blur,
  raise `--hairline` to 12% so the shape stays defined over a busy desktop.
- **Increase Contrast.** `--text-muted` to `--text`, `--text-subtle` up one step,
  and a full 1px `--hairline` border on the capsule.
- **Reduce Motion.** Covered in `motion.md`. The reference ships a
  `prefers-reduced-motion` guard with every transition, so this is inherited
  rather than invented.
- **Contrast.** `--text` and `--text-muted` clear 4.5:1 against `--surface-solid`
  in both appearances. `--text-faint` is decorative only and never carries
  meaning alone. `--live` clears 3:1, the bar for a non-text indicator.
- **Color is never the only signal.** Because motion carries state here, this is
  mostly free: listening and transcribing differ in width, in what occupies the
  center, and in whether the waveform is live.
- **VoiceOver.** The capsule announces state changes through a live region. The
  status line already carries `role="status"` in the reference's markup.
- **Keyboard.** The history window is fully operable without a mouse. The
  capsule has no controls by design.

---

## 7. What this deliberately does not have

Stated so it stays absent.

No logo in the capsule. No settings gear on the overlay. No waveform when there
is no audio. No progress bar with a fake percentage. No success checkmark, even
though the reference ships a good one. No onboarding tooltips over other
people's apps. No sound. No badge counts. No theme picker.

Every one of these is common in this category, and every one makes the object
heavier than what it does.
