// Aboden Assets — lowpoly/lp-plants.js — نخلة لو-بولي
(function (g) {
  'use strict';
  const AA = g.AA, LP = AA.lp, V = AA.v, lerp = AA.lerp, vary = AA.vary, mixc = AA.mixc;

  function palm(p, q) {
    const rng = AA.rng(p.seed), T = new AA.Builder(), F = new AA.Builder(), D = new AA.Builder(), H = p.height;
    const low = q === 'low', segs = low ? 5 : 8, sides = low ? 5 : 6, lean = p.lean, la = rng() * Math.PI * 2;
    // الجذع: قطع متدرّجة (كل قطعة أعرض قليلاً من أعلاها) بلونين متبادلين ومنحنى ميلان
    const pt = t => [Math.cos(la) * lean * H * 0.22 * t * t, H * t, Math.sin(la) * lean * H * 0.22 * t * t];
    for (let i = 0; i < segs; i++) {
      const t0 = i / segs, t1 = (i + 1) / segs, r = lerp(0.24, 0.15, t0) * (H / 9 + 0.5) * 0.75;
      LP.prism(T, pt(t0), pt(t1), r * 1.08, r * 0.86, sides, LP.c(i % 2 ? 'trunk' : 'trunk2'), { rot: i * 0.5, sway: pp => 0.004 * pp[1] / H });
    }
    const top = pt(1), up = V.norm(V.sub(pt(1), pt(0.92)));
    LP.ico(T, V.add(top, [0, 0.05, 0]), [0.32, 0.26, 0.32], 0, () => LP.c('woodDark'));
    // السعف: شريط مطوي على شكل V من ثلاث قطع، ينحني للأسفل، بلونين أخضرين
    const n = Math.round(p.fronds);
    for (let k = 0; k < n; k++) {
      const a = k / n * Math.PI * 2 + rng() * 0.3, tilt = (k % 2 ? 0.25 : 0.55) + rng() * 0.25, L = p.frondLen * (0.85 + rng() * 0.3);
      const dir = V.norm([Math.cos(a), tilt, Math.sin(a)]), side = V.norm([-Math.sin(a), 0, Math.cos(a)]);
      const col = LP.c(k % 2 ? 'palmGreen' : 'palmGreen2'), cs = 3, ph = rng() * 6;
      let prev = null;
      for (let i = 0; i <= cs; i++) {
        const t = i / cs, c = V.add(V.add(top, V.scale(dir, L * t)), [0, -L * 0.55 * t * t, 0]), w = 0.32 * L / 2.6 * Math.sin(Math.PI * Math.min(1, t * 0.9 + 0.12)) * (1 - 0.5 * t);
        const fold = [0, -w * 0.35, 0], l = V.add(V.add(c, V.scale(side, w)), fold), r = V.add(V.add(c, V.scale(side, -w)), fold), sw = 0.15 + 0.5 * t;
        const ids = [F.v(c, col, sw, ph, 0.4 * t), F.v(l, mixc(col, [0, 0, 0], 0.12), sw, ph, 0.6 * t), F.v(r, mixc(col, [0, 0, 0], 0.12), sw, ph, 0.6 * t)];
        if (prev) { F.t(prev[0], ids[0], prev[1]); F.t(ids[0], ids[1], prev[1]); F.t(prev[0], prev[2], ids[0]); F.t(ids[0], prev[2], ids[2]); }
        prev = ids;
      }
    }
    // سعف يابس متدلٍّ تحت التاج
    for (let k = 0; k < (low ? 2 : 4); k++) {
      const a = rng() * Math.PI * 2, d = V.norm([Math.cos(a), -1.6, Math.sin(a)]), b = V.add(top, [0, -0.15, 0]), e = V.add(b, V.scale(d, p.frondLen * 0.55)), sd = V.norm([-Math.sin(a), 0, Math.cos(a)]);
      LP.tri(D, b, V.add(e, V.scale(sd, 0.12)), V.add(e, V.scale(sd, -0.12)), LP.c('palmDry'));
      LP.tri(D, b, V.add(e, V.scale(sd, -0.12)), V.add(e, V.scale(sd, 0.12)), LP.c('palmDry'));
    }
    // عذوق التمر
    for (let k = 0; k < Math.round(p.bunches); k++) {
      const a = k / Math.max(1, p.bunches) * Math.PI * 2 + 0.6, c = V.add(top, [Math.cos(a) * 0.32, -0.35, Math.sin(a) * 0.32]);
      for (let j = 0; j < (low ? 3 : 6); j++) LP.ico(D, V.add(c, [(rng() - 0.5) * 0.18, -j * 0.05 - rng() * 0.08, (rng() - 0.5) * 0.18]), 0.07, 0, () => LP.c(j % 2 ? 'date' : 'date2'));
    }
    return LP.finalize('lp_palm', {
      trunk:  { builder: T, material: LP.mat('wood') },
      fronds: { builder: F, material: LP.mat('leaves', { doubleSided: true }) },
      detail: { builder: D, material: LP.mat('fruit', { doubleSided: true }) }
    }, { height: H + 1, radius: p.frondLen, stiffness: 0.02, collider: { type: 'cylinder', radius: 0.3, height: H } });
  }

  AA.assets.lp_palm = { id: 'lp_palm', name: 'نخلة', nameEn: 'Low-poly palm', category: 'lowpoly',
    schema: [
      { key: 'height', label: 'الطول', min: 3, max: 12, step: 0.5, def: 7, unit: 'م' },
      { key: 'fronds', label: 'عدد السعف', min: 6, max: 16, step: 1, def: 11 },
      { key: 'frondLen', label: 'طول السعفة', min: 1.5, max: 3.5, step: 0.1, def: 2.6, unit: 'م' },
      { key: 'lean', label: 'الميلان', min: 0, max: 1, step: 0.05, def: 0.35, pct: true },
      { key: 'bunches', label: 'عذوق التمر', min: 0, max: 5, step: 1, def: 3 }
    ], presets: { 'فسيلة': { height: 3, fronds: 9, frondLen: 1.7, bunches: 0 }, 'نخلة طويلة': { height: 11, lean: 0.6 } }, generate: palm };
})(typeof window !== 'undefined' ? window : globalThis);
