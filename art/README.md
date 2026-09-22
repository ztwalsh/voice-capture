# art

Code-based pieces. Each folder is a self-contained page: open `index.html`
directly or serve the folder with any static server.

| Piece | What it is |
|-------|------------|
| [`solid-state/`](solid-state/) | One lattice of points cycling sphere to cube to pyramid and back, holding on each solid. Every point slides along a fixed ray from the centre, so the lattice is pushed out to whichever surface that ray hits and never tears. |
| [`aperture/`](aperture/) | Two nested latitude/longitude lattices of points, turning against each other, with a rectangular cut that travels over the outer shell and reveals the inner one. |

Both are rendered to a texture and pushed through the Serenity CRT shader used
on the ztwalsh.com explorations, and both share the same controls:

- **drag / swipe** turns the object; it keeps its momentum
- **invert** (or `I`) flips black-on-white / white-on-black through a TV power cycle
- **space** pauses
- `?theme=light` opens inverted and skips the power-on
- `?crt=off` shows the raw points with no tube

## solid-state

Sphere, cube, square pyramid, then back to the sphere, resting 2.4s on each
solid and taking 3.2s to travel between them.

1. Each of the 21,632 points is stored as nothing but a direction: a
   latitude and an azimuth. Only the radius changes, so points slide along
   their own ray and the lattice never tears or crosses itself.
2. The cube and the pyramid are each described as a set of planes around the
   origin. For a ray leaving the centre, the surface it hits is the nearest
   plane it crosses, so one loop in the vertex shader gives both the radius
   and, from how close the two nearest planes come to agreeing, how near the
   point sits to an edge or a corner. Edges and corners light up; the sphere
   reports no edges at all.
3. A morph is the same ray measured against two solids, mixed with a
   smootherstep. Halfway between sphere and cube you get a rounded cube,
   which is a real surface rather than a cross-fade.
4. Each solid is sized by its silhouette rather than its face distance, so
   the object changes form without appearing to change mass.
5. The tube is flat: the shader's curvature is set to 0, so the screen does
   not warp and the image reaches the frame edges. Scanlines, bloom, vignette,
   flicker and the power collapse all still apply.
6. The invert control is painted into the tube like everything else, so its
   real hit target is placed by `apparent()`, which reports where a painted
   point lands on screen. With a curved tube that differed from where the
   browser put the button by enough to miss it near a corner; flat, it is the
   identity, and it stays so the control survives turning curvature back up.

## aperture

## aperture

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
