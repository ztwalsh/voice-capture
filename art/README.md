# art

Code-based pieces. Each folder is a self-contained page: open `index.html`
directly or serve the folder with any static server.

| Piece | What it is |
|-------|------------|
| [`aperture/`](aperture/) | Two nested latitude/longitude lattices of points, turning against each other, with a rectangular cut that travels over the outer shell and reveals the inner one. Rendered to a texture and pushed through the Serenity CRT shader used on the ztwalsh.com explorations. |

## aperture

Controls:

- **drag / swipe** turns the object; it keeps its momentum
- **invert** (or `I`) flips black-on-white / white-on-black through a TV power cycle
- **space** pauses
- `?theme=light` opens inverted and skips the power-on
- `?crt=off` shows the raw points with no tube

How it is built (`aperture/index.html`, no dependencies beyond Geist Mono
from Google Fonts):

1. Two static point buffers, one per shell, hold only latitude, azimuth and
   a shell id. Everything that moves is computed in the vertex shader from a
   handful of uniforms per frame, so the 21,760 points cost one draw call.
2. The cut is a rectangular slot through the front of the shell: on each
   ring the removed arc is the one whose chord is narrower than the slot, so
   rings narrower than the slot lose their whole front half. The slot tracks
   the viewer and swings side to side, so the lattice streams through it and
   its profile shows at the extremes.
3. Inner-shell points look up the outer-shell point in front of them and
   only light fully where that point was cut away, so the inner shell reads
   as something glimpsed through a window rather than a second sphere.
4. The scene renders into a texture over a partially faded copy of the last
   frame (phosphor persistence), then a full-screen pass applies Matt
   Sephton's Serenity CRT shader (MIT, https://github.com/gingerbeardman/webgl-crt-shader)
   with the `uPower` collapse and edge colour additions from the website
   explorations, plus a caption overlay texture so the text rides the tube too.
