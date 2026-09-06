/**
 * Substitute the encoded images and the title into the template.
 *
 *   node build.mjs template.html images.json "Page Title" out.html
 *
 * Fails loudly on any placeholder the images file does not cover, because a
 * missing figure in a review brief is worse than no brief — the reader assumes
 * they have seen everything.
 */
import fs from 'fs';
const [tpl, imgsPath, title, out] = process.argv.slice(2);
let html = fs.readFileSync(tpl, 'utf8');
const imgs = JSON.parse(fs.readFileSync(imgsPath, 'utf8'));

html = html.replace(/\{\{TITLE\}\}/g, title);

// Image slots are {{img:key}}. Prose placeholders are plain {{...}} and are
// left alone, so writing copy cannot accidentally look like a missing figure.
const missing = [];
html = html.replace(/\{\{img:([a-z0-9-]+)\}\}/g, (m, k) => (imgs[k] ?? (missing.push(k), m)));
if (missing.length) { console.error('MISSING IMAGES:', [...new Set(missing)].join(', ')); process.exit(1); }

const unused = Object.keys(imgs).filter(k => !html.includes(imgs[k]));
if (unused.length) console.warn('encoded but not used by the template:', unused.join(', '));

const left = [...html.matchAll(/\{\{(?!img:)([^}]{0,40})/g)].length;
if (left) console.warn(left + ' prose placeholder(s) still unfilled — check before publishing');

fs.writeFileSync(out, html);
console.log('wrote', out, (html.length / 1024 / 1024).toFixed(2), 'MB');
