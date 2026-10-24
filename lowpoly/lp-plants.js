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

  const branchTo = (B, a, b, r0, r1, col, sw) => LP.prism(B, a, b, r0, r1, 5, col, { sway: pp => sw * Math.max(0, pp[1]) });

  // فسيلة: سعف ينبت من الأرض مباشرة حول قاعدة صغيرة (بدون جذع)
  function fasila(p, q) {
    const rng = AA.rng(p.seed), T = new AA.Builder(), F = new AA.Builder(), D = new AA.Builder(), low = q === 'low', L = p.frondLen;
    LP.ico(T, [0, 0.12, 0], [0.2 * L / 1.8 + 0.06, 0.2, 0.2 * L / 1.8 + 0.06], 0, d => LP.c(d[1] > 0.3 ? 'palmGreen3' : 'trunkTop'));
    const top = [0, 0.22, 0], G = [LP.c('palmGreen'), LP.c('palmGreen2')], G2 = [LP.c('palmGreen3'), LP.c('palmGreen')];
    for (let k = 0; k < p.fronds; k++) {
      const inner = k % 3 === 0, a = k * 2.39996 + rng() * 0.3, len = L * (inner ? 0.75 : 1) * (0.85 + rng() * 0.3);
      frond(F, top, a, inner ? 1.6 + rng() * 0.8 : 0.55 + rng() * 0.5, len, inner ? 0.3 : 0.55 + rng() * 0.2, inner ? G : (k % 2 ? G : G2), low ? 4 : 6, rng() * 6, 0.6, 0.02);
    }
    for (let k = 0; k < p.dry; k++) frond(D, [0, 0.12, 0], rng() * Math.PI * 2, 0.15 + rng() * 0.25, L * 0.7, 0.35, [LP.c('palmDry'), LP.c('palmDry2')], low ? 3 : 4, rng() * 6, 0.2, 0.02);
    return LP.finalize('lp_fasila', { trunk: { builder: T, material: LP.mat('wood') }, fronds: { builder: F, material: LP.mat('leaves', { doubleSided: true }) }, detail: { builder: D, material: LP.mat('leaves', { doubleSided: true }) } },
      { height: 0.5, stiffness: 0, radius: L * 0.9, collider: { type: 'cylinder', radius: 0.4, height: 0.6 } });
  }

  // سدرة: جذع قصير ملتوٍ يتفرع لثلاثة-أربعة أغصان، وتاج قبّة كثيفة من كتل خضراء داكنة، ونبق أصفر-برتقالي
  function sidr(p, q) {
    const rng = AA.rng(p.seed), W = new AA.Builder(), L = new AA.Builder(), Fr = new AA.Builder(), low = q === 'low', H = p.height, S = p.spread * H * 0.42;
    const base = [0, 0, 0], fork = [(rng() - 0.5) * 0.3, H * 0.32, (rng() - 0.5) * 0.3], tr = 0.12 + H * 0.025, sw = 0.0015;
    branchTo(W, base, fork, tr * 1.25, tr, LP.c('#8a6440'), sw);
    const nb = low ? 3 : 4, tips = [];
    for (let k = 0; k < nb; k++) {
      const a = k / nb * Math.PI * 2 + rng() * 0.6, t = [Math.cos(a) * S * 0.55, H * (0.55 + rng() * 0.12), Math.sin(a) * S * 0.55];
      branchTo(W, fork, t, tr * 0.7, tr * 0.35, LP.c('#9c7448'), sw); tips.push(t);
    }
    const C = ['#3f6b2c', '#4d7d33', '#5f9238', '#6fa33f'].map(LP.c), n = Math.round((low ? 6 : 10) * p.density);
    LP.clump(L, [0, H * 0.72, 0], [S * 0.85, H * 0.3, S * 0.85], C, rng, { detail: low ? 1 : 2, sway: 0.25, jitter: 0.18 });
    for (let k = 0; k < n; k++) {
      const a = k * 2.39996 + rng(), rr = S * (0.55 + rng() * 0.35), c = [Math.cos(a) * rr, H * (0.55 + rng() * 0.3), Math.sin(a) * rr];
      LP.clump(L, c, S * (0.34 + rng() * 0.16), C, rng, { detail: low ? 0 : 1, sway: 0.4, phase: k, flutter: 0.3 });
    }
    if (p.fruit) for (let k = 0; k < (low ? 10 : 24); k++) {
      const a = rng() * Math.PI * 2, rr = S * (0.75 + rng() * 0.3), c = [Math.cos(a) * rr, H * (0.5 + rng() * 0.32), Math.sin(a) * rr];
      LP.ico(Fr, c, 0.05, 0, () => LP.c(rng() < 0.5 ? '#e2a23e' : '#c8641f'), { sway: 0.4, phase: k });
    }
    return LP.finalize('lp_sidr', { wood: { builder: W, material: LP.mat('wood') }, leaves: { builder: L, material: LP.mat('leaves') }, fruit: { builder: Fr, material: LP.mat('fruit') } },
      { height: H, stiffness: 0.008, radius: S * 1.3, collider: { type: 'cylinder', radius: 0.28, height: 1.6 } });
  }

  // طلحة: سيقان مائلة تتفرع، ومظلة مسطحة عريضة من أقراص منخفضة، وزهر أصفر اختياري
  function talh(p, q) {
    const rng = AA.rng(p.seed), W = new AA.Builder(), L = new AA.Builder(), low = q === 'low', H = p.height, S = p.spread * H * 0.7, sw = 0.0015;
    const C = ['#5e7a35', '#6f8c3c', '#85a347', '#93b052'].map(LP.c), crownY = H * 0.86;
    for (let t = 0; t < p.trunks; t++) {
      const a = t / p.trunks * Math.PI * 2 + rng() * 0.8, lean = 0.12 + rng() * 0.12, f = [Math.cos(a) * H * lean, H * 0.45, Math.sin(a) * H * lean];
      branchTo(W, [Math.cos(a) * 0.08, 0, Math.sin(a) * 0.08], f, 0.11, 0.08, LP.c('#76583e'), sw);
      for (let k = 0; k < (low ? 2 : 3); k++) {
        const b = a + (k - 1) * 0.9 + rng() * 0.3, tip = [f[0] + Math.cos(b) * S * 0.45, crownY - 0.15 - rng() * 0.3, f[2] + Math.sin(b) * S * 0.45];
        branchTo(W, f, tip, 0.065, 0.025, LP.c('wood'), sw);
      }
    }
    const pads = Math.round((low ? 5 : 9) * Math.max(0.5, p.density));
    for (let k = 0; k < pads; k++) {
      const a = k * 2.39996, rr = k === 0 ? 0 : S * (0.25 + 0.5 * Math.sqrt(k / pads)), c = [Math.cos(a) * rr, crownY + (rng() - 0.5) * 0.25, Math.sin(a) * rr];
      const R = S * (0.38 + rng() * 0.12) * (p.density < 0.6 ? 0.6 : 1);
      LP.clump(L, c, [R, 0.24 + 0.1 * p.density, R], C, rng, { detail: low ? 0 : 1, flatBottom: 0.4, sway: 0.3, phase: k, flutter: 0.3 });
      if (p.flowers) for (let f = 0; f < (low ? 3 : 6); f++) { const fa = rng() * Math.PI * 2, fr = R * 0.8 * Math.sqrt(rng()); LP.ico(L, [c[0] + Math.cos(fa) * fr, c[1] + 0.2 + 0.1 * p.density, c[2] + Math.sin(fa) * fr], 0.06, 0, () => LP.c('#f2c53a'), { sway: 0.3, phase: k }); }
    }
    return LP.finalize('lp_talh', { wood: { builder: W, material: LP.mat('wood') }, leaves: { builder: L, material: LP.mat('leaves') } },
      { height: H, stiffness: 0.01, radius: S * 1.2, collider: { type: 'cylinder', radius: 0.22, height: 1.2 } });
  }

  // أثلة: جذع غليظ قصير وأغصان صاعدة، وكتل ريشية رمادية-خضراء متدلية (مخاريط مقلوبة)
  function athl(p, q) {
    const rng = AA.rng(p.seed), W = new AA.Builder(), L = new AA.Builder(), low = q === 'low', H = p.height, S = H * 0.32, sw = 0.0012;
    const C = ['#7a9572', '#8aa682', '#9cb893', '#adc6a2'].map(LP.c), fork = [0, H * 0.28, 0];
    branchTo(W, [0, 0, 0], fork, 0.28, 0.2, LP.c('#7d6250'), sw);
    const nb = low ? 3 : 5, tips = [];
    for (let k = 0; k < nb; k++) { const a = k / nb * Math.PI * 2 + rng() * 0.5, t = [Math.cos(a) * S * 0.6, H * (0.6 + rng() * 0.15), Math.sin(a) * S * 0.6]; branchTo(W, fork, t, 0.13, 0.05, LP.c('#8d7260'), sw); tips.push(t); }
    // تاج من عدة كتل مستطيلة رأسياً، وخصلات ريشية متدلية (مثلثات رفيعة) على الأطراف
    const nC = Math.round((low ? 5 : 8) * p.density);
    for (let k = 0; k < nC; k++) { const a = k * 2.39996, rr = k ? S * (0.35 + 0.35 * rng()) : 0, c = [Math.cos(a) * rr, H * (0.68 + rng() * 0.18), Math.sin(a) * rr]; LP.clump(L, c, [S * 0.42, H * 0.2, S * 0.42], C, rng, { detail: low ? 0 : 1, sway: 0.3, phase: k, jitter: 0.2 }); }
    const n = Math.round((low ? 10 : 26) * p.density);
    for (let k = 0; k < n; k++) {
      const a = k * 2.39996 + rng() * 0.4, rr = S * (0.6 + rng() * 0.35), top = [Math.cos(a) * rr, H * (0.6 + rng() * 0.22), Math.sin(a) * rr], len = p.droop * (0.7 + rng() * 0.6), out = [Math.cos(a), 0, Math.sin(a)], side = [-Math.sin(a), 0, Math.cos(a)];
      const col = AA.vary(C[1 + (k % 3)], rng, 0.08), tip = V.add(V.add(top, V.scale(out, 0.12)), [0, -len, 0]);
      for (const sd of [-1, 1]) { const b0 = V.add(top, V.scale(side, sd * 0.09)); const i0 = L.v(b0, col, 0.4, k, 0.3), i1 = L.v(V.add(top, V.scale(out, 0.05)), col, 0.4, k, 0.3), i2 = L.v(tip, col, 0.9, k, 0.8); L.t(i0, i1, i2); }
    }
    return LP.finalize('lp_athl', { wood: { builder: W, material: LP.mat('wood') }, leaves: { builder: L, material: LP.mat('leaves', { doubleSided: true }) } },
      { height: H, stiffness: 0.006, radius: S * 1.4, collider: { type: 'cylinder', radius: 0.4, height: 1.8 } });
  }

  // عرفج: شجيرة مدوّرة صغيرة من كتل متراكبة بخضرة رمادية، مع زهر أصفر في الربيع
  function arfaj(p, q) {
    const rng = AA.rng(p.seed), W = new AA.Builder(), L = new AA.Builder(), Fr = new AA.Builder(), low = q === 'low', S = p.size;
    const C = ['#6f7d4a', '#7f8e54', '#919f5f', '#a3ae6c'].map(LP.c);
    for (let k = 0; k < 4; k++) { const a = k * 1.6; branchTo(W, [0, 0, 0], [Math.cos(a) * S * 0.3, S * 0.35, Math.sin(a) * S * 0.3], 0.03, 0.012, LP.c('woodDark'), 0); }
    const n = Math.round((low ? 3 : 6) * p.density);
    LP.clump(L, [0, S * 0.42, 0], [S * 0.55, S * 0.42, S * 0.55], C, rng, { detail: 1, sway: 0.15 });
    for (let k = 0; k < n; k++) { const a = k * 2.39996, c = [Math.cos(a) * S * 0.38, S * (0.35 + rng() * 0.25), Math.sin(a) * S * 0.38]; LP.clump(L, c, S * (0.25 + rng() * 0.1), C, rng, { detail: 0, sway: 0.2, phase: k }); }
    if (p.bloom) for (let k = 0; k < (low ? 8 : 18); k++) { const d = V.norm([rng() - 0.5, 0.35 + rng() * 0.6, rng() - 0.5]); LP.ico(Fr, [d[0] * S * 0.6, S * 0.4 + d[1] * S * 0.45, d[2] * S * 0.6], 0.035 + S * 0.02, 0, () => LP.c(rng() < 0.7 ? '#f2c53a' : '#e8a32e'), { sway: 0.2, phase: k }); }
    return LP.finalize('lp_arfaj', { wood: { builder: W, material: LP.mat('wood') }, leaves: { builder: L, material: LP.mat('leaves') }, fruit: { builder: Fr, material: LP.mat('flower') } },
      { height: S, stiffness: 0, radius: S * 0.8, collider: { type: 'sphere', radius: S * 0.6 } });
  }

  // ثمام: خصلة سيقان (مثلثات رفيعة) تنفرج للخارج، تخضرّ أو تصفرّ حسب اليباس
  function thumam(p, q) {
    const rng = AA.rng(p.seed), L = new AA.Builder(), low = q === 'low', S = p.size, n = Math.round(p.blades / (low ? 10 : 5));
    const G = LP.c('#8fa14e'), Y = LP.c('#d6b56d'), Dy = LP.c('#b9965a');
    LP.ico(L, [0, 0.03, 0], [0.16 * S + 0.04, 0.06, 0.16 * S + 0.04], 0, () => mixc(G, Dy, p.dryness * 0.8));
    for (let k = 0; k < n; k++) {
      const a = k * 2.39996 + rng() * 0.3, out = 0.25 + rng() * 0.55, h = S * (0.6 + rng() * 0.45), r0 = 0.05 + rng() * 0.08;
      const b = [Math.cos(a) * r0, 0.02, Math.sin(a) * r0], t = [Math.cos(a) * (r0 + h * out * 0.7), h, Math.sin(a) * (r0 + h * out * 0.7)], sd = V.scale(V.norm([-Math.sin(a), 0, Math.cos(a)]), 0.025 + rng() * 0.02);
      const col = AA.vary(mixc(G, rng() < 0.5 ? Y : Dy, AA.clamp(p.dryness + (rng() - 0.5) * 0.4, 0, 1)), rng, 0.1);
      const i0 = L.v(V.add(b, sd), col, 0, 0, 0), i1 = L.v(V.sub(b, sd), col, 0, 0, 0), i2 = L.v(t, col, 0.5, k, 0.6); L.t(i0, i1, i2);
    }
    return LP.finalize('lp_thumam', { wood: { builder: new AA.Builder(), material: LP.mat('wood') }, leaves: { builder: L, material: LP.mat('leaves', { doubleSided: true }) } },
      { height: S, stiffness: 0, radius: S * 0.7, collider: { type: 'none' } });
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
    const n = Math.max(6, Math.round(p.fronds * 0.55)), FL = p.frondLen * 0.72, lf = low ? 4 : 7, G = [LP.c('palmGreen'), LP.c('palmGreen2')], G2 = [LP.c('palmGreen3'), LP.c('palmGreen')];
    for (let k = 0; k < n; k++) {
      const inner = k % 3 === 0, a = k * 2.39996 + rng() * 0.25, L = FL * (inner ? 0.78 : 1) * (0.88 + rng() * 0.24);
      const tilt = inner ? 1.1 + rng() * 0.6 : 0.15 + rng() * 0.35, droop = inner ? 0.28 : 0.55 + rng() * 0.2;
      frond(F, V.add(top, [0, 0.12, 0]), a, tilt, L, droop, inner ? G : (k % 2 ? G : G2), lf + (inner ? -1 : 0), rng() * 6, 0.65, 0.05);
    }
    // سعف يابس متدلٍّ تحت التاج
    const nd = Math.round(p.dry / (low ? 4 : 2));
    for (let k = 0; k < nd; k++) frond(D, V.add(top, [0, -0.12, 0]), k / nd * Math.PI * 2 + rng(), -0.9 - rng() * 0.5, FL * 0.6, 0.12, [LP.c('palmDry'), LP.c('palmDry2')], low ? 3 : 4, rng() * 6, 0.25, 0.08);
    // عذوق التمر: شمراخ برتقالي مقوّس ينتهي بعنقود
    const nbu = Math.round(p.bunches * 0.7), DC = { khalal: ['#e8c23a', '#d9a82c'], rutab: ['date', 'date2'], tamr: ['#7a3a1c', '#5a2812'] }[p.stage] || ['date', 'date2'];
    for (let k = 0; k < nbu; k++) {
      const a = k / Math.max(1, nbu) * Math.PI * 2 + 0.6, ca = Math.cos(a), sa = Math.sin(a);
      const s0 = V.add(top, [ca * 0.12, -0.05, sa * 0.12]), s1 = V.add(top, [ca * 0.42 * th, -0.22, sa * 0.42 * th]), c = V.add(top, [ca * 0.5 * th, -0.48, sa * 0.5 * th]);
      LP.prism(D, s0, s1, 0.035, 0.03, 4, LP.c('stalk')); LP.prism(D, s1, c, 0.03, 0.025, 4, LP.c('stalk'));
      LP.ico(D, V.add(c, [0, -0.08, 0]), [0.1 * th, 0.19 * th, 0.1 * th], low ? 0 : 1, d => vary(LP.c(d[1] > 0.2 ? DC[0] : DC[1]), rng, 0.15), { shape: d => [d[0] * (1 - 0.35 * Math.max(0, -d[1])), d[1], d[2] * (1 - 0.35 * Math.max(0, -d[1]))] });
    }
    return LP.finalize('lp_palm', {
      trunk:  { builder: T, material: LP.mat('wood') },
      fronds: { builder: F, material: LP.mat('leaves', { doubleSided: true }) },
      detail: { builder: D, material: LP.mat('fruit', { doubleSided: true }) }
    }, { height: H + 1, radius: FL, stiffness: 0.02, collider: { type: 'cylinder', radius: 0.3, height: H } });
  }

  LP.def('fasila', fasila); LP.def('sidr', sidr); LP.def('talh', talh); LP.def('athl', athl); LP.def('arfaj', arfaj); LP.def('thumam', thumam);
  LP.def('palm', palm);
})(typeof window !== 'undefined' ? window : globalThis);
