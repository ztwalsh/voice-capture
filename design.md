# Harps — Design

**References.** Motion comes from [transitions.dev](https://transitions.dev) and is
specified in `motion.md`. The visual language of the second pass comes from two
places: a fintech dashboard (MonRize) for the window's structure, and a markdown
notes app for how the files stay visible as files.

**Status.** Approved. This describes the second pass, built in
`prototype/library-v2.html` and `prototype/capture-v2.html`. It supersedes the
first pass, which used a softer grey palette, a single-column history panel, one
accent, and push-to-talk as the only trigger.

---

## 1. The premise

Harps is two surfaces with opposite jobs, and almost every decision follows from
which one you are in.

**The capsule appears on top of someone else's app, mid-sentence, and its job is
to leave.** It is closer to the macOS volume overlay than to an app. It is never
asked to be memorable, only legible in peripheral vision while your attention is
on a sentence you are composing.

**The window is where you sit and read.** Native, calm, dense, comfortable. It
follows the opposite rules on purpose.

## 2. Principles

**Invisible until invoked.** No idle overlay. Before you press the key or click
the menu bar there is nothing on screen but a 16px template glyph.

**One object, resized.** The capsule is a single shape that changes width. Every
state is the same object at a different size, which is what makes it readable
peripherally: you learn one silhouette and its proportions tell you the state.

**Motion carries state, colour does not.** What tells you Harps is listening is
that the waveform is moving; what tells you it is working is that the label is
shimmering. This is why the palette can be almost monochrome.

**Two colours, both earned.** Red means the microphone is hot, and appears on
nothing else. Green means a delta improved, never appears without an arrow and a
comparison label, and appears nowhere but the Overview. Anything else is neutral.

**Soft materials, hairline edges.** Surfaces are defined by layered low-opacity
shadow and a one-pixel border, never by heavy strokes or strong fills. Separators
are hairlines, not cards — border, fill, radius and shadow are spent by role
rather than stamped on every block.

**The files stay visible as files.** The Document view keeps the `##` markers on
screen, dimmed. The `.md` panel shows the real file. The status bar names the
real path. A local-first tool that hides its own storage is asking to be trusted
rather than earning it.

**Confidence over reassurance.** Success is not celebrated. When a capture works,
the text appears and the capsule leaves.

---

## 3. Tokens

### Colour

Both appearances are first-class. Nothing is designed for one and flipped.

```
/* ── Neutral scale ──────────────────────────── */
neutral/50   #fafafa
neutral/800  #1c1c24
neutral/850  #13131c
neutral/900  #0d0d16
neutral/950  #0c0c0d

/* ── Light ─────────────────────────────────── */
--bg          #fafafa     /* window ground — neutral/50       */
--side        #fbfbfc     /* sidebar, panels, status bar      */
--sel         #ececed     /* selected row, pressed control    */
--trough      #f4f4f5     /* inputs, chips, inactive tabs     */
--hairline    rgba(0,0,0,0.075)
--text        #0a0a0a
--text-muted  #6a6a6c
--text-subtle #86868a
--text-faint  #a8a8ac
--label-mono  #6f7180     /* mono metadata — a cool grey      */

/* ── Dark ──────────────────────────────────── */
--side        #0a0a13     /* one step darker than neutral/900, same blue lean — neutral/950 has almost no blue in it, confirmed too close to plain black live */
--bg          #0d0d16     /* neutral/900 */
--trough      #13131c     /* neutral/850 */
--sel         #1c1c24     /* neutral/800 — lightest */
--hairline    rgba(255,255,255,0.075)
--text        #fafafa     /* neutral/50 */
--text-muted  rgba(255,255,255,0.56)
--text-subtle rgba(255,255,255,0.44)
--text-faint  rgba(255,255,255,0.30)
--label-mono  rgba(255,255,255,0.48)

/* ── The two accents — one value, both appearances ─ */
--live   #130CEE   /* indigo/500. microphone is hot. Nothing else — ownable, not a system-red */
--up     #4ADE80   /* green/400. a delta improved. Overview only */
```

The neutral scale carries a deliberate blue tint (`--side`/`--sel`/`--trough` in
dark mode lean toward `#0d0d16`/`#1c1c24`/`#13131c` rather than pure grey,
and `--bg` in light mode is `#fafafa`, not `#ffffff`) — a pure neutral reads
as unconsidered. `--live` and `--up` are each one value now, not a
light/dark pair: a single ownable accent that doesn't shift character
between appearances.

### Elevation

Three layers, always: a wide soft ambient, a tight contact shadow, and a hairline
ring standing in for a border. That structure is what makes surfaces read as
material rather than as boxes.

```
/* window */
0 24px 70px 0 rgba(0,0,0,0.18), 0 6px 18px 0 rgba(0,0,0,0.10), 0 0 0 1px rgba(0,0,0,0.08)
/* capsule and popover — floating over unknown content, so more separation */
0 18px 50px 0 rgba(0,0,0,0.16), 0 4px 14px 0 rgba(0,0,0,0.09), 0 0 0 1px rgba(0,0,0,0.08)
/* dark: one ambient plus a light ring, since shadow alone cannot separate */
0 18px 50px 0 rgba(0,0,0,0.60), 0 0 0 1px rgba(255,255,255,0.09)
```

### Type

**Geist and Geist Mono** ([vercel.com/font](https://vercel.com/font)), self-hosted,
52 KB for the variable latin subset. Both are SIL Open Font License, so the same
files ship inside the app rather than falling back to a system substitute.

The mono earns its place. The timer needs tabular digits so the readout does not
jitter as it counts, and Geist Mono's slashed zero and open counters hold at 10
and 11 px, which is the entire size range the capsule lives in.

| Role | Size / line | Weight | Tracking | Used for |
| --- | --- | --- | --- | --- |
| Display | 27 / 30 | Semibold | −0.03em | Overview stat values |
| Title | 17 / 22 | Semibold | −0.02em | Window header |
| Subtitle | 15.5 / 20 | Semibold | −0.012em | Row headings |
| Body | 13.5 / 21 | Regular | 0 | Transcript text |
| Label | 11 / 14 | Medium | +0.01em | Capsule status |
| Meta | 10.5 / 14 | Regular, mono | +0.01em | Times, durations, paths |
| Section | 9.5 / 12 | Regular, mono | +0.09em, upper | Sidebar and section headers |

Mono uppercase with wide tracking is the app's structural voice: it marks
sections and metadata, and never carries a sentence.

### Space and radius

4pt base. Permitted: 4, 8, 10, 12, 14, 16, 20, 22, 24, 32, 40.

| Token | Value |
| --- | --- |
| `--r-capsule` | fully rounded, height ÷ 2 |
| `--r-window` | 14 |
| `--r-popover` | 13 |
| `--r-card` | 10 |
| `--r-control` | 8 to 9 |
| `--r-pill` | 48 (tabs, chips) |

---

## 4. The mark

**Caret** — an I-beam, `M5.6 2.6h4.8 M5.6 13.4h4.8 M8 2.6v10.8`, 1.7px stroke with
round caps on a 16 viewBox.

It is the most apt idea available: Harps puts text at a caret, so the mark is the
place the text lands. It is not a microphone, not a waveform, and not the generic
record circle.

**The known risk.** At 16px monochrome it can read as a text-tool cursor rather
than as an app. If that ambiguity ever bites in practice, the fallback is `arc`
(a dot with two arcs opening right), which was the alternative recommendation and
is already drawn in `prototype/capture-v2.html`.

The mark ships three ways, and only the first has to survive at 16px:

- **Menu bar** — 16px, template style, taking the menu bar's own colour, and
  `--live` for the full duration of a capture.
- **Sidebar and popover** — 14px reversed out of a rounded tile in `--text`.
- **App icon** — the full-size mark, out of scope until packaging.

The wordmark is **Harps** in Geist Semibold at −0.02em. One word, so no
two-weight split.

---

## 5. The capsule

Fully rounded, 44px tall, on `--bg` with the floating elevation above.

### Invocation decides the anchor

The capsule emerges from whatever summoned it, so the object always comes from
the thing you touched.

| Trigger | Anchor | Motion |
| --- | --- | --- |
| Hotkey | Bottom centre, 92px up | Rises from below |
| Menu bar | Under the item, 34px down, 14px from the right | Descends from above |

Fixed placement rather than following the caret. Caret position is not reliably
available across apps, and a capsule that lands in the wrong place is worse than
one that lands consistently.

### Two modes, and they are not the same interaction

A button cannot be held, so the menu bar means toggle — which can be left running,
the exact failure push-to-talk was chosen to avoid. The safeguards are the design,
not polish:

| | Hotkey | Menu bar |
| --- | --- | --- |
| Mode | Push-to-talk | Toggle |
| Width, listening | 248 | 286 |
| Stop | Release the key | Stop control, or the menu bar item again |
| Timer | Appears after 3s | Visible from the first tick |
| Menu bar icon | `--live` throughout | `--live` throughout |

The `--live` menu bar icon is the one signal that survives every window being
covered, which is why it is not optional in either mode.

### States

**Dormant.** Nothing on screen.

**Listening.** Record dot in `--live`, 6px, 20px from the left edge, solid and
never pulsing — a pulse would be decoration competing with the waveform. Waveform
centred, 148px, 30 bars. Timer right-aligned in Meta type. In toggle mode, a 32px
round stop control at the right edge.

**Transcribing.** Contracts to 176. The dot goes neutral and the centre becomes a
shimmering `Transcribing` label. No spinner, and no progress bar that would have
to invent a percentage.

**Inserted.** No visual state. The capsule leaves; the text appearing is the
confirmation.

**Error.** Sized to the message, maximum 320. The capsule shakes once, holds three
seconds, and dismisses.

In every state that drops the timer, the centre box carries a mirrored 18px right
margin matching the dot and its gap, or the label sits visibly right of centre.

### Error copy

The only sentences this interface ever writes.

| Condition | Message |
| --- | --- |
| Secure input active | `Can't type into a password field` |
| No speech detected | `Didn't catch anything` |
| Microphone unavailable | `No microphone` |
| Accessibility not granted | `Needs Accessibility access` |
| Transcription failed | `Couldn't transcribe that` |
| Insertion failed | `Copied to clipboard instead` |

Each under six words, describing the situation rather than assigning blame. The
last one matters most: when insertion fails the text is never lost, it goes to the
clipboard, and the message says so.

---

## 6. The menu bar popover

300px wide, `--r-popover`, anchored under the item with its transform origin at
the top right. The discoverable path — the hotkey needs none of this, which is
why it does not have it.

Contents, in order: the mark on a tile with the wordmark and the hotkey in Meta
type; a full-width record button with a `--live` bulb; three recent captures as
time, app and one clamped line; a hairline footer with **Open window** and
**Settings**.

While a capture is running the popover does not open — the menu bar item becomes
the stop instead.

---

## 7. The window

1140 × 720 default, `--r-window`, remembers size and position.

### Sidebar, 236px

On `--side`. The mark and wordmark at the top, then three destinations, then the
days.

**Three destinations, not eight.** Overview, Transcripts, Settings. The reference
this borrows from is a platform with eight; padding the list to match its density
would be borrowing the look without the substance.

Selected rows take a `--sel` pill at `--r-control` with the label in `--text` at
Medium and the icon at full opacity; everything else sits at `--text-muted` with
icons at 62%.

Below a `RECENT` section header, the days, each with a `→` prefix, the day name,
and a **⌘1–⌘9 shortcut in Meta type**, right-aligned. Sidebar width contracts to
150 in the Document layout, since the day list is all it needs to carry there.

A hairline footer carries the current file path and a settings gear.

### Overview

Four stat blocks in a row, separated by hairlines rather than made into cards.
Each is a small `--text-subtle` label, a Display numeral, then a delta line: an
arrow and percentage in `--up`, then the comparison in `--text-faint`.

Below, one chart on its own hairline-bounded band: captures per day, this week
solid and last week dashed. The two series are **one measure across consecutive
periods**, so they separate by lightness and dash pattern rather than hue. There
is no categorical palette, the distinction survives any colour vision, and the
legend plus a hover crosshair and tooltip carry the rest.

Then `RECENT CAPTURES` and the four most recent cards.

### Transcripts

A sliding pill tab switches two layouts over the same data.

**Library** is built for finding a thing: cards carrying time, destination app,
duration and word count, body clamped to two lines, expanding in place on click.
A dictated sentence is too short to deserve a detail pane.

**Document** is built for reading a day back: the whole day set in Geist Mono at a
700px measure, frontmatter shown as frontmatter, and the `##` markers left visible
but dimmed to `--text-faint`. It should be obvious you are looking at a file.

Search filters every day at once and groups the hits, in both layouts, focused by
⌘F. Matches highlight in a warm translucent mark.

### The `.md` panel

360px, slides in from the right, shows the real file behind whatever is on screen
with the frontmatter dimmed and the `##` headings in `--text`. Its header carries
the filename and byte count.

### Settings

Label, one-line explanation, and a control. Rows separated by hairlines.
Hotkey, model, insertion strategy, keep audio, launch at login, transcript folder.

Two rows carry the app's promises and should read as statements rather than
options: **Runs on device. Nothing leaves this Mac.** and **Off by default. Audio
has no use after transcription.** Where a model that leaves the machine can be
chosen, that row says so where it is chosen — see `PLAN.md`.

---

## 8. Accessibility

- **Reduce Transparency.** Drop the capsule's backdrop blur for `--bg` solid and
  raise `--hairline` to 12% so the shape stays defined over a busy desktop.
- **Increase Contrast.** `--text-muted` to `--text`, `--text-subtle` up one step,
  a full 1px border on the capsule and popover.
- **Reduce Motion.** In `motion.md`, with full functional parity.
- **Contrast.** `--text` and `--text-muted` clear 4.5:1 on `--bg` in both
  appearances. `--text-faint` is decorative and never carries meaning alone.
  `--live` and `--up` clear 3:1, the bar for a non-text indicator.
- **Colour is never the only signal.** `--up` always ships with an arrow and a
  comparison label. `--live` is reinforced by the waveform being live and by the
  capsule's silhouette. Listening and transcribing differ in width, not just hue.
- **VoiceOver.** The capsule announces state changes through a live region. The
  window is a standard accessible list and form.
- **Keyboard.** The window is fully operable without a mouse: ⌘F to search,
  ⌘1–⌘9 for days, tab order through the sidebar. The capsule has no controls in
  push-to-talk by design, and one reachable stop in toggle.

---

## 9. What this deliberately does not have

No logo in the capsule. No settings gear on the overlay. No waveform when there is
no audio. No progress bar with an invented percentage. No success checkmark. No
onboarding tooltips over other people's apps. No sound. No badge counts. No theme
picker — the system decides.

Every one of these is common in this category, and every one makes the object
heavier than what it does.
