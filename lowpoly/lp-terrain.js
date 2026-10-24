// Aboden Assets — lowpoly/lp-terrain.js — صخور لو-بولي: كتل أوجه حادة بطبقات لونين ومنغرسة قليلاً
(function (g) {
  'use strict';
  const AA = g.AA, LP = AA.lp, V = AA.v;
  const TONES = { sand: ['#e2c08c', '#cfa874', '#b98f5e'], red: ['#d38a5c', '#bb7046', '#9c5a38'], dark: ['#8a7566', '#715e52', '#5a4a40'] };
  // صخرة: كرة أوجه درجة 1 بتشويه حاد (تكسّر) ومقطوعة من الأسفل، والأوجه العليا أفتح
  function rockInto(B, c, s, rng, flat, tone, detail) {
    const C = tone.map(LP.c), sx = s * (0.8 + rng() * 0.5), sz = s * (0.8 + rng() * 0.5), sy = s * flat * (0.75 + rng() * 0.4), seed = rng() * 50;
    const h = d => { const v = Math.sin(d[0] * 9.1 + d[1] * 17.3 + d[2] * 5.7 + seed) * 43758.5; return v - Math.floor(v); };
    LP.ico(B, c, [sx, sy, sz], detail, d => AA.vary(d[1] > 0.45 ? C[0] : d[1] > -0.1 ? C[1] : C[2], rng, 0.07), {
      shape: d => { const k = 0.8 + 0.3 * h(d); let y = d[1] * k; if (y < -0.25) y = -0.25 - (y + 0.25) * 0.2; return [d[0] * k, y, d[2] * k]; } });
  }
  function rocks(p, q) {
    const B = new AA.Builder(), rng = AA.rng(p.seed), n = Math.round(p.count), tone = TONES[p.tone] || TONES.sand, placed = [];
    for (let k = 0; k < n; k++) {
      const s = p.size * (k === 0 ? 1 : 0.25 + rng() * 0.6); let x = 0, z = 0;
      if (k) { let g2 = 0; do { const a = rng() * 6.28, d = p.size * (0.6 + rng() * p.spread); x = Math.cos(a) * d; z = Math.sin(a) * d; g2++; } while (g2 < 30 && placed.some(([px, pz, ps]) => Math.hypot(px - x, pz - z) < (ps + s) * 0.8)); }
      placed.push([x, z, s]);
      rockInto(B, [x, s * p.flat * 0.3, z], s, rng, p.flat, tone, q === 'low' || s < 0.3 ? 0 : 1);
    }
    for (let k = 0; k < (q === 'low' ? 3 : 8); k++) { const a = rng() * 6.28, d = p.size * (0.5 + rng() * p.spread), s = 0.04 + rng() * 0.05; rockInto(B, [Math.cos(a) * d, s * 0.2, Math.sin(a) * d], s, rng, 0.6, tone, 0); }
    return LP.finalize('lp_rocks', { stone: { builder: B, material: LP.mat('stone') } },
      { stiffness: 0, height: p.size * p.flat * 1.3, radius: p.size * (p.spread + 1), collider: { type: 'compound', spheres: placed.map(([x, z, s]) => ({ at: [x, s * p.flat * 0.3, z], r: s * 0.8 })) } });
  }
  LP.rockInto = rockInto;
  LP.def('rocks', rocks);
})(typeof window !== 'undefined' ? window : globalThis);
