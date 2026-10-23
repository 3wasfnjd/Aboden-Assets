// Aboden Assets — lowpoly/lp-architecture.js — بيت نجدي لو-بولي
(function (g) {
  'use strict';
  const AA = g.AA, LP = AA.lp, V = AA.v, vary = AA.vary, mixc = AA.mixc;

  // شُرفة: قاعدة + درجة + رأس هرمي
  function crenel(B, c, k, col, colTop, rot) {
    const o = { at: c, rot: rot || 0 };
    AA.box(B, [0, 0.06 * k, 0], [0.42 * k, 0.12 * k, 0.2 * k], col, 1, o);
    AA.box(B, [0, 0.17 * k, 0], [0.26 * k, 0.12 * k, 0.18 * k], col, 1, o);
    const t = [0, 0.38 * k, 0], b = [[-0.12, 0.23, 0.08], [0.12, 0.23, 0.08], [0.12, 0.23, -0.08], [-0.12, 0.23, -0.08]].map(p => AA.xform(p.map(v => v * k), o));
    const tw = AA.xform(t, o);
    for (let i = 0; i < 4; i++) LP.tri(B, b[i], b[(i + 1) % 4], tw, colTop, V.sub(V.scale(V.add(b[i], b[(i + 1) % 4]), 0.5), AA.xform([0, 0.2 * k, 0], o)));
  }
  function house(p, q) {
    const rng = AA.rng(p.seed), Wl = new AA.Builder(), Dk = new AA.Builder(), Wd = new AA.Builder(), Dr = new AA.Builder();
    const W = p.width, D = p.depth, F = Math.round(p.floors), fh = 3.0, Hroof = F * fh, Hp = Hroof + 0.8;
    const wall = LP.c('mud'), wallL = LP.c('mudLight'), wallD = LP.c('mudDark');
    const shade = (c, k) => vary(c, rng, k || 0.06);
    // الكتلة: جسم مع ميلان بسيط للداخل (منشور 4 أضلاع)
    const tw = (y) => 1 - 0.012 * y;
    const box4 = (y0, y1, w, d, col) => { // صندوق بأوجه مائلة قليلاً
      const c0 = [[-w / 2, y0, d / 2], [w / 2, y0, d / 2], [w / 2, y0, -d / 2], [-w / 2, y0, -d / 2]].map(p => [p[0] * tw(y0), p[1], p[2] * tw(y0)]);
      const c1 = [[-w / 2, y1, d / 2], [w / 2, y1, d / 2], [w / 2, y1, -d / 2], [-w / 2, y1, -d / 2]].map(p => [p[0] * tw(y1), p[1], p[2] * tw(y1)]);
      for (let i = 0; i < 4; i++) { const j = (i + 1) % 4, n = [[0, 0, 1], [1, 0, 0], [0, 0, -1], [-1, 0, 0]][i]; AA.quad(Wl, [c0[i], c0[j], c1[j], c1[i]], [[0, 0], [1, 0], [1, 1], [0, 1]], [shade(col)], n); }
      AA.quad(Wl, c1, [[0, 0], [1, 0], [1, 1], [0, 1]], [wallL], [0, 1, 0]);
    };
    box4(0, Hp, W, D, wall);
    // شريط أغمق عند الأرض وخط بين الأدوار
    for (const [y, h] of [[0.15, 0.3]].concat(F > 1 ? [[fh, 0.08]] : [])) AA.box(Wl, [0, y, 0], [W * tw(y) + 0.04, h, D * tw(y) + 0.04], wallD, 1, {});
    // الدروة: طوق خفيف أفتح فوق السطح
    AA.box(Wl, [0, Hp + 0.04, 0], [W * tw(Hp) + 0.06, 0.08, D * tw(Hp) + 0.06], wallL, 1, {});
    // الشُّرَف على الأطراف
    const zF = D / 2 * tw(Hp), xF = W / 2 * tw(Hp);
    for (const [len, at, rot] of [[W, [0, Hp + 0.08, zF - 0.1], 0], [W, [0, Hp + 0.08, -zF + 0.1], Math.PI], [D, [xF - 0.1, Hp + 0.08, 0], Math.PI / 2], [D, [-xF + 0.1, Hp + 0.08, 0], -Math.PI / 2]]) {
      const n = Math.max(2, Math.round((len - 1) / 0.9));
      for (let k = 1; k < n; k++) crenel(Wl, AA.xform([-len / 2 + k * len / n, 0, 0], { at, rot }), 1, wallL, LP.c('mudLight'), rot);
    }
    for (const sx of [1, -1]) for (const sz of [1, -1]) crenel(Wl, [sx * (xF - 0.2), Hp + 0.08, sz * (zF - 0.2)], 1.45, wallL, LP.c('mudLight'), 0);
    // الباب النجدي الملوّن + عتبة خشب
    const dx = (rng() - 0.5) * (W - 3), dw = 1.1, dh = 2.1, zf = D / 2 * tw(1) + 0.01;
    AA.box(Dk, [dx, dh / 2, zf - 0.02], [dw + 0.12, dh + 0.08, 0.06], LP.c('dark'), 1, {});
    AA.box(Dr, [dx, dh / 2, zf + 0.01], [dw, dh, 0.05], LP.c('teal'), 1, {});
    for (const y of [0.45, 1.05, 1.65]) AA.box(Dr, [dx, y, zf + 0.04], [dw - 0.12, 0.1, 0.02], LP.c('yellow'), 1, {});
    AA.box(Dr, [dx, dh * 0.55, zf + 0.045], [0.05, 0.05, 0.02], LP.c('white'), 1, {});
    AA.box(Wd, [dx, dh + 0.12, zf + 0.04], [dw + 0.5, 0.14, 0.14], LP.c('wood'), 1, {});
    // نوافذ صغيرة ومثلثات تهوية
    const face = (side) => side === 'f' ? { z: D / 2, L: W, rot: 0 } : side === 'b' ? { z: D / 2, L: W, rot: Math.PI } : side === 'r' ? { z: W / 2, L: D, rot: Math.PI / 2 } : { z: W / 2, L: D, rot: -Math.PI / 2 };
    for (const sd of ['f', 'r', 'l', 'b']) {
      const fc = face(sd);
      for (let f = 0; f < F; f++) {
        const nw = Math.max(1, Math.floor((fc.L - 1) / 2.4));
        for (let k = 0; k < nw; k++) {
          const x = -fc.L / 2 + (k + 0.5) * fc.L / nw, y = f * fh + 1.55;
          if (sd === 'f' && f === 0 && Math.abs(x - dx) < 1.1) continue;
          if (rng() < 0.25) continue;
          const zz = fc.z * tw(y) + 0.005, o = { rot: fc.rot };
          AA.box(Dk, [x, y, zz], [0.4, 0.5, 0.03], LP.c('dark'), 1, o);
          AA.box(Wd, [x, y - 0.3, zz + 0.04], [0.6, 0.06, 0.1], LP.c('wood'), 1, o);
        }
      }
      // صف مثلثات تهوية تحت الدروة
      const yv = Hroof + 0.25, zz = fc.z * tw(yv) + 0.01;
      for (let x = -fc.L / 2 + 0.6; x < fc.L / 2 - 0.5; x += 0.42) {
        const o = { rot: fc.rot }, a = AA.xform([x - 0.09, yv, zz], o), b = AA.xform([x + 0.09, yv, zz], o), c = AA.xform([x, yv + 0.2, zz], o);
        LP.tri(Dk, a, b, c, LP.c('dark'), AA.xform([0, 0, 1], o));
      }
      // رؤوس جذوع السقف بين الأدوار
      for (let f = 1; f <= F; f++) for (let x = -fc.L / 2 + 0.5; x < fc.L / 2 - 0.3; x += 0.7) {
        const y = f * fh - 0.15, o = { rot: fc.rot };
        AA.box(Wd, [x, y, fc.z * tw(y) + 0.1], [0.12, 0.12, 0.22], LP.c('woodDark'), 1, o);
      }
    }
    // مزراب
    AA.box(Wd, [dx > 0 ? -W / 4 : W / 4, Hroof + 0.05, zF + 0.4], [0.18, 0.12, 0.8], LP.c('wood'), 1, {});
    // غرفة سطح اختيارية
    if (p.roofRoom) {
      const rw = Math.max(2.6, W * 0.4), rd = Math.max(2.4, D * 0.4), cx = W / 2 - rw / 2 - 0.4, cz = -D / 2 + rd / 2 + 0.4;
      AA.box(Wl, [cx, Hp + 1.25, cz], [rw, 2.5, rd], shade(wall), 1, {});
      AA.box(Wl, [cx, Hp + 2.55, cz], [rw + 0.06, 0.1, rd + 0.06], wallL, 1, {});
      AA.box(Dr, [cx, Hp + 0.95, cz + rd / 2 + 0.01], [0.85, 1.8, 0.05], LP.c('red'), 1, {});
      for (const sx of [1, -1]) for (const sz of [1, -1]) crenel(Wl, [cx + sx * (rw / 2 - 0.2), Hp + 2.6, cz + sz * (rd / 2 - 0.2)], 1.2, wallL, LP.c('mudLight'), 0);
    }
    return LP.finalize('lp_house', {
      walls: { builder: Wl, material: LP.mat('mud') },
      dark:  { builder: Dk, material: LP.mat('dark') },
      wood:  { builder: Wd, material: LP.mat('wood') },
      door:  { builder: Dr, material: LP.mat('wood') }
    }, { stiffness: 0, height: Hp + (p.roofRoom ? 3 : 0.6), radius: Math.max(W, D) / 2, collider: { type: 'box', size: [W, Hp, D] }, door: { x: dx, z: D / 2, width: dw } });
  }

  AA.assets.lp_house = { id: 'lp_house', name: 'بيت نجدي', nameEn: 'Low-poly Najdi house', category: 'lowpoly',
    schema: [
      { key: 'width', label: 'العرض', min: 5, max: 14, step: 0.5, def: 8, unit: 'م' },
      { key: 'depth', label: 'العمق', min: 5, max: 12, step: 0.5, def: 7, unit: 'م' },
      { key: 'floors', label: 'الأدوار', min: 1, max: 2, step: 1, def: 2 },
      { key: 'roofRoom', label: 'غرفة سطح', type: 'bool', def: true }
    ], presets: { 'بيت صغير': { width: 6, depth: 5.5, floors: 1, roofRoom: false } }, generate: house };
})(typeof window !== 'undefined' ? window : globalThis);
