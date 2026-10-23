// Aboden Assets — terrain/rocks.js
// صخور وحصى: كتل حجر رملي مكسّرة الأوجه (ضجيج على كرة منخفضة) تنغرس قليلاً في الأرض.
(function (g) {
  'use strict';
  const AA = g.AA;
  const V = AA.v, vary = AA.vary, lerp = AA.lerp;
  const LOW = q => q === 'low';

  // صخرة: كرة مقسّمة بضجيج حاد (طبقات أفقية مثل الحجر الرملي) ومقصوصة من الأسفل
  function rockInto(B, c, s, rng, q, flat, tint) {
    const nu = LOW(q) ? 7 : 12, nv = LOW(q) ? 4 : 7, seed = Math.floor(rng() * 1e5), rows = [];
    const sx = s * (0.8 + rng() * 0.5), sz = s * (0.8 + rng() * 0.5), sy = s * flat * (0.7 + rng() * 0.4), rot = rng() * 6.28;
    for (let i = 0; i <= nv; i++) {
      const th = i / nv * Math.PI, row = [];
      for (let j = 0; j <= nu; j++) {
        const ph = j / nu * Math.PI * 2, d = [Math.sin(th) * Math.cos(ph + rot), Math.cos(th), Math.sin(th) * Math.sin(ph + rot)];
        const f = AA.fbm3(d[0] * 1.8 + seed, d[1] * 1.8, d[2] * 1.8, seed), n = 0.62 + 0.75 * f + 0.18 * Math.abs(AA.noise3(d[0] * 4 + seed, d[1] * 4, d[2] * 4, seed + 1) - 0.5) + 0.05 * Math.round(Math.sin(d[1] * 7 + seed) * 2) / 2; // تكسّر + طبقات
        let y = d[1] * sy * n; if (y < -0.06 * s) y = -0.06 * s - (y + 0.06 * s) * 0.15;
        row.push([c[0] + d[0] * sx * n, c[1] + y, c[2] + d[2] * sz * n]);
      }
      rows.push(row);
    }
    const ids = rows.map((r, i) => r.map((p, j) => B.v(p, vary(AA.mixc(tint, [0.55, 0.48, 0.4], 0.35 * (1 - i / nv) * (p[1] < c[1] + 0.05 * s ? 1 : 0.3)), rng, 0.06), 0, 0, 0, [j / nu * 2 * s, i / nv * s])));
    for (let i = 0; i < nv; i++) for (let j = 0; j < nu; j++) { B.t(ids[i][j], ids[i + 1][j + 1], ids[i + 1][j]); B.t(ids[i][j], ids[i][j + 1], ids[i + 1][j + 1]); }
  }
  function rocks(p, q) {
    const B = new AA.Builder(), rng = AA.rng(p.seed), n = Math.round(p.count), tint = p.tone === 'dark' ? [0.62, 0.52, 0.44] : p.tone === 'red' ? [0.86, 0.6, 0.44] : [0.95, 0.86, 0.74];
    const placed = [];
    for (let k = 0; k < n; k++) {
      const s = p.size * (k === 0 ? 1 : 0.25 + rng() * 0.6);
      let x = 0, z = 0;
      if (k) { let g2 = 0; do { const a = rng() * 6.28, d = p.size * (0.6 + rng() * p.spread); x = Math.cos(a) * d; z = Math.sin(a) * d; g2++; } while (g2 < 30 && placed.some(([px, pz, ps]) => Math.hypot(px - x, pz - z) < (ps + s) * 0.8)); }
      placed.push([x, z, s]);
      rockInto(B, [x, s * p.flat * 0.35, z], s, rng, q, p.flat, tint);
    }
    // حصى صغيرة حول الصخور
    for (let k = 0; k < (LOW(q) ? 4 : 14); k++) { const a = rng() * 6.28, d = p.size * (0.5 + rng() * (p.spread + 0.6)), s = 0.03 + rng() * 0.05; AA.blob(B, [Math.cos(a) * d, s * 0.3, Math.sin(a) * d], [s, 0, 0], [0, s * 0.6, 0], [0, 0, s * 1.2], () => vary(tint, rng, 0.2), 0, 0, 0, rng, 0.4, true); }
    return AA.finalize('rocks', { stone: { builder: B, material: { kind: 'stone', texture: 'sandstone', roughness: 0.95 } } },
      { stiffness: 0, height: p.size * p.flat * 1.3, radius: p.size * (p.spread + 1), collider: { type: 'compound', spheres: placed.map(([x, z, s]) => ({ at: [x, s * p.flat * 0.3, z], r: s * 0.8 })) } });
  }

  AA.assets.rocks = { id: 'rocks', name: 'صخور', nameEn: 'Rocks', category: 'terrain',
    schema: [
      { key: 'size', label: 'حجم الأكبر', min: 0.2, max: 2.5, step: 0.05, def: 0.7, unit: 'م' },
      { key: 'count', label: 'العدد', min: 1, max: 9, step: 1, def: 4 },
      { key: 'spread', label: 'الانتشار', min: 0.3, max: 3, step: 0.1, def: 1.2 },
      { key: 'flat', label: 'التسطّح', min: 0.3, max: 1.2, step: 0.05, def: 0.65 },
      { key: 'tone', label: 'اللون', type: 'enum', options: [['sand', 'رملي'], ['red', 'أحمر'], ['dark', 'داكن']], def: 'sand' }
    ], presets: { 'صخرة كبيرة': { size: 2, count: 2, flat: 0.8 }, 'حصى': { size: 0.25, count: 9, spread: 2.5 } }, generate: rocks };
  AA.rockInto = rockInto;
})(typeof window !== 'undefined' ? window : globalThis);
