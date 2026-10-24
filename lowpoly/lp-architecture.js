// Aboden Assets — lowpoly/lp-architecture.js — العمارة النجدية بأسلوب لو-بولي
// كل القطع بنفس معاملات وأبعاد ونقاط ربط الحزمة الواقعية: جدران، واجهات، شُرَف، أعمدة، أبراج، دكّة،
// بيت نجدي، حوض وساقية وبئر، سور وبوابة ومسجد ومئذنة. الطين مسطّح الأوجه بدرجات لونية بسيطة.
(function (g) {
  'use strict';
  const AA = g.AA, LP = AA.lp, V = AA.v, vary = AA.vary, mixc = AA.mixc, lerp = AA.lerp, smooth = AA.smooth;
  const X = (o, p) => AA.xform(p, o), RD = (o, d) => { if (!o || !o.rot) return d; const c = Math.cos(o.rot), s = Math.sin(o.rot); return [d[0] * c + d[2] * s, d[1], -d[0] * s + d[2] * c]; };
  const MUD = { wall: 'mud', top: 'mudLight', dark: 'mudDark' }, WHITE = { wall: '#ece3d4', top: '#f6efe3', dark: '#d6cbb8' };
  const DOORS = ['teal', '#2f6fa3', '#8a5a34', '#3b8c6e'];
  function kit() { return { wall: new AA.Builder(), top: new AA.Builder(), dark: new AA.Builder(), wood: new AA.Builder(), door: new AA.Builder() }; }
  function done(id, P, meta, extra) {
    const parts = { wall: { builder: P.wall, material: LP.mat('mud') }, top: { builder: P.top, material: LP.mat('mud') }, dark: { builder: P.dark, material: LP.mat('dark') },
      wood: { builder: P.wood, material: LP.mat('wood') }, door: { builder: P.door, material: LP.mat('wood') } };
    return LP.finalize(id, Object.assign(parts, extra || {}), Object.assign({ stiffness: 0 }, meta));
  }
  // رباعي بأوجه للخارج (want = اتجاه الوجه المطلوب)
  const quad = (B, a, b, c, d, col, want) => { LP.tri(B, a, b, c, col, want); LP.tri(B, a, c, d, col, want); };

  // لوح طيني: x من x0 إلى x1، y من y0 إلى top(x)، سماكة T حول z=0، ويتراجع الوجهان للداخل بمقدار taper عند الارتفاع Href
  // opt = { n, xs (نقاط كسر إضافية)، taper، Href، col، colTop، rng، bottom، ends }
  function panel(P, o, x0, x1, y0, top, T, opt) {
    opt = opt || {}; const rng = opt.rng || Math.random, n = Math.max(1, opt.n || Math.ceil((x1 - x0) / 1.2)), Href = opt.Href || 3, tp = opt.taper || 0;
    const C = opt.colors || MUD, wallC = () => vary(LP.c(C.wall), rng, 0.05), topC = LP.c(C.top);
    let xs = []; for (let i = 0; i <= n; i++) xs.push(lerp(x0, x1, i / n));
    if (opt.xs) xs = xs.concat(opt.xs.filter(x => x > x0 + 1e-3 && x < x1 - 1e-3)).sort((a, b) => a - b);
    const zf = y => Math.max(0.02, T / 2 - tp * y / Href);
    const F = (x, y, s) => X(o, [x, y, s * zf(y)]);
    for (let i = 0; i < xs.length - 1; i++) {
      const xa = xs[i], xb = xs[i + 1], ya = top(xa), yb = top(xb), c = wallC();
      quad(P.wall, F(xa, y0, 1), F(xb, y0, 1), F(xb, yb, 1), F(xa, ya, 1), c, RD(o, [0, 0, 1]));
      quad(P.wall, F(xb, y0, -1), F(xa, y0, -1), F(xa, ya, -1), F(xb, yb, -1), wallC(), RD(o, [0, 0, -1]));
      quad(P.top, F(xa, ya, 1), F(xb, yb, 1), F(xb, yb, -1), F(xa, ya, -1), topC, RD(o, [0, 1, 0]));
      if (opt.bottom) quad(P.wall, F(xa, y0, 1), F(xa, y0, -1), F(xb, y0, -1), F(xb, y0, 1), c, RD(o, [0, -1, 0]));
    }
    if (opt.ends !== false) for (const [x, s] of [[x0, -1], [x1, 1]]) quad(P.wall, F(x, y0, 1), F(x, y0, -1), F(x, top(x), -1), F(x, top(x), 1), wallC(), RD(o, [s, 0, 0]));
    return { faceZ: zf };
  }
  // لوح بفتحات: openings = [{x0,x1,y0,y1}] (أبواب حتى الأرض أو نوافذ) — يقسَّم إلى ألواح حولها
  function panelOpen(P, o, L, H, T, top, ops, opt) {
    const cuts = [-L / 2]; for (const op of ops) cuts.push(op.x0, op.x1); cuts.push(L / 2);
    for (let i = 0; i < cuts.length - 1; i += 2) if (cuts[i + 1] - cuts[i] > 1e-3) panel(P, o, cuts[i], cuts[i + 1], 0, top, T, Object.assign({}, opt, { n: Math.max(1, Math.ceil((cuts[i + 1] - cuts[i]) / 1.2)) }));
    for (const op of ops) {
      panel(P, o, op.x0, op.x1, op.y1, top, T, Object.assign({}, opt, { n: 1, bottom: true, ends: false }));
      if (op.y0 > 0.01) panel(P, o, op.x0, op.x1, 0, () => op.y0, T, Object.assign({}, opt, { n: 1, ends: false }));
    }
    return { faceZ: y => Math.max(0.02, T / 2 - (opt.taper || 0) * y / (opt.Href || 3)) };
  }
  // كتلة طينية مائلة الأوجه (برج، دكّة، قاعدة) بقرون اختيارية في زوايا القمة
  function block(P, o, sx, sz, y0, h, opt) {
    opt = opt || {}; const rng = opt.rng || Math.random, C = opt.colors || MUD, tpx = opt.taperX || 0, tpz = opt.taperZ || 0;
    const corners = (y, k) => [[-1, 1], [1, 1], [1, -1], [-1, -1]].map(([a, b]) => X(o, [a * (sx / 2 - tpx * k), y, b * (sz / 2 - tpz * k)]));
    const c0 = corners(y0, 0), c1 = corners(y0 + h, 1), N = [[0, 0, 1], [1, 0, 0], [0, 0, -1], [-1, 0, 0]];
    for (let i = 0; i < 4; i++) { const j = (i + 1) % 4; quad(P.wall, c0[i], c0[j], c1[j], c1[i], vary(LP.c(C.wall), rng, 0.05), RD(o, N[i])); }
    quad(P.top, c1[0], c1[1], c1[2], c1[3], LP.c(C.top), RD(o, [0, 1, 0]));
    if (opt.horns) for (const c of c1) { const ctr = X(o, [0, y0 + h, 0]), d = V.norm(V.sub([c[0], 0, c[2]], [ctr[0], 0, ctr[2]])), b = V.sub(c, V.scale(d, opt.horns * 0.45)); LP.prism(P.top, b, V.add(b, [0, opt.horns, 0]), opt.horns * 0.42, 0.02, 4, LP.c(C.top), { rot: Math.PI / 4 + (o.rot || 0) }); }
    if (opt.bottom) quad(P.wall, c0[3], c0[2], c0[1], c0[0], LP.c(C.dark), RD(o, [0, -1, 0]));
    return { faceAt: y => sz / 2 - tpz * (y - y0) / h, faceXAt: y => sx / 2 - tpx * (y - y0) / h };
  }
  // تفاصيل: مثلث تهوية، نافذة داكنة بعتبة، رؤوس جذوع، باب نجدي، شُرفة
  function vent(P, o, x, y, z, s) { LP.tri(P.dark, X(o, [x - s * 0.55, y, z]), X(o, [x + s * 0.55, y, z]), X(o, [x, y + s * 1.1, z]), LP.c('dark'), RD(o, [0, 0, 1])); }
  function win(P, o, x, y, z, w, h, sill) {
    quad(P.dark, X(o, [x - w / 2, y - h / 2, z]), X(o, [x + w / 2, y - h / 2, z]), X(o, [x + w / 2, y + h / 2, z]), X(o, [x - w / 2, y + h / 2, z]), LP.c('dark'), RD(o, [0, 0, 1]));
    if (sill) AA.box(P.wood, [x, y - h / 2 - 0.05, z + 0.04], [w + 0.18, 0.06, 0.1], LP.c('wood'), 1, o);
  }
  function beams(P, o, x0, x1, y, z, step) { for (let x = x0; x <= x1 + 1e-6; x += step || 0.7) AA.box(P.wood, [x, y, z + 0.1], [0.12, 0.12, 0.22], LP.c('woodDark'), 1, o); }
  function doorLeaf(P, o, x0, w, h, z, color, open) { // ضلفة باب نجدي: ملوّنة بأشرطة صفراء ومقبض
    const oo = open ? { at: X(o, [x0, 0, z]), rot: (o.rot || 0) + open } : { at: X(o, [x0, 0, z]), rot: o.rot || 0 };
    AA.box(P.door, [w / 2, h / 2, 0.025], [w, h, 0.05], LP.c(color), 1, oo);
    for (const y of [0.22, 0.5, 0.78]) AA.box(P.door, [w / 2, h * y, 0.055], [w - 0.12, 0.09, 0.02], LP.c('yellow'), 1, oo);
    for (let k = 0; k < 3; k++) LP.tri(P.door, AA.xform([0.15 + k * (w - 0.3) / 2 - 0.08, h * 0.64, 0.056], oo), AA.xform([0.15 + k * (w - 0.3) / 2 + 0.08, h * 0.64, 0.056], oo), AA.xform([0.15 + k * (w - 0.3) / 2, h * 0.7, 0.056], oo), LP.c('white'), RD(oo, [0, 0, 1]));
    AA.box(P.door, [w * 0.82, h * 0.5, 0.06], [0.05, 0.05, 0.03], LP.c('#d8d2c8'), 1, oo);
  }
  function crenel(P, at, k, rot, C, corner) { // شُرفة نجدية: ثلاث درجات ورأس هرمي
    const o = { at, rot: rot || 0 }, cc = C || MUD, d = corner ? null : 0.24 * k;
    let y = 0;
    for (const w of [0.9, 0.66, 0.44]) { AA.box(P.wall, [0, y + 0.12 * k, 0], [w * k, 0.24 * k, corner ? w * k : d], vary(LP.c(cc.top), Math.random, 0.03), 1, o); y += 0.24 * k; }
    const tw = 0.42 * k / 2, tz = corner ? tw : d / 2, tip = X(o, [0, y + 0.34 * k, 0]), b = [[-tw, tz], [tw, tz], [tw, -tz], [-tw, -tz]].map(([x, z]) => X(o, [x, y, z]));
    for (let i = 0; i < 4; i++) { const m = V.scale(V.add(b[i], b[(i + 1) % 4]), 0.5); LP.tri(P.top, b[i], b[(i + 1) % 4], tip, LP.c(cc.top), V.sub(m, X(o, [0, y, 0]))); }
    return y + 0.34 * k;
  }
  function crenelRow(P, o, L, y, z, k, step, C) {
    const n = Math.max(1, Math.round(L / (step || 0.9)));
    for (let i = 0; i < n; i++) crenel(P, X(o, [-L / 2 + (i + 0.5) * L / n, y, z]), k, o.rot || 0, C);
  }
  function wornPatches(P, o, L, H, z, rng, n) { // طوب ظاهر: بقع أغمق بارزة قليلاً
    for (let i = 0; i < n; i++) { const x = (rng() - 0.5) * (L - 0.6), y = 0.3 + rng() * (H - 0.8), w = 0.3 + rng() * 0.5, h = 0.18 + rng() * 0.3;
      AA.box(P.wall, [x, y, z + 0.01], [w, h, 0.04], LP.c(MUD.dark), 1, o); }
  }
  const wavy = (H, seed, a) => x => H + (a || 0.035) * Math.sin(x * 2.3 + seed) + 0.02 * Math.sin(x * 5.1 + seed * 2);

  // ---------- الجدران ----------
  function wall(p, q) {
    const P = kit(), rng = AA.rng(p.seed), ph = rng() * 6.28, L = p.length, H = p.height, T = p.thickness;
    const r = panel(P, {}, -L / 2, L / 2, 0, wavy(H, ph), T, { taper: 0.04, Href: H, rng });
    if (p.beams) beams(P, {}, -L / 2 + 0.4, L / 2 - 0.3, H - 0.45, r.faceZ(H - 0.45));
    if (p.worn) for (const s of [0, Math.PI]) wornPatches(P, { rot: s }, L, H, r.faceZ(1.2), rng, Math.round(L));
    return done('lp_wall', P, { height: H, radius: L / 2, collider: { type: 'box', size: [L, H, T] }, snap: { length: L } });
  }
  function corner(p, q) {
    const P = kit(), rng = AA.rng(p.seed), A = p.arm, T = p.thickness, H = p.height;
    panel(P, { at: [A / 2 - T / 2, 0, 0] }, -A / 2, A / 2, 0, wavy(H, 1), T, { taper: 0.04, Href: H, rng });
    panel(P, { at: [0, 0, -(A / 2 - T / 2)], rot: Math.PI / 2 }, -A / 2, A / 2, 0, wavy(H, 2), T, { taper: 0.04, Href: H, rng });
    if (p.worn) wornPatches(P, { at: [A / 2 - T / 2, 0, 0] }, A, H, T / 2 - 0.03, rng, 3);
    return done('lp_wall_corner', P, { height: H, radius: A, collider: { type: 'compound' } });
  }
  function wallDoor(p, q) {
    const P = kit(), rng = AA.rng(p.seed), L = p.length, H = p.height, T = p.thickness, w = p.doorWidth, h = p.doorHeight;
    const r = panelOpen(P, {}, L, H, T, wavy(H, 1, 0.03), [{ x0: -w / 2, x1: w / 2, y0: 0, y1: h }], { taper: 0.04, Href: H, rng });
    AA.box(P.wood, [0, h + 0.08, r.faceZ(h) - 0.02], [w + 0.55, 0.15, 0.12], LP.c('wood'), 1, {});
    if (p.door !== 'none') doorLeaf(P, {}, -w / 2 + 0.01, w - 0.02, h - 0.01, -0.03, DOORS[p.seed % DOORS.length], p.door === 'open' ? -1.35 : 0);
    if (p.vents) for (let k = 0; k < 3; k++) vent(P, {}, (k - 1) * 0.32, h + 0.5, r.faceZ(h + 0.5) + 0.01, 0.18);
    if (p.worn) wornPatches(P, {}, L, H, r.faceZ(1) + 0.01, rng, 3);
    return done('lp_wall_door', P, { height: H, radius: L / 2, collider: { type: 'box', size: [L, H, T] }, door: { hinge: [-w / 2, 0, 0], width: w, height: h }, snap: { length: L } });
  }
  // ---------- الواجهات ----------
  const bump = (x, c, w) => Math.max(0, 1 - ((x - c) / w) ** 2);
  function facadeGable(p, q) {
    const P = kit(), rng = AA.rng(p.seed), L = p.length, H = p.height, pk = p.peak, s = L / 6;
    const top = x => H + pk * (0.95 * bump(x, 0, 1.15 * s) + 0.55 * bump(Math.abs(x), 2.75 * s, 0.35 * s));
    const xs = []; for (let x = -L / 2; x <= L / 2 + 1e-6; x += s * 0.25) xs.push(x);
    const r = panel(P, {}, -L / 2, L / 2, 0, top, p.thickness, { n: 4, xs, taper: 0.03, Href: H, rng });
    if (p.windows) for (const [x, y] of [[-1.6, 2.15], [0, 2.15], [1.6, 2.15], [-1.0, 1.35], [0.8, 1.35]]) win(P, {}, x * s, y * H / 3.3, r.faceZ(y) + 0.01, 0.3, 0.3, false);
    if (p.vents) { for (const cx of [-1.2, -0.6, 0, 0.6, 1.2].map(v => v * s)) for (let y = H + 0.12; y < top(cx) - 0.32; y += 0.26) vent(P, {}, cx, y, r.faceZ(y) + 0.01, 0.1); for (let x = -L / 2 + 0.35; x < L / 2 - 0.3; x += 0.32) vent(P, {}, x, H - 0.2, r.faceZ(H) + 0.01, 0.11); }
    if (p.worn) wornPatches(P, {}, L, H, r.faceZ(1) + 0.01, rng, 4);
    return done('lp_facade_gable', P, { height: H + pk, radius: L / 2, collider: { type: 'box', size: [L, H, p.thickness] }, snap: { length: L } });
  }
  function facadeSteps(p, q) {
    const P = kit(), rng = AA.rng(p.seed), L = p.length, H = p.height, s = L / 6;
    const lv = [[-3, 1.0], [-1.6, 0.62], [-0.5, 0.3], [1.1, 0.0], [2.3, 0.45]].map(([x, h]) => [x * s, h * p.rise]);
    const top = x => { let h = lv[0][1]; for (const [x0, hh] of lv) if (x >= x0 - 1e-6) h = hh; return H + h; };
    const xs = []; for (const [x0] of lv.slice(1)) xs.push(x0 - 0.001, x0 + 0.001);
    const r = panel(P, {}, -L / 2, L / 2, 0, top, p.thickness, { n: 2, xs, taper: 0.03, Href: H, rng });
    if (p.windows) for (const [x, y] of [[-2.0, 1.95], [-0.3, 1.25], [1.6, 1.95]]) win(P, {}, x * s, y * H / 3.6, r.faceZ(y) + 0.01, 0.3, 0.3, false);
    if (p.vents) {
      const add = (cx, cy) => { for (let rr = 0; rr < 5; rr++) { const cnt = rr < 3 ? rr + 1 : 5 - rr; for (let k = 0; k < cnt; k++) vent(P, {}, cx + (k - (cnt - 1) / 2) * 0.17, cy - rr * 0.16, r.faceZ(cy) + 0.01, 0.1); } };
      add(-2.3 * s, H + 0.55 * p.rise + 0.05); add(-0.9 * s, H + 0.25 * p.rise + 0.05);
      for (let x = -L / 2 + 0.3; x < L / 2 - 0.25; x += 0.3) vent(P, {}, x, H - 0.3, r.faceZ(H) + 0.01, 0.1);
    }
    if (p.worn) wornPatches(P, {}, L, H, r.faceZ(1) + 0.01, rng, 4);
    return done('lp_facade_steps', P, { height: H + p.rise, radius: L / 2, collider: { type: 'box', size: [L, H, p.thickness] }, snap: { length: L } });
  }
  // ---------- شُرَف وعمود ودكّة ----------
  function crenelA(p, q) { const P = kit(), h = crenel(P, [0, 0, 0], p.size, 0, p.white ? WHITE : MUD); return done('lp_crenel', P, { height: h, radius: 0.5 * p.size, collider: { type: 'box', size: [0.9 * p.size, h, 0.24 * p.size] } }); }
  function crenelC(p, q) { const P = kit(), h = crenel(P, [0, 0, 0], p.size, 0, p.white ? WHITE : MUD, true); return done('lp_crenel_corner', P, { height: h, radius: 0.5 * p.size, collider: { type: 'box', size: [0.9 * p.size, h, 0.9 * p.size] } }); }
  function column(p, q) {
    const P = kit(), H = p.height, C = p.white ? WHITE : MUD, rng = AA.rng(p.seed);
    block(P, {}, 0.44, 0.44, 0, 0.16, { colors: C, rng });
    LP.prism(P.wall, [0, 0.16, 0], [0, H - 0.2, 0], 0.17, 0.15, 8, vary(LP.c(C.wall), rng, 0.04), { rot: Math.PI / 8 });
    block(P, {}, 0.38, 0.38, H - 0.2, 0.09, { colors: C, rng }); block(P, {}, 0.5, 0.5, H - 0.11, 0.11, { colors: C, rng });
    return done('lp_column', P, { height: H, radius: 0.3, collider: { type: 'box', size: [0.3, H, 0.3] } });
  }
  function dakka(p, q) {
    const P = kit(), rng = AA.rng(p.seed);
    block(P, {}, p.length, 0.6, 0, 0.36, { taperZ: 0.02, rng });
    block(P, {}, p.length - 0.06, 0.56, 0.36, 0.06, { taperX: 0.03, taperZ: 0.03, rng }); // حافة مشطوفة
    return done('lp_dakka', P, { height: 0.46, radius: p.length / 2, collider: { type: 'box', size: [p.length, 0.45, 0.6] } });
  }
  // ---------- البرج ----------
  function tower(p, q) {
    const P = kit(), rng = AA.rng(p.seed), Wd = p.width, H = p.height, tp = p.taper * Wd * 0.18;
    const sol = block(P, {}, Wd, Wd, 0, H, { taperX: tp, taperZ: tp, horns: 0.6, rng });
    for (let f = 0; f < 4; f++) {
      const o = { rot: f * Math.PI / 2 }, zf = y => sol.faceAt(y) + 0.02, span = y => sol.faceXAt(y) - 0.45, yv = H - 0.75;
      for (let x = -span(yv); x <= span(yv) + 1e-6; x += 0.34) vent(P, o, x, yv, zf(yv), 0.15);
      for (const [yy, n] of [[H * 0.62, 2], [H * 0.38, 1]]) for (let k = 0; k < n; k++) win(P, o, n === 1 ? 0 : (k - 0.5) * Wd * 0.38, yy, zf(yy), 0.3, 0.4, false);
      beams(P, o, -span(H - 1.3), span(H - 1.3), H - 1.3, zf(H - 1.3) - 0.1, 0.55);
      if (f === 0) doorLeaf(P, o, -0.45, 0.9, 1.9, sol.faceAt(1) + 0.01, DOORS[p.seed % DOORS.length]);
      if (p.worn) wornPatches(P, o, Wd * 0.8, H, zf(H / 2), rng, 3);
    }
    return done('lp_tower', P, { height: H + 0.75, radius: Wd / 2, collider: { type: 'box', size: [Wd, H, Wd] } });
  }

  // ---------- البيت النجدي ----------
  function house(p, q) {
    const rng = AA.rng(p.seed), P = kit();
    const W = p.width, D = p.depth, F = Math.round(p.floors), fh = p.floorH, roofY = F * fh, H = roofY + p.parapet, T = p.thickness;
    const doorX = (rng() - 0.5) * (W - 3), dw = p.doorWidth, dh = 2.15; // نفس موضع الباب في الحزمة الواقعية (أول رقم عشوائي)
    const tap = 0.012 * H, colors = MUD;
    const sol = block(P, {}, W, D, 0, H, { taperX: tap, taperZ: tap, rng });
    // سطح داخل الدروة (أخفض من القمة) وطوق أفتح
    AA.box(P.top, [0, roofY + 0.02, 0], [W - 2 * tap - 0.5, 0.04, D - 2 * tap - 0.5], LP.c(colors.top), 1, {});
    // شريط أغمق عند الأرض وخط بين الأدوار
    for (const [y, h] of [[0.15, 0.3]].concat(F > 1 ? [[fh, 0.08]] : [])) AA.box(P.wall, [0, y, 0], [W - 2 * tap * y / H + 0.04, h, D - 2 * tap * y / H + 0.04], LP.c(colors.dark), 1, {});
    const faces = [{ rot: 0, L: W, half: D / 2 }, { rot: Math.PI, L: W, half: D / 2 }, { rot: Math.PI / 2, L: D, half: W / 2 }, { rot: -Math.PI / 2, L: D, half: W / 2 }];
    const zAt = (fc, y) => fc.half - tap * y / H + 0.01;
    faces.forEach((fc, fi) => {
      const o = { rot: fc.rot };
      // نوافذ صغيرة
      for (let f = 0; f < F; f++) {
        const n = Math.max(1, Math.floor((fc.L - 1.2) / 2.2));
        for (let k = 0; k < n; k++) {
          const x = -fc.L / 2 + 0.9 + (k + 0.5) * (fc.L - 1.8) / n + (rng() - 0.5) * 0.4, y = f * fh + 1.55;
          if (fi === 0 && f === 0 && Math.abs(x - doorX) < 1.2) continue;
          if (rng() < (fi === 1 ? 0.55 : 0.25)) continue;
          win(P, o, x, y, zAt(fc, y), 0.42, 0.52, true);
        }
      }
      // مثلثات تهوية تحت الدروة ورؤوس جذوع السقف
      if (p.vents) { const yv = roofY + 0.2; for (let x = -fc.L / 2 + 0.6; x < fc.L / 2 - 0.5; x += 0.42) vent(P, o, x, yv, zAt(fc, yv), 0.17); }
      if (fi === 0 || fi === 2) for (let f = 1; f <= F; f++) beams(P, o, -fc.L / 2 + 0.5, fc.L / 2 - 0.4, f * fh - 0.15, zAt(fc, f * fh) - 0.1);
      if (p.worn) wornPatches(P, o, fc.L, roofY, zAt(fc, 1), rng, Math.round(fc.L / 2));
    });
    // الباب النجدي بإطار داكن وعتبة خشب
    const zf = zAt(faces[0], 1);
    AA.box(P.dark, [doorX, dh / 2, zf - 0.02], [dw + 0.12, dh + 0.08, 0.05], LP.c('dark'), 1, {});
    doorLeaf(P, {}, doorX - dw / 2, dw, dh, zf, DOORS[p.seed % DOORS.length]);
    AA.box(P.wood, [doorX, dh + 0.12, zf + 0.04], [dw + 0.5, 0.14, 0.14], LP.c('wood'), 1, {});
    AA.box(P.wood, [doorX > 0 ? -W / 4 : W / 4, roofY + 0.1, zAt(faces[0], roofY) + 0.4], [0.18, 0.12, 0.8], LP.c('wood'), 1, {}); // مزراب
    // الشُّرَف على الدروة وزواياها
    if (p.crenels) {
      for (const fc of faces) crenelRow(P, { rot: fc.rot }, fc.L - 1.4, H, zAt(fc, H) - 0.13, 0.9, 0.95, colors);
      for (const sx of [1, -1]) for (const sz of [1, -1]) crenel(P, [sx * (W / 2 - tap - 0.25), H, sz * (D / 2 - tap - 0.25)], 1.45, 0, colors, true);
    }
    let topH = H;
    if (p.roofRoom) { // غرفة سطح
      const rw = Math.max(2.8, W * 0.38), rd = Math.max(2.8, D * 0.42), rh = fh * 0.85 + p.parapet * 0.6, cx = (rng() < 0.5 ? -1 : 1) * (W / 2 - rw / 2 - 0.2), cz = -(D / 2 - rd / 2 - 0.2);
      block(P, { at: [cx, 0, cz] }, rw, rd, roofY, rh, { taperX: 0.04, taperZ: 0.04, rng });
      doorLeaf(P, { at: [cx, roofY, cz] }, -0.45, 0.9, 1.9, rd / 2 + 0.005, 'red');
      for (const sx of [1, -1]) for (const sz of [1, -1]) crenel(P, [cx + sx * (rw / 2 - 0.25), roofY + rh, cz + sz * (rd / 2 - 0.25)], 1.2, 0, colors, true);
      topH = roofY + rh + 0.6;
    }
    if (p.tower) { // برج في الزاوية الخلفية
      const tw = 2.6, th = H + 3.2, at = [W / 2 - tw / 2 + 0.25, 0, -(D / 2 - tw / 2 + 0.25)];
      const ts = block(P, { at }, tw, tw, 0, th, { taperX: 0.28, taperZ: 0.28, horns: 0.5, rng });
      for (let f = 0; f < 4; f++) { const o = { at, rot: f * Math.PI / 2 }, yv = th - 0.6; for (let x = -0.7; x <= 0.71; x += 0.35) vent(P, o, x, yv, ts.faceAt(yv) + 0.02, 0.13); win(P, o, 0, th * 0.75, ts.faceAt(th * 0.75) + 0.02, 0.28, 0.38, false); }
      topH = Math.max(topH, th + 0.5);
    }
    return done('lp_najdi_house', P, { height: topH, radius: Math.max(W, D) / 2, collider: { type: 'box', size: [W, H, D] }, door: { x: doorX, z: D / 2, width: dw } });
  }

  // ---------- الماء: حوض وساقية وبئر ----------
  const STONE = ['#cdb48c', '#bda57d', '#ab936c'];
  function waterPart(B) { return { builder: B, material: LP.mat('water', { opacity: 0.78, roughness: 0.15, metalness: 0.05 }) }; }
  function waterRect(B, x0, x1, z0, z1, y) { quad(B, [x0, y, z1], [x1, y, z1], [x1, y, z0], [x0, y, z0], LP.c('#4f9fc0'), [0, 1, 0]); }
  function stoneBox(P, rng, c, s, rot) { AA.box(P.wall, c, s, vary(LP.c(STONE[Math.floor(rng() * 3)]), rng, 0.05), 1, { rot: rot || 0 }); }
  function basin(p, q) {
    const P = kit(), Wt = new AA.Builder(), rng = AA.rng(p.seed), S = p.size, h = p.rimHeight, w = 0.24, half = S / 2;
    for (let s = 0; s < 4; s++) {
      const o = { rot: s * Math.PI / 2 }, n = Math.max(2, Math.round(S / 0.55));
      for (let k = 0; k < n; k++) { const x = -half + (k + 0.5) * S / n; if (s === 0 && p.inlet && Math.abs(x) < 0.2) continue; AA.box(P.wall, [x, h / 2, half - w / 2], [S / n - 0.02, h, w], vary(LP.c(STONE[(k + s) % 3]), rng, 0.05), 1, o); }
    }
    AA.box(P.top, [0, 0.03, 0], [S - 2 * w, 0.06, S - 2 * w], LP.c('#9c8a6c'), 1, {});
    if (p.water) waterRect(Wt, -half + w, half - w, -half + w, half - w, h - 0.08);
    return done('lp_water_basin', P, { height: h, radius: S / 2, collider: { type: 'box', size: [S, h, S] }, snap: { inlet: p.inlet ? [0, 0, half] : null } }, { water: waterPart(Wt) });
  }
  function channel(p, q) {
    const P = kit(), Wt = new AA.Builder(), rng = AA.rng(p.seed), L = p.length, inner = p.width, w = 0.2, h = 0.3;
    for (const s of [1, -1]) { const n = Math.max(1, Math.round(L / 0.5)); for (let k = 0; k < n; k++) AA.box(P.wall, [s * (inner / 2 + w / 2), h / 2, -L / 2 + (k + 0.5) * L / n], [w, h, L / n - 0.015], vary(LP.c(STONE[(k + (s > 0 ? 1 : 0)) % 3]), rng, 0.05), 1, {}); }
    AA.box(P.top, [0, 0.03, 0], [inner, 0.06, L], LP.c('#9c8a6c'), 1, {});
    if (p.water) waterRect(Wt, -inner / 2, inner / 2, -L / 2, L / 2, h - 0.1);
    return done('lp_water_channel', P, { height: h, radius: L / 2, collider: { type: 'box', size: [inner + 2 * w, h, L] }, snap: { length: L, ends: [[0, 0, -L / 2], [0, 0, L / 2]] } }, { water: waterPart(Wt) });
  }
  function well(p, q) {
    const P = kit(), Wt = new AA.Builder(), Rp = new AA.Builder(), Mt = new AA.Builder(), rng = AA.rng(p.seed), n = q === 'low' ? 8 : 12, r0 = 0.5, r1 = 0.72, ch = 0.26, Hh = p.courses * ch;
    for (let c = 0; c < p.courses; c++) for (let k = 0; k < n; k++) {
      const a0 = (k + (c % 2) * 0.5) / n * Math.PI * 2, a1 = a0 + Math.PI * 2 / n - 0.03, y0 = c * ch, y1 = y0 + ch - 0.015, col = vary(LP.c(STONE[(k + c) % 3]), rng, 0.06);
      const P4 = (a, r, y) => [Math.sin(a) * r, y, Math.cos(a) * r];
      quad(P.wall, P4(a0, r1, y0), P4(a1, r1, y0), P4(a1, r1, y1), P4(a0, r1, y1), col, P4((a0 + a1) / 2, 1, 0));
      quad(P.wall, P4(a1, r0, y0), P4(a0, r0, y0), P4(a0, r0, y1), P4(a1, r0, y1), mixc(col, [0, 0, 0], 0.25), P4((a0 + a1) / 2, -1, 0));
      quad(P.top, P4(a0, r1, y1), P4(a1, r1, y1), P4(a1, r0, y1), P4(a0, r0, y1), mixc(col, [1, 1, 1], 0.08), [0, 1, 0]);
    }
    LP.prism(P.dark, [0, Hh - 0.6, 0], [0, Hh - 0.05, 0], r0 - 0.01, r0 - 0.01, n, LP.c('#2a1f18'), { noCaps: true });
    if (p.water) { const ids = []; for (let k = 0; k < n; k++) { const a = k / n * Math.PI * 2; ids.push([Math.sin(a) * (r0 - 0.02), Hh - 0.55, Math.cos(a) * (r0 - 0.02)]); } for (let k = 0; k < n; k++) LP.tri(Wt, [0, Hh - 0.55, 0], ids[k], ids[(k + 1) % n], LP.c('#3f7f9a'), [0, 1, 0]); }
    if (p.frame) { // قائمان وعارضة وبكرة ودلو
      for (const s of [1, -1]) LP.prism(P.wood, [s * 0.62, Hh - 0.1, 0], [s * 0.6, Hh + 1.45, 0], 0.07, 0.06, 5, LP.c('wood'));
      LP.prism(P.wood, [-0.72, Hh + 1.4, 0], [0.72, Hh + 1.4, 0], 0.06, 0.06, 5, LP.c('woodDark'));
      LP.prism(P.wood, [-0.08, Hh + 1.28, 0], [0.08, Hh + 1.28, 0], 0.14, 0.14, 8, LP.c('woodLight'));
      LP.prism(Rp, [0, Hh + 1.18, 0.12], [0, Hh + 0.62, 0.12], 0.012, 0.012, 4, LP.c('#c9b38a'));
      LP.prism(Mt, [0, Hh + 0.62, 0.12], [0, Hh + 0.42, 0.12], 0.1, 0.12, 8, LP.c('#6e7478'));
    }
    if (p.trough) { const o = { at: [1.15, 0, 0], rot: Math.PI / 2 }; AA.box(P.wall, [0, 0.2, 0.25], [1.1, 0.4, 0.12], LP.c(STONE[0]), 1, o); AA.box(P.wall, [0, 0.2, -0.25], [1.1, 0.4, 0.12], LP.c(STONE[1]), 1, o); for (const s of [1, -1]) AA.box(P.wall, [s * 0.5, 0.2, 0], [0.12, 0.4, 0.4], LP.c(STONE[2]), 1, o); if (p.water) waterRect(Wt, 1.15 - 0.19, 1.15 + 0.19, -0.44, 0.44, 0.3); }
    return done('lp_well', P, { height: p.frame ? Hh + 1.6 : Hh, radius: p.trough ? 1.6 : r1, collider: { type: 'cylinder', radius: r1, height: Hh } }, { water: waterPart(Wt), rope: { builder: Rp, material: LP.mat('rope') }, metal: { builder: Mt, material: LP.mat('metal', { metalness: 0.4 }) } });
  }

  // ---------- السور والبوابة ----------
  function sur(p, q) {
    const P = kit(), rng = AA.rng(p.seed), L = p.length, H = p.height, T = p.thickness;
    const r = panel(P, {}, -L / 2, L / 2, 0, wavy(H, p.seed, 0.04), T, { taper: T * 0.22, Href: H, rng });
    const zt = r.faceZ(H);
    const pr = panel(P, { at: [0, 0, zt - 0.17] }, -L / 2, L / 2, H - 0.02, () => H + 0.88, 0.3, { taper: 0.02, Href: 1, rng, n: Math.ceil(L / 2) });
    if (p.crenels) crenelRow(P, { at: [0, 0, 0] }, L, H + 0.88, zt - 0.17, 0.22 / 0.24, 0.85);
    if (p.loopholes) for (let x = -L / 2 + 0.7; x < L / 2 - 0.5; x += 1.4) win(P, {}, x, H + 0.42, zt - 0.17 + 0.16, 0.1, 0.22, false);
    if (p.buttress) for (const x of [-L / 2 + 0.6, L / 2 - 0.6]) block(P, { at: [x, 0, 0.1] }, 1.1, T + 0.5, 0, H * 0.75, { taperZ: 0.25, rng });
    if (p.worn) for (const s of [0, Math.PI]) wornPatches(P, { rot: s }, L, H, r.faceZ(1.5) + 0.01, rng, Math.round(L * 0.8));
    return done('lp_sur', P, { height: H + 1.3, radius: L / 2, collider: { type: 'box', size: [L, H + 0.9, T] }, snap: { length: L }, walkway: { y: H, width: T * 0.6 } });
  }
  function bigLeaf(P, o, x0, w, h, rng) { // ضلفة بوابة: ألواح طولية وعوارض ومسامير
    const n = Math.max(3, Math.round(w / 0.3));
    for (let k = 0; k < n; k++) AA.box(P.wood, [x0 + (k + 0.5) * w / n, h / 2, 0], [w / n - 0.015, h, 0.08], vary(LP.c('woodLight'), rng, 0.1), 1, o);
    for (const y of [0.35, h * 0.5, h - 0.35]) AA.box(P.wood, [x0 + w / 2, y, -0.07], [w - 0.06, 0.16, 0.06], LP.c('woodDark'), 1, o);
    for (const y of [0.35, h * 0.5, h - 0.35]) for (let k = 0; k < 4; k++) AA.box(P.door, [x0 + 0.15 + k * (w - 0.3) / 3, y, 0.045], [0.04, 0.04, 0.02], LP.c('#3a3330'), 1, o);
  }
  function gate(p, q) {
    const P = kit(), rng = AA.rng(p.seed), gw = p.gateWidth, gh = p.gateHeight, H = Math.max(gh + 1.6, p.height), T = 1.0, L = gw + 2.4;
    const r = panelOpen(P, {}, L, H, T, x => H + 0.03 * Math.sin(x * 2), [{ x0: -gw / 2, x1: gw / 2, y0: 0, y1: gh }], { taper: 0.12, Href: H, rng });
    const zf = r.faceZ(gh);
    AA.box(P.wood, [0, gh + 0.12, zf - 0.03], [gw + 0.7, 0.2, 0.16], LP.c('wood'), 1, {});
    beams(P, {}, -gw / 2 - 0.2, gw / 2 + 0.2, gh + 0.34, zf, 0.32);
    for (let k = -2; k <= 2; k++) vent(P, {}, k * 0.36, gh + 0.75, r.faceZ(gh + 0.75) + 0.01, 0.16);
    const op = p.open * 1.45;
    for (const s of [-1, 1]) bigLeaf(P, { at: [s * gw / 2, 0, -0.05], rot: s * op }, s < 0 ? 0 : -gw / 2, gw / 2 - 0.02, gh - 0.02, rng);
    crenelRow(P, { at: [0, 0, 0] }, L, H - 0.02, r.faceZ(H) - 0.12, 1, 0.85);
    if (p.towers) for (const s of [-1, 1]) {
      const tw = 3.0, th = H + 2.2, at = [s * (L / 2 + tw / 2 - 0.35), 0, 0.15];
      const sol = block(P, { at }, tw, tw, 0, th, { taperX: 0.42, taperZ: 0.42, horns: 0.7, rng });
      for (let f = 0; f < 4; f++) { const o = { at, rot: f * Math.PI / 2 }, yv = th - 0.75; for (let x = -0.6; x <= 0.61; x += 0.3) vent(P, o, x, yv, sol.faceAt(yv) + 0.02, 0.14); for (const yy of [th * 0.55, th * 0.3]) win(P, o, 0, yy, sol.faceAt(yy) + 0.02, 0.12, 0.32, false); }
    }
    if (p.worn) for (const s of [0, Math.PI]) wornPatches(P, { rot: s }, L, H, r.faceZ(1) + 0.01, rng, 4);
    return done('lp_gate', P, { height: H + 3, radius: L / 2 + (p.towers ? 3 : 0), collider: { type: 'compound' }, door: { x: 0, z: 0, width: gw, height: gh }, snap: { length: L + (p.towers ? 5.3 : 0) } }, { metal: { builder: new AA.Builder(), material: LP.mat('metal') } });
  }

  // ---------- المئذنة والمسجد ----------
  function minaretInto(P, at, H, B0, rng) {
    const tp = B0 * 0.2, sol = block(P, { at }, B0, B0, 0, H, { taperX: tp, taperZ: tp, horns: 0.45, rng }), yb = H - 1.4;
    block(P, { at }, (sol.faceXAt(yb) + 0.14) * 2, (sol.faceAt(yb) + 0.14) * 2, yb, 0.22, { rng, bottom: true }); // حزام شرفة المؤذن
    for (let f = 0; f < 4; f++) {
      const o = { at, rot: f * Math.PI / 2 }, zf = y => sol.faceAt(y) + 0.02;
      for (let y = 1.8; y < yb - 0.6; y += 1.6) { vent(P, o, 0, y, zf(y), 0.16); if (f % 2 === 0) win(P, o, 0, y + 0.75, zf(y + 0.75), 0.14, 0.36, false); }
      win(P, o, 0, H - 0.75, zf(H - 0.75), 0.32, 0.5, false);
      beams(P, o, -(sol.faceXAt(H * 0.3) - 0.3), sol.faceXAt(H * 0.3) - 0.3, H * 0.3, zf(H * 0.3) - 0.1, 0.5);
    }
    crenel(P, V.add(at, [0, H, 0]), 1.2, 0, MUD, true);
    return sol;
  }
  function minaret(p, q) {
    const P = kit(), rng = AA.rng(p.seed);
    minaretInto(P, [0, 0, 0], p.height, p.base, rng);
    doorLeaf(P, {}, -0.4, 0.8, 1.8, p.base / 2 + 0.01, DOORS[p.seed % DOORS.length]);
    if (p.worn) wornPatches(P, {}, p.base * 0.7, p.height * 0.6, p.base / 2, rng, 3);
    return done('lp_minaret', P, { height: p.height + 1.2, radius: p.base / 2 + 0.3, collider: { type: 'box', size: [p.base, p.height, p.base] } });
  }
  function mosque(p, q) {
    const P = kit(), Fl = new AA.Builder(), rng = AA.rng(p.seed), W = p.width, D = p.depth, C = p.court;
    const H = 4.4, roofY = 3.7, T = 0.6, Ttot = D + C, zb = -Ttot / 2, zh = zb + D, top = s => x => H + 0.03 * Math.sin(x * 1.7 + s), opt = { taper: 0.04, Href: H, rng };
    // جدار القبلة والجانبان (بنوافذ صماء)
    panel(P, { at: [0, 0, zb + T / 2], rot: Math.PI }, -W / 2, W / 2, 0, top(1), T, opt);
    for (const s of [1, -1]) {
      const o = { at: [s * (W / 2 - T / 2), 0, zb + D / 2], rot: s * Math.PI / 2 };
      const r = panel(P, o, -D / 2, D / 2, 0, top(2 + s), T, opt);
      for (let z = 1.6; z < D - 1.2; z += 2.2) win(P, o, s * (z - D / 2), 1.5, r.faceZ(1.5) + 0.01, 0.5, 0.65, false);
    }
    // الرواق على الصحن: فتحات بين أعمدة
    const bays = Math.max(3, Math.round((W - 1.2) / 2.1)), bw = (W - 1.2) / bays, ops = [];
    for (let k = 0; k < bays; k++) { const cx = -W / 2 + 0.6 + (k + 0.5) * bw; ops.push({ x0: cx - bw / 2 + 0.32, x1: cx + bw / 2 - 0.32, y0: 0, y1: 2.75 }); }
    const fr = panelOpen(P, { at: [0, 0, zh - 0.28] }, W - T * 1.8, H, 0.55, top(5), ops, { taper: 0.03, Href: H, rng });
    for (const o2 of ops) AA.box(P.wood, [(o2.x0 + o2.x1) / 2, 2.84, zh - 0.28 + fr.faceZ(2.8) - 0.03], [o2.x1 - o2.x0 + 0.3, 0.14, 0.1], LP.c('wood'), 1, {});
    // أعمدة داخلية وعتمة الداخل وأرضية المصلى
    for (let k = 1; k < bays; k++) block(P, { at: [-W / 2 + 0.6 + k * bw, 0, zb + D * 0.38] }, 0.5, 0.5, 0, roofY - 0.08, { taperX: 0.03, taperZ: 0.03, rng });
    quad(Fl, [-W / 2 + T, 0.035, zh - 0.3], [W / 2 - T, 0.035, zh - 0.3], [W / 2 - T, 0.035, zb + T], [-W / 2 + T, 0.035, zb + T], LP.c('#b8483e'), [0, 1, 0]);
    quad(P.dark, [-W / 2 + T + 0.01, 0.05, zb + T + 0.02], [W / 2 - T - 0.01, 0.05, zb + T + 0.02], [W / 2 - T - 0.01, roofY - 0.05, zb + T + 0.02], [-W / 2 + T + 0.01, roofY - 0.05, zb + T + 0.02], LP.c('#3a2a20'), [0, 0, 1]);
    quad(P.dark, [-0.45, 0.06, zb + T + 0.03], [0.45, 0.06, zb + T + 0.03], [0.45, 2.3, zb + T + 0.03], [-0.45, 2.3, zb + T + 0.03], LP.c('dark'), [0, 0, 1]); // المحراب
    block(P, { at: [0, 0, zb - 0.35] }, 1.7, 1.3, 0, 3.3, { taperX: 0.06, taperZ: 0.05, rng });
    // السقف والشُّرَف
    { const hw = W / 2 - T * 0.6; AA.box(P.top, [0, roofY, (zb + T * 0.6 + zh - 0.1) / 2], [hw * 2, 0.12, zh - 0.1 - zb - T * 0.6], LP.c(MUD.top), 1, {}); quad(P.wall, [-hw, roofY - 0.06, zh - 0.1], [hw, roofY - 0.06, zh - 0.1], [hw, roofY - 0.06, zb + T], [-hw, roofY - 0.06, zb + T], LP.c('#3a2a20'), [0, -1, 0]); }
    if (p.crenels) {
      crenelRow(P, { at: [0, 0, 0] }, W - 1.4, H - 0.02, zh - 0.28, 1.1, 0.9);
      if (q !== 'low') { for (const s of [1, -1]) crenelRow(P, { at: [s * (W / 2 - T / 2), 0, zb + D / 2], rot: s * Math.PI / 2 }, D - 1.4, H - 0.02, 0, 1.1, 0.9); crenelRow(P, { at: [0, 0, zb + T / 2], rot: Math.PI }, W - 1.4, H - 0.02, 0, 1.1, 0.9); }
      for (const [sx, sz] of [[1, 1], [-1, 1], [1, -1], [-1, -1]]) crenel(P, [sx * (W / 2 - 0.3), H - 0.03, sz > 0 ? zh - 0.3 : zb + 0.3], 1.45, 0, MUD, true);
    }
    beams(P, {}, -W / 2 + 0.7, W / 2 - 0.5, roofY - 0.12, zh - 0.28 + fr.faceZ(roofY), 0.65);
    // سور الصحن المنخفض ومدخله
    const cw = 2.3, cT = 0.45, zc = zh + C, gwid = 1.6, copt = { taper: 0.03, Href: cw, rng };
    panelOpen(P, { at: [0, 0, zc - cT / 2] }, W, cw, cT, x => cw + 0.03 * Math.sin(x * 2.3), [{ x0: -gwid / 2, x1: gwid / 2, y0: 0, y1: 2.1 }], copt);
    AA.box(P.wood, [0, 2.18, zc - cT / 2 + 0.2], [gwid + 0.5, 0.14, 0.12], LP.c('wood'), 1, {});
    for (const s of [1, -1]) panel(P, { at: [s * (W / 2 - cT / 2), 0, zh + C / 2], rot: s * Math.PI / 2 }, -C / 2, C / 2, 0, x => cw + 0.03 * Math.sin(x * 2.1 + s), cT, copt);
    for (const s of [1, -1]) doorLeaf(P, { at: [s * gwid / 2, 0, zc - cT / 2 + 0.12], rot: s * -1.2 }, s > 0 ? -gwid / 2 + 0.01 : 0.01, gwid / 2 - 0.02, 2.08, 0, 'teal');
    let mz = null;
    if (p.minaret) { const mb = 2.6, at = [W / 2 - mb / 2 - 0.05, 0, zc - mb / 2 - 0.05]; minaretInto(P, at, p.minaretHeight, mb, rng); doorLeaf(P, { at, rot: -Math.PI / 2 }, -0.4, 0.8, 1.8, mb / 2 + 0.01, 'teal'); mz = at; }
    if (p.worn) wornPatches(P, { at: [0, 0, zb], rot: Math.PI }, W, H, T / 2, rng, 5);
    return done('lp_mosque', P, { height: Math.max(H + 0.5, p.minaret ? p.minaretHeight + 1.2 : 0), radius: Math.max(W, Ttot) / 2 + 0.5, collider: { type: 'compound' },
      door: { x: 0, z: zc, width: gwid }, qibla: [0, 0, -1], minaret: mz, court: { z0: zh, z1: zc, width: W } }, { floor: { builder: Fl, material: LP.mat('rug') } });
  }

  LP.def('wall', wall); LP.def('wall_corner', corner); LP.def('wall_door', wallDoor); LP.def('facade_gable', facadeGable); LP.def('facade_steps', facadeSteps);
  LP.def('crenel', crenelA); LP.def('crenel_corner', crenelC); LP.def('column', column); LP.def('tower', tower); LP.def('dakka', dakka); LP.def('najdi_house', house);
  LP.def('water_basin', basin); LP.def('water_channel', channel); LP.def('well', well); LP.def('sur', sur); LP.def('gate', gate); LP.def('mosque', mosque); LP.def('minaret', minaret);
  Object.assign(LP, { panel, panelOpen, block, vent, win, beams, doorLeaf, crenel, crenelRow, wornPatches, quad, MUD, WHITE, DOORS });
})(typeof window !== 'undefined' ? window : globalThis);
