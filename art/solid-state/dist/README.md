# Solid State

A lattice of points cycling sphere → cube → square pyramid and back, drawn
through a CRT shader. Drag to turn it, open the panel to retune it, save a PNG
of whatever it is doing.

Four files, no build step, no dependencies, and no outside requests: the font
ships in the folder. Anything that can serve a static file can serve this.

```
solid-state/
├── index.html         the piece, self-contained
├── geist-mono.woff2   the one typeface it uses
├── preview.png        1200×630 share image
└── README.md          this file
```

## Install

**Next.js** (app or pages router) — copy the folder into `public/`:

```
public/solid-state/
```

It is then live at `/solid-state/`. Link to it with the trailing slash. A host
that does not resolve directory indexes wants `/solid-state/index.html`
instead; both work on Vercel.

**Astro, SvelteKit, Vite** — same idea, into `public/` or `static/`.
**Jekyll, Hugo, plain Apache or nginx, GitHub Pages, Netlify** — drop the
folder at the web root.

Nothing here is framework-aware, so it does not matter which you use.

## Embed it in a page

The piece fills whatever box it is given, so an iframe works:

```html
<iframe src="/solid-state/" title="Solid State"
        style="width:100%;aspect-ratio:16/10;border:0;display:block"
        loading="lazy"></iframe>
```

Add `?crt=off` for the raw points with no tube, or `?theme=light` to open it
on a pale ground.

## Configure

Near the top of the script in `index.html`:

```js
const HOME_URL   = '/';        // where the panel's back link goes
const HOME_LABEL = '← back';   // what it says; HOME_URL = '' removes it
```

The opening state lives in the `BASE` object just below, and the six colour
presets in `PRESETS` above it. A visitor's own changes are saved to their
browser under the key `solid-state`, so editing `BASE` changes what a new
visitor sees, not what a returning one does.

The share image is referenced as `/solid-state/preview.png`. If the folder
lands anywhere else, or a crawler insists on an absolute URL, edit the
`og:image` meta tag.

## Controls

| | |
|---|---|
| Drag or swipe | turn it; it keeps its momentum |
| Panel | shape, zoom, dot size, density, uniformity, spin, colour, tube |
| `Space` | pause |
| `I` | swap ink and ground, through a TV power cycle |
| `H` | hide the panel and captions for a clean view |
| Save PNG | the shape and the ground only, no captions, no panel |

## Notes

It needs WebGL2, which every current browser has; anything older gets a line
of text instead of a blank page. A visitor who asks their system for reduced
motion gets a still sphere on arrival, with the controls still there.

The CRT treatment is Matt Sephton's Serenity shader (MIT,
https://github.com/gingerbeardman/webgl-crt-shader), with a power-collapse and
an edge colour added. Curvature is off, so the screen does not warp; the
panel's Curve slider turns it back on.
