# MoveThink — landing page options

Four directions for the MoveThink landing page, each a standalone HTML file with
inline CSS and JS. Type is Geist / Geist Mono from Google Fonts (Option C adds
Bricolage Grotesque), so serve the folder rather than opening files from Finder:

```bash
python3 -m http.server 8000
# then http://127.0.0.1:8000/landing/
```

| File | Direction | What makes it different |
| --- | --- | --- |
| `aurora.html` | A · Aurora | Closest to the reference. Warm canvas, centred headline, gradient-mesh showcase with four icon tabs that recolour the mesh and advance as you scroll (sticky story on wide screens, auto-rotating on phones), then a four-step section. |
| `studio.html` | B · Studio | Dark-first, drawn from `design.md`'s tokens. The hero is a working demo: hold Space or press the capsule to "record", release to see text typed at the caret. Features are a measured spec sheet. |
| `paper.html` | C · Paper | The page is a day file. Ruled paper, `#`/`##` markers left visible, the Markdown file as the hero object, sections stamped with times and apps. Display face is Bricolage Grotesque. |
| `kinetic.html` | D · Kinetic | Electric indigo hero, very large type, a stage where dictated sentences type themselves into Slack, Xcode, Notes and Messages in turn, then a bento grid. |

All four support light and dark, work at phone width, and respect
`prefers-reduced-motion`. Copy is drawn from the app as it exists in `app/`
(hold-to-record or tap-to-toggle hotkey, on-device SpeechAnalyzer, one Markdown
file per day, Transforms, retention, the eight target apps and the PLAN.md
latency targets).
