# ztwalsh.com — CRT explorations

Five layouts of the same content (name, one line, the experiments list), each
rendered through a WebGL CRT shader. Every page flips between black-on-white
and white-on-black with the **invert** control, using a TV power-off/on
collapse. Geist throughout, loaded from Google Fonts.

| # | Page | Idea |
|---|------|------|
| 01 | `01-broadcast.html` | The current site's structure, monochrome, through the tube. The control. |
| 02 | `02-index.html` | A teletext page: header strip, page number, live clock, numbered rows. |
| 03 | `03-signal.html` | The page types itself in behind a blinking block cursor. |
| 04 | `04-channel.html` | A TV on-screen menu. Arrow keys / hover move the highlight; the caption follows. |
| 05 | `05-set.html` | The page inside a physical set: bezel, glass, brand plate, power LED. |

`index.html` links to all of them in both themes.

## Run

Any static server from this folder:

```bash
npx serve .            # or: python3 -m http.server 8000
```

Controls on every page:

- **invert** (in the page) — switch black/white with the power animation
- **T** — toggle the shader tuning panel (sliders for every parameter, "copy params" to grab a preset)
- `?theme=light` / `?theme=dark` — open in a given theme, skipping the power-on
- `?crt=off` — show the plain DOM underneath
- `?tune=1` — open with the panel showing

## How the treatment works (`crt.js`)

The shader needs a texture, and a web page is not a texture. Rather than
draw the whole site with canvas calls (and lose links, focus, selection and
screen readers), the engine keeps the real DOM in place and mirrors it:

1. The content root (`#page`) stays in the document but is made invisible
   with `opacity: 0`. Links, hover, keyboard focus and assistive tech all
   keep working on the real elements.
2. On every change (resize, scroll, hover, focus, DOM mutation) the engine
   walks the root, asks the browser where each word and box landed
   (`Range.getClientRects`, `getBoundingClientRect`, computed styles) and
   paints the same thing onto a 2D canvas with the same fonts and colours.
   Each word is fitted to the width the browser gave it, so canvas and DOM
   never drift.
3. That canvas is uploaded as a texture and drawn through the fragment
   shader every frame.

The shader is Matt Sephton's *Serenity* WebGL CRT shader (MIT),
https://github.com/gingerbeardman/webgl-crt-shader, with three changes:

- `uPower` — squashes the image to a line, then a dot, for the power animation
- `uEdge` — colour outside the curved tube (black)
- RGB shift fringes only at edges instead of tinting flat areas, so white
  pages do not go magenta

Per-theme parameter presets live in `DEFAULTS` and `LIGHT_ADJUST`; each page
passes its own overrides to `CRT.mount()`.

## Caveats

- **Curvature moves pixels, hit targets do not.** At curvature 0.1 the drawn
  text is a few pixels from its real position near the screen edges. Content
  is kept away from the edges so it does not matter in practice; a real build
  could inverse-map pointer events.
- **Text selection is invisible** (the DOM is transparent). It still works.
- Only text, solid backgrounds, uniform borders, underlines and `<img>` are
  mirrored. Gradients, shadows, SVG and transforms are not.
- Without WebGL2 the page falls back to the plain DOM.
- Scanline count defaults to one line per 3 CSS px of viewport height, so the
  effect scales with the window. Match it to the tube you want.
- No analytics or contact form are wired up; the contact link points at the
  live site's `/contact` page.
