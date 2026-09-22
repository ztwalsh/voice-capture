# art

Code-based pieces. Each folder is a self-contained page: open `index.html`
directly or serve the folder with any static server.

| Piece | What it is |
|-------|------------|
| [`solid-state/`](solid-state/) | One lattice of points cycling sphere to cube to pyramid and back, holding on each solid. Every point slides along a fixed ray from the centre, so the lattice is pushed out to whichever surface that ray hits and never tears. |
| [`aperture/`](aperture/) | Two nested latitude/longitude lattices of points, turning against each other, with a rectangular cut that travels over the outer shell and reveals the inner one. |

Both are rendered to a texture and pushed through the Serenity CRT shader used
on the ztwalsh.com explorations. Drag or swipe to turn either one; it keeps its
momentum.

## solid-state

Sphere, cube, square pyramid, then back to the sphere, resting 2.4s on each
solid and taking 3.2s to travel between them. The panel opens the piece up:

| Group | Controls |
|-------|----------|
| Form | shape (cycle, or pin one solid), zoom, dot size, density, uniformity, spin |
| Colour | six phosphor presets, ink and ground pickers, swap |
| Tube | scanlines, bloom, curve, trails |
| Export | captions on screen, save PNG |

Settings persist per browser. `Space` pauses, `I` swaps ink and ground through
the power cycle, `H` clears the panel and captions for an unobstructed view.
`?crt=off` shows the raw points with no tube.

**Save PNG** writes what the tube is showing at that moment, the shape and the
ground only, with no captions and no panel: the frame is redrawn once with the
caption texture swapped for a blank one, then read straight back out of the
drawing buffer. Published as an Artifact it hands the file over through the
`downloads` capability, since that sandbox makes an ordinary download link
inert; opened as a local file it falls back to one.

How it is built:

1. Each point is stored as nothing but a direction, a latitude and an azimuth,
   plus two fixed random numbers. Only the radius changes, so points slide
   along their own ray and the lattice never tears or crosses itself.
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
5. Uniformity spends those two random numbers: each point wanders that
   fraction of a lattice cell, so the slider dissolves the grid live without
   rebuilding anything. Density does rebuild the buffer, from 2k to 55k points.
6. Brightness, contrast and colour fringing follow the ground's luminance
   rather than a theme flag, so a pale ground does not clip.

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
