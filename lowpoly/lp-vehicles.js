// Aboden Assets — lowpoly/lp-vehicles.js — المركبات بأسلوب لو-بولي: جيب، وانيت، لوري، وايت
// نفس الأبعاد ومواضع العجلات والمقاعد والأبواب في الحزمة الواقعية: عجلات تدور (والأمامية تلف مع المقود)،
// وأبواب بمفصّل عمودي، وأنوار أمامية تتوهج ليلاً. الجسم مقطع جانبي مبثوق بأقواس للعجلات.
(function (g) {
  'use strict';
  const AA = g.AA, LP = AA.lp, V = AA.v, vary = AA.vary, lerp = AA.lerp, mixc = AA.mixc, smooth = AA.smooth;
  const PAINT = { white: '#eeeeea', beige: '#d6c6a2', red: '#b8322c', blue: '#2f5a9a', black: '#262628', champagne: '#cdb894', green: '#5f6b45', silver: '#b9bec2' };
  const DUST = '#c2a274';
  function kit() { const k = {}; for (const n of ['paint', 'trim', 'chrome', 'glass', 'lamp', 'tail', 'amber', 'tireFL', 'tireFR', 'tireR', 'rimFL', 'rimFR', 'rimR', 'interior', 'under', 'burlap', 'rope', 'goods', 'wood', 'hay', 'weave', 'clay', 'metal', 'mud', 'mudTop', 'dark']) k[n] = new AA.Builder(); return k; }
  function done(id, P, meta, axF, axR, R, ex) {
    const spinR = { pivot: [0, R, axR], axis: 'x', radius: R }, spinFx = sx => ({ pivot: [sx * ex.wx, R, axF], axis: 'x', radius: R, steer: true }), parts = {};
    (ex.doors || []).forEach((d, k) => { for (const [sd, sx] of [['L', 1], ['R', -1]]) {
      const hinge = { id: 'door' + k + sd, pivot: [sx * ex.W, 0, d[1]], axis: 'y', sign: -sx, max: 1.15 };
      parts['door' + k + sd] = { builder: P['door' + k + sd], material: LP.mat('paint', { roughness: 0.5, doubleSided: true, hinge }) };
      parts['dglass' + k + sd] = { builder: P['dglass' + k + sd], material: LP.mat('glass', { roughness: 0.1, opacity: 0.55, doubleSided: true, hinge }) };
    } });
    return LP.finalize(id, Object.assign({
      paint: { builder: P.paint, material: LP.mat('paint', { roughness: 0.5, doubleSided: true }) }, trim: { builder: P.trim, material: LP.mat('plastic') },
      chrome: { builder: P.chrome, material: LP.mat('metal', { metalness: 0.5, roughness: 0.3 }) }, glass: { builder: P.glass, material: LP.mat('glass', { roughness: 0.1, opacity: 0.55, doubleSided: true }) },
      lamp: { builder: P.lamp, material: LP.mat('lamp', { emissive: [1, 0.95, 0.82], glow: 1.1 }) }, tail: { builder: P.tail, material: LP.mat('lamp', { emissive: [0.9, 0.05, 0.03], glow: 0.5 }) },
      amber: { builder: P.amber, material: LP.mat('lamp', { emissive: [1, 0.5, 0.05], glow: 0.3 }) },
      tireFL: { builder: P.tireFL, material: LP.mat('rubber', { spin: spinFx(1) }) }, tireFR: { builder: P.tireFR, material: LP.mat('rubber', { spin: spinFx(-1) }) }, tireR: { builder: P.tireR, material: LP.mat('rubber', { spin: spinR }) },
      rimFL: { builder: P.rimFL, material: LP.mat('metal', { metalness: 0.3, spin: spinFx(1) }) }, rimFR: { builder: P.rimFR, material: LP.mat('metal', { metalness: 0.3, spin: spinFx(-1) }) }, rimR: { builder: P.rimR, material: LP.mat('metal', { metalness: 0.3, spin: spinR }) },
      interior: { builder: P.interior, material: LP.mat('cloth') }, under: { builder: P.under, material: LP.mat('dark') },
      burlap: { builder: P.burlap, material: LP.mat('cloth') }, rope: { builder: P.rope, material: LP.mat('rope') }, goods: { builder: P.goods, material: LP.mat('fruit') },
      wood: { builder: P.wood, material: LP.mat('wood') }, hay: { builder: P.hay, material: LP.mat('hay') }, weave: { builder: P.weave, material: LP.mat('weave', { doubleSided: true }) }, dark: { builder: P.dark, material: LP.mat('dark') }
    }, parts), Object.assign({ stiffness: 0, pose: { steer: ex.steer || 0, doors: ex.open || 0 } }, meta));
  }
  // تثليث مضلع ثنائي الأبعاد (قطع الآذان)
  function earclip(pts) {
    const n = pts.length, idx = pts.map((_, i) => i), out = [], area = pts.reduce((s, p, i) => { const q = pts[(i + 1) % n]; return s + p[0] * q[1] - q[0] * p[1]; }, 0), ccw = area > 0;
    const cross = (a, b, c) => (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0]);
    const inside = (p, a, b, c) => { const d1 = cross(a, b, p), d2 = cross(b, c, p), d3 = cross(c, a, p); return ccw ? d1 > 1e-9 && d2 > 1e-9 && d3 > 1e-9 : d1 < -1e-9 && d2 < -1e-9 && d3 < -1e-9; };
    let guard = 0;
    while (idx.length > 3 && guard++ < 5000) {
      let cut = false;
      for (let i = 0; i < idx.length; i++) {
        const ia = idx[(i + idx.length - 1) % idx.length], ib = idx[i], ic = idx[(i + 1) % idx.length], a = pts[ia], b = pts[ib], c = pts[ic], cr = cross(a, b, c);
        if (ccw ? cr <= 1e-9 : cr >= -1e-9) continue;
        if (idx.some(j => j !== ia && j !== ib && j !== ic && inside(pts[j], a, b, c))) continue;
        out.push([ia, ib, ic]); idx.splice(i, 1); cut = true; break;
      }
      if (!cut) break;
    }
    if (idx.length === 3) out.push([idx[0], idx[1], idx[2]]);
    return { tris: out, ccw };
  }
  // بثق مقطع جانبي (z,y) عبر العرض: hw(y) نصف العرض عند الارتفاع y، col(p) لون الرأس
  function extrude(B, prof, hw, col, o) {
    o = o || {}; const { tris, ccw } = earclip(prof), n = prof.length, H = typeof hw === 'function' ? hw : () => hw;
    const P3 = (pt, s) => [s * H(pt[1]), pt[1], pt[0]];
    for (const s of [1, -1]) if (!o.noSides) for (const [a, b, c] of tris) LP.tri(B, P3(prof[a], s), P3(prof[b], s), P3(prof[c], s), col(P3(prof[a], s)), [s, 0, 0]);
    for (let i = 0; i < n; i++) {
      const a = prof[i], b = prof[(i + 1) % n], dz = b[0] - a[0], dy = b[1] - a[1], nrm = ccw ? [0, -dz, dy] : [0, dz, -dy];
      const A1 = P3(a, 1), B1 = P3(b, 1), A2 = P3(a, -1), B2 = P3(b, -1), c = (o.edgeCol || col)([0, (a[1] + b[1]) / 2, (a[0] + b[0]) / 2], nrm);
      LP.quad(B, A1, B1, B2, A2, c, nrm);
    }
  }
  // قوس عجلة في المقطع السفلي (من الخلف للأمام)
  const arch = (zc, R, y0, n, yMax) => { const pts = [], Ra = R + 0.08; for (let k = 0; k <= n; k++) { const a = Math.PI - k / n * Math.PI; pts.push([zc + Math.cos(a) * Ra, Math.min(yMax || 9, Math.max(y0, R + Math.sin(a) * Ra * 0.95))]); } return pts; };
  function wheelInto(T, Rm, c, R, w, sx, q, rimCol, axis) {
    const n = q === 'low' ? 8 : 12, ax = axis === 'z' ? [0, 0, 1] : [1, 0, 0], a = V.madd(c, ax, -w / 2), b = V.madd(c, ax, w / 2);
    LP.prism(T, a, b, R, R, n, LP.c('#232220'), { rot: Math.PI / n });
    LP.prism(T, V.madd(c, ax, -w / 2 - 0.005), V.madd(c, ax, w / 2 + 0.005), R * 0.78, R * 0.78, n, LP.c('#33302d'), { rot: Math.PI / n, noCaps: false });
    const out = V.madd(c, ax, sx * (w / 2 + 0.012));
    LP.prism(Rm, V.madd(c, ax, sx * (w / 2 - 0.02)), out, R * 0.56, R * 0.5, n, rimCol, { rot: Math.PI / n });
    LP.prism(Rm, out, V.madd(out, ax, sx * 0.03), R * 0.16, R * 0.12, 6, mixc(rimCol, [0, 0, 0], 0.3));
    for (let k = 0; k < 5; k++) { const ang = k / 5 * Math.PI * 2, d = axis === 'z' ? [Math.cos(ang), Math.sin(ang), 0] : [0, Math.cos(ang), Math.sin(ang)]; AA.box(Rm, V.add(V.madd(out, ax, sx * 0.004), V.scale(d, R * 0.34)), axis === 'z' ? [0.05, 0.05, 0.01] : [0.01, 0.05, 0.05], mixc(rimCol, [0, 0, 0], 0.45), 1, {}); }
  }
  // الجسم: s = { L, W, R, axF, axR, bottom, bumperY, hoodY, belt, cowlZ, glassF, roofY, roofR, cabRear, zF, zB, windows, doors, roundLamps, bed, truck }
  function bodyInto(P, s, p, q, rng) {
    const paint = LP.c(PAINT[p.color] || PAINT.white), dust = LP.c(DUST), pc = pt => vary(mixc(paint, dust, (p.dirt || 0) * (0.12 + 0.75 * smooth(s.belt, s.bottom, pt[1]))), rng, 0.015);
    const hw = s.W - 0.03, zF = s.zF || s.L / 2, zR = -s.L / 2, an = q === 'low' ? 4 : 6;
    for (let k = 0; k < (s.doors || []).length; k++) for (const sd of ['L', 'R']) { P['dglass' + k + sd] = new AA.Builder(); P['door' + k + sd] = new AA.Builder(); }
    let prof;
    if (s.truck) { // الكابينة فقط (الغطاء الأمامي منفصل)
      prof = [[s.zB, s.bottom], [s.cowlZ, s.bottom], [s.cowlZ, s.belt], [s.zB, s.belt]];
      extrude(P.paint, prof, hw, pc);
      const hoodW = 0.78; // غطاء المحرك: أضيق، ينحدر للأمام قليلاً
      extrude(P.paint, [[s.cowlZ - 0.02, s.bottom + 0.05], [zF, s.bottom + 0.05], [zF, s.hoodY - 0.12], [zF - 0.15, s.hoodY], [s.cowlZ - 0.02, s.hoodY + 0.04]], hoodW, pc);
      AA.box(P.trim, [0, (s.bottom + s.hoodY) / 2 + 0.05, zF + 0.01], [hoodW * 2 - 0.12, s.hoodY - s.bottom - 0.25, 0.04], LP.c('#2a2a2a'), 1, {}); // الشبك
      for (let k = 0; k < 6; k++) AA.box(P.chrome, [0, s.bottom + 0.25 + k * 0.1, zF + 0.035], [hoodW * 2 - 0.2, 0.025, 0.01], LP.c('#c9cacb'), 1, {});
    } else {
      const bot = [[zR, s.bottom]].concat(arch(s.axR, s.R, s.bottom, an, s.bed ? s.bed - 0.05 : null), arch(s.axF, s.R, s.bottom, an), [[zF, s.bottom]]);
      const top = s.bed ? [[zF, s.bumperY + 0.1], [zF - 0.05, s.hoodY - 0.06], [zF - 0.3, s.hoodY], [s.cowlZ, s.hoodY + 0.02], [s.cabRear, s.belt], [s.cabRear, s.bed], [zR, s.bed]]
        : [[zF, s.bumperY + 0.1], [zF - 0.05, s.hoodY - 0.06], [zF - 0.3, s.hoodY], [s.cowlZ, s.hoodY + 0.02], [zR + 0.02, s.belt], [zR, s.belt - 0.1]];
      prof = bot.concat(top);
      extrude(P.paint, prof, hw, pc, { edgeCol: (pt, n) => n[1] < -0.3 ? LP.c('#2a2826') : pc(pt) });
    }
    // القمرة الزجاجية: إطار ملوّن بأعمدة، وألواح زجاج داكن
    const gh = [[s.cowlZ, s.belt], [s.glassF, s.roofY], [s.roofR, s.roofY], [s.cabRear, s.belt]], ghw = y => hw - 0.12 * (y - s.belt) / (s.roofY - s.belt);
    extrude(P.paint, gh, ghw, pc);
    const glassC = LP.c('#2c3a44');
    const gx = y => ghw(y) + 0.008;
    // زجاج أمامي وخلفي
    { const a = [s.cowlZ - 0.04, s.belt + 0.04], b = [s.glassF + 0.03, s.roofY - 0.05], d = V.norm([0, s.glassF - s.cowlZ, -(s.roofY - s.belt)]).map(v => v * 0.01);
      const w0 = ghw(a[1]) - 0.06, w1 = ghw(b[1]) - 0.06, f = (x, y, z) => [x, y - d[1] * 0, z + 0.012];
      LP.quad(P.glass, f(-w0, a[1], a[0]), f(w0, a[1], a[0]), f(w1, b[1], b[0]), f(-w1, b[1], b[0]), glassC, [0, s.glassF - s.cowlZ < 0 ? 0.6 : 0.6, 1]); }
    { const a = [s.cabRear - 0.012, s.belt + 0.08], b = [s.roofR - 0.012, s.roofY - 0.06], w0 = ghw(a[1]) - 0.08, w1 = ghw(b[1]) - 0.08;
      LP.quad(P.glass, [w0, a[1], a[0]], [-w0, a[1], a[0]], [-w1, b[1], b[0]], [w1, b[1], b[0]], glassC, [0, 0, -1]); }
    // نوافذ جانبية (للأجزاء غير المتحركة) — زجاج الأبواب يُرسم مع الباب
    const doorZ = (s.doors || []).map(d => d);
    for (const [z0, z1] of s.windows || []) {
      const isDoor = doorZ.some(d => z0 >= d[0] - 0.08 && z1 <= d[1] + 0.08);
      for (const sx of [1, -1]) {
        const B = isDoor ? P['dglass' + doorZ.findIndex(d => z0 >= d[0] - 0.08 && z1 <= d[1] + 0.08) + (sx > 0 ? 'L' : 'R')] : P.glass;
        const yb = s.belt + 0.05, yt = s.roofY - 0.07, zt0 = Math.max(z0, lerp(s.cabRear, s.roofR, (yt - s.belt) / (s.roofY - s.belt)) + 0.04), zt1 = Math.min(z1, lerp(s.cowlZ, s.glassF, (yt - s.belt) / (s.roofY - s.belt)) - 0.04);
        LP.quad(B, [sx * gx(yb), yb, z0], [sx * gx(yb), yb, z1], [sx * gx(yt), yt, zt1], [sx * gx(yt), yt, zt0], glassC, [sx, 0, 0]);
      }
    }
    // الأبواب: لوح بارز قليلاً على جانب الجسم بخطوط داكنة ومقبض
    (s.doors || []).forEach(([z0, z1], k) => { for (const [sd, sx] of [['L', 1], ['R', -1]]) {
      const B = P['door' + k + sd] = P['door' + k + sd] || new AA.Builder(), y0 = s.bottom + 0.06, y1 = s.belt - 0.01, x0 = sx * (hw + 0.002), x1 = sx * (hw + 0.03);
      const dp = [[z0, y0], [z1, y0], [z1, y1], [z0, y1]];
      for (const [x, nx] of [[x1, sx], [x0, -sx]]) LP.quad(B, [x, y0, z0], [x, y0, z1], [x, y1, z1], [x, y1, z0], pc([x, (y0 + y1) / 2, z0]), [nx, 0, 0]);
      for (let i = 0; i < 4; i++) { const a = dp[i], b = dp[(i + 1) % 4]; LP.quad(B, [x0, a[1], a[0]], [x0, b[1], b[0]], [x1, b[1], b[0]], [x1, a[1], a[0]], mixc(paint, [0, 0, 0], 0.4), [0, b[0] - a[0] === 0 ? 0 : (i === 0 ? -1 : 1), a[1] === b[1] ? 0 : (i === 1 ? 1 : -1)].map((v, j) => j === 0 ? 0 : v)); }
      AA.box(B, [sx * (hw + 0.04), y1 - 0.12, z0 + 0.15], [0.02, 0.03, 0.12], LP.c('#2a2a2a'), 1, {});
    } });
    // داخل القمرة: عتمة ومقاعد حتى لا يُرى الفراغ من الزجاج
    AA.box(P.interior, [0, (s.belt + s.roofY) / 2 - 0.1, (s.cowlZ + s.cabRear) / 2], [hw * 2 - 0.3, s.roofY - s.belt - 0.1, Math.abs(s.cowlZ - s.cabRear) - 0.3], LP.c('#2a2624'), 1, {});
    // الصدامات والأنوار
    if (!s.truck) {
      const bc = p.bumper === 'chrome' ? P.chrome : P.trim, bcol = p.bumper === 'chrome' ? LP.c('#c9cacb') : LP.c('#2a2a2a');
      AA.box(bc, [0, s.bumperY, zF + 0.06], [hw * 2 + 0.06, 0.16, 0.14], bcol, 1, {}); AA.box(bc, [0, s.bumperY, zR - 0.06], [hw * 2 + 0.06, 0.16, 0.14], bcol, 1, {});
      AA.box(P.trim, [0, s.hoodY - 0.2, zF + 0.005], [hw * 1.1, 0.16, 0.02], LP.c('#2a2a2a'), 1, {});
    } else AA.box(P.trim, [0, s.bumperY, zF + 0.1], [2.2, 0.22, 0.18], LP.c('#c9cacb'), 1, {});
    for (const sx of [1, -1]) {
      const ly = s.truck ? s.hoodY - 0.35 : s.hoodY - 0.2, lx = s.truck ? sx * 0.62 : sx * (hw - 0.22);
      if (s.roundLamps) LP.prism(P.lamp, [lx, ly, zF - 0.01], [lx, ly, zF + 0.025], 0.09, 0.09, 8, LP.c('#fff6dc'), { rot: Math.PI / 8 });
      else AA.box(P.lamp, [lx, ly, zF + 0.005], [0.3, 0.12, 0.03], LP.c('#fff6dc'), 1, {});
      AA.box(P.amber, [sx * (hw - 0.09), s.bumperY + 0.12, zF + 0.01], [0.1, 0.06, 0.03], LP.c('#f2a33a'), 1, {});
      if (!s.truck) AA.box(P.tail, [sx * (hw - 0.1), s.belt - 0.25, zR - 0.005], [0.12, 0.2, 0.03], LP.c('#b8231a'), 1, {});
      // مرايا جانبية
      AA.box(P.trim, [sx * (hw + 0.1), s.belt + 0.12, s.cowlZ - 0.12], [0.1, 0.14, 0.04], LP.c('#2a2a2a'), 1, {});
    }
    // ما تحت الجسم
    AA.box(P.under, [0, s.bottom - 0.08, (zF + zR) / 2], [hw * 1.4, 0.12, Math.abs(zF - zR) - 0.6], LP.c('#1c1c1c'), 1, {});
    for (const z of [s.axF, s.axR]) LP.prism(P.under, [-hw + 0.1, s.R, z], [hw - 0.1, s.R, z], 0.05, 0.05, 6, LP.c('#1c1c1c'));
  }
  const rimOf = r => LP.c(r === 'black' ? '#2a2a2a' : r === 'steel' ? '#e6e6e2' : '#b9bcbe');

  // ---------- الجيب ----------
  function jeep(p, q) {
    const P = kit(), rng = AA.rng(p.seed), R = 0.39 * p.tire, L = 4.85, W = 0.9;
    const s = { L, W, R, axF: 1.3, axR: -1.43, bottom: 0.44 + (R - 0.39), bumperY: 0.55 + (R - 0.39) * 0.8, hoodY: 1.13, belt: 1.1, cowlZ: 1.15, glassF: 0.72, roofY: 1.92, roofR: -2.32, cabRear: -2.42,
      floorY: 0.55, seatF: 0.2, seatR: -0.85, windows: [[0.02, 0.95], [-1.05, -0.08], [-2.28, -1.15]], doors: [[-0.04, 0.98], [-1.08, -0.06]], roundLamps: true };
    s.hoodY += (R - 0.39); s.belt += (R - 0.39); s.roofY += (R - 0.39) * 0.9; s.floorY += R - 0.39;
    bodyInto(P, s, p, q, rng);
    if (p.stripe) for (const sx of [1, -1]) AA.box(P.paint, [sx * (W - 0.025), s.belt - 0.2, -0.6], [0.012, 0.07, L - 1.2], LP.c('#8a3a24'), 1, {});
    const rc = rimOf(p.rims === 'silver' ? 'silver' : p.rims);
    for (const sx of [1, -1]) { wheelInto(P[sx > 0 ? 'tireFL' : 'tireFR'], P[sx > 0 ? 'rimFL' : 'rimFR'], [sx * 0.79, R, s.axF], R, 0.27, sx, q, rc); wheelInto(P.tireR, P.rimR, [sx * 0.79, R, s.axR], R, 0.27, sx, q, rc); }
    for (const sx of [1, -1]) for (const z of [s.axF, s.axR]) AA.box(P.trim, [sx * (W - 0.01), R + R + 0.12, z], [0.1, 0.06, 2 * R + 0.3], LP.c('#2a2a2a'), 1, {}); // رفارف
    if (p.spare) { wheelInto(P.trim, P.chrome, [0.25, s.belt - 0.12, -L / 2 - 0.16], R * 0.98, 0.25, 1, q, rc, 'z'); }
    if (p.snorkel) LP.chain(P.trim, [[-W - 0.03, s.belt - 0.15, s.cowlZ + 0.25], [-W - 0.05, s.belt + 0.05, s.cowlZ + 0.05], [-W + 0.0, s.roofY - 0.08, s.glassF - 0.08], [-W + 0.02, s.roofY + 0.08, s.glassF - 0.05]], [0.05, 0.05, 0.048, 0.05], 6, () => LP.c('#2a2a2a'));
    if (p.rack) {
      const y = s.roofY + 0.12, z0 = -2.1, z1 = 0.5;
      for (const sx of [1, -1]) { LP.prism(P.chrome, [sx * 0.72, y, z0], [sx * 0.72, y, z1], 0.022, 0.022, 5, LP.c('#5a5a5a')); for (const z of [z0 + 0.1, (z0 + z1) / 2, z1 - 0.1]) AA.box(P.trim, [sx * 0.72, y - 0.07, z], [0.05, 0.13, 0.05], LP.c('#2a2a2a'), 1, {}); }
      for (let k = 0; k <= 5; k++) LP.prism(P.chrome, [-0.72, y, lerp(z0, z1, k / 5)], [0.72, y, lerp(z0, z1, k / 5)], 0.016, 0.016, 4, LP.c('#5a5a5a'));
      if (p.load !== 'none') { const S = LP.souq; for (let k = 0; k < 3; k++) S.sackInto(P, { at: [-0.35 + k * 0.35, y + 0.02, -1.55 + (k % 2) * 0.2], rot: rng() * 6 }, { height: 0.5, radius: 0.2, open: false }, rng); for (let k = 0; k < 2; k++) AA.box(P.paint, [0.3 - k * 0.22, y + 0.21, -0.4], [0.18, 0.4, 0.3], LP.c('#3f5a33'), 1, {}); }
    }
    return done('lp_jeep', P, { height: s.roofY + (p.rack ? 0.5 : 0.05), radius: L / 2 + 0.3, collider: { type: 'box', size: [W * 2 + 0.2, s.roofY, L] },
      physics: { mass: 2200, centerOfMass: [0, 0.75, -0.05], wheelbase: s.axF - s.axR, track: 1.58, wheelRadius: R, suspension: { travel: 0.24, stiffness: 42000, damping: 3800 }, maxSteer: 34, drive: '4x4' },
      wheels: [[0.79, R, s.axF], [-0.79, R, s.axF], [0.79, R, s.axR], [-0.79, R, s.axR]], seats: [{ at: [0.4, s.floorY + 0.28, s.seatF], driver: true }, { at: [-0.4, s.floorY + 0.28, s.seatF] }, { at: [0.4, s.floorY + 0.28, s.seatR] }, { at: [-0.4, s.floorY + 0.28, s.seatR] }],
      light: { at: [0, s.hoodY - 0.2, L / 2 + 0.4], color: [1, 0.95, 0.82], intensity: 2.2, distance: 14 }, walkSpeed: 3.2 }, s.axF, s.axR, R, { wx: 0.79, W, doors: s.doors, steer: p.steer, open: p.doors });
  }

  // ---------- الوانيت ----------
  function pickup(p, q) {
    const P = kit(), rng = AA.rng(p.seed), R = 0.37 * p.tire, L = 5.1, W = 0.88;
    const s = { L, W, R, axF: 1.55, axR: -1.5, bottom: 0.42 + (R - 0.37), bumperY: 0.52 + (R - 0.37) * 0.8, hoodY: 1.06, belt: 1.04, cowlZ: 1.3, glassF: 0.85, roofY: 1.78, roofR: -0.5, cabRear: -0.62,
      floorY: 0.5, seatF: 0.0, windows: [[-0.47, 1.1]], doors: [[-0.52, 1.12]], roundLamps: false };
    s.hoodY += (R - 0.37); s.belt += (R - 0.37); s.roofY += (R - 0.37) * 0.9; s.floorY += R - 0.37;
    const zb0 = s.cabRear - 0.06, zb1 = -L / 2 + 0.06, fy = s.belt - 0.38, wi = W - 0.05; s.bed = fy;
    bodyInto(P, s, p, q, rng);
    const paint = LP.c(PAINT[p.color] || PAINT.white), inC = mixc(paint, [0.2, 0.2, 0.2], 0.25);
    // جدران الصندوق والباب الخلفي
    for (const sx of [1, -1]) AA.box(P.paint, [sx * (W - 0.07), (fy + s.belt) / 2, (zb0 + zb1) / 2], [0.06, s.belt - fy, zb0 - zb1 + 0.1], vary(paint, rng, 0.02), 1, {});
    AA.box(P.paint, [0, (fy + s.belt) / 2 - 0.005, zb1 - 0.03], [(W - 0.1) * 2, s.belt - fy - 0.01, 0.06], vary(paint, rng, 0.02), 1, {});
    AA.box(P.paint, [0, fy + 0.01, (zb0 + zb1) / 2], [wi * 2, 0.02, zb0 - zb1], mixc(inC, [0.1, 0.1, 0.1], 0.4), 1, {});
    for (const sx of [1, -1]) AA.box(P.paint, [sx * (wi - 0.14), fy + 0.12, s.axR], [0.28, 0.24, 0.98], inC, 1, {});
    for (const sx of [1, -1]) AA.box(P.tail, [sx * (W - 0.08), s.belt - 0.22, zb1 - 0.065], [0.12, 0.22, 0.02], LP.c('#b8231a'), 1, {});
    if (p.cage) { const top = s.belt + 0.55, zz = [zb0 + 0.05, (zb0 + zb1) / 2, zb1 + 0.05]; for (const sx of [1, -1]) { for (const z of zz) LP.prism(P.trim, [sx * (W - 0.04), s.belt, z], [sx * (W - 0.04), top, z], 0.018, 0.018, 4, LP.c('#3a3a3a')); for (const y of [s.belt + 0.28, top]) LP.prism(P.trim, [sx * (W - 0.04), y, zb0 + 0.05], [sx * (W - 0.04), y, zb1 + 0.05], 0.016, 0.016, 4, LP.c('#3a3a3a')); } for (const z of zz) LP.prism(P.trim, [-(W - 0.04), top, z], [W - 0.04, top, z], 0.016, 0.016, 4, LP.c('#3a3a3a')); }
    let riders = null; const ld = p.load, S = LP.souq;
    if (ld === 'sacks') [[-0.45, 0.2], [0.05, 0.25], [0.5, 0.2], [-0.4, 0.75], [0.1, 0.8], [0.5, 0.7], [-0.2, 0.48]].forEach(([x, t], k) => S.sackInto(P, { at: [x, fy + 0.01 + (k === 6 ? 0.42 : 0), lerp(zb0, zb1, t)], rot: rng() * 6 }, { height: 0.55, radius: 0.22, open: false }, rng));
    else if (ld === 'crates') for (let k = 0; k < 6; k++) S.crateInto(P, { at: [(k % 2 ? 0.3 : -0.3), fy + 0.01 + (k > 3 ? 0.32 : 0), lerp(zb0, zb1, 0.2 + 0.3 * (k % 4 > 1 ? 1 : 0) + (k > 3 ? 0.15 : 0))], rot: (rng() - 0.5) * 0.15 }, { w: 0.55, d: 0.42, h: 0.3, goods: k > 3 ? null : ['oranges', 'tomatoes', 'lemons', 'oranges'][k], lid: k > 3 }, rng);
    else if (ld === 'hay') for (let k = 0; k < 6; k++) { const x = (k % 2 ? 0.34 : -0.34), z = lerp(zb0, zb1, 0.22 + 0.55 * (Math.floor(k / 2) % 2)); AA.box(P.hay, [x, fy + 0.18 + (k > 3 ? 0.36 : 0), k > 3 ? lerp(zb0, zb1, 0.5) : z], [0.62, 0.36, 0.95], vary(LP.c('#d9c96a'), rng, 0.08), 1, {}); }
    else if (ld === 'sheep') { riders = []; for (let k = 0; k < 3; k++) riders.push({ asset: 'lp_sheep', params: { seed: p.seed + k, breed: k === 1 ? 'naimi' : 'najdi' }, at: [(k - 1) * 0.42, fy - 0.01, lerp(zb0, zb1, 0.35 + 0.15 * (k % 2))], rot: Math.PI / 2 + (k - 1) * 0.4 }); }
    else if (ld === 'water') for (let k = 0; k < 2; k++) LP.prism(P.paint, [(k ? 0.32 : -0.32), fy + 0.02, lerp(zb0, zb1, 0.5)], [(k ? 0.32 : -0.32), fy + 0.6, lerp(zb0, zb1, 0.5)], 0.36, 0.34, 10, LP.c('#dcdcd6'));
    const rc = rimOf(p.rims);
    for (const sx of [1, -1]) { wheelInto(P[sx > 0 ? 'tireFL' : 'tireFR'], P[sx > 0 ? 'rimFL' : 'rimFR'], [sx * 0.78, R, s.axF], R, 0.25, sx, q, rc); wheelInto(P.tireR, P.rimR, [sx * 0.78, R, s.axR], R, 0.25, sx, q, rc); }
    return done('lp_pickup', P, { height: s.roofY + (p.cage ? 0 : 0.05), radius: L / 2 + 0.3, collider: { type: 'box', size: [W * 2 + 0.2, s.roofY, L] },
      physics: { mass: 1650, centerOfMass: [0, 0.7, 0.2], wheelbase: s.axF - s.axR, track: 1.54, wheelRadius: R, suspension: { travel: 0.22, stiffness: 36000, damping: 3200 }, maxSteer: 36, drive: '4x2' },
      wheels: [[0.78, R, s.axF], [-0.78, R, s.axF], [0.78, R, s.axR], [-0.78, R, s.axR]], seats: [{ at: [0.4, s.floorY + 0.28, s.seatF], driver: true }, { at: [-0.4, s.floorY + 0.28, s.seatF] }],
      bed: { floorY: fy, z0: zb1, z1: zb0, halfWidth: wi }, riders, light: { at: [0, s.hoodY - 0.17, L / 2 + 0.4], color: [1, 0.95, 0.82], intensity: 2.2, distance: 14 }, walkSpeed: 3.6 }, s.axF, s.axR, R, { wx: 0.78, W, doors: s.doors, steer: p.steer, open: p.doors });
  }

  // ---------- اللوري والوايت ----------
  function truck(p, q, kind) {
    const P = kit(), rng = AA.rng(p.seed), R = 0.5 * p.tire, W = 1.12, axF = 2.75, axR = -2.35, zEnd = -4.15, fy = 1.32;
    const s = { L: 8, W, R, axF, axR, zF: 4.02, zB: 0.95, bottom: 1.0, bumperY: 0.92, hoodY: 1.82, belt: 1.92, cowlZ: 2.32, glassF: 2.16, roofY: 2.86, roofR: 1.06, cabRear: 0.98,
      floorY: 1.12, seatF: 1.45, windows: [[1.1, 2.12]], doors: [[1.02, 2.2]], roundLamps: true, truck: true };
    bodyInto(P, s, p, q, rng);
    const paint = LP.c(PAINT[p.color] || PAINT.red);
    for (const sx of [1, -1]) { // رفارف أمامية سميكة فوق العجلات
      const n = q === 'low' ? 4 : 6, pts = []; for (let k = 0; k <= n; k++) { const a = lerp(0.15, Math.PI - 0.15, k / n); pts.push([axF + Math.cos(a) * (R + 0.18), R + Math.sin(a) * (R + 0.18)]); }
      for (let k = 0; k < n; k++) { const a = pts[k], b = pts[k + 1], x0 = sx * (W - 0.3), x1 = sx * (W - 0.08); LP.quad(P.paint, [x0, a[1], a[0]], [x1, a[1], a[0]], [x1, b[1], b[0]], [x0, b[1], b[0]], vary(paint, rng, 0.03), [0, a[1] + b[1] - 2 * R, a[0] + b[0] - 2 * axF]); LP.quad(P.paint, [x1, a[1], a[0]], [x1, a[1] - 0.06, a[0]], [x1, b[1] - 0.06, b[0]], [x1, b[1], b[0]], vary(paint, rng, 0.03), [sx, 0, 0]); }
      AA.box(P.trim, [sx * (W - 0.12), 0.85, 1.6], [0.3, 0.05, 0.9], LP.c('#2a2a2a'), 1, {}); // درجة
    }
    AA.box(P.paint, [0, s.roofY + 0.02, s.glassF + 0.1], [W * 2 - 0.1, 0.05, 0.36], paint, 1, {});
    for (let k = -2; k <= 2; k++) AA.box(P.amber, [k * 0.3, s.roofY + 0.07, s.glassF + 0.1], [0.12, 0.06, 0.06], LP.c('#f2a33a'), 1, {});
    LP.chain(P.chrome, [[-W + 0.12, 1.0, 0.78], [-W + 0.12, 2.4, 0.78], [-W + 0.12, 3.25, 0.76]], [0.065, 0.065, 0.06], 6, () => LP.c('#9a9a9a')); // عادم
    LP.prism(P.chrome, [W - 0.18, 0.72, 0.4], [W - 0.18, 0.72, -1.0], 0.26, 0.26, 8, LP.c('#c9cacb')); // خزان وقود
    for (const sx of [1, -1]) AA.box(P.under, [sx * 0.45, 0.88, (4.0 + zEnd) / 2], [0.16, 0.26, 4.0 - zEnd], LP.c('#1c1c1c'), 1, {});
    LP.ico(P.under, [0, R, axR], [0.22, 0.22, 0.2], 0, () => LP.c('#1c1c1c'));
    const rc = rimOf(p.rims);
    for (const sx of [1, -1]) {
      wheelInto(P[sx > 0 ? 'tireFL' : 'tireFR'], P[sx > 0 ? 'rimFL' : 'rimFR'], [sx * 0.98, R, axF], R, 0.3, sx, q, rc);
      wheelInto(P.tireR, P.rimR, [sx * 1.0, R, axR], R, 0.29, sx, q, rc); wheelInto(P.tireR, P.rimR, [sx * 0.69, R, axR], R, 0.29, sx, q, mixc(rc, [0.3, 0.3, 0.3], 0.4));
      AA.box(P.trim, [sx * 0.92, 0.42, axR - R - 0.12], [0.55, 0.62, 0.02], LP.c('#2a2a2a'), 1, {});
      AA.box(P.paint, [sx * 0.88, 1.1, axR], [0.65, 0.02, 1.5], mixc(paint, [0.1, 0.1, 0.1], 0.5), 1, {});
    }
    AA.box(P.trim, [0, 0.62, zEnd + 0.05], [2.2, 0.12, 0.1], LP.c('#2a2a2a'), 1, {});
    for (const sx of [1, -1]) { AA.box(P.tail, [sx * 0.95, 0.82, zEnd], [0.22, 0.12, 0.04], LP.c('#b8231a'), 1, {}); AA.box(P.amber, [sx * 0.68, 0.82, zEnd], [0.12, 0.12, 0.04], LP.c('#f2a33a'), 1, {}); }
    let riders = null, height = s.roofY + 0.1;
    if (kind === 'lorry') {
      const z0 = 0.8, z1 = zEnd + 0.05, bw = 1.2, H = p.sideH, rows = Math.max(2, Math.round(H / 0.3)), COLS = ['#2a5a9a', '#c9302a', '#e0b030', '#2f7a4a'];
      const at = t => lerp(z0 - 0.2, z1 + 0.2, t), plankCol = r => p.painted ? LP.c(COLS[r % 4]) : vary(LP.c('woodLight'), rng, 0.1);
      AA.box(P.wood, [0, fy, (z0 + z1) / 2], [bw * 2, 0.07, z0 - z1], LP.c('woodLight'), 1, {});
      for (const sx of [1, -1]) AA.box(P.paint, [sx * (bw - 0.07), fy - 0.12, (z0 + z1) / 2], [0.1, 0.18, z0 - z1 - 0.02], LP.c('#3a3a3a'), 1, {});
      for (let r = 0; r < rows; r++) { const y = fy + 0.04 + (r + 0.5) * H / rows, h = H / rows - 0.02, c = plankCol(r);
        for (const sx of [1, -1]) AA.box(p.painted ? P.paint : P.wood, [sx * bw, y, (z0 + z1) / 2], [0.05, h, z0 - z1], c, 1, {});
        AA.box(p.painted ? P.paint : P.wood, [0, y, z1], [bw * 2 - 0.06, h, 0.05], c, 1, {}); }
      for (let r = 0; r < rows + 2; r++) { const y = fy + 0.04 + (r + 0.5) * (H + 0.6) / (rows + 2); AA.box(p.painted ? P.paint : P.wood, [0, y, z0], [bw * 2 - 0.06, (H + 0.6) / (rows + 2) - 0.02, 0.06], plankCol(r + 1), 1, {}); }
      for (const z of [z0, (z0 + z1) / 2, z1]) for (const sx of [1, -1]) AA.box(P.paint, [sx * (bw + 0.03), fy + H / 2 + 0.03, z], [0.07, H + 0.06, 0.09], LP.c('#383838'), 1, {});
      const ld = p.load, S = LP.souq;
      if (ld === 'sacks') for (let k = 0; k < 14; k++) S.sackInto(P, { at: [(k % 3 - 1) * 0.7, fy + 0.04 + (k > 8 ? 0.5 : 0), at(((k % 9) / 3 | 0) * 0.33 + 0.12 + (k > 8 ? 0.1 : 0))], rot: rng() * 6 }, { height: 0.6, radius: 0.27, open: false }, rng);
      else if (ld === 'hay') for (let k = 0; k < 12; k++) AA.box(P.hay, [(k % 2 ? 0.55 : -0.55), fy + 0.24 + Math.floor(k / 6) * 0.42, at(0.12 + (k % 6 / 2 | 0) * 0.36)], [1.0, 0.4, 1.3], vary(LP.c('#d9c96a'), rng, 0.08), 1, {});
      else if (ld === 'crates') for (let k = 0; k < 12; k++) S.crateInto(P, { at: [(k % 3 - 1) * 0.72, fy + 0.04 + (k > 8 ? 0.42 : 0), at(((k % 9) / 3 | 0) * 0.33 + 0.12)], rot: (rng() - 0.5) * 0.1 }, { w: 0.65, d: 0.5, h: 0.4, lid: true }, rng);
      else if (ld === 'camel') riders = [{ asset: 'lp_camel', params: { seed: p.seed, saddle: false, coat: 'wadh' }, at: [0, fy + 0.04, at(0.5)], rot: 0 }];
      else if (ld === 'sheep') { riders = []; for (let k = 0; k < 6; k++) riders.push({ asset: 'lp_sheep', params: { seed: p.seed + k, breed: k % 3 === 1 ? 'naimi' : k % 3 === 2 ? 'goat' : 'najdi' }, at: [(k % 2 ? 0.45 : -0.45), fy + 0.04, at(0.15 + (k >> 1) * 0.32)], rot: (rng() - 0.5) * 1.5 }); }
      height = Math.max(height, fy + H + 0.7);
    } else {
      const z0 = 0.62, z1 = zEnd + 0.15, ry = 0.82, rx = 1.08, cy = fy + 0.02 + ry, tc = LP.c(p.tank === 'steel' ? '#c8cacb' : '#f2f2ee'), band = LP.c(p.band === 'green' ? '#2f7a4a' : p.band === 'red' ? '#b8312f' : '#2a5a9a');
      const n = q === 'low' ? 10 : 14, rows = [];
      for (let k = 0; k < n; k++) { const a = k / n * Math.PI * 2; rows.push([Math.sin(a) * rx, cy + Math.cos(a) * ry]); }
      for (let k = 0; k < n; k++) { const a = rows[k], b = rows[(k + 1) % n], mid = (a[1] + b[1]) / 2 - cy, c = Math.abs(mid / ry + 0.1) < 0.2 ? band : tc; LP.quad(P.paint, [a[0], a[1], z0], [b[0], b[1], z0], [b[0], b[1], z1], [a[0], a[1], z1], c, [a[0] + b[0], mid * 2, 0]); }
      for (const [z, d] of [[z0, 1], [z1, -1]]) for (let k = 0; k < n; k++) { const a = rows[k], b = rows[(k + 1) % n]; LP.tri(P.paint, [a[0], a[1], z], [b[0], b[1], z], [0, cy, z + d * 0.16], tc, [0, 0, d]); }
      for (const z of [z0 - 0.3, (z0 + z1) / 2, z1 + 0.4]) AA.box(P.under, [0, fy + 0.12, z], [1.6, 0.24, 0.25], LP.c('#1c1c1c'), 1, {});
      for (const z of [z0 - 0.9, z1 + 1.1]) LP.prism(P.chrome, [0, cy + ry - 0.05, z], [0, cy + ry + 0.08, z], 0.26, 0.26, 8, LP.c('#c9cacb'));
      for (const sx of [1, -1]) LP.prism(P.chrome, [sx * 0.55, cy + ry + 0.25, z0 - 0.2], [sx * 0.55, cy + ry + 0.25, z1 + 0.3], 0.025, 0.025, 4, LP.c('#c9cacb'));
      for (let k = 0; k < 7; k++) LP.prism(P.chrome, [-0.25, fy + 0.4 + k * 0.28, z1 - 0.16], [0.25, fy + 0.4 + k * 0.28, z1 - 0.16], 0.018, 0.018, 4, LP.c('#c9cacb'));
      for (const sx of [1, -1]) LP.prism(P.chrome, [sx * 0.25, fy + 0.2, z1 - 0.16], [sx * 0.25, cy + ry + 0.25, z1 - 0.16], 0.022, 0.022, 4, LP.c('#c9cacb'));
      LP.chain(P.trim, [[0.5, fy + 0.25, z1 - 0.1], [0.5, fy + 0.25, z1 - 0.45], [0.5, 0.6, zEnd - 0.1]], [0.07, 0.07, 0.07], 6, () => LP.c('#2a2a2a'));
      height = Math.max(height, cy + ry + 0.3);
    }
    const mass = kind === 'lorry' ? 7500 : 11000;
    return done('lp_' + kind, P, { height, radius: 4.4, collider: { type: 'box', size: [2.5, height, 8.3] },
      physics: { mass, centerOfMass: [0, 1.2, -0.4], wheelbase: axF - axR, track: 2.0, wheelRadius: R, dualRear: true, suspension: { travel: 0.18, stiffness: 180000, damping: 14000 }, maxSteer: 38, drive: '4x2' },
      wheels: [[0.98, R, axF], [-0.98, R, axF], [1.0, R, axR], [0.69, R, axR], [-0.69, R, axR], [-1.0, R, axR]], seats: [{ at: [0.45, s.floorY + 0.28, s.seatF], driver: true }, { at: [-0.45, s.floorY + 0.28, s.seatF] }],
      riders, light: { at: [0, 1.3, 4.5], color: [1, 0.95, 0.82], intensity: 2.6, distance: 16 }, walkSpeed: 3.0, capacity: kind === 'wayt' ? { water_l: 12000 } : { kg: 6000 } }, axF, axR, R, { wx: 0.98, W, doors: s.doors, steer: p.steer, open: p.doors });
  }
  LP.def('jeep', jeep); LP.def('pickup', pickup); LP.def('lorry', (p, q) => truck(p, q, 'lorry')); LP.def('wayt', (p, q) => truck(p, q, 'wayt'));
  LP.earclip = earclip; LP.extrude = extrude;
})(typeof window !== 'undefined' ? window : globalThis);
