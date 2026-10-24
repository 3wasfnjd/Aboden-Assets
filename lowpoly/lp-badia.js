// Aboden Assets — lowpoly/lp-badia.js — البادية بأسلوب لو-بولي: بيت شعر وخيمة قماش
// نفس الأبعاد والمعاملات ونقاط الربط (المجلس، القاطع، أماكن الجلوس، النار) في الحزمة الواقعية.
(function (g) {
  'use strict';
  const AA = g.AA, LP = AA.lp, V = AA.v, vary = AA.vary, lerp = AA.lerp, mixc = AA.mixc, smooth = AA.smooth, clamp = AA.clamp;
  function kit() { const k = {}; for (const n of ['hair', 'wood', 'rope', 'sadu', 'rug', 'cloth', 'canvas', 'lining', 'metal', 'flame', 'ember', 'stone', 'ash', 'woodDark', 'porcelain', 'goods', 'clay', 'metal2', 'glass', 'smoke']) k[n] = new AA.Builder(); return k; }
  function done(id, P, meta) {
    return LP.finalize(id, {
      hair: { builder: P.hair, material: LP.mat('cloth', { doubleSided: true }) }, canvas: { builder: P.canvas, material: LP.mat('cloth') }, lining: { builder: P.lining, material: LP.mat('cloth') },
      wood: { builder: P.wood, material: LP.mat('wood') }, woodDark: { builder: P.woodDark, material: LP.mat('wood') }, rope: { builder: P.rope, material: LP.mat('rope') },
      sadu: { builder: P.sadu, material: LP.mat('cloth', { doubleSided: true }) }, rug: { builder: P.rug, material: LP.mat('rug') }, cloth: { builder: P.cloth, material: LP.mat('cloth', { doubleSided: true }) },
      metal: { builder: P.metal, material: LP.mat('metal', { metalness: 0.5, roughness: 0.35 }) }, metal2: { builder: P.metal2, material: LP.mat('metal', { metalness: 0.4 }) }, porcelain: { builder: P.porcelain, material: LP.mat('porcelain') },
      goods: { builder: P.goods, material: LP.mat('fruit') }, clay: { builder: P.clay, material: LP.mat('clay') }, stone: { builder: P.stone, material: LP.mat('stone') }, ash: { builder: P.ash, material: LP.mat('ash') },
      ember: { builder: P.ember, material: LP.mat('ember', { emissive: [1, 0.32, 0.06], glow: 1.4 }) }, flame: { builder: P.flame, material: LP.mat('flame', { emissive: [1, 0.45, 0.1], glow: 1.5, doubleSided: true }) },
      glass: { builder: P.glass, material: LP.mat('glass', { opacity: 0.35, doubleSided: true }) }, smoke: { builder: P.smoke, material: LP.mat('smoke', { opacity: 0.18, doubleSided: true }) }
    }, Object.assign({ stiffness: 0 }, meta));
  }
  // شبكة سطح: f(i, j) → نقطة، col(p,i,j) لون، want(p) اتجاه الوجه
  function sheet(B, nu, nv, f, col, want, sw) {
    const ids = []; for (let i = 0; i <= nu; i++) { ids.push([]); for (let j = 0; j <= nv; j++) ids[i].push(f(i, j)); }
    for (let i = 0; i < nu; i++) for (let j = 0; j < nv; j++) {
      const a = ids[i][j], b = ids[i + 1][j], c = ids[i + 1][j + 1], d = ids[i][j + 1], cc = col(a, i, j), w = want(a), s = sw ? sw(a) : 0;
      for (const tri of [[a, b, c], [a, c, d]]) { const n = V.cross(V.sub(tri[1], tri[0]), V.sub(tri[2], tri[0])), t = V.dot(n, w) >= 0 ? tri : [tri[0], tri[2], tri[1]]; const ix = t.map(p => B.v(p, cc, s * (p[1] > 0.3 ? 1 : 0), (i + j) * 0.3, s * 0.5)); B.t(ix[0], ix[1], ix[2]); }
    }
    return ids;
  }
  function guy(P, a, b, rng) { LP.prism(P.rope, a, b, 0.012, 0.012, 3, LP.c('#a8865a')); LP.prism(P.woodDark, V.add(b, [0, -0.05, 0]), V.add(b, [(a[0] - b[0]) * 0.02, 0.22, (a[2] - b[2]) * 0.02]), 0.025, 0.018, 4, vary(LP.c('wood'), rng, 0.1)); }

  // ---------- بيت الشعر ----------
  function baitShaar(p, q) {
    const P = kit(), rng = AA.rng(p.seed), L = p.length, D = p.depth, hc = p.height, hf = hc * 0.78, hb = hc * 0.62, nPole = Math.max(2, Math.round(L / 2.6)), sp = L / nPole, low = q === 'low';
    const poleX = []; for (let k = 0; k <= nPole; k++) poleX.push(-L / 2 + k * sp);
    const C = p.color === 'brown' ? ['#4a3a2e', '#5a4636', '#c9b48a'] : ['#2b2522', '#3a322c', '#bfb4a0'];
    const hairCol = (pt, i, j) => vary(LP.c(j % 4 === 2 ? C[1] : C[0]), rng, 0.05);
    const base = z => { const t = (z + D / 2) / D; return t < 0.5 ? lerp(hb, hc, smooth(0, 1, t * 2) * 0.7 + t * 2 * 0.3) : lerp(hc, hf, smooth(0, 1, (t - 0.5) * 2) * 0.7 + (t - 0.5) * 2 * 0.3); };
    const roofH = (x, z) => { let dx = Infinity; for (const px of poleX) dx = Math.min(dx, Math.abs(x - px)); const edge = Math.abs(z) / (D / 2), sag = (0.1 + 0.16 * edge) * (1 - Math.cos(Math.PI * clamp(dx / (sp / 2), 0, 1))) / 2; return base(z) - sag; };
    const nu = nPole * (low ? 2 : 4), nv = low ? 4 : 7, ov = 0.15;
    sheet(P.hair, nu, nv, (i, j) => { const x = lerp(-L / 2 - ov, L / 2 + ov, i / nu), z = lerp(-D / 2, D / 2, j / nv); return [x, roofH(x, z), z]; }, hairCol, () => [0, 1, 0], pp => 0.04 * Math.abs(pp[2]) / D);
    sheet(P.hair, nu, 1, (i, j) => { const x = lerp(-L / 2 - ov, L / 2 + ov, i / nu), y0 = roofH(x, D / 2); return [x, y0 - 0.32 * j, D / 2 + 0.02 * j]; }, (pt, i) => LP.c(i % 3 === 1 ? C[2] : C[1]), () => [0, 0, 1]);
    const br = low ? 2 : 4;
    sheet(P.hair, nu, br, (i, j) => { const x = lerp(-L / 2 - ov, L / 2 + ov, i / nu), t = j / br, y0 = roofH(x, -D / 2); return [x, lerp(y0, 0.02, t), -D / 2 - 0.35 * t * t]; }, hairCol, () => [0, 0, -1]);
    if (p.sides) for (const sx of [1, -1]) { const nz = low ? 3 : 6, ny = low ? 2 : 4, xE = sx * (L / 2 + ov);
      sheet(P.hair, nz, ny, (i, j) => { const z = lerp(-D / 2, D / 2 * (1 - 0.35 * p.open), i / nz), t = j / ny; return [xE + sx * 0.25 * t * t, lerp(roofH(xE, z), 0.02, t), z]; }, hairCol, () => [sx, 0, 0]); }
    for (const px of poleX) for (const z of [-D / 2 + 0.05, 0, D / 2 - 0.02]) { if (z < 0 && (px === poleX[0] || px === poleX[nPole])) continue; LP.prism(P.wood, [px, 0, z], [px, roofH(px, z) - 0.01, z], 0.045, 0.038, 5, vary(LP.c('woodLight'), rng, 0.1)); }
    for (const px of poleX) for (const sz of [1, -1]) { const z = sz * D / 2; guy(P, [px, roofH(px, z) - 0.02, z + sz * 0.02], [px * 1.08, 0.02, sz * (D / 2 + 1.7 + hc * 0.4)], rng); }
    for (const sx of [1, -1]) for (const z of [-D / 4, D / 4]) guy(P, [sx * (L / 2 + ov), roofH(sx * L / 2, z), z], [sx * (L / 2 + 1.8), 0.02, z * 1.3], rng);
    const xd = L / 2 - L * p.majlis, SADU = ['#8a2a24', '#efe4cf', '#1f1b1a', '#c8a24a'];
    if (p.divider) sheet(P.sadu, 2, low ? 3 : 6, (i, j) => { const z = lerp(-D / 2 + 0.05, D / 2 - 0.25, j / (low ? 3 : 6)), y = i === 0 ? 0.02 : i === 1 ? roofH(xd, z) * 0.5 : roofH(xd, z) - 0.03; return [xd, y, z]; }, (pt, i, j) => LP.c(SADU[(i + j) % 4]), () => [1, 0, 0]);
    const M = LP.majlis, mw = L * p.majlis - 0.5, mx = (xd + L / 2) / 2;
    if (p.furnish && M) {
      M.rugInto(P, { at: [mx, 0, 0] }, mw, D - 0.8, rng, true);
      M.seatRun(P, { at: [mx, 0, -D / 2 + 0.55] }, mw - 0.4, rng);
      if (mw > 2.6) M.seatRun(P, { at: [L / 2 - 0.45, 0, 0.2], rot: -Math.PI / 2 }, D - 2.0, rng);
      M.flameInto(P, [mx - 0.2, 0.07, D / 2 - 1.0], 0.38, rng, low ? 3 : 5);
      for (let k = 0; k < 8; k++) { const a = k / 8 * Math.PI * 2; LP.rockInto(P.stone, [mx - 0.2 + Math.cos(a) * 0.32, 0.05, D / 2 - 1.0 + Math.sin(a) * 0.32], 0.08, rng, 0.7, ['#b8ab98', '#a09582', '#8a7f6e'], 0); }
      for (let k = 0; k < 4; k++) { const a = k / 4 * Math.PI * 2 + 0.4; LP.prism(P.woodDark, [mx - 0.2 + Math.cos(a) * 0.3, 0.05, D / 2 - 1.0 + Math.sin(a) * 0.3], [mx - 0.2, 0.15, D / 2 - 1.0], 0.028, 0.02, 4, LP.c('#5e4a3a')); }
      M.dallahInto(P.metal, [mx + 0.25, 0.04, D / 2 - 0.85], 1, -1.3, 'brass'); M.dallahInto(P.metal, [mx + 0.2, 0.04, D / 2 - 1.2], 0.8, -2.0, 'brass');
      const wx = (-L / 2 + xd) / 2, ww = xd + L / 2 - 0.5;
      if (ww > 1.2) { M.rugInto(P, { at: [wx, 0, 0.2] }, ww, D - 1.4, rng, false); M.seatRun(P, { at: [wx, 0, -D / 2 + 0.55] }, Math.max(1, ww - 0.6), rng); M.jarInto(P, [-L / 2 + 0.5, 0.02, D / 2 - 0.6], 'burma', 1.3, rng); M.jarInto(P, [-L / 2 + 0.85, 0.02, D / 2 - 0.7], 'jarra', 1.2, rng); }
    }
    const seats = []; if (p.furnish) { const n = Math.max(1, Math.floor((mw - 0.4) / 0.8)); for (let k = 0; k < n; k++) seats.push({ at: [mx - (mw - 0.4) / 2 + (k + 0.5) * (mw - 0.4) / n, 0.17, -D / 2 + 0.53], rot: 0 }); }
    return done('lp_bait_shaar', P, { height: hc + 0.1, radius: Math.hypot(L / 2 + 2, D / 2 + 2.5), collider: { type: 'compound' }, seats, majlis: { x: mx, width: mw }, divider: xd,
      light: p.furnish ? { at: [mx - 0.2, 0.4, D / 2 - 1.0], color: [1, 0.55, 0.2], intensity: 2.2, distance: 9, flicker: true } : null });
  }

  // ---------- خيمة قماش ----------
  function khaima(p, q) {
    const P = kit(), rng = AA.rng(p.seed), low = q === 'low', col = LP.c(p.color === 'beige' ? '#e2d3b2' : p.color === 'green' ? '#7d8a5a' : '#f1ede4'), trim = LP.c('#2f5f8a'), M = LP.majlis;
    const cc = (pt, i, j) => vary(j === 2 ? trim : col, rng, 0.03), lin = (pt, i, j) => LP.c(['#8a2a24', '#efe4cf', '#1f1b1a'][(i + j) % 3]);
    let light = null, H;
    if (p.style === 'bell') {
      const R = p.size, wallH = 1.35, apex = 2.0 + R * 0.45, door = 0.32, n = low ? 10 : 18;
      H = apex;
      const prof = [[0.02, R * 1.02], [wallH * 0.5, R], [wallH, R], [wallH + 0.06, R * 1.03], [lerp(wallH, apex, 0.4), R * 0.62], [apex, 0.08]];
      const angs = []; for (let k = 0; k <= n; k++) angs.push(lerp(door, Math.PI * 2 - door, k / n));
      const pt = (a, y, r) => [Math.sin(a) * r, y, Math.cos(a) * r];
      sheet(P.canvas, n, prof.length - 1, (i, j) => pt(angs[i], prof[j][0], prof[j][1]), cc, pp => [pp[0], 0.3, pp[2]]);
      sheet(P.lining, n, prof.length - 1, (i, j) => pt(angs[i], prof[j][0], prof[j][1] - 0.015), lin, pp => [-pp[0], -0.3, -pp[2]]);
      sheet(P.canvas, 3, 2, (i, j) => { const a = lerp(-door, door, i / 3), y = lerp(wallH + 0.06, apex, j / 2), r = lerp(R * 1.03, 0.08, j / 2); return pt(a, y, r); }, () => col, pp => [pp[0] * 0.3, 0.8, pp[2] * 0.3]);
      for (const s2 of [1, -1]) { const c = pt(s2 * door, wallH * 0.98, R + 0.04); LP.prism(P.canvas, [c[0], 0.3, c[2]], [c[0], wallH, c[2]], 0.07, 0.07, 6, col); }
      LP.prism(P.wood, [0, 0, 0], [0, apex + 0.12, 0], 0.05, 0.04, 6, LP.c('woodLight'));
      LP.prism(P.canvas, [0, apex - 0.05, 0], [0, apex + 0.1, 0], 0.14, 0.0, 8, mixc(col, [0.4, 0.3, 0.2], 0.3));
      for (let k = 0; k < 8; k++) { const a = (k + 0.5) / 8 * Math.PI * 2; guy(P, pt(a, wallH + 0.05, R * 1.03), pt(a, 0.02, R + 1.5), rng); }
      if (p.furnish && M) { M.rugInto(P, { at: [0, 0, 0] }, R * 1.3, R * 1.3, rng, false); M.seatRun(P, { at: [0, 0, -R + 0.55] }, R * 1.2, rng); M.lanternInto(P, { at: [0.25, 1.5, 0.05] }, 1, true); light = { at: [0.25, 1.6, 0.05], color: [1, 0.7, 0.35], intensity: 1.2, distance: 6, flicker: true }; }
    } else {
      const Lx = p.size * 1.6, Dz = p.size * 1.15, wallH = 1.6, ridge = 2.7, door = 0.55, nx = low ? 3 : 6;
      H = ridge;
      const rf = z => lerp(wallH + 0.05, ridge, 1 - Math.abs(z) / (Dz / 2 + 0.15));
      for (const [B, out, ins, cf] of [[P.canvas, 1, 0, cc], [P.lining, -1, 0.015, lin]]) {
        for (const sz of [1, -1]) sheet(B, nx, 2, (i, j) => { const x = lerp(-Lx / 2 - 0.15, Lx / 2 + 0.15, i / nx), z = sz * lerp(0, Dz / 2 + 0.15, j / 2); return [x, rf(z) - ins, z]; }, cf, () => [0, out, sz * out * 0.5]);
        for (const sz of [1, -1]) { const segs = sz > 0 ? [[-Lx / 2, -door], [door, Lx / 2]] : [[-Lx / 2, Lx / 2]]; for (const [x0, x1] of segs) sheet(B, 2, 1, (i, j) => [lerp(x0, x1, i / 2), lerp(0.02, wallH, j), sz * (Dz / 2 - ins)], cf, () => [0, 0, sz * out]); }
        for (const sx of [1, -1]) { sheet(B, 3, 1, (i, j) => [sx * (Lx / 2 - ins), lerp(0.02, wallH, j), lerp(-Dz / 2, Dz / 2, i / 3)], cf, () => [sx * out, 0, 0]); sheet(B, 2, 1, (i, j) => { const z = lerp(-Dz / 2, Dz / 2, i / 2); return [sx * (Lx / 2 - ins), lerp(wallH, rf(z), j), z]; }, cf, () => [sx * out, 0, 0]); }
      }
      LP.prism(P.canvas, [-door, wallH - 0.05, Dz / 2 + 0.06], [door, wallH - 0.05, Dz / 2 + 0.06], 0.09, 0.09, 6, col);
      for (const x of [-Lx / 2, 0, Lx / 2]) LP.prism(P.wood, [x * 0.98, 0, 0], [x * 0.98, (x === 0 ? ridge : wallH) + 0.05, 0], 0.045, 0.04, 5, LP.c('woodLight'));
      LP.prism(P.wood, [-Lx / 2, ridge - 0.04, 0], [Lx / 2, ridge - 0.04, 0], 0.035, 0.035, 5, LP.c('woodLight'));
      for (const sz of [1, -1]) for (let k = 0; k <= 3; k++) { const x = lerp(-Lx / 2, Lx / 2, k / 3); guy(P, [x, wallH + 0.05, sz * (Dz / 2 + 0.15)], [x * 1.1, 0.02, sz * (Dz / 2 + 1.6)], rng); }
      if (p.furnish && M) { M.rugInto(P, { at: [0, 0, 0] }, Lx - 0.4, Dz - 0.4, rng, false); M.seatRun(P, { at: [0, 0, -Dz / 2 + 0.5] }, Lx - 0.6, rng); M.lanternInto(P, { at: [0.3, 1.7, 0] }, 1, true); light = { at: [0.3, 1.8, 0], color: [1, 0.7, 0.35], intensity: 1.2, distance: 6, flicker: true }; }
    }
    return done('lp_khaima', P, { height: H + 0.2, radius: p.size * 1.6 + 1.6, collider: { type: 'compound' }, door: { z: 1, width: 0.9 }, light });
  }
  LP.def('bait_shaar', baitShaar); LP.def('khaima', khaima);
})(typeof window !== 'undefined' ? window : globalThis);
