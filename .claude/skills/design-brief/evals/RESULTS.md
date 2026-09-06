# design-brief — iteration 1

Three prompts, each run with the skill and without it. Fixtures are real product
screenshots in `fixtures/`.

## What happened

| Eval | With skill | Without skill |
| --- | --- | --- |
| 0 · explicit review request | HTML page, 4 images inlined, **4 settled / 5 open, 3 costs named** | HTML page, 4 images inlined, **0 settled / 0 open, 0 costs** |
| 1 · implicit recap | HTML page, 3 images inlined, 6 settled / 5 open, 5 costs | Prose markdown answer |
| 2 · near-miss single question | Prose answer, **no brief built** | Prose answer, no brief built |

Both pages defined light and dark at token level and inlined every image. No run
exceeded 400 KB.

## What the numbers actually say

**The skill does not change whether a page gets built. It changes what is on it.**
Asked outright to compile screenshots, a baseline agent already produces a
respectable HTML gallery — same images, same size, both themes. What it does not
produce is a decisions section: zero settled items, zero open items, zero named
costs. The reader gets something to look at and nothing to answer. That gap is
the whole reason the format exists, and it is the one thing the skill reliably
adds.

**The pushy description earns its keep on eval 1.** "can you summarise… i want to
look back at it later" reads like a request for prose, and the baseline gave
prose. The skill recognised that a durable, returnable page was the better answer
to *look back at it later* and built one, adding a decisions list the user never
asked for. That is the case the description was written to catch.

**No over-triggering.** On the near-miss the with-skill agent read the scoping
section, quoted its "a sentence, not a page" line, and deliberately declined.
Worth keeping: the section that stops the skill firing is doing as much work as
the description that starts it.

**The bundled template pays for itself.** The eval 0 baseline wrote its own 30 KB
page template from scratch before it could start. That is reinvented work on
every invocation, and it is why the template ships with the skill rather than
being described in prose.

## Not run

Eval 0's baseline hit a session rate limit partway through. It had already
written its page, so the comparison above holds, but it never self-reviewed —
treat its output as slightly less polished than a completed run would be.

## Next iteration

Nothing here justifies a rewrite. If the skill is revisited, the question worth
testing is whether the decisions section holds up when the work has **no** open
questions left — a brief that manufactures uncertainty to fill the template would
be worse than one that says the work is done.

## Reproducing

Run each prompt in `evals.json` twice, once pointing at
`.claude/skills/design-brief` and once with no skill, then check: images inlined
rather than linked, both themes defined at token level, and — the one that
matters — whether settled and open are actually separated.
