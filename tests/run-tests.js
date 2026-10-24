// اختبارات آلية لكل الأصول — تعمل في GitHub Actions بدون أي مكتبات
// تتحقق: الأرقام سليمة، الفهارس داخل الحدود، نفس البذرة = نفس الشكل، وعدد المثلثات ضمن الميزانية.
'use strict';
const fs = require('fs');
const path = require('path');
const vm = require('vm');

const root = path.join(__dirname, '..');
const ctx = { console, Math, Float32Array, Uint32Array, Uint8Array, Object, Array, JSON, Set };
ctx.globalThis = ctx;
vm.createContext(ctx);
const order = ['core/math.js', 'core/builder.js', 'core/tree.js', 'core/texture.js', 'core/mud.js', 'core/skeleton.js'];
const assetDirs = ['plants', 'architecture', 'animals', 'characters', 'souq', 'majlis', 'terrain', 'vehicles', 'badia', 'lowpoly'].filter(d => fs.existsSync(path.join(root, d)));
for (const f of order) vm.runInContext(fs.readFileSync(path.join(root, f), 'utf8'), ctx, { filename: f });
for (const d of assetDirs) for (const f of fs.readdirSync(path.join(root, d)).filter(x => x.endsWith('.js') && x !== 'scenes.js').sort((a, b) => ((b === 'lp-schemas.js') * 2 + (b === 'lp-core.js')) - ((a === 'lp-schemas.js') * 2 + (a === 'lp-core.js')) || a.localeCompare(b)))
  vm.runInContext(fs.readFileSync(path.join(root, d, f), 'utf8'), ctx, { filename: d + '/' + f });

const AA = ctx.AA;
const BUDGET = { high: 90000, med: 40000, low: 15000 };
let failures = 0;
const rows = [];

function hash(a) { let h = 2166136261; for (let i = 0; i < a.length; i += 7) { h ^= Math.round(a[i] * 1000); h = Math.imul(h, 16777619); } return h >>> 0; }
function check(cond, msg) { if (!cond) { failures++; console.error('  ✗ ' + msg); } }

for (const id of Object.keys(AA.assets)) {
  const asset = AA.assets[id];
  check(asset.schema && asset.generate, id + ': schema/generate missing');
  const variants = [['افتراضي', {}]].concat(Object.entries(asset.presets || {}));
  for (const q of AA.QUALITY) {
    for (const [pname, over] of variants) {
      const p = AA.params(asset, Object.assign({ seed: 1234 }, over));
      const t0 = Date.now();
      const out = asset.generate(p, q);
      const ms = Date.now() - t0;
      const tag = `${id}/${q}/${pname}`;
      check(out.triangles > 0, tag + ': no triangles');
      check(out.triangles <= BUDGET[q], `${tag}: ${out.triangles} triangles > budget ${BUDGET[q]}`);
      for (const [name, part] of Object.entries(out.parts)) {
        const nv = part.positions.length / 3;
        for (const k of ['colors', 'normals']) check(part[k].length === nv * 3, `${tag}/${name}: ${k} length`);
        for (const k of ['sway', 'phase', 'flutter', 'bend']) check(part[k].length === nv, `${tag}/${name}: ${k} length`);
        check(part.uvs.length === nv * 2, `${tag}/${name}: uvs length`);
        if (part.material.texture) check(ctx.AA.TEXTURES.includes(part.material.texture), `${tag}/${name}: unknown texture ${part.material.texture}`);
        check(part.indices.length % 3 === 0, `${tag}/${name}: indices not triangles`);
        let maxI = 0; for (const i of part.indices) if (i > maxI) maxI = i;
        check(maxI < nv, `${tag}/${name}: index out of range`);
        for (const k of ['positions', 'colors', 'normals', 'sway', 'bend']) {
          const a = part[k]; let bad = 0; for (let i = 0; i < a.length; i++) if (!Number.isFinite(a[i])) bad++;
          check(bad === 0, `${tag}/${name}: ${bad} non-finite ${k}`);
        }
        let minY = Infinity; for (let i = 1; i < part.positions.length; i += 3) minY = Math.min(minY, part.positions[i]);
        check(minY > -0.6, `${tag}/${name}: geometry goes ${minY.toFixed(2)} m below ground`);
      }
      const again = asset.generate(p, q);
      const h1 = Object.values(out.parts).map(x => hash(x.positions)).join(','), h2 = Object.values(again.parts).map(x => hash(x.positions)).join(',');
      check(h1 === h2, tag + ': same seed gave different shape');
      rows.push({ asset: id, quality: q, preset: pname, triangles: out.triangles, vertices: out.vertices, ms });
    }
  }
}

const table = ['| الأصل | الجودة | القالب | مثلثات | نقاط | زمن البناء |', '|---|---|---|---:|---:|---:|']
  .concat(rows.map(r => `| ${r.asset} | ${r.quality} | ${r.preset} | ${r.triangles} | ${r.vertices} | ${r.ms} ms |`)).join('\n');
console.log(table);
if (process.env.GITHUB_STEP_SUMMARY) fs.appendFileSync(process.env.GITHUB_STEP_SUMMARY, '## نتائج اختبار الأصول\n\n' + table + '\n');
console.log(failures ? `\n${failures} فشل` : '\nكل الاختبارات نجحت');
process.exit(failures ? 1 : 0);
