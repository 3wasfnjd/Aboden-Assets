// Aboden Assets — plants/trees.js
// أشجار البيئة السعودية: السدر، الطلح، الأثل — كلها من مولّد الشجرة العام core/tree.js
(function (g) {
  'use strict';
  const AA = g.AA;
  const V = AA.v, hex = AA.hex, mixc = AA.mixc, vary = AA.vary, lerp = AA.lerp;

  function barkFn(dark, light, rng0) {
    const d = hex(dark), l = hex(light);
    return (depth, t, k, rng) => vary(mixc(d, l, (k % 2 ? 0.25 : 0.7) + depth * 0.08), rng, 0.2);
  }

  // ---------------- السدر ----------------
  const QS = {
    high: { clusters: 8, leaves: 9, sides: [10, 6, 4, 3], segs: [5, 4, 3, 3], tips: [0.35, 0.7, 1] },
    med:  { clusters: 6, leaves: 7, sides: [8, 5, 4, 3],  segs: [4, 3, 3, 2], tips: [0.5, 1] },
    low:  { clusters: 5, leaves: 5, sides: [6, 4, 3, 3],  segs: [3, 2, 2, 2], tips: [1] }
  };
  function sidr(p, quality) {
    const q = QS[quality] || QS.med, rng = AA.rng(p.seed), S = p.height / 6;
    const W = new AA.Builder(), L = new AA.Builder(), Fr = new AA.Builder();
    const leafA = hex('#3f5c29'), leafB = hex('#5c7a36'), leafTip = hex('#8a9a4c'), inner = hex('#2c4020');
    const nabqA = hex('#d6a23a'), nabqB = hex('#b8602a');
    const crownC = [0, p.height * 0.62, 0];
    const lean = rng() * Math.PI * 2;
    AA.growTree({ wood: W }, rng, {
      trunks: [{ base: [0, 0, 0], dir: [Math.cos(lean) * 0.12, 1, Math.sin(lean) * 0.12] }],
      trunkLength: 1.8 * S, trunkRadius: 0.24 * S,
      levels: 3, children: [4, 3, 3], spread: [0.8 * p.spread, 0.7 * p.spread, 0.65],
      upward: [0.2, 0.12, 0.05], lenRatio: [1.35, 0.62, 0.6], radRatio: 0.6, taper: 0.62,
      childStart: 0.55, gnarl: 0.28, leader: true,
      segs: q.segs, sides: q.sides, swayGain: [0, 0.15, 0.2, 0.25],
      bark: barkFn('#3d342d', '#6a5c4f'),
      tipPoints: q.tips,
      onTip: (pt, d, sw, depth, r) => {
        const ph = rng() * 6.28;
        AA.blob(L, pt, [0.42 * S, 0, 0], [0, 0.32 * S, 0], [0, 0, 0.42 * S], () => vary(inner, rng, 0.15), sw, ph, 0, rng, 0.4, quality === 'low');
        const n = Math.round(q.clusters * p.density);
        for (let c = 0; c < n; c++) {
          const ctr = V.madd(V.madd(pt, AA.inSphere(rng), 0.55 * S), d, 0.12 * S);
          const out = V.norm(V.sub(ctr, crownC));
          const nrm = V.norm(V.add(V.add(V.scale(AA.inSphere(rng), 0.7), [0, 0.7, 0]), V.scale(out, 0.8)));
          const hgt = AA.clamp(ctr[1] / (p.height * 1.1), 0, 1);
          AA.leafCluster(L, ctr, nrm, 0.15 * S, q.leaves, mixc(leafA, leafB, hgt + (rng() - 0.5) * 0.4), leafTip, sw + 0.12, ph + c, 1, rng, { elong: 1.9, cup: 0.15 });
        }
        if (p.fruit) for (let f = 0; f < 4; f++) {
          const fc = V.madd(pt, AA.inSphere(rng), 0.5 * S), fr = 0.028;
          const col = vary(mixc(nabqA, nabqB, rng()), rng, 0.15);
          AA.blob(Fr, fc, [fr, 0, 0], [0, fr, 0], [0, 0, fr], () => col, sw + 0.15, ph, 0.1, rng, 0, true);
        }
      }
    });
    return AA.finalize('sidr', {
      wood: { builder: W, material: { kind: 'bark', roughness: 0.95 } },
      leaves: { builder: L, material: { kind: 'leaf', roughness: 0.55, doubleSided: true } },
      fruit: { builder: Fr, material: { kind: 'fruit', roughness: 0.4 } }
    }, { height: p.height, stiffness: 0.008, radius: 3 * S * p.spread, collider: { type: 'cylinder', radius: 0.3 * S, height: 1.8 * S } });
  }

  AA.assets.sidr = {
    id: 'sidr', name: 'سدرة', nameEn: 'Sidr (Ziziphus)', category: 'plants',
    schema: [
      { key: 'height', label: 'الارتفاع', min: 3, max: 9, step: 0.5, def: 6, unit: 'م' },
      { key: 'spread', label: 'اتساع التاج', min: 0.7, max: 1.4, step: 0.05, def: 1, pct: true },
      { key: 'density', label: 'كثافة الورق', min: 0.4, max: 1.6, step: 0.1, def: 1, pct: true },
      { key: 'fruit', label: 'النبق', type: 'bool', def: true }
    ],
    presets: { 'سدرة معمّرة': { height: 8, spread: 1.3, density: 1.3 }, 'سدرة صغيرة': { height: 3.5, spread: 0.9, density: 0.9, fruit: false } },
    generate: sidr
  };

  // ---------------- الطلح ----------------
  const QT = {
    high: { clusters: 7, leaves: 8, sides: [8, 5, 4, 3], segs: [4, 4, 3, 3], tips: [0.5, 1] },
    med:  { clusters: 5, leaves: 6, sides: [6, 4, 3, 3], segs: [3, 3, 3, 2], tips: [0.6, 1] },
    low:  { clusters: 4, leaves: 5, sides: [5, 4, 3, 3], segs: [3, 2, 2, 2], tips: [1] }
  };
  function talh(p, quality) {
    const q = QT[quality] || QT.med, rng = AA.rng(p.seed), S = p.height / 4.5;
    const W = new AA.Builder(), L = new AA.Builder(), Fl = new AA.Builder();
    const leafA = hex('#6f8445'), leafB = hex('#8c9a58'), leafTip = hex('#a9ad6e'), under = hex('#4f6331'), flower = hex('#efc93a');
    const trunks = [];
    const n = Math.max(1, Math.round(p.trunks)), az0 = rng() * 6.28;
    for (let i = 0; i < n; i++) {
      const a = az0 + i / n * 6.28 + (rng() - 0.5) * 0.6, k = n > 1 ? 0.5 : 0.12;
      trunks.push({ base: [Math.cos(a) * 0.08 * (n > 1 ? 1 : 0), 0, Math.sin(a) * 0.08 * (n > 1 ? 1 : 0)], dir: [Math.cos(a) * k, 1, Math.sin(a) * k], radius: 0.16 * S / Math.sqrt(n) * 1.3 });
    }
    AA.growTree({ wood: W }, rng, {
      trunks, trunkLength: 1.4 * S,
      levels: 3, children: [3, 3, 3], spread: [0.65 * p.spread, 0.85 * p.spread, 0.9],
      upward: [0.12, -0.05, -0.12], flatten: 0.65, flattenFrom: 2,
      lenRatio: [1.25, 0.72, 0.6], radRatio: 0.6, taper: 0.6, childStart: 0.6, gnarl: 0.55, leader: false,
      segs: q.segs, sides: q.sides, swayGain: [0, 0.12, 0.2, 0.25],
      bark: barkFn('#3a3029', '#5f5246'),
      tipPoints: q.tips,
      onTip: (pt, d, sw, depth) => {
        const ph = rng() * 6.28;
        AA.blob(L, V.add(pt, [0, -0.05 * S, 0]), [0.55 * S, 0, 0], [0, 0.11 * S, 0], [0, 0, 0.55 * S], () => vary(under, rng, 0.15), sw, ph, 0, rng, 0.3, quality === 'low');
        const m = Math.round(q.clusters * p.density);
        for (let c = 0; c < m; c++) {
          const r = AA.inSphere(rng);
          const ctr = V.add(pt, [r[0] * 0.65 * S, Math.abs(r[1]) * 0.12 * S, r[2] * 0.65 * S]);
          const nrm = V.norm(V.add([0, 1, 0], V.scale(AA.inSphere(rng), 0.3)));
          AA.leafCluster(L, ctr, nrm, 0.2 * S, q.leaves, vary(mixc(leafA, leafB, rng()), rng, 0.15), leafTip, sw + 0.1, ph + c, 0.9, rng, { elong: 3.2, cup: 0.03, tilt: 0.25 });
        }
        if (p.flowers) for (let f = 0; f < 3; f++) {
          const fc = V.add(pt, [(rng() - 0.5) * 0.9 * S, 0.06 * S, (rng() - 0.5) * 0.9 * S]), fr = 0.03;
          AA.blob(Fl, fc, [fr, 0, 0], [0, fr, 0], [0, 0, fr], () => vary(flower, rng, 0.1), sw + 0.1, ph, 0.3, rng, 0.2, true);
        }
      }
    });
    return AA.finalize('talh', {
      wood: { builder: W, material: { kind: 'bark', roughness: 0.95 } },
      leaves: { builder: L, material: { kind: 'leaf', roughness: 0.75, doubleSided: true } },
      fruit: { builder: Fl, material: { kind: 'flower', roughness: 0.6 } }
    }, { height: p.height, stiffness: 0.01, radius: 3.4 * S * p.spread, collider: { type: 'cylinder', radius: 0.25 * S, height: 1.4 * S } });
  }

  AA.assets.talh = {
    id: 'talh', name: 'طلحة', nameEn: 'Talh (Acacia)', category: 'plants',
    schema: [
      { key: 'height', label: 'الارتفاع', min: 2.5, max: 7, step: 0.5, def: 4.5, unit: 'م' },
      { key: 'spread', label: 'اتساع المظلة', min: 0.8, max: 1.6, step: 0.05, def: 1.15, pct: true },
      { key: 'trunks', label: 'عدد السيقان', min: 1, max: 4, step: 1, def: 2 },
      { key: 'density', label: 'كثافة الورق', min: 0.4, max: 1.6, step: 0.1, def: 1, pct: true },
      { key: 'flowers', label: 'الزهر الأصفر', type: 'bool', def: false }
    ],
    presets: { 'طلحة الوادي': { height: 5.5, spread: 1.5, trunks: 3 }, 'طلحة يابسة': { height: 4, density: 0.4, trunks: 1 } },
    generate: talh
  };

  // ---------------- الأثل ----------------
  const QA = {
    high: { strands: 14, segs: 4, sides: [10, 6, 4, 3], bsegs: [5, 4, 3, 3], tips: [0.4, 0.75, 1] },
    med:  { strands: 10, segs: 3, sides: [8, 5, 4, 3],  bsegs: [4, 3, 3, 2], tips: [0.5, 1] },
    low:  { strands: 6,  segs: 2, sides: [6, 4, 3, 3],  bsegs: [3, 2, 2, 2], tips: [1] }
  };
  function athl(p, quality) {
    const q = QA[quality] || QA.med, rng = AA.rng(p.seed), S = p.height / 7;
    const W = new AA.Builder(), L = new AA.Builder();
    const sA = hex('#76866a'), sB = hex('#8e9a7e'), sTip = hex('#a9b196'), inner = hex('#55634c');
    const lean = rng() * 6.28;
    AA.growTree({ wood: W }, rng, {
      trunks: [{ base: [0, 0, 0], dir: [Math.cos(lean) * 0.2, 1, Math.sin(lean) * 0.2] }],
      trunkLength: 1.7 * S, trunkRadius: 0.34 * S,
      levels: 3, children: [3, 3, 3], spread: [0.75, 0.65, 0.6],
      upward: [0.35, 0.25, 0.15], lenRatio: [1.15, 0.7, 0.62], radRatio: 0.58, taper: 0.55,
      childStart: 0.5, gnarl: 0.4, leader: true,
      segs: q.bsegs, sides: q.sides, swayGain: [0, 0.12, 0.18, 0.22],
      bark: barkFn('#352c25', '#5e5045'),
      tipPoints: q.tips,
      onTip: (pt, d, sw) => {
        const ph = rng() * 6.28;
        AA.blob(L, pt, [0.4 * S, 0, 0], [0, 0.35 * S, 0], [0, 0, 0.4 * S], () => vary(inner, rng, 0.15), sw, ph, 0, rng, 0.4, quality === 'low');
        const m = Math.round(q.strands * p.density);
        for (let c = 0; c < m; c++) {
          const start = V.madd(pt, AA.inSphere(rng), 0.35 * S);
          const dir = V.norm(V.add(V.add(V.scale(d, 0.6), V.scale(AA.inSphere(rng), 0.7)), [0, 0.15, 0]));
          AA.ribbon(L, start, dir, p.droop * S * (0.6 + rng() * 0.6), 0.035 * S, q.segs, 0.9,
            vary(mixc(sA, sB, rng()), rng, 0.12), sTip, sw + 0.08, ph + c * 0.4, 0.8, rng, { swayGain: 0.35, twist: 1.2 });
        }
      }
    });
    return AA.finalize('athl', {
      wood: { builder: W, material: { kind: 'bark', roughness: 0.97 } },
      leaves: { builder: L, material: { kind: 'leaf', roughness: 0.8, doubleSided: true } }
    }, { height: p.height, stiffness: 0.006, radius: 3 * S, collider: { type: 'cylinder', radius: 0.4 * S, height: 1.7 * S } });
  }

  AA.assets.athl = {
    id: 'athl', name: 'أثلة', nameEn: 'Athl (Tamarisk)', category: 'plants',
    schema: [
      { key: 'height', label: 'الارتفاع', min: 4, max: 11, step: 0.5, def: 7, unit: 'م' },
      { key: 'droop', label: 'طول الأغصان المتدلية', min: 0.4, max: 1.4, step: 0.05, def: 0.85, unit: 'م' },
      { key: 'density', label: 'الكثافة', min: 0.4, max: 1.6, step: 0.1, def: 1, pct: true }
    ],
    presets: { 'أثلة مصدّات رياح': { height: 9, density: 1.5, droop: 0.7 }, 'أثلة عجوز': { height: 6, density: 0.7, droop: 1.3 } },
    generate: athl
  };
})(typeof window !== 'undefined' ? window : globalThis);
