/**
 * Downscale screenshots and encode them as JPEG data URIs for an Artifact.
 *
 * Artifacts cannot load external images, so every figure has to be inlined.
 * Raw retina PNGs are far too heavy for that — a dozen of them will blow past
 * the 16MB page limit — so this resamples through a canvas and re-encodes.
 * Typical result is 100–150 KB per figure, about an eighth of the PNG.
 *
 *   node shots-to-datauri.mjs manifest.json out.json
 *
 * manifest.json: [{ "key": "app-overview", "path": "/abs/shot.png", "width": 1500 }]
 *   key    — the {{placeholder}} it fills in the template
 *   width  — max CSS pixels; 1500 is right for a full window, 1300 for a detail
 *
 * out.json: { "app-overview": "data:image/jpeg;base64,..." }
 */
import fs from 'fs';
import { createRequire } from 'module';

// require() honours NODE_PATH; a bare ESM import does not, and playwright is
// often only installed globally.
const require = createRequire(import.meta.url);
const { chromium } = require('playwright');

const [manifestPath, outPath] = process.argv.slice(2);
if (!manifestPath || !outPath) {
  console.error('usage: node shots-to-datauri.mjs <manifest.json> <out.json>');
  process.exit(1);
}
const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));

const browser = await chromium.launch();
const page = await browser.newPage();
const out = {};

for (const { key, path, width = 1500, quality = 0.82 } of manifest) {
  if (!fs.existsSync(path)) { console.error('MISSING', key, path); process.exit(1); }
  const src = 'data:image/png;base64,' + fs.readFileSync(path).toString('base64');
  out[key] = await page.evaluate(async ([src, width, quality]) => {
    const img = new Image();
    await new Promise((res, rej) => { img.onload = res; img.onerror = rej; img.src = src; });
    const scale = Math.min(1, width / img.width);
    const c = document.createElement('canvas');
    c.width = Math.round(img.width * scale);
    c.height = Math.round(img.height * scale);
    const ctx = c.getContext('2d');
    ctx.imageSmoothingQuality = 'high';
    ctx.drawImage(img, 0, 0, c.width, c.height);
    return c.toDataURL('image/jpeg', quality);
  }, [src, width, quality]);
  console.log(key.padEnd(24), Math.round(out[key].length / 1024) + ' KB');
}

fs.writeFileSync(outPath, JSON.stringify(out));
const mb = Object.values(out).reduce((n, s) => n + s.length, 0) / 1024 / 1024;
console.log('TOTAL', mb.toFixed(2), 'MB', mb > 12 ? '— too heavy, lower the widths' : '');
await browser.close();
