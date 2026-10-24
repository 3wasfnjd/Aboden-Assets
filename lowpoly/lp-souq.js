// Aboden Assets — lowpoly/lp-souq.js — السوق بأسلوب لو-بولي: كشك، دكان، عربة، أكياس، صناديق، سلال، حواجز، حوش
// بنفس معاملات وأبعاد ونقاط ربط الحزمة الواقعية (البائع، الباب، العجلات، الدابة).
(function (g) {
  'use strict';
  const AA = g.AA, LP = AA.lp, V = AA.v, vary = AA.vary, lerp = AA.lerp, mixc = AA.mixc;
  const GOODS = { dates: '#7a3a1c', spice_red: '#c8432a', spice_yellow: '#e0a92a', spice_green: '#7a9a3a', rice: '#f1ece0', coffee: '#6b4a2b', cardamom: '#8fa65a', oranges: '#ef8a22', lemons: '#e9d23a', tomatoes: '#d6392c' };
  const AWN = { palm: ['#c9a25e', '#b38a4a'], red: ['#c83a32', '#f2e8d8'], green: ['#3f8a4e', '#f2e8d8'], blue: ['#2f6aa8', '#f2e8d8'] };
  function kit() { const k = {}; for (const n of ['wood', 'burlap', 'weave', 'awning', 'goods', 'dark', 'metal', 'rope', 'mud', 'mudTop', 'clay', 'brass', 'metal2', 'glass', 'flame', 'cloth', 'wheel', 'tire']) k[n] = new AA.Builder(); return k; }
  function done(id, P, meta) {
    const spin = meta.spin; delete meta.spin;
    return LP.finalize(id, {
      wheel: { builder: P.wheel, material: LP.mat('wood', { spin }) }, tire: { builder: P.tire, material: LP.mat('metal', { spin }) },
      wood: { builder: P.wood, material: LP.mat('wood') }, burlap: { builder: P.burlap, material: LP.mat('cloth') }, weave: { builder: P.weave, material: LP.mat('weave', { doubleSided: true }) },
      awning: { builder: P.awning, material: LP.mat('cloth', { doubleSided: true }) }, goods: { builder: P.goods, material: LP.mat('fruit') }, dark: { builder: P.dark, material: LP.mat('dark') },
      metal: { builder: P.metal, material: LP.mat('metal', { metalness: 0.3 }) }, rope: { builder: P.rope, material: LP.mat('rope') }, mud: { builder: P.mud, material: LP.mat('mud') }, mudTop: { builder: P.mudTop, material: LP.mat('mud') },
      clay: { builder: P.clay, material: LP.mat('clay') }, brass: { builder: P.brass, material: LP.mat('metal', { metalness: 0.5, roughness: 0.35 }) }, metal2: { builder: P.metal2, material: LP.mat('metal', { metalness: 0.4 }) },
      glass: { builder: P.glass, material: LP.mat('glass', { opacity: 0.35, doubleSided: true }) }, flame: { builder: P.flame, material: LP.mat('flame', { emissive: [1, 0.45, 0.1], glow: 1.5, doubleSided: true }) },
      cloth: { builder: P.cloth, material: LP.mat('cloth', { doubleSided: true }) }
    }, Object.assign({ stiffness: 0 }, meta));
  }
  // يرسم بإحداثيات محلية ثم ينقل الرؤوس الجديدة (إزاحة + دوران حول Y)
  function place(P, o, fn) {
    const start = {}; for (const k in P) start[k] = P[k].vertexCount;
    fn();
    if (!o || (!o.at && !o.rot)) return;
    for (const k in P) { const B = P[k]; for (let i = start[k]; i < B.vertexCount; i++) { const q = AA.xform([B.pos[i * 3], B.pos[i * 3 + 1], B.pos[i * 3 + 2]], o); B.pos[i * 3] = q[0]; B.pos[i * 3 + 1] = q[1]; B.pos[i * 3 + 2] = q[2]; } }
  }
  const plank = (P, c, s, rng, col, rot) => AA.box(P.wood, c, s, vary(LP.c(col || 'woodLight'), rng, 0.1), 1, {}, rot);
  const post = (P, c, h, r, rng) => LP.prism(P.wood, c, V.add(c, [0, h, 0]), r, r * 0.9, 5, vary(LP.c('wood'), rng, 0.1));
  // كومة بضاعة: كرة أوجه منخفضة بلون البضاعة
  function mound(P, c, r, h, goods, rng) {
    const col = LP.c(GOODS[goods] || GOODS.dates);
    if (/oranges|lemons|tomatoes|dates/.test(goods)) { for (let k = 0; k < 7; k++) { const a = k * 2.39996, d = k ? r * 0.55 : 0; LP.ico(P.goods, [c[0] + Math.cos(a) * d, c[1] + (k ? 0 : h * 0.35), c[2] + Math.sin(a) * d], goods === 'dates' ? 0.03 : 0.055, 0, () => vary(col, rng, 0.12)); } }
    else LP.ico(P.goods, c, [r, h, r], 0, () => vary(col, rng, 0.06), { keep: d => d[1] > -0.2 });
  }
  // كيس خيش: منشور مثمّن منتفخ، مفتوح بحافة مطوية وبضاعة، أو مربوط من الأعلى
  function sackInto(P, o, s, rng) {
    place(P, o, () => {
      const H = s.height, R = s.radius * 0.96, C = LP.c('#c9a873'), prof = [[0, R * 0.85], [0.08, R], [0.5, R * 1.02], [0.85, R * 0.95], [1, s.open ? R * 1.0 : R * 0.35]];
      for (let i = 0; i < prof.length - 1; i++) LP.prism(P.burlap, [0, prof[i][0] * H, 0], [0, prof[i + 1][0] * H, 0], prof[i][1], prof[i + 1][1], 7, vary(C, rng, 0.06), { noCaps: i > 0, rot: 0.3 });
      if (s.open) { LP.prism(P.burlap, [0, H, 0], [0, H - 0.06, 0], R * 1.06, R * 1.03, 7, LP.c('#b89664'), { rot: 0.3 }); mound(P, [0, H - 0.04, 0], R * 0.95, 0.07, s.goods, rng); }
      else { LP.prism(P.rope, [0, H * 0.92, 0], [0, H * 0.96, 0], R * 0.38, R * 0.38, 6, LP.c('#9a7a4a')); LP.prism(P.burlap, [0, H, 0], [0, H + 0.08, 0], R * 0.35, R * 0.5, 6, LP.c('#c9a873')); }
    });
  }
  // صندوق خشب: ألواح جانبية بفراغات وبضاعة أو غطاء
  function crateInto(P, o, s, rng) {
    place(P, o, () => {
      const { w, d, h } = s;
      AA.box(P.wood, [0, 0.015, 0], [w, 0.03, d], LP.c('wood'), 1, {});
      for (const [y, hh] of [[0.03, h * 0.42], [h * 0.52, h * 0.42]]) for (const [x, z, sx, sz] of [[0, d / 2, w, 0.02], [0, -d / 2, w, 0.02], [w / 2, 0, 0.02, d], [-w / 2, 0, 0.02, d]]) AA.box(P.wood, [x, y + hh / 2, z], [sx, hh, sz], vary(LP.c('woodLight'), rng, 0.1), 1, {});
      if (s.lid || s.goods === 'closed') AA.box(P.wood, [0, h, 0], [w + 0.02, 0.03, d + 0.02], vary(LP.c('woodLight'), rng, 0.1), 1, {});
      else if (s.goods && s.goods !== 'empty') mound(P, [0, h * 0.85, 0], Math.min(w, d) * 0.45, h * 0.3, s.goods, rng);
    });
  }
  // سلة خوص: مخروط مقلوب بحلقات أفتح وبضاعة ومقبضان
  function basketInto(P, o, s, rng) {
    place(P, o, () => {
      const r = s.radius, h = s.height, f = s.flare || 1.25, C = LP.c('#c9a25e');
      LP.prism(P.weave, [0, 0, 0], [0, h, 0], r / f, r, 8, d => vary(mixc(C, [0, 0, 0], 0.1 * (d % 2)), rng, 0.05), { rot: 0.2 });
      LP.prism(P.weave, [0, h - 0.015, 0], [0, h + 0.015, 0], r * 1.04, r * 1.04, 8, LP.c('#a8803e'), { rot: 0.2 });
      if (s.goods && s.goods !== 'empty') mound(P, [0, h - 0.01, 0], r * 0.9, Math.min(0.08, h * 0.4), s.goods, rng);
      if (s.handles) for (const sd of [1, -1]) LP.chain(P.weave, [[sd * r, h, 0], [sd * r * 1.15, h + 0.05, 0], [sd * r, h + 0.09, 0]], [0.01, 0.01, 0.01], 4, () => LP.c('#a8803e'));
    });
  }
  // مظلة: سطح مائل من شرائح (سعف أو قماش مخطّط) بحافة متدلية
  function awning(P, x0, x1, z0, z1, yBack, yFront, roof, rng) {
    const C = AWN[roof] || AWN.palm, n = Math.max(4, Math.round((x1 - x0) / 0.35));
    for (let k = 0; k < n; k++) {
      const a = lerp(x0, x1, k / n), b = lerp(x0, x1, (k + 1) / n), col = roof === 'palm' ? vary(LP.c(C[k % 2]), rng, 0.1) : LP.c(C[k % 2]);
      LP.quad(P.awning, [a, yBack, z0], [b, yBack, z0], [b, yFront, z1], [a, yFront, z1], col, [0, 1, 0.2]);
      LP.quad(P.awning, [a, yFront, z1], [b, yFront, z1], [b, yFront - 0.2, z1 + 0.02], [a, yFront - 0.2, z1 + 0.02], col, [0, 0, 1]);
      if (roof === 'palm') LP.tri(P.awning, [a, yFront - 0.2, z1 + 0.02], [b, yFront - 0.2, z1 + 0.02], [(a + b) / 2, yFront - 0.32, z1 + 0.03], col, [0, 0, 1]);
    }
  }

  // ---------- الكشك ----------
  function kiosk(p, q) {
    const P = kit(), rng = AA.rng(p.seed), W = p.width, D = 1.6, H = 2.3, cY = 0.9;
    for (const [x, z] of [[-W / 2, -D / 2], [W / 2, -D / 2], [-W / 2, D / 2], [W / 2, D / 2]]) post(P, [x, 0, z], z > 0 ? H : H + 0.3, 0.06, rng);
    AA.box(P.wood, [0, cY / 2, D / 2 - 0.05], [W - 0.08, cY, 0.04], vary(LP.c('woodLight'), rng, 0.08), 1, {});
    for (let k = 0; k < 4; k++) AA.box(P.dark, [0, 0.18 + k * 0.2, D / 2 - 0.02], [W - 0.1, 0.015, 0.01], LP.c('wood'), 1, {});
    AA.box(P.wood, [0, cY + 0.02, D / 2 - 0.35], [W, 0.04, 0.66], vary(LP.c('woodLight'), rng, 0.05), 1, {});
    AA.box(P.wood, [0, (H + 0.24) / 2, -D / 2 + 0.03], [W, H + 0.24, 0.03], vary(LP.c('wood'), rng, 0.05), 1, {});
    for (const y of [1.2, 1.65]) plank(P, [0, y, -D / 2 + 0.2], [W - 0.12, 0.035, 0.3], rng);
    for (const s of [1, -1]) AA.box(P.wood, [s * W / 2, 0.45, 0], [0.03, 0.85, D - 0.1], vary(LP.c('wood'), rng, 0.05), 1, {});
    awning(P, -W / 2 - 0.1, W / 2 + 0.1, -D / 2 - 0.05, D / 2 + 0.55, H + 0.35, H - 0.05, p.roof, rng);
    const g2 = p.goods, M = AA.lp.majlis;
    if (g2 === 'spices' || g2 === 'dates') {
      const types = g2 === 'dates' ? ['dates'] : ['spice_red', 'spice_yellow', 'spice_green', 'coffee', 'cardamom', 'rice'], n = Math.max(3, Math.round(W / 0.38));
      for (let k = 0; k < n; k++) basketInto(P, { at: [-W / 2 + 0.25 + k * (W - 0.5) / Math.max(1, n - 1), cY + 0.04, D / 2 - 0.35] }, { radius: 0.14, height: 0.12, flare: 1.3, goods: types[k % types.length] }, rng);
      for (let k = 0; k < 3; k++) sackInto(P, { at: [-W / 2 + 0.35 + k * 0.45, 0, D / 2 + 0.35], rot: rng() * 6 }, { height: 0.6, radius: 0.24, open: true, goods: types[(k + 2) % types.length] }, rng);
      for (const y of [1.22, 1.67]) for (let k = 0; k < Math.round(W / 0.4); k++) LP.prism(P.glass, [-W / 2 + 0.25 + k * 0.4, y + 0.02, -D / 2 + 0.2], [-W / 2 + 0.25 + k * 0.4, y + 0.2, -D / 2 + 0.2], 0.06, 0.06, 6, LP.c('#e8e2d0'));
    } else if (g2 === 'fruit') {
      const types = ['oranges', 'lemons', 'tomatoes'], n = Math.max(2, Math.round(W / 0.55));
      for (let k = 0; k < n; k++) crateInto(P, { at: [-W / 2 + 0.33 + k * (W - 0.66) / Math.max(1, n - 1), cY + 0.04, D / 2 - 0.35] }, { w: 0.48, d: 0.36, h: 0.2, goods: types[k % 3] }, rng);
      for (let k = 0; k < 2; k++) crateInto(P, { at: [-W / 2 + 0.4 + k * 0.6, 0, D / 2 + 0.3], rot: (rng() - 0.5) * 0.2 }, { w: 0.5, d: 0.38, h: 0.32, goods: types[(k + 1) % 3] }, rng);
    } else if (g2 === 'pottery') {
      const n = Math.max(3, Math.round(W / 0.42)), kinds = ['jarra', 'burma', 'ibriq'];
      for (let k = 0; k < n; k++) M.jarInto(P, [-W / 2 + 0.25 + k * (W - 0.5) / Math.max(1, n - 1), cY + 0.04, D / 2 - 0.35], kinds[(k + 1) % 3], 0.8 + rng() * 0.3, rng);
      for (let k = 0; k < 3; k++) M.jarInto(P, [-W / 2 + 0.35 + k * 0.5, 0.02, D / 2 + 0.35], k === 1 ? 'burma' : 'jarra', 1.5 + rng() * 0.3, rng);
      for (const y of [1.22, 1.67]) for (let k = 0; k < Math.round(W / 0.3); k++) M.jarInto(P, [-W / 2 + 0.2 + k * 0.3, y + 0.02, -D / 2 + 0.2], 'ibriq', 0.9, rng);
    } else if (g2 === 'brass') {
      const n = Math.max(3, Math.round(W / 0.36));
      for (let k = 0; k < n; k++) M.dallahInto(P.brass, [-W / 2 + 0.22 + k * (W - 0.44) / Math.max(1, n - 1), cY + 0.04, D / 2 - 0.35 + (k % 2) * 0.12], 0.9 + 0.2 * (k % 3), (rng() - 0.5) * 1.2);
      for (const y of [1.22, 1.67]) for (let k = 0; k < Math.round(W / 0.4); k++) LP.prism(P.brass, [-W / 2 + 0.25 + k * 0.4, y + 0.17, -D / 2 + 0.07], [-W / 2 + 0.25 + k * 0.4, y + 0.17, -D / 2 + 0.085], 0.15, 0.15, 10, LP.c('#d1a24a'));
    } else if (g2 === 'cloth') {
      const COLS = ['#8a2a24', '#2f5f8a', '#d9c9a8', '#3f6f3a', '#c48a2a', '#6a3a7a', '#efe9de', '#1b1716'];
      for (let k = 0; k < 6; k++) { const c = [-W / 2 + 0.5 + (k % 3) * (W - 1) / 2, cY + 0.04 + Math.floor(k / 3) * 0.13 + 0.065, D / 2 - 0.45 + (k % 2) * 0.16]; LP.prism(P.cloth, [c[0] - 0.35, c[1], c[2]], [c[0] + 0.35, c[1], c[2]], 0.065, 0.065, 6, LP.c(COLS[k])); }
      for (const y of [1.22, 1.67]) for (let k = 0; k < Math.round((W - 0.2) / 0.16); k++) LP.prism(P.cloth, [-W / 2 + 0.16 + k * 0.16, y + 0.08, -D / 2 + 0.06], [-W / 2 + 0.16 + k * 0.16, y + 0.08, -D / 2 + 0.34], 0.07, 0.07, 6, LP.c(COLS[(k * 3 + (y > 1.5 ? 1 : 0)) % 8]));
      for (let k = 0; k < 3; k++) AA.box(P.cloth, [-W / 2 + 0.4 + k * (W - 0.8) / 2, H - 0.55, D / 2 + 0.05], [0.4, 0.9, 0.01], LP.c(COLS[(k + 4) % 8]), 1, {});
    }
    return done('lp_kiosk', P, { height: H + 0.4, radius: W / 2 + 0.6, collider: { type: 'box', size: [W, H, D] }, seller: { at: [0, 0, -0.25], rot: 0 }, light: null });
  }

  // ---------- الدكان ----------
  function shop(p, q) {
    const P = kit(), rng = AA.rng(p.seed), W = p.width, D = 3, H = 3.1, dw = Math.min(2.2, W - 1.2), dh = 2.2;
    const MP = { wall: P.mud, top: P.mudTop, dark: P.dark, wood: P.wood, door: P.wood }, opt = { taper: 0.03, Href: H, rng };
    LP.panelOpen(MP, { at: [0, 0, D / 2 - 0.22] }, W, H, 0.45, x => H + 0.03 * Math.sin(x * 2), [{ x0: -dw / 2, x1: dw / 2, y0: 0, y1: dh }], opt);
    for (const s of [1, -1]) LP.panel(MP, { at: [s * (W / 2 - 0.22), 0, 0], rot: s * Math.PI / 2 }, -(D - 0.4) / 2, (D - 0.4) / 2, 0, () => H, 0.45, opt);
    LP.panel(MP, { at: [0, 0, -D / 2 + 0.22], rot: Math.PI }, -W / 2, W / 2, 0, () => H, 0.45, opt);
    AA.box(P.mudTop, [0, H - 0.1, 0], [W - 0.4, 0.12, D - 0.4], LP.c('mudLight'), 1, {});
    AA.box(P.dark, [0, H / 2, -D / 2 + 0.46], [W - 0.9, H - 0.3, 0.02], LP.c('dark'), 1, {});
    AA.box(P.dark, [0, 0.045, 0], [W - 0.9, 0.03, D - 0.9], LP.c('#3a2a20'), 1, {});
    plank(P, [0, dh + 0.08, D / 2 + 0.02], [dw + 0.5, 0.14, 0.12], rng, 'wood');
    for (const s of [1, -1]) place(P, { at: [s * dw / 2, 0, D / 2 + 0.03], rot: s * 1.35 }, () => {
      const lw = dw / 2 - 0.02;
      AA.box(P.wood, [-s * lw / 2, dh / 2, 0.02], [lw, dh - 0.04, 0.04], vary(LP.c('wood'), rng, 0.06), 1, {});
      for (const y of [0.25, dh / 2, dh - 0.25]) AA.box(P.wood, [-s * lw / 2, y, 0.05], [lw, 0.09, 0.03], LP.c('woodDark'), 1, {});
    });
    awning(P, -dw / 2 - 0.5, dw / 2 + 0.5, D / 2 + 0.05, D / 2 + 1.3, dh + 0.45, dh - 0.05, p.roof, rng);
    for (const s of [1, -1]) post(P, [s * (dw / 2 + 0.45), 0, D / 2 + 1.28], dh - 0.05, 0.045, rng);
    if (p.goods !== 'none') {
      const types = p.goods === 'spices' ? ['spice_red', 'spice_yellow', 'coffee', 'cardamom'] : ['rice', 'coffee', 'rice', 'spice_yellow'];
      for (let k = 0; k < 4; k++) sackInto(P, { at: [(k < 2 ? -1 : 1) * (dw / 2 + 0.05 + (k % 2) * 0.48), 0, D / 2 + 0.7], rot: rng() * 6 }, { height: 0.62, radius: 0.24, open: true, goods: types[k] }, rng);
      for (let k = 0; k < 3; k++) sackInto(P, { at: [-W / 2 + 0.9 + k * 0.5, 0, -D / 2 + 0.75], rot: rng() * 6 }, { height: 0.75, radius: 0.27, open: false }, rng);
    }
    return done('lp_shop', P, { height: H + 0.1, radius: Math.max(W, D) / 2 + 0.8, collider: { type: 'box', size: [W, H, D] }, door: { x: 0, z: D / 2, width: dw } });
  }

  // ---------- العربة ----------
  function wheel(P, c, R, rng, q) {
    const n = q === 'low' ? 8 : 12;
    LP.prism(P.tire, [c[0] - 0.045, c[1], c[2]], [c[0] + 0.045, c[1], c[2]], R, R, n, LP.c('#3a3330'), { noCaps: true });
    LP.prism(P.wheel, [c[0] - 0.04, c[1], c[2]], [c[0] + 0.04, c[1], c[2]], R - 0.015, R - 0.015, n, LP.c('wood'), { noCaps: true });
    // أشعة: نرسمها كمنشورات بين المحور والإطار
    for (let k = 0; k < 6; k++) { const a = k / 6 * Math.PI * 2; LP.prism(P.wheel, c, [c[0], c[1] + Math.cos(a) * (R - 0.03), c[2] + Math.sin(a) * (R - 0.03)], 0.025, 0.02, 4, LP.c('woodLight')); }
  }
  function cart(p, q) {
    const P = kit(), rng = AA.rng(p.seed), L = p.length, W = 1.15, R = p.wheel, bedY = R + 0.08;
    AA.box(P.wood, [0, bedY, 0], [W, 0.04, L], vary(LP.c('woodLight'), rng, 0.05), 1, {});
    for (let k = 1; k < 7; k++) AA.box(P.dark, [-W / 2 + k * W / 7, bedY + 0.021, 0], [0.008, 0.002, L], LP.c('wood'), 1, {});
    let hitch = null;
    if (p.animal !== 'none') {
      const id = 'lp_' + p.animal, ap = AA.params(AA.assets[id], { seed: p.seed + 5, harness: true }), am = AA.assets[id].generate(ap, 'low').meta.hitch;
      const az = L / 2 + 0.32 - am.rump, sY = am.shaftY, hw = am.halfWidth + 0.07, zEnd = az + am.shoulder;
      hitch = { asset: id, params: ap, at: [0, 0, az] };
      for (const s of [1, -1]) {
        const a0 = [s * (W / 2 - 0.05), bedY - 0.05, -L / 2 + 0.1], a1 = [s * (W / 2 - 0.05), bedY - 0.05, L / 2], a2 = [s * hw, sY, zEnd];
        LP.prism(P.wood, a0, a1, 0.04, 0.04, 4, LP.c('wood')); LP.prism(P.wood, a1, a2, 0.04, 0.035, 4, LP.c('wood'));
        AA.box(P.dark, [s * hw, sY, zEnd - 0.04], [0.09, 0.09, 0.05], LP.c('#5e3b22'), 1, {});
      }
      plank(P, [0, bedY - 0.02, L / 2 + 0.04], [W - 0.1, 0.06, 0.06], rng, 'wood');
    }
    for (const s of [1, -1]) {
      if (p.animal === 'none') plank(P, [s * (W / 2 - 0.05), bedY - 0.05, 0.3], [0.08, 0.07, L + 0.6 + p.shafts], rng, 'wood');
      plank(P, [s * (W / 2 - 0.01), bedY + 0.16, 0], [0.04, 0.24, L], rng);
      for (const z of [-L / 2 + 0.05, -L / 6, L / 6, L / 2 - 0.05]) plank(P, [s * (W / 2 - 0.01), bedY + 0.16, z], [0.06, 0.3, 0.06], rng, 'wood');
    }
    plank(P, [0, bedY + 0.16, -L / 2 + 0.01], [W, 0.24, 0.04], rng);
    if (p.animal === 'none') { plank(P, [0, bedY + 0.16, L / 2 + 0.6 + p.shafts / 2 - 0.05], [W - 0.1, 0.06, 0.06], rng, 'wood'); plank(P, [0, (bedY - 0.06) / 2, L / 2 + 0.35], [0.06, bedY - 0.06, 0.06], rng, 'wood'); }
    LP.prism(P.metal, [-W / 2 - 0.12, R, -0.1], [W / 2 + 0.12, R, -0.1], 0.03, 0.03, 6, LP.c('#3a3330'));
    for (const s of [1, -1]) wheel(P, [s * (W / 2 + 0.1), R, -0.1], R, rng, q);
    if (p.load === 'sacks') [[-0.3, -0.45], [0.28, -0.4], [-0.28, 0.25], [0.3, 0.3]].forEach(([x, z], k) => sackInto(P, { at: [x, bedY + 0.02, z * L / 1.6], rot: rng() * 6 }, { height: 0.55, radius: 0.22, open: k % 2 === 1, goods: ['spice_red', 'spice_yellow', 'rice', 'coffee'][k] }, rng));
    else if (p.load === 'crates') { crateInto(P, { at: [-0.25, bedY + 0.02, -0.3], rot: 0.05 }, { w: 0.5, d: 0.38, h: 0.3, goods: 'oranges' }, rng); crateInto(P, { at: [0.27, bedY + 0.02, -0.25], rot: -0.08 }, { w: 0.5, d: 0.38, h: 0.3, goods: 'lemons' }, rng); crateInto(P, { at: [0, bedY + 0.02, 0.3], rot: 0.02 }, { w: 0.5, d: 0.38, h: 0.3, goods: 'tomatoes' }, rng); crateInto(P, { at: [-0.22, bedY + 0.32, -0.28], rot: 0.12 }, { w: 0.5, d: 0.38, h: 0.3, lid: true }, rng); }
    else if (p.load === 'dates') for (let k = 0; k < 5; k++) basketInto(P, { at: [(k % 2 ? 0.27 : -0.27), bedY + 0.02, -0.45 + k * 0.24] }, { radius: 0.17, height: 0.2, flare: 1.25, goods: 'dates' }, rng);
    return done('lp_cart', P, { height: bedY + 0.6, radius: (L + 1.2) / 2 + (hitch ? 1 : 0), collider: { type: 'box', size: [W + 0.3, bedY + 0.3, L + 0.6 + p.shafts] }, physics: { mass: 120, friction: 0.5 },
      wheels: [[W / 2 + 0.1, R, -0.1], [-(W / 2 + 0.1), R, -0.1]], wheelRadius: R, spin: { pivot: [0, R, -0.1], axis: 'x', radius: R }, hitch, walkSpeed: hitch ? AA.assets[hitch.asset].generate(hitch.params, 'low').meta.walkSpeed : 0 });
  }

  // ---------- قطع صغيرة ----------
  function sack(p, q) { const P = kit(), rng = AA.rng(p.seed), R = p.height * 0.4; sackInto(P, null, { height: p.height, radius: R, open: p.open, goods: p.goods }, rng); return done('lp_sack', P, { height: p.height, radius: R * 1.1, collider: { type: 'cylinder', radius: R, height: p.height }, physics: { mass: 35 * p.height, friction: 0.8 } }); }
  function crate(p, q) {
    const P = kit(), rng = AA.rng(p.seed), w = p.width, d = w * 0.72, h = w * 0.55;
    for (let k = 0; k < p.stack; k++) crateInto(P, { at: [0, k * (h + 0.005), 0], rot: k ? (rng() - 0.5) * 0.15 : 0 }, { w, d, h, goods: k === p.stack - 1 ? p.goods : 'closed', lid: k < p.stack - 1 }, rng);
    return done('lp_crate', P, { height: h * p.stack + 0.03, radius: w * 0.6, collider: { type: 'box', size: [w, h * p.stack, d] }, physics: { mass: 12 * p.stack, friction: 0.6 } });
  }
  function basket(p, q) {
    const P = kit(), rng = AA.rng(p.seed), tall = p.shape === 'tall', r = p.radius, h = tall ? r * 2 : r;
    basketInto(P, null, { radius: r, height: h, flare: tall ? 1.1 : 1.3, goods: p.goods, handles: p.handles }, rng);
    return done('lp_basket', P, { height: h + 0.08, radius: r * 1.3, collider: { type: 'cylinder', radius: r * 1.2, height: h }, physics: { mass: 3, friction: 0.7 } });
  }
  function fenceRun(P, x0, x1, z, style, H, rng) {
    const L = x1 - x0, n = Math.max(1, Math.round(L / (style === 'fronds' ? 1.6 : 2)));
    for (let k = 0; k <= n; k++) post(P, [lerp(x0, x1, k / n), 0, z], H + 0.12, style === 'fronds' ? 0.05 : 0.06, rng);
    if (style === 'rails') { for (const y of [H * 0.3, H * 0.62, H * 0.92]) for (let k = 0; k < n; k++) { const a = lerp(x0, x1, k / n), b = lerp(x0, x1, (k + 1) / n); AA.box(P.wood, [(a + b) / 2, y + (rng() - 0.5) * 0.03, z + 0.06], [b - a + 0.12, 0.08, 0.04], vary(LP.c('woodLight'), rng, 0.12), 1, {}, (rng() - 0.5) * 0.04); } }
    else if (style === 'pickets') { for (const y of [H * 0.25, H * 0.75]) AA.box(P.wood, [(x0 + x1) / 2, y, z + 0.05], [L + 0.1, 0.07, 0.035], LP.c('wood'), 1, {}); for (let x = x0 + 0.08; x < x1 - 0.04; x += 0.18) { const h = H * (0.95 + rng() * 0.1); AA.box(P.wood, [x, h / 2, z + 0.08], [0.1, h, 0.025], vary(LP.c('woodLight'), rng, 0.14), 1, {}); LP.tri(P.wood, [x - 0.05, h, z + 0.0925], [x + 0.05, h, z + 0.0925], [x, h + 0.07, z + 0.0925], LP.c('woodLight'), [0, 0, 1]); } }
    else { for (let x = x0 + 0.04; x < x1 - 0.02; x += 0.09) { const h = H * (0.9 + rng() * 0.2), col = vary(LP.c('palmDry'), rng, 0.14); LP.tri(P.weave, [x - 0.05, 0, z], [x + 0.05, 0, z], [x + (rng() - 0.5) * 0.06, h, z], col, [0, 0, 1]); } for (const y of [H * 0.35, H * 0.75]) LP.prism(P.rope, [x0, y, z + 0.03], [x1, y, z + 0.03], 0.012, 0.012, 4, LP.c('#9a7a4a')); }
  }
  function fence(p, q) { const P = kit(), rng = AA.rng(p.seed); fenceRun(P, -p.length / 2, p.length / 2, 0, p.style, p.height, rng); return done('lp_fence', P, { height: p.height + 0.15, radius: p.length / 2, collider: { type: 'box', size: [p.length, p.height, 0.15] }, snap: { length: p.length } }); }
  function pen(p, q) {
    const P = kit(), rng = AA.rng(p.seed), W = p.width, D = p.depth, H = p.height, g2 = 1.4;
    place(P, { at: [0, 0, -D / 2], rot: 0 }, () => fenceRun(P, -W / 2, W / 2, 0, p.style, H, rng));
    place(P, { at: [-W / 2, 0, 0], rot: Math.PI / 2 }, () => fenceRun(P, -D / 2, D / 2, 0, p.style, H, rng));
    place(P, { at: [W / 2, 0, 0], rot: -Math.PI / 2 }, () => fenceRun(P, -D / 2, D / 2, 0, p.style, H, rng));
    place(P, { at: [0, 0, D / 2], rot: Math.PI }, () => { fenceRun(P, -W / 2, -g2 / 2, 0, p.style, H, rng); fenceRun(P, g2 / 2, W / 2, 0, p.style, H, rng); });
    place(P, { at: [-g2 / 2, 0, D / 2], rot: -p.gate * 1.4 }, () => {
      for (const y of [0.15, H * 0.5, H - 0.08]) AA.box(P.wood, [g2 / 2, y, 0], [g2 - 0.04, 0.08, 0.045], vary(LP.c('woodLight'), rng, 0.1), 1, {});
      for (const x of [0.04, g2 - 0.04]) AA.box(P.wood, [x, H / 2, 0], [0.07, H, 0.05], LP.c('wood'), 1, {});
      AA.box(P.wood, [g2 / 2, H / 2, 0.01], [0.06, Math.hypot(g2, H) - 0.15, 0.04], LP.c('wood'), 1, {}, Math.atan2(g2, H));
    });
    if (p.feeder) place(P, { at: [-W / 2 + 1.0, 0, -D / 2 + 0.5] }, () => {
      for (const s of [1, -1]) AA.box(P.wood, [0, 0.25, s * 0.22], [1.6, 0.4, 0.04], LP.c('woodLight'), 1, {});
      for (const s of [1, -1]) AA.box(P.wood, [s * 0.8, 0.26, 0], [0.04, 0.38, 0.4], LP.c('woodLight'), 1, {});
      AA.box(P.wood, [0, 0.11, 0], [1.56, 0.04, 0.4], LP.c('wood'), 1, {});
      LP.ico(P.goods, [0, 0.38, 0], [0.75, 0.1, 0.18], 0, () => vary(LP.c('#c9b45a'), rng, 0.1), { keep: d => d[1] > -0.3 });
    });
    return done('lp_pen', P, { height: H + 0.15, radius: Math.max(W, D) / 2, collider: { type: 'compound' }, gate: { at: [0, 0, D / 2], width: g2 } });
  }

  LP.def('kiosk', kiosk); LP.def('shop', shop); LP.def('cart', cart); LP.def('sack', sack); LP.def('crate', crate); LP.def('basket', basket); LP.def('fence', fence); LP.def('pen', pen);
  LP.souq = { place, sackInto, crateInto, basketInto, kit, done, GOODS };
})(typeof window !== 'undefined' ? window : globalThis);
