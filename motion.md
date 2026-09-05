# Voice Capture — Motion Principles

> **Same note as `design.md`.** The Threads reference was unreachable from this
> environment, so this is a direction reasoned from the product rather than
> derived from that post. Send me the reference and I will reconcile it. The
> numbered specs are the layer to change; the principles should survive most
> aesthetic shifts, because they follow from what the app does.

---

## The premise

Motion in this app carries almost the entire status channel. There is no text
explaining what is happening, because the whole point is that you are not
looking at it. Whether it is hearing you, working, or finished has to be
readable in peripheral vision, in a shape that changes.

That raises the standard. Motion here is not decoration that can be tuned down
later. It is the interface.

---

## Six principles

### 1. It emerges, it does not enter

Nothing slides in from an edge, drops from above, or travels across the screen.
The capsule appears where it will live, at 92% scale, and settles. Travel
implies the object came from somewhere and has a home elsewhere. This object has
no elsewhere. It exists for four seconds in the place you are already looking.

### 2. Motion tracks the voice, not the clock

The waveform is driven by measured audio amplitude, never by a timer. This is
the difference between an interface that is listening and one that is
pretending. When you stop talking, it goes flat — not to an idle shimmer, flat.
Silence should look like silence.

The corollary: **your voice draws the line.** The only free-running animation in
the listening state is the one you are personally causing.

### 3. One object, transformed

There are no cross-fades between states, because there are no separate views to
cross-fade. The capsule changes width, and its contents change. You should be
able to watch the whole session and never see two objects on screen at once.

This is what makes peripheral reading work. You learn one silhouette, and its
proportions tell you where you are.

### 4. Leaving is faster than arriving

Entry gets a spring, around 240ms to settle. Exit gets 120ms of straight
acceleration and no spring at all. Getting out of the way is the feature, and an
exit that lingers is the app asking for a moment of your attention on the way
out. It should feel like it was already gone before you noticed.

### 5. Nothing loops unless work is genuinely happening

There is exactly one looping animation in the app: the sweep across the frozen
waveform while transcription runs. It is justified because work really is
ongoing and its duration really is unknown. Every other looping animation —
breathing glows, pulsing dots, idle shimmer — is the interface performing
liveness it does not have.

The sweep also carries information a spinner cannot: it passes over a frozen
picture of the audio you just recorded, so you can see *what* it is working on.

### 6. The inserted text never animates

The moment the transcript lands in your app, it appears. No fade, no typewriter,
no highlight flash. This is the one place where the app touches your actual
work, and any animation there puts the app between you and your sentence.

---

## Specifications

### Named springs

| Name | Use | SwiftUI | CSS approximation |
| --- | --- | --- | --- |
| `snap` | Appearance, shape changes | `.spring(response: 0.24, dampingFraction: 0.86)` | `cubic-bezier(0.22, 1, 0.36, 1)`, 240ms |
| `settle` | Capsule width morph | `.spring(response: 0.36, dampingFraction: 0.75)` | `cubic-bezier(0.34, 1.4, 0.5, 1)`, 360ms |
| `glide` | Anything that must not attract the eye | `.spring(response: 0.5, dampingFraction: 1.0)` | `cubic-bezier(0.4, 0, 0.2, 1)`, 420ms |

In CSS, a generated `linear()` easing from the same spring constants is more
faithful than these bezier approximations and is worth using in the prototype,
since the prototype is where the feel gets signed off.

### Non-spring durations

For opacity and color only, which should never overshoot.

| Token | Duration | Easing |
| --- | --- | --- |
| `instant` | 80ms | linear |
| `quick` | 140ms | `cubic-bezier(0.32, 0.72, 0, 1)` in, `cubic-bezier(0.4, 0, 1, 1)` out |
| `base` | 200ms | same |
| `exit` | 120ms | `cubic-bezier(0.4, 0, 1, 1)` |

### Transitions

**Dormant → Listening.** Scale 0.92 → 1.0 and translateY +8 → 0 on `snap`.
Opacity 0 → 1 over `quick`. The 32 waveform bars stagger up from the center
outward, 8ms per mirrored pair, total 128ms — the shape wakes from the middle
rather than appearing whole.

Budget: first frame within **120ms** of key-down, fully settled by 240ms. This
has an implementation consequence. The panel must be created and warmed
offscreen at launch, because allocating a window on the hot path will cost more
than the entire budget.

**Listening.** Only the waveform moves. The tally dot is solid and static. The
elapsed timer fades in at `quick` once three seconds have passed.

**Listening → Transcribing.** Width 240 → 132 on `settle`, which is the one
place a small overshoot is wanted, because the shape change is the state change
and it should register. Concurrently, over `quick`: the waveform freezes on its
last frame and desaturates to `--text-tertiary`, and the tally dot fades out.
The sweep starts only after the width has settled — motion in sequence, not
piled on top of itself.

**The sweep.** A soft 40px-wide highlight at 24% white travels left to right
across the frozen waveform. 1200ms per pass, linear, looping, with an 80ms gap
between passes. Linear on purpose: eased motion here would read as organic, and
this is a machine working.

**Transcribing → Dormant.** Opacity 1 → 0 and scale 1.0 → 0.96 over `exit`. No
spring. Total 120ms.

**Any → Error.** Width morphs on `settle` to fit the message. The tally dot
cross-fades to `--negative` over `quick`. The message text fades in over `quick`
delayed by 60ms, so the container arrives before the content.

**Error → Dormant.** Same as the success exit but over 200ms. Slightly slower,
because an error is worth registering as it ends.

### The waveform

The most important spec in the app, since it is the thing you actually watch.

**Sampling.** RMS over 20ms windows, delivered at 50 Hz.

**Normalization.** Convert RMS to dB, clamp to a −50 dB floor and −6 dB
ceiling, and map that range to 0…1. Absolute amplitude is useless here; the
range that matters is the range of a human speaking a few feet from a laptop.

**Asymmetric smoothing.** This is what separates a waveform that feels alive
from one that feels like a graph.

```
value += (target - value) * (target > value ? 0.60 : 0.12)
```

Fast attack so consonants punch through. Slow release so the display does not
strobe between syllables. The asymmetry is the entire trick, and getting the two
coefficients right is worth an afternoon in the prototype.

**Height.** `height = 3 + pow(value, 0.7) * 21`, giving the 3px to 24px range
from `design.md`. The 0.7 exponent lifts quiet speech into visibility, since
normal talking sits low in the range and a linear map makes it look like the app
is barely hearing you.

**Color.** Linearly interpolate `--text-secondary` → `--accent` across the same
0…1. Loudness becomes warmth.

**History.** The bar array shifts one position per sample. 32 bars at 50 Hz is
640ms of visible history, which is roughly a phrase — long enough to show the
shape of what you said, short enough to feel immediate.

**Silence.** Flat at 3px. No jitter, no floor animation, no idle life. Per
principle 2, and it is also the clearest possible signal that the microphone is
not picking you up.

---

## Reduce Motion

Full functional parity, not a degraded experience. Everything that motion
communicates must still be communicated.

| Element | Reduce Motion behavior |
| --- | --- |
| Appearance and exit | Opacity only, 100ms. No scale, no translate. |
| Width morph | Instant. The silhouette still changes, it just does not travel. |
| Bar stagger | Removed. Bars appear at their current heights. |
| Sweep | Replaced by a static `Transcribing` label in Label type. Text instead of motion. |
| Waveform | Kept, with the horizontal scroll removed. Bars change height in place rather than shifting, so nothing translates. |

The waveform survives because Reduce Motion targets large-scale movement that
provokes vestibular discomfort, not small in-place data display — and because it
is the only feedback that the microphone is working. Removing it would make the
app unusable rather than calmer.

---

## Performance rules

Motion this central has to be cheap, or it becomes the thing that makes the app
feel bad.

- Render the waveform on a display-link-driven canvas, not by pushing SwiftUI
  state 50 times a second. State churn at that rate will drop frames.
- Animate only `transform` and `opacity` in the HTML prototype. No layout
  properties, no `filter` transitions, no animated `backdrop-filter`. Animating
  the blur is the single most expensive mistake available here.
- The audio engine, the panel, and the model all warm at launch, not on
  key-down. Everything on the hot path between the hotkey and the first frame
  must already exist.
- If a frame budget has to be missed, miss it during transcribing, never during
  listening. The listening state is the one under direct observation.
