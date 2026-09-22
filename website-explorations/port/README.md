# Port to ztwalsh.com-new

`0001-crt-broadcast.patch` is one commit against `ztwalsh/ztwalsh.com-new`
at `bc563a3` (main on 2026-09-22). It rebuilds the site as the Broadcast
exploration: monochrome Geist through the CRT shader, invert control,
contact page with red error state. `npm run lint` and `npm run build` pass
(the build needs `RESEND_API_KEY` set, as it always has).

Apply it from a checkout of ztwalsh.com-new:

```bash
git checkout -b crt-broadcast origin/main
git am path/to/0001-crt-broadcast.patch
npm ci
npm run dev
```

`crt-broadcast.bundle` holds the same commit as a git bundle:
`git fetch path/to/crt-broadcast.bundle crt-broadcast:crt-broadcast`.

What the commit changes:

- `src/lib/crt.js` — the engine as an ES module (same code as `../crt.js`)
- `src/lib/crt.d.ts` — types for it
- `src/components/CRT.tsx` — client component that mounts the engine over `#page`
- `src/components/InvertButton.tsx` — dispatches `crt:toggle`
- `src/app/layout.tsx` — Geist only, `#page` wrapper, theme applied before first paint
- `src/app/page.tsx`, `src/app/contact/page.tsx`, `src/app/globals.css` — Broadcast markup and styles
- removes `Header.tsx`, Inria Serif and the Hugeicons dependencies
