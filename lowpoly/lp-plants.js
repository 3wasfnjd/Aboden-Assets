// Aboden Assets — lowpoly/lp-plants.js — نخلة لو-بولي
(function (g) {
  'use strict';
  const AA = g.AA, LP = AA.lp, V = AA.v, lerp = AA.lerp, vary = AA.vary, mixc = AA.mixc;

  // سعفة: عرق وسطي مقوّس وخوص مسنّن على الجانبين (كل خوصة مثلث مائل نحو الطرف) مطويّ للأسفل على شكل V
  function frond(B, top, a, tilt, L, droop, cols, n, ph, sw0, start) {
    const dir = V.norm([Math.cos(a), tilt, Math.sin(a)]), side = V.norm([-Math.sin(a), 0, Math.cos(a)]);
    const C = t => V.add(V.add(top, V.scale(dir, L * (start + (1 - start) * t))), [0, -L * droop * t * t, 0]);
    const W = t => L * 0.19 * Math.pow(Math.max(0, Math.sin(Math.PI * (0.06 + 0.94 * t))), 0.75);
    const sw = t => sw0 * (0.12 + 0.88 * t);
    // العرق: شريط ضيق حتى تُقرأ السعفة من تحت
    for (let i = 0; i < n; i++) {
      const t0 = i / n, t1 = (i + 1) / n, tt = Math.min(1, t1 + 0.7 / n), p0 = C(t0), p1 = C(t1), w = W((t0 + t1) / 2);
      for (const sd of [1, -1]) {
        const tip = V.add(V.add(C(tt), V.scale(side, sd * w)), [0, -0.42 * w, 0]), col = cols[(i + (sd > 0 ? 0 : 1)) % cols.length];
        B.t(B.v(p0, col, sw(t0), ph, 0.15 * t0), B.v(p1, col, sw(t1), ph, 0.15 * t1), B.v(tip, col, sw(tt), ph, 0.45 + 0.4 * tt));
      }
    }
  }

  function palm(p, q) {
    const rng = AA.rng(p.seed), T = new AA.Builder(), F = new AA.Builder(), D = new AA.Builder(), H = p.height;
    const low = q === 'low', segs = low ? 6 : 10, sides = low ? 5 : 7, lean = p.lean, la = rng() * Math.PI * 2, th = H / 9 + 0.5;
    // الجذع: حلقات كَرَب متراكبة (كل حلقة أعرض من أعلاها) بلونين متبادلين وتدوير متدرّج ومنحنى ميلان
    const pt = t => [Math.cos(la) * lean * H * 0.22 * t * t, H * t, Math.sin(la) * lean * H * 0.22 * t * t];
    const swT = pp => 0.004 * pp[1] / H;
    for (let i = 0; i < segs; i++) {
      const t0 = i / segs, t1 = (i + 1) / segs, r = lerp(0.27, 0.17, t0) * th * 0.75, base = i === 0 ? 1.25 : 0.84;
      LP.prism(T, pt(t0), pt(Math.min(1, t1 + 0.012)), r * base, r * 1.06, sides, vary(LP.c(i % 2 ? 'trunk' : 'trunk2'), rng, 0.08), { rot: i * 0.45, sway: swT });
    }
    const top = pt(1);
    // رأس الجذع (القلب) وبقايا قواعد السعف
    LP.ico(T, V.add(top, [0, 0.1, 0]), [0.24 * th, 0.3 * th, 0.24 * th], 0, d => LP.c(d[1] > 0.3 ? 'palmGreen3' : 'trunkTop'), { sway: 0.03 });
    for (let k = 0; k < (low ? 4 : 7); k++) {
      const a = k / (low ? 4 : 7) * Math.PI * 2 + 0.4, d = [Math.cos(a), 0.55, Math.sin(a)], b = V.add(top, [0, -0.12, 0]);
      LP.prism(T, b, V.add(b, V.scale(d, 0.32 * th)), 0.075 * th, 0.03 * th, 4, LP.c('trunkTop'), { sway: swT });
    }
    // السعف: طبقة داخلية قائمة فاتحة وطبقة خارجية متدلّية أغمق
    const n = Math.round(p.fronds), lf = low ? 4 : 7, G = [LP.c('palmGreen'), LP.c('palmGreen2')], G2 = [LP.c('palmGreen3'), LP.c('palmGreen')];
    for (let k = 0; k < n; k++) {
      const inner = k % 3 === 0, a = k * 2.39996 + rng() * 0.25, L = p.frondLen * (inner ? 0.78 : 1) * (0.88 + rng() * 0.24);
      const tilt = inner ? 1.1 + rng() * 0.6 : 0.15 + rng() * 0.35, droop = inner ? 0.28 : 0.55 + rng() * 0.2;
      frond(F, V.add(top, [0, 0.12, 0]), a, tilt, L, droop, inner ? G : (k % 2 ? G : G2), lf + (inner ? -1 : 0), rng() * 6, 0.65, 0.05);
    }
    // سعف يابس متدلٍّ تحت التاج
    const nd = low ? 2 : 4;
    for (let k = 0; k < nd; k++) frond(D, V.add(top, [0, -0.12, 0]), k / nd * Math.PI * 2 + rng(), -0.9 - rng() * 0.5, p.frondLen * 0.6, 0.12, [LP.c('palmDry'), LP.c('palmDry2')], low ? 3 : 4, rng() * 6, 0.25, 0.08);
    // عذوق التمر: شمراخ برتقالي مقوّس ينتهي بعنقود
    for (let k = 0; k < Math.round(p.bunches); k++) {
      const a = k / Math.max(1, p.bunches) * Math.PI * 2 + 0.6, ca = Math.cos(a), sa = Math.sin(a);
      const s0 = V.add(top, [ca * 0.12, -0.05, sa * 0.12]), s1 = V.add(top, [ca * 0.42 * th, -0.22, sa * 0.42 * th]), c = V.add(top, [ca * 0.5 * th, -0.48, sa * 0.5 * th]);
      LP.prism(D, s0, s1, 0.035, 0.03, 4, LP.c('stalk')); LP.prism(D, s1, c, 0.03, 0.025, 4, LP.c('stalk'));
      LP.ico(D, V.add(c, [0, -0.08, 0]), [0.1 * th, 0.19 * th, 0.1 * th], low ? 0 : 1, d => vary(LP.c(d[1] > 0.2 ? 'date' : 'date2'), rng, 0.15), { shape: d => [d[0] * (1 - 0.35 * Math.max(0, -d[1])), d[1], d[2] * (1 - 0.35 * Math.max(0, -d[1]))] });
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
      { key: 'fronds', label: 'عدد السعف', min: 6, max: 20, step: 1, def: 15 },
      { key: 'frondLen', label: 'طول السعفة', min: 1.5, max: 3.5, step: 0.1, def: 2.6, unit: 'م' },
      { key: 'lean', label: 'الميلان', min: 0, max: 1, step: 0.05, def: 0.35, pct: true },
      { key: 'bunches', label: 'عذوق التمر', min: 0, max: 5, step: 1, def: 3 }
    ], presets: { 'فسيلة': { height: 3, fronds: 11, frondLen: 1.7, bunches: 0 }, 'نخلة طويلة': { height: 11, lean: 0.6 } }, generate: palm };
})(typeof window !== 'undefined' ? window : globalThis);
