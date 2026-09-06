---
name: design-brief
description: Build a design review brief — annotated screenshots grouped into sections, plus a settled-versus-open decisions list — and publish it as an Artifact for sign-off. Use this whenever work needs to be put in front of someone to approve, compare, or react to: "compile the screenshots", "put together a review", "I want to make sure I'm approving the right things", "show me all the versions", "write this up so I can look at it", "can I see everything in one place", a design or spec walkthrough, a decision memo, or a progress recap at the end of a run of prototypes. Reach for it even when the person only asks to "collect" or "summarise" what was built — the value is the decisions list, and they usually do not know to ask for it.
---

# Design brief

A brief is not a gallery. Screenshots show what was built; the brief exists to
tell someone **what they are being asked to approve, and what is still open.**
If you strip the decisions section out you have a slideshow, and the reader will
nod at it without ever making a decision — which is the failure this format
exists to prevent.

Publish it as an Artifact. A brief that lives in terminal scrollback cannot be
returned to, and this is exactly the kind of thing someone reopens a week later.

## When it is worth building

The trigger is that **a decision is pending**, not that screenshots exist. A
brief earns its cost when someone has to choose between directions, sign off
before you commit to something expensive, or catch up on a run of work they were
not watching. A single change with no open question needs a sentence, not a page.

## Build it

### 1. Take the shots

Full states, not crops, unless the point is a detail. Capture both light and dark
where the work supports both — showing one and claiming the other works is the
most common way a brief overstates what is finished.

Drive the page with Playwright rather than hand-cropping, so the states are real
and reproducible:

```js
await page.locator('#someControl').click();
await page.waitForTimeout(600);            // let transitions settle
await page.screenshot({ path: out, clip: box });
```

Give it `deviceScaleFactor: 2` or `3`. The downscale below reads better from a
retina source than from a 1x one.

### 2. Encode them

Artifacts cannot load external images, so every figure is inlined. Raw retina
PNGs will blow past the 16MB page limit, so use the bundled script:

```bash
node scripts/shots-to-datauri.mjs manifest.json images.json
```

`manifest.json` is `[{ "key": "app-overview", "path": "/abs/shot.png", "width": 1500 }]`.
The key fills an `{{img:key}}` slot in the template. Prose placeholders are
plain `{{...}}` and are left alone, so draft copy is never mistaken for a
missing figure. Use 1500 for a full window, 1300 for a
detail. The script prints a total — keep it under about 12MB.

### 3. Write it

Start from `assets/template.html`, which carries the finished page: tokens for
both themes, the figure and decision components, and the type scale. It holds one
example of each component so you fill in rather than delete.

```bash
node scripts/build.mjs assets/template.html images.json "Page Title" out.html
```

`build.mjs` fails loudly on any unfilled figure, because a missing image in a
review brief is worse than no brief — the reader assumes they have seen
everything.

### 4. Look once, then publish

Render the file and look at it a single time before publishing — check for
clipped figures, broken images, and text that collides. Then publish with the
Artifact tool and hand over the link. The live page is the review surface; do not
build a screenshot loop around your own file.

## What makes the writing work

**Every figure makes a claim.** The caption says what decision the figure shows
and why it went that way, not what is visible in it. "Overview in dark mode" is a
filename. "Big numerals over small labels, green only on deltas, never alone" is
a caption. If a figure has nothing to argue, it is probably not worth a figure.

**Split settled from open, and be honest about which is which.** Settled means
built and consistent — the reader is confirming, not choosing. Open means it
changes the work and you genuinely need an answer. Filing something as settled to
avoid a conversation is how briefs stop being trusted.

**Name the cost of settled decisions.** A settled list where nothing has a
downside reads as salesmanship and invites the reader to skim. The `<em>The
cost:</em>` line is where the tradeoff goes, and it is what makes the rest
credible.

**Recommend, do not survey.** Every open item should say which way you would go
and what would tip it. A brief that lists options without a view pushes the whole
decision back onto the reader, who has less context than you.

**Close with the one thing that unblocks you.** The `.note` callout at the end
names what is waiting on their answer and what you will do the moment you have
it. That is what turns a document into a decision.

## The visual system

Deliberately quiet — the screenshots are the loud part, and a brief that competes
with its own figures is working against itself.

- **Type**: Geist for prose, Geist Mono for labels, metadata and section markers.
  Mono uppercase with wide tracking is the structural voice; it marks and never
  narrates.
- **Colour**: near-white and near-black grounds with a slight cool bias in the
  greys. Green and amber appear only on the settled and open chips; red only on
  the closing callout's rule.
- **Figures** sit full width on a soft three-layer shadow. `class="shot plain"`
  swaps that for a hairline ring, for images that already have their own frame.
- **Both themes** are defined at token level in the bare `:root`, then redefined
  under `prefers-color-scheme` and `[data-theme]`, so the page holds in all three
  viewer states.

When the subject has its own design system, borrow it — building the brief out of
the thing it reviews makes the page feel like part of the work rather than a
wrapper around it. That is what the bundled template does: its tokens and faces
are the reviewed app's own.

## Files

| Path | What it is |
| --- | --- |
| `assets/template.html` | The page — tokens, components, one example of each |
| `scripts/shots-to-datauri.mjs` | Downscale and inline the screenshots |
| `scripts/build.mjs` | Substitute images and title, fail on anything missing |
