// Aboden Assets — plants/shrubs.js
// شجيرات وأعشاب البر: العرفج والثمام
(function (g) {
  'use strict';
  const AA = g.AA;
  const V = AA.v, hex = AA.hex, mixc = AA.mixc, vary = AA.vary, lerp = AA.lerp;

  // ---------------- العرفج ----------------
  const QF = {
    high: { stems: 70, segs: 4, leaves: 3, leafAt: [0.35, 0.6, 0.85] },
    med:  { stems: 45, segs: 3, leaves: 3, leafAt: [0.45, 0.8] },
    low:  { stems: 24, segs: 2, leaves: 2, leafAt: [0.7] }
  };
  function arfaj(p, quality) {
    const q = QF[quality] || QF.med, rng = AA.rng(p.seed), S = p.size;
    const W = new AA.Builder(), L = new AA.Builder(), Fl = new AA.Builder();
    const woodA = hex('#7c6c55'), woodB = hex('#8e9168'), leafC = hex('#8c9868'), leafTip = hex('#b0b387'), yel = hex('#efc52e');
    const n = Math.round(q.stems * p.density);
    for (let i = 0; i < n; i++) {
      const az = rng() * 6.283, e = lerp(0.2, 1.4, Math.pow(rng(), 0.7));
      const out = [Math.cos(az), 0, Math.sin(az)];
      const base = [out[0] * 0.05 * S, 0, out[2] * 0.05 * S];
      const dir = [out[0] * Math.cos(e), Math.sin(e), out[2] * Math.cos(e)];
      const len = S * (0.55 + rng() * 0.5);
      const pts = [], radii = [];
      for (let k = 0; k <= q.segs; k++) {
        const u = k / q.segs;
        pts.push(V.madd(V.madd(V.madd(base, dir, len * u), out, len * 0.15 * u * u), AA.UP, (rng() - 0.5) * 0.04 * S * u));
        radii.push(lerp(0.012, 0.003, u) * S);
      }
      const ph = rng() * 6.28;
      AA.tube(W, pts, radii, 3, k => vary(mixc(woodA, woodB, k / q.segs), rng, 0.15), k => 0.45 * k / q.segs, ph, null, true);
      for (const t of q.leafAt) {
        const f = t * q.segs, j = Math.min(q.segs - 1, Math.floor(f));
        const pt = V.lerp(pts[j], pts[j + 1], f - j);
        const nrm = V.norm(V.add(dir, V.scale(AA.inSphere(rng), 0.8)));
        AA.leafCluster(L, pt, nrm, 0.07 * S, q.leaves, leafC, leafTip, 0.45 * t, ph, 0.6, rng, { elong: 3, cup: 0.05 });
      }
      if (p.bloom && rng() < 0.75) {
        const tip = pts[pts.length - 1], fr = 0.022 * S;
        AA.blob(Fl, tip, [fr, 0, 0], [0, fr * 0.8, 0], [0, 0, fr], () => vary(yel, rng, 0.12), 0.45, ph, 0.2, rng, 0.15, true);
      }
    }
    return AA.finalize('arfaj', {
      wood: { builder: W, material: { kind: 'bark', roughness: 0.9 } },
      leaves: { builder: L, material: { kind: 'leaf', roughness: 0.8, doubleSided: true } },
      fruit: { builder: Fl, material: { kind: 'flower', roughness: 0.6 } }
    }, { height: S, stiffness: 0, radius: S * 0.9, collider: { type: 'sphere', radius: S * 0.6 } });
  }

  AA.assets.arfaj = {
    id: 'arfaj', name: 'عرفج', nameEn: 'Arfaj (Rhanterium)', category: 'plants',
    schema: [
      { key: 'size', label: 'الحجم', min: 0.3, max: 1.3, step: 0.05, def: 0.75, unit: 'م' },
      { key: 'density', label: 'الكثافة', min: 0.4, max: 1.6, step: 0.1, def: 1, pct: true },
      { key: 'bloom', label: 'مزهر (الربيع)', type: 'bool', def: true }
    ],
    presets: { 'عرفج الربيع': { size: 0.9, bloom: true, density: 1.3 }, 'عرفج الصيف': { size: 0.7, bloom: false, density: 0.8 } },
    generate: arfaj
  };

  // ---------------- الثمام ----------------
  const QG = { high: { k: 1, segs: 4 }, med: { k: 0.7, segs: 3 }, low: { k: 0.4, segs: 2 } };
  function thumam(p, quality) {
    const q = QG[quality] || QG.med, rng = AA.rng(p.seed), S = p.size;
    const L = new AA.Builder(), W = new AA.Builder();
    const green = hex('#7f8c48'), dry = hex('#c6ad74'), tipG = hex('#b3b36e'), tipD = hex('#ddc995');
    const base = mixc(green, dry, p.dryness), tip = mixc(tipG, tipD, p.dryness);
    const n = Math.round(p.blades * q.k);
    for (let i = 0; i < n; i++) {
      const az = rng() * 6.283, r0 = Math.sqrt(rng()) * 0.13 * S;
      const out = [Math.cos(az), 0, Math.sin(az)];
      const e = lerp(0.85, 1.5, rng());
      const dir = [out[0] * Math.cos(e), Math.sin(e), out[2] * Math.cos(e)];
      AA.ribbon(L, [out[0] * r0, 0, out[2] * r0], dir, S * (0.5 + rng() * 0.6), 0.016 * S, q.segs, 0.25 + rng() * 0.4,
        vary(base, rng, 0.2), tip, 0, rng() * 6.28, 1, rng, { swayGain: 0.8, twist: 0.8 });
    }
    const stalks = Math.round(n / 9);
    const stalkC = mixc(hex('#a49a62'), dry, p.dryness), seedC = hex('#cdb684');
    for (let i = 0; i < stalks; i++) {
      const az = rng() * 6.283, out = [Math.cos(az), 0, Math.sin(az)];
      const h = S * (1.0 + rng() * 0.4), ph = rng() * 6.28;
      const b = [out[0] * 0.05 * S, 0, out[2] * 0.05 * S];
      const top = V.add(b, [out[0] * 0.15 * h, h, out[2] * 0.15 * h]);
      AA.tube(W, [b, V.lerp(b, top, 0.5), top], [0.006 * S, 0.004 * S, 0.002 * S], 3, () => stalkC, k => 0.4 * k, ph, null, false);
      AA.leafCluster(L, top, [out[0] * 0.3, 1, out[2] * 0.3], 0.12 * S, 4, seedC, tipD, 0.85, ph, 0.6, rng, { elong: 5, cup: 0, lift: 0.8 });
    }
    return AA.finalize('thumam', {
      wood: { builder: W, material: { kind: 'bark', roughness: 0.9 } },
      leaves: { builder: L, material: { kind: 'leaf', roughness: 0.85, doubleSided: true } }
    }, { height: S, stiffness: 0, radius: S * 0.7, collider: { type: 'none' } });
  }

  AA.assets.thumam = {
    id: 'thumam', name: 'ثمام', nameEn: 'Thumam (desert grass)', category: 'plants',
    schema: [
      { key: 'size', label: 'الطول', min: 0.3, max: 1.4, step: 0.05, def: 0.8, unit: 'م' },
      { key: 'blades', label: 'عدد الأعواد', min: 40, max: 220, step: 10, def: 130 },
      { key: 'dryness', label: 'اليباس', min: 0, max: 1, step: 0.05, def: 0.35, pct: true }
    ],
    presets: { 'ثمام أخضر': { dryness: 0.05, blades: 160 }, 'ثمام يابس': { dryness: 0.9, blades: 100 } },
    generate: thumam
  };
})(typeof window !== 'undefined' ? window : globalThis);
