// Aboden Assets — vehicles/vehicles.js
// مركبات صحراوية عامة (بدون شعارات أو ماركات): جيب صحراوي بأبواب أربعة، ووانيت بصندوق مفتوح.
// البدن مقاطع جانبية تُمدّ عرضياً بحواف مشطوفة وفتحات عجلات حقيقية، والزجاج شفاف يبيّن المقاعد.
// العجلات الأمامية والخلفية جزءان مستقلان (spin) يدوران حول محوريهما، و meta فيها بيانات الفيزياء.
// الأمام = +Z، يسار السائق = +X (قيادة يسار).
(function (g) {
  'use strict';
  const AA = g.AA;
  const V = AA.v, hex = AA.hex, mixc = AA.mixc, vary = AA.vary, lerp = AA.lerp, smooth = AA.smooth, clamp = AA.clamp;
  const LOW = q => q === 'low';

  const PAINT = { white: '#eeeeea', beige: '#d6c6a2', red: '#9a2620', blue: '#2a4876', black: '#1a1a1c', champagne: '#c4ae84', green: '#55603e', silver: '#b4b6b6' };
  function kit() {
    const k = {};
    for (const n of ['paint', 'trim', 'chrome', 'glass', 'lamp', 'tail', 'amber', 'tireF', 'tireR', 'rimF', 'rimR', 'interior', 'under', 'burlap', 'rope', 'goods', 'wood', 'hay']) k[n] = new AA.Builder();
    return k;
  }
  function done(id, P, meta, axF, axR, R) {
    const spinF = { pivot: [0, R, axF], axis: 'x', radius: R }, spinR = { pivot: [0, R, axR], axis: 'x', radius: R };
    return AA.finalize(id, {
      paint:    { builder: P.paint,    material: { kind: 'paint', roughness: 0.36, metalness: 0.12 } },
      trim:     { builder: P.trim,     material: { kind: 'plastic', roughness: 0.6, color: [0.07, 0.07, 0.07] } },
      chrome:   { builder: P.chrome,   material: { kind: 'metal', roughness: 0.25, metalness: 0.6, color: [0.78, 0.78, 0.78] } },
      glass:    { builder: P.glass,    material: { kind: 'glass', roughness: 0.05, opacity: 0.55, doubleSided: true, color: [0.1, 0.13, 0.15] } },
      lamp:     { builder: P.lamp,     material: { kind: 'lamp', roughness: 0.2, emissive: [1, 0.95, 0.82], glow: 1.1 } },
      tail:     { builder: P.tail,     material: { kind: 'lamp', roughness: 0.3, color: [0.7, 0.08, 0.06], emissive: [0.9, 0.05, 0.03], glow: 0.5 } },
      amber:    { builder: P.amber,    material: { kind: 'lamp', roughness: 0.3, color: [0.95, 0.55, 0.1], emissive: [1, 0.5, 0.05], glow: 0.3 } },
      tireF:    { builder: P.tireF,    material: { kind: 'rubber', roughness: 0.92, color: [0.075, 0.072, 0.07], spin: spinF } },
      tireR:    { builder: P.tireR,    material: { kind: 'rubber', roughness: 0.92, color: [0.075, 0.072, 0.07], spin: spinR } },
      rimF:     { builder: P.rimF,     material: { kind: 'metal', roughness: 0.35, metalness: 0.35, spin: spinF } },
      rimR:     { builder: P.rimR,     material: { kind: 'metal', roughness: 0.35, metalness: 0.35, spin: spinR } },
      interior: { builder: P.interior, material: { kind: 'cloth', roughness: 0.95, color: [0.2, 0.18, 0.16] } },
      under:    { builder: P.under,    material: { kind: 'dark', roughness: 0.9, color: [0.05, 0.05, 0.05] } },
      burlap:   { builder: P.burlap,   material: { kind: 'cloth', texture: 'burlap', roughness: 0.95 } },
      rope:     { builder: P.rope,     material: { kind: 'rope', roughness: 1, color: [0.62, 0.5, 0.32] } },
      goods:    { builder: P.goods,    material: { kind: 'fruit', roughness: 0.6 } },
      wood:     { builder: P.wood,     material: { kind: 'wood', texture: 'wood', roughness: 0.82 } },
      hay:      { builder: P.hay,      material: { kind: 'hay', texture: 'weave', roughness: 1 } }
    }, Object.assign({ stiffness: 0 }, meta));
  }

  // ---------- هندسة مساعدة ----------
  const area2 = pts => { let a = 0; for (let i = 0; i < pts.length; i++) { const p = pts[i], q2 = pts[(i + 1) % pts.length]; a += p[0] * q2[1] - q2[0] * p[1]; } return a / 2; };
  const cr = (a, b, c) => (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0]);
  function inTri(p, a, b, c) { const d1 = cr(a, b, p), d2 = cr(b, c, p), d3 = cr(c, a, p); return d1 > 1e-9 && d2 > 1e-9 && d3 > 1e-9; }
  // تثليث مضلع (حتى غير المحدّب، مثل جانب السيارة بفتحات العجلات) بطريقة قصّ الآذان. المضلع عكس عقارب الساعة
  function earclip(pts) {
    const idx = pts.map((_, i) => i), tris = [];
    let guard = 0;
    while (idx.length > 3 && guard++ < 10000) {
      let found = false;
      for (let i = 0; i < idx.length; i++) {
        const a = idx[(i + idx.length - 1) % idx.length], b = idx[i], c = idx[(i + 1) % idx.length];
        if (cr(pts[a], pts[b], pts[c]) <= 1e-10) continue;
        let ok = true;
        for (const k of idx) { if (k === a || k === b || k === c) continue; if (inTri(pts[k], pts[a], pts[b], pts[c])) { ok = false; break; } }
        if (!ok) continue;
        tris.push([a, b, c]); idx.splice(i, 1); found = true; break;
      }
      if (!found) break;
    }
    if (idx.length === 3) tris.push([idx[0], idx[1], idx[2]]);
    return tris;
  }
  function tri3(B, ps, cols, want) {
    const ids = ps.map((p, k) => B.v(p, cols[k], 0, 0, 0, [0, 0]));
    const n = V.cross(V.sub(ps[1], ps[0]), V.sub(ps[2], ps[0]));
    if (V.dot(n, want) >= 0) B.t(ids[0], ids[1], ids[2]); else B.t(ids[0], ids[2], ids[1]);
  }
  /*
   مقطع جانبي (z, y) يُمدّ على X من −w إلى +w بحواف مشطوفة r.
   w(z, y): نصف العرض (يسمح بميلان الزجاج للداخل). color(p): لون كل نقطة. skip: أضلاع لا يُرسم سطحها (فتحة الصندوق)
  */
  function extrudeX(B, prof, o) {
    let P = prof.map(p => p.slice());
    if (area2(P) < 0) P.reverse();
    const n = P.length, r = o.r || 0.04, wF = o.w, col = o.color || (() => [1, 1, 1]), skip = o.skip || (() => false);
    const en = []; // متجه الخروج لكل ضلع
    for (let i = 0; i < n; i++) { const a = P[i], b = P[(i + 1) % n], du = b[0] - a[0], dv = b[1] - a[1], l = Math.hypot(du, dv) || 1; en.push([dv / l, -du / l]); }
    const inset = P.map((p, i) => {
      const e0 = en[(i + n - 1) % n], e1 = en[i]; let m = [e0[0] + e1[0], e0[1] + e1[1]]; const ml = Math.hypot(m[0], m[1]) || 1; m = [m[0] / ml, m[1] / ml];
      const c = Math.max(0.35, m[0] * e1[0] + m[1] * e1[1]); return [p[0] - m[0] * r / c, p[1] - m[1] * r / c];
    });
    const L = [ // أربع طبقات: وجه +X مقصوص، حافة، حافة، وجه −X
      inset.map((p, i) => [wF(P[i][0], P[i][1]), p[1], p[0]]),
      P.map(p => [wF(p[0], p[1]) - r, p[1], p[0]]),
      P.map(p => [-(wF(p[0], p[1]) - r), p[1], p[0]]),
      inset.map((p, i) => [-wF(P[i][0], P[i][1]), p[1], p[0]])
    ];
    for (let i = 0; i < n; i++) {
      const j = (i + 1) % n, e = en[i], ew = [0, e[1], e[0]];
      for (let k = 0; k < 3; k++) {
        if (k === 1 && skip(i, P[i], P[j])) continue;
        const want = k === 0 ? V.norm(V.add(ew, [1, 0, 0])) : k === 2 ? V.norm(V.add(ew, [-1, 0, 0])) : ew;
        const ps = [L[k][i], L[k][j], L[k + 1][j], L[k + 1][i]];
        AA.quad(B, ps, [[0, 0], [1, 0], [1, 1], [0, 1]], ps.map(col), want);
      }
    }
    for (const t of earclip(inset)) for (const [k, sx] of [[0, 1], [3, -1]]) { const ps = t.map(i => L[k][i]); tri3(B, ps, ps.map(col), [sx, 0, 0]); }
    return { P, inset, layers: L };
  }
  // قصّ مضلع بين خطّين z0 ≤ z ≤ z1 (لتقسيم الزجاج الجانبي إلى نوافذ)
  function clipZ(poly, z0, z1) {
    const clip = (pts, keep, inter) => { const out = []; for (let i = 0; i < pts.length; i++) { const a = pts[i], b = pts[(i + 1) % pts.length], ka = keep(a), kb = keep(b); if (ka) out.push(a); if (ka !== kb) out.push(inter(a, b)); } return out; };
    const at = z => (a, b) => { const t = (z - a[0]) / (b[0] - a[0]); return [z, a[1] + (b[1] - a[1]) * t]; };
    return clip(clip(poly, p => p[0] >= z0, at(z0)), p => p[0] <= z1, at(z1));
  }
  function offsetPoly(poly, d) { // إزاحة للداخل (المضلع عكس عقارب الساعة)
    const P = area2(poly) < 0 ? poly.slice().reverse() : poly, n = P.length, en = [];
    for (let i = 0; i < n; i++) { const a = P[i], b = P[(i + 1) % n], du = b[0] - a[0], dv = b[1] - a[1], l = Math.hypot(du, dv) || 1; en.push([dv / l, -du / l]); }
    return P.map((p, i) => { const e0 = en[(i + n - 1) % n], e1 = en[i]; let m = [e0[0] + e1[0], e0[1] + e1[1]]; const ml = Math.hypot(m[0], m[1]) || 1; m = [m[0] / ml, m[1] / ml]; const c = Math.max(0.35, m[0] * e1[0] + m[1] * e1[1]); return [p[0] - m[0] * d / c, p[1] - m[1] * d / c]; });
  }
  // مضلع مسطّح على جانبي السيارة (زجاج، خطوط أبواب، شريط زينة) على بُعد x = ±(w + off)
  function sidePoly(B, poly, wF, off, col, sides) {
    if (poly.length < 3) return;
    const P = area2(poly) < 0 ? poly.slice().reverse() : poly;
    for (const t of earclip(P)) for (const sx of sides || [1, -1]) { const ps = t.map(i => [sx * (wF(P[i][0], P[i][1]) + off), P[i][1], P[i][0]]); tri3(B, ps, ps.map(() => col), [sx, 0, 0]); }
  }
  // مربع على سطح مائل بين نقطتين من المقطع (زجاج أمامي/خلفي)
  function slopeQuad(B, a, b, t0, t1, wF, inX, off, col) {
    const p0 = [lerp(a[0], b[0], t0), lerp(a[1], b[1], t0)], p1 = [lerp(a[0], b[0], t1), lerp(a[1], b[1], t1)], du = b[0] - a[0], dv = b[1] - a[1], l = Math.hypot(du, dv);
    let nz = dv / l, ny = -du / l; // خارج المضلع عكس عقارب الساعة؛ نتحقق بالاتجاه المطلوب لاحقاً
    const mk = (p, sx) => [sx * (wF(p[0], p[1]) - inX), p[1] + ny * off, p[0] + nz * off];
    const ps = [mk(p0, 1), mk(p1, 1), mk(p1, -1), mk(p0, -1)];
    return { ps, n: [0, ny, nz], draw: want => AA.quad(B, ps, [[0, 0], [1, 0], [1, 1], [0, 1]], [col], want) };
  }
  // نقل الرؤوس الجديدة في بنّاء: rot حول Y ثم إزاحة
  function moveNew(B, from, fn) { for (let i = from; i < B.vertexCount; i++) { const p = fn([B.pos[i * 3], B.pos[i * 3 + 1], B.pos[i * 3 + 2]]); B.pos[i * 3] = p[0]; B.pos[i * 3 + 1] = p[1]; B.pos[i * 3 + 2] = p[2]; } }

  // ---------- العجلة: إطار بنقشة بارزة + جنط ----------
  function wheelInto(T, Rm, c, R, w, side, q, rimCol, axis) {
    const sides = LOW(q) ? 16 : 32;
    const prof = [[-w / 2 + 0.012, 0.6 * R], [-w / 2, 0.74 * R], [-w / 2 + 0.008, 0.9 * R], [-w / 2 + 0.035, 0.975 * R], [-w / 2 + 0.07, R], [w / 2 - 0.07, R], [w / 2 - 0.035, 0.975 * R], [w / 2 - 0.008, 0.9 * R], [w / 2, 0.74 * R], [w / 2 - 0.012, 0.6 * R]];
    const map = axis === 'z' ? p => [c[0] + p[0], c[1] + p[2], c[2] - p[1]] : side > 0 ? p => [c[0] + p[1], c[1] - p[0], c[2] + p[2]] : p => [c[0] - p[1], c[1] + p[0], c[2] + p[2]];
    let n0 = T.vertexCount;
    AA.lathe(T, prof, { sides, color: (y, a, i) => i >= 4 && i <= 5 ? [0.85, 0.85, 0.85] : [1, 1, 1] });
    for (let i = n0; i < T.vertexCount; i++) { // نقشة الإطار: كتل بارزة متبادلة
      const x = T.pos[i * 3], z = T.pos[i * 3 + 2], r = Math.hypot(x, z); if (r < 0.96 * R) continue;
      const a = Math.atan2(x, z), k = Math.round(a / (Math.PI * 2) * sides), y = T.pos[i * 3 + 1], f = ((k + (y > 0 ? 1 : 0)) % 4 + 4) % 4 < 2 ? 1 : 0.972;
      T.pos[i * 3] = x * f; T.pos[i * 3 + 2] = z * f;
    }
    moveNew(T, n0, map);
    n0 = Rm.vertexCount;
    AA.lathe(Rm, [[w / 2 - 0.02, 0.62 * R], [w / 2 - 0.03, 0.6 * R], [w / 2 - 0.065, 0.46 * R], [w / 2 - 0.065, 0.22 * R], [w / 2 - 0.045, 0.18 * R], [w / 2 - 0.04, 0.08 * R], [w / 2 - 0.045, 0]], { sides: LOW(q) ? 12 : 20, color: (y, a, i) => i === 2 || i === 3 ? mixc(rimCol, [0.2, 0.2, 0.2], 0.15) : rimCol });
    // فتحات الجنط وصواميل
    if (!LOW(q)) for (let k = 0; k < 6; k++) { const a = k / 6 * Math.PI * 2; AA.blob(Rm, [Math.sin(a) * 0.34 * R, w / 2 - 0.06, Math.cos(a) * 0.34 * R], [0.045 * R, 0, 0], [0, 0.004, 0], [0, 0, 0.045 * R], () => [0.15, 0.15, 0.15], 0, 0, 0, null, 0, true); }
    for (let k = 0; k < 6; k++) { const a = k / 6 * Math.PI * 2 + 0.5; AA.blob(Rm, [Math.sin(a) * 0.13 * R, w / 2 - 0.04, Math.cos(a) * 0.13 * R], [0.012, 0, 0], [0, 0.012, 0], [0, 0, 0.012], () => [0.8, 0.8, 0.8], 0, 0, 0, null, 0, true); }
    moveNew(Rm, n0, map);
  }

  // ---------- البدن المشترك ----------
  // spec: { L, W, R, axF, axR, floorY, hoodY, belt, roofF, roofR, glassF, cabRear, bed }
  function bodyInto(P, s, p, q, rng) {
    const paint = hex(PAINT[p.color] || PAINT.white), dust = hex('#b8996e'), dirt = p.dirt;
    const pc = pt => vary(mixc(paint, dust, dirt * (0.15 + 0.85 * smooth(0.95, 0.42, pt[1]))), rng, 0.01);
    const W = s.W, wBody = () => W, Ra = s.R + 0.075;
    // المقطع الجانبي السفلي: مقدمة، غطاء المحرك، الخط العلوي، المؤخرة، والقاع بفتحتي العجلات
    const arch = (zc, from, to) => { const out = [], n = LOW(q) ? 6 : 12, a0 = Math.PI - Math.asin(clamp((s.bottom - s.R) / Ra, -1, 1)), a1 = Math.asin(clamp((s.bottom - s.R) / Ra, -1, 1)); for (let k = 0; k <= n; k++) { const a = lerp(a0, a1, k / n); out.push([zc + Ra * Math.cos(a), s.R + Ra * Math.sin(a)]); } return out; };
    const prof = [[s.L / 2 - 0.06, s.bottom], [s.L / 2, s.bumperY + 0.18], [s.L / 2 - 0.03, s.hoodY - 0.04], [s.L / 2 - 0.16, s.hoodY], [s.cowlZ, s.belt + 0.02]];
    if (s.bed) prof.push([s.cabRear - 0.04, s.belt], [-s.L / 2 + 0.05, s.belt - 0.02]); else prof.push([-s.L / 2 + 0.08, s.belt]);
    prof.push([-s.L / 2, s.belt - 0.1], [-s.L / 2 + 0.02, s.bottom + 0.05], [-s.L / 2 + 0.12, s.bottom]);
    // القاع من الخلف للأمام: فتحة العجلة الخلفية ثم الأمامية (عكس اتجاه الزاوية لأن المسار يمشي نحو +Z)
    for (const zc of [s.axR, s.axF]) for (const pt of arch(zc)) prof.push([pt[0], pt[1]]);
    const bedSkip = s.bed ? (i, a, b) => Math.abs(a[1] - s.belt) < 0.05 && Math.abs(b[1] - s.belt) < 0.05 && Math.max(a[0], b[0]) < s.cabRear && Math.abs(a[0] - b[0]) > 1 : null;
    const body = extrudeX(P.paint, prof, { w: wBody, r: 0.05, color: pc, skip: bedSkip });
    // الكابينة / الجزء الزجاجي: تميل جوانبه للداخل
    const gW = (z, y) => W - 0.05 - 0.09 * clamp((y - s.belt) / (s.roofY - s.belt), 0, 1);
    const gh = [[s.cowlZ - 0.02, s.belt], [s.glassF, s.roofY - 0.02], [s.glassF - 0.12, s.roofY], [s.roofR + 0.1, s.roofY], [s.roofR, s.roofY - 0.05], [s.cabRear, s.belt]];
    extrudeX(P.paint, gh, { w: gW, r: 0.045, color: pc });
    // الزجاج الجانبي: نوافذ مفصولة بأعمدة
    const inner = offsetPoly(gh, 0.075).filter(pt => pt[1] > s.belt + 0.03 || true).map(pt => [pt[0], Math.max(pt[1], s.belt + 0.06)]);
    for (const [z0, z1] of s.windows) sidePoly(P.glass, clipZ(inner, z0, z1), gW, 0.004, [1, 1, 1]);
    // الزجاج الأمامي والخلفي
    { const a = gh[0], b = gh[1], sq = slopeQuad(P.glass, a, b, 0.07, 0.93, gW, 0.1, 0.006, [1, 1, 1]); sq.draw(V.norm([0, 0.5, 1])); }
    { const a = gh[4], b = gh[5], sq = slopeQuad(P.glass, a, b, 0.1, 0.85, gW, 0.12, 0.006, [1, 1, 1]); sq.draw([0, 0.2, -1]); }
    // خطوط الأبواب ومقابضها
    const archTop = z => { let y = s.bottom + 0.1; for (const zc of [s.axF, s.axR]) if (Math.abs(z - zc) < Ra) y = Math.max(y, s.R + Math.sqrt(Ra * Ra - (z - zc) * (z - zc)) + 0.06); return y; };
    for (const z of s.seams) { const y0 = archTop(z); sidePoly(P.trim, [[z - 0.006, y0], [z + 0.006, y0], [z + 0.006, s.belt - 0.04], [z - 0.006, s.belt - 0.04]], wBody, 0.003, [1, 1, 1]); }
    for (const z of s.handles) AA.box(P.trim, [W + 0.012, s.belt - 0.13, z], [0.025, 0.035, 0.16], [1, 1, 1], 1, {}), AA.box(P.trim, [-W - 0.012, s.belt - 0.13, z], [0.025, 0.035, 0.16], [1, 1, 1], 1, {});
    if (p.stripe) for (const [y0, y1] of [[s.belt - 0.24, s.belt - 0.2], [s.belt - 0.18, s.belt - 0.165]]) sidePoly(P.trim, clipZ([[-s.L / 2 + 0.15, y0], [s.L / 2 - 0.2, y0], [s.L / 2 - 0.2, y1], [-s.L / 2 + 0.15, y1]], -9, 9), wBody, 0.004, [1, 1, 1]);
    // شريط بلاستيك سفلي وحواف فتحات العجلات
    for (const zc of [s.axF, s.axR]) for (const sx of [1, -1]) {
      const pts = arch(zc).map(pt => [sx * (W + 0.01), pt[1], pt[0]]);
      AA.tube(P.trim, pts, pts.map(() => 0.035), 5, () => [1, 1, 1], () => 0, 0, null, false);
    }
    // تحت السيارة: هيكل ومحوران
    AA.box(P.under, [0, s.bottom - 0.08, (s.axF + s.axR) / 2], [W * 1.4, 0.16, s.axF - s.axR + 0.6], [1, 1, 1], 1, {});
    for (const zc of [s.axF, s.axR]) AA.loft(P.under, { path: [[-W + 0.08, s.R, zc], [W - 0.08, s.R, zc]], sides: 6, up: () => [0, 1, 0], capStart: true, capEnd: true, radius: () => 0.05, color: () => [1, 1, 1] });
    // الداخل: مقاعد، لوحة قيادة، مقود (يسار)
    AA.box(P.interior, [0, s.belt - 0.02, s.cowlZ - 0.3], [W * 2 - 0.2, 0.22, 0.4], [1, 1, 1], 1, {});
    for (const x of [0.4, -0.4]) { AA.roundBox(P.interior, [x, s.floorY + 0.2, s.seatF], [0.5, 0.14, 0.5], 0.05, { seg: 1 }); AA.roundBox(P.interior, [x, s.floorY + 0.55, s.seatF - 0.26], [0.5, 0.65, 0.12], 0.05, { seg: 1 }); }
    if (s.seatR != null) { AA.roundBox(P.interior, [0, s.floorY + 0.2, s.seatR], [W * 2 - 0.3, 0.14, 0.5], 0.05, { seg: 1 }); AA.roundBox(P.interior, [0, s.floorY + 0.55, s.seatR - 0.26], [W * 2 - 0.3, 0.6, 0.12], 0.05, { seg: 1 }); }
    { const c = [0.4, s.belt + 0.08, s.cowlZ - 0.48], ring = []; for (let k = 0; k <= 16; k++) { const a = k / 16 * Math.PI * 2; ring.push([c[0] + Math.cos(a) * 0.19, c[1] + Math.sin(a) * 0.19 * 0.8, c[2] - Math.sin(a) * 0.19 * 0.6]); } AA.tube(P.trim, ring, ring.map(() => 0.018), 5, () => [1, 1, 1], () => 0, 0, null, false); }
    // المقدمة: شبك، مصابيح، صدام، ولوحة
    const zf = s.L / 2;
    AA.box(P.trim, [0, s.hoodY - 0.2, zf + 0.005], [W * 1.15, 0.26, 0.03], [1, 1, 1], 1, {});
    for (let k = 0; k < 4; k++) AA.box(P.chrome, [0, s.hoodY - 0.11 - k * 0.06, zf + 0.022], [W * 1.12, 0.014, 0.012], [1, 1, 1], 1, {});
    for (const sx of [1, -1]) {
      if (s.roundLamps) {
        AA.loft(P.chrome, { path: [[sx * (W - 0.2), s.hoodY - 0.2, zf - 0.01], [sx * (W - 0.2), s.hoodY - 0.2, zf + 0.03]], sides: 16, up: () => [0, 1, 0], capStart: false, capEnd: false, radius: () => 0.105, color: () => [1, 1, 1] });
        AA.loft(P.lamp, { path: [[sx * (W - 0.2), s.hoodY - 0.2, zf + 0.0], [sx * (W - 0.2), s.hoodY - 0.2, zf + 0.025]], sides: 16, up: () => [0, 1, 0], capEnd: true, radius: t => 0.09 - 0.02 * t, color: () => [1, 1, 1] });
      } else {
        AA.box(P.chrome, [sx * (W - 0.24), s.hoodY - 0.17, zf + 0.004], [0.36, 0.17, 0.03], [1, 1, 1], 1, {});
        AA.box(P.lamp, [sx * (W - 0.24), s.hoodY - 0.17, zf + 0.02], [0.32, 0.13, 0.01], [1, 1, 1], 1, {});
      }
      AA.box(P.amber, [sx * (W - 0.12), s.bumperY + 0.14, zf - 0.02], [0.14, 0.06, 0.03], [1, 1, 1], 1, {});
      AA.box(P.tail, [sx * (W - 0.09), s.belt - 0.2, -s.L / 2 - 0.004], [0.16, 0.26, 0.02], [1, 1, 1], 1, {});
      AA.box(P.amber, [sx * (W - 0.09), s.belt - 0.38, -s.L / 2 - 0.004], [0.16, 0.07, 0.02], [1, 1, 1], 1, {});
      // مرآة جانبية
      AA.box(P.trim, [sx * (W + 0.08), s.belt + 0.2, s.glassF - 0.05], [0.12, 0.16, 0.05], [1, 1, 1], 1, {});
      AA.box(P.trim, [sx * (W + 0.02), s.belt + 0.14, s.glassF - 0.05], [0.08, 0.03, 0.03], [1, 1, 1], 1, {});
    }
    const bump = p.bumper === 'chrome' ? P.chrome : P.trim;
    AA.roundBox(bump, [0, s.bumperY, zf + 0.05], [W * 2 + 0.06, 0.2, 0.16], 0.05, { seg: LOW(q) ? 1 : 2 });
    AA.roundBox(bump, [0, s.bumperY, -zf - 0.05], [W * 2 + 0.06, 0.2, 0.16], 0.05, { seg: LOW(q) ? 1 : 2 });
    for (const z of [zf + 0.135, -zf - 0.135]) AA.box(P.chrome, [0, s.bumperY + 0.04, z], [0.42, 0.11, 0.01], [0.95, 0.95, 0.95], 1, {}); // لوحة بلا كتابة
    return { body, gW };
  }

  // ---------- جيب صحراوي ----------
  function jeep(p, q) {
    const P = kit(), rng = AA.rng(p.seed), R = 0.39 * p.tire, L = 4.85, W = 0.9;
    const s = { L, W, R, axF: 1.3, axR: -1.43, bottom: 0.44 + (R - 0.39), bumperY: 0.55 + (R - 0.39) * 0.8, hoodY: 1.13, belt: 1.1, cowlZ: 1.15, glassF: 0.72, roofY: 1.92, roofR: -2.32, cabRear: -2.42,
      floorY: 0.55, seatF: 0.2, seatR: -0.85, windows: [[0.02, 0.95], [-1.05, -0.08], [-2.28, -1.15]], seams: [1.0, -0.03, -1.1], handles: [0.05, -1.0], roundLamps: true };
    s.hoodY += (R - 0.39); s.belt += (R - 0.39); s.roofY += (R - 0.39) * 0.9; s.floorY += R - 0.39;
    bodyInto(P, s, p, q, rng);
    const rimCol = p.rims === 'black' ? [0.18, 0.18, 0.18] : p.rims === 'steel' ? [0.92, 0.92, 0.9] : [0.72, 0.73, 0.74];
    for (const sx of [1, -1]) { wheelInto(P.tireF, P.rimF, [sx * 0.79, R, s.axF], R, 0.27, sx, q, rimCol); wheelInto(P.tireR, P.rimR, [sx * 0.79, R, s.axR], R, 0.27, sx, q, rimCol); }
    // إطار احتياطي على الباب الخلفي
    if (p.spare) { const a = P.trim.vertexCount; wheelInto(P.trim, P.chrome, [0.25, s.belt - 0.12, -L / 2 - 0.16], R * 0.98, 0.25, 1, q, rimCol, 'z'); }
    // شنكل (سنوركل) على الجهة اليمنى
    if (p.snorkel) { const pts = [[-W - 0.03, s.belt - 0.15, s.cowlZ + 0.25], [-W - 0.05, s.belt + 0.05, s.cowlZ + 0.05], [-W + 0.0, s.roofY - 0.08, s.glassF - 0.08], [-W + 0.02, s.roofY + 0.08, s.glassF - 0.05]]; AA.tube(P.trim, pts, [0.05, 0.05, 0.048, 0.05], 8, () => [1, 1, 1], () => 0, 0, null, true); AA.box(P.trim, [-W + 0.02, s.roofY + 0.1, s.glassF - 0.0], [0.12, 0.1, 0.14], [1, 1, 1], 1, {}); }
    // حامل سقف وحمولة
    if (p.rack) {
      const y = s.roofY + 0.12, z0 = -2.1, z1 = 0.5;
      for (const sx of [1, -1]) { AA.loft(P.chrome, { path: [[sx * 0.72, y, z0], [sx * 0.72, y, z1]], sides: 6, up: () => [0, 1, 0], capStart: true, capEnd: true, radius: () => 0.022, color: () => [0.35, 0.35, 0.35] }); for (const z of [z0 + 0.1, (z0 + z1) / 2, z1 - 0.1]) AA.box(P.trim, [sx * 0.72, y - 0.07, z], [0.05, 0.13, 0.05], [1, 1, 1], 1, {}); }
      for (let k = 0; k <= 5; k++) AA.loft(P.chrome, { path: [[-0.72, y, lerp(z0, z1, k / 5)], [0.72, y, lerp(z0, z1, k / 5)]], sides: 5, up: () => [0, 1, 0], radius: () => 0.016, color: () => [0.35, 0.35, 0.35] });
      if (p.load !== 'none') { // أكياس وجالونات مربوطة
        for (let k = 0; k < 3; k++) AA.souq.sackInto(P, { at: [-0.35 + k * 0.35, y + 0.02, -1.55 + (k % 2) * 0.2], rot: rng() * 6 }, { height: 0.5, radius: 0.2, open: false, seed: k + p.seed }, rng, q);
        for (let k = 0; k < 2; k++) AA.roundBox(P.paint, [0.3 - k * 0.22, y + 0.21, -0.4], [0.18, 0.4, 0.3], 0.03, { seg: 1, color: () => [0.25, 0.35, 0.2] });
      }
    }
    const lights = { at: [0, s.hoodY - 0.2, L / 2 + 0.4], color: [1, 0.95, 0.82], intensity: 2.2, distance: 14 };
    return done('jeep', P, { height: s.roofY + (p.rack ? 0.5 : 0.05), radius: L / 2 + 0.3, collider: { type: 'box', size: [W * 2 + 0.2, s.roofY, L] },
      physics: { mass: 2200, centerOfMass: [0, 0.75, -0.05], wheelbase: s.axF - s.axR, track: 1.58, wheelRadius: R, suspension: { travel: 0.24, stiffness: 42000, damping: 3800 }, maxSteer: 34, drive: '4x4' },
      wheels: [[0.79, R, s.axF], [-0.79, R, s.axF], [0.79, R, s.axR], [-0.79, R, s.axR]], seats: [{ at: [0.4, s.floorY + 0.28, s.seatF], driver: true }, { at: [-0.4, s.floorY + 0.28, s.seatF] }, { at: [0.4, s.floorY + 0.28, s.seatR] }, { at: [-0.4, s.floorY + 0.28, s.seatR] }],
      light: lights, walkSpeed: 3.2 }, s.axF, s.axR, R);
  }

  // ---------- وانيت ----------
  function pickup(p, q) {
    const P = kit(), rng = AA.rng(p.seed), R = 0.37 * p.tire, L = 5.1, W = 0.88;
    const s = { L, W, R, axF: 1.55, axR: -1.5, bottom: 0.42 + (R - 0.37), bumperY: 0.52 + (R - 0.37) * 0.8, hoodY: 1.06, belt: 1.04, cowlZ: 1.3, glassF: 0.85, roofY: 1.78, roofR: -0.5, cabRear: -0.62,
      floorY: 0.5, seatF: 0.0, seatR: null, windows: [[-0.5, 1.1]], seams: [1.15, -0.55], handles: [-0.4], roundLamps: false, bed: true };
    s.hoodY += (R - 0.37); s.belt += (R - 0.37); s.roofY += (R - 0.37) * 0.9; s.floorY += R - 0.37;
    bodyInto(P, s, p, q, rng);
    // الصندوق: أرضية وجدران داخلية وحافة علوية وأقواس العجلات من الداخل
    const zb0 = s.cabRear - 0.06, zb1 = -L / 2 + 0.06, fy = s.belt - 0.38, wi = W - 0.05, paint = hex(PAINT[p.color] || PAINT.white), inC = mixc(paint, [0.2, 0.2, 0.2], 0.25);
    AA.quad(P.paint, [[-wi, fy, zb0], [wi, fy, zb0], [wi, fy, zb1], [-wi, fy, zb1]], [[0, 0], [1, 0], [1, 1], [0, 1]], [mixc(inC, [0.1, 0.1, 0.1], 0.4)], [0, 1, 0]);
    for (let k = 0; k < 6; k++) AA.box(P.trim, [0, fy + 0.008, lerp(zb0, zb1, (k + 0.5) / 6)], [wi * 2 - 0.05, 0.014, 0.04], [1, 1, 1], 1, {}); // مجاري الأرضية
    for (const sx of [1, -1]) AA.quad(P.paint, [[sx * wi, fy, zb0], [sx * wi, s.belt - 0.02, zb0], [sx * wi, s.belt - 0.02, zb1], [sx * wi, fy, zb1]], [[0, 0], [1, 0], [1, 1], [0, 1]], [inC], [-sx, 0, 0]);
    AA.quad(P.paint, [[-wi, fy, zb0], [wi, fy, zb0], [wi, s.belt, zb0], [-wi, s.belt, zb0]], [[0, 0], [1, 0], [1, 1], [0, 1]], [inC], [0, 0, -1]);
    AA.quad(P.paint, [[-wi, fy, zb1], [wi, fy, zb1], [wi, s.belt - 0.02, zb1], [-wi, s.belt - 0.02, zb1]], [[0, 0], [1, 0], [1, 1], [0, 1]], [inC], [0, 0, 1]);
    for (const sx of [1, -1]) AA.roundBox(P.paint, [sx * (wi - 0.14), fy + 0.12, s.axR], [0.28, 0.26, 0.98], 0.08, { seg: 1, color: () => inC });
    AA.roundBox(P.paint, [0, s.belt + 0.01, zb0 + 0.02], [W * 2 - 0.04, 0.04, 0.08], 0.015, { seg: 1, color: () => paint });
    // قفص حديد للصندوق (لنقل الغنم)
    if (p.cage) {
      const top = s.belt + 0.55, zz = [zb0 + 0.05, (zb0 + zb1) / 2, zb1 + 0.05];
      for (const sx of [1, -1]) { for (const z of zz) AA.loft(P.trim, { path: [[sx * (W - 0.04), s.belt, z], [sx * (W - 0.04), top, z]], sides: 5, up: () => [0, 0, 1], radius: () => 0.018, color: () => [1, 1, 1] }); for (const y of [s.belt + 0.28, top]) AA.loft(P.trim, { path: [[sx * (W - 0.04), y, zb0 + 0.05], [sx * (W - 0.04), y, zb1 + 0.05]], sides: 5, up: () => [0, 1, 0], radius: () => 0.016, color: () => [1, 1, 1] }); }
      for (const z of zz) AA.loft(P.trim, { path: [[-(W - 0.04), top, z], [W - 0.04, top, z]], sides: 5, up: () => [0, 1, 0], radius: () => 0.016, color: () => [1, 1, 1] });
    }
    // الحمولة
    let riders = null;
    const ld = p.load, bedL = zb0 - zb1;
    if (ld === 'sacks') { const spots = [[-0.45, 0.2], [0.05, 0.25], [0.5, 0.2], [-0.4, 0.75], [0.1, 0.8], [0.5, 0.7], [-0.2, 0.48]]; spots.forEach(([x, t], k) => AA.souq.sackInto(P, { at: [x, fy + 0.01 + (k === 6 ? 0.42 : 0), lerp(zb0, zb1, t)], rot: rng() * 6 }, { height: 0.55, radius: 0.22, open: false, seed: k + p.seed }, rng, q)); }
    else if (ld === 'crates') { for (let k = 0; k < 6; k++) AA.souq.crateInto(P, { at: [(k % 2 ? 0.3 : -0.3), fy + 0.01 + (k > 3 ? 0.32 : 0), lerp(zb0, zb1, 0.2 + 0.3 * (k % 4 > 1 ? 1 : 0) + (k > 3 ? 0.15 : 0))], rot: (rng() - 0.5) * 0.15 }, { w: 0.55, d: 0.42, h: 0.3, goods: k > 3 ? null : ['oranges', 'tomatoes', 'lemons', 'oranges'][k], lid: k > 3 }, rng, q); }
    else if (ld === 'hay') { for (let k = 0; k < 6; k++) { const x = (k % 2 ? 0.34 : -0.34), z = lerp(zb0, zb1, 0.22 + 0.55 * (Math.floor(k / 2) % 2)), y = fy + 0.18 + (k > 3 ? 0.36 : 0); AA.roundBox(P.hay, [x, y, k > 3 ? lerp(zb0, zb1, 0.5) : z], [0.62, 0.36, 0.95], 0.06, { seg: 1, tile: 0.4, color: () => vary([0.86, 0.82, 0.5], rng, 0.1) }); } }
    else if (ld === 'sheep') { riders = []; for (let k = 0; k < 3; k++) riders.push({ asset: 'sheep', params: { seed: p.seed + k, breed: k === 1 ? 'naimi' : 'najdi' }, at: [(k - 1) * 0.42, fy - 0.01, lerp(zb0, zb1, 0.35 + 0.15 * (k % 2))], rot: Math.PI / 2 + (k - 1) * 0.4 }); }
    else if (ld === 'water') { for (let k = 0; k < 2; k++) AA.loft(P.paint, { path: [[(k ? 0.32 : -0.32), fy + 0.02, lerp(zb0, zb1, 0.5)], [(k ? 0.32 : -0.32), fy + 0.6, lerp(zb0, zb1, 0.5)]], sides: LOW(q) ? 10 : 20, up: () => [0, 0, 1], capEnd: true, uvU: 1, radius: () => 0.36, color: () => [0.86, 0.86, 0.82] }); }
    const rimCol = p.rims === 'black' ? [0.18, 0.18, 0.18] : p.rims === 'steel' ? [0.92, 0.92, 0.9] : [0.72, 0.73, 0.74];
    for (const sx of [1, -1]) { wheelInto(P.tireF, P.rimF, [sx * 0.78, R, s.axF], R, 0.25, sx, q, rimCol); wheelInto(P.tireR, P.rimR, [sx * 0.78, R, s.axR], R, 0.25, sx, q, rimCol); }
    return done('pickup', P, { height: s.roofY + (p.cage ? 0 : 0.05), radius: L / 2 + 0.3, collider: { type: 'box', size: [W * 2 + 0.2, s.roofY, L] },
      physics: { mass: 1650, centerOfMass: [0, 0.7, 0.2], wheelbase: s.axF - s.axR, track: 1.54, wheelRadius: R, suspension: { travel: 0.22, stiffness: 36000, damping: 3200 }, maxSteer: 36, drive: '4x2' },
      wheels: [[0.78, R, s.axF], [-0.78, R, s.axF], [0.78, R, s.axR], [-0.78, R, s.axR]], seats: [{ at: [0.4, s.floorY + 0.28, s.seatF], driver: true }, { at: [-0.4, s.floorY + 0.28, s.seatF] }],
      bed: { floorY: fy, z0: zb1, z1: zb0, halfWidth: wi }, riders, light: { at: [0, s.hoodY - 0.17, L / 2 + 0.4], color: [1, 0.95, 0.82], intensity: 2.2, distance: 14 }, walkSpeed: 3.6 }, s.axF, s.axR, R);
  }

  const A = AA.assets;
  const colorOpt = def => ({ key: 'color', label: 'اللون', type: 'enum', options: [['white', 'أبيض'], ['beige', 'بيج'], ['champagne', 'ذهبي'], ['silver', 'فضي'], ['red', 'أحمر'], ['blue', 'أزرق'], ['green', 'زيتي'], ['black', 'أسود']], def });
  const common = [
    { key: 'dirt', label: 'غبار', min: 0, max: 1, step: 0.05, def: 0.35, pct: true },
    { key: 'tire', label: 'حجم الكفرات', min: 0.9, max: 1.25, step: 0.01, def: 1, pct: true },
    { key: 'rims', label: 'الجنوط', type: 'enum', options: [['silver', 'فضية'], ['steel', 'حديد أبيض'], ['black', 'سوداء']], def: 'silver' },
    { key: 'bumper', label: 'الصدام', type: 'enum', options: [['black', 'أسود'], ['chrome', 'كروم']], def: 'black' }
  ];
  A.jeep = { id: 'jeep', name: 'جيب صحراوي', nameEn: 'Desert 4x4', category: 'vehicles',
    schema: [colorOpt('beige')].concat(common, [
      { key: 'stripe', label: 'شريط جانبي', type: 'bool', def: true },
      { key: 'spare', label: 'كفر احتياطي', type: 'bool', def: true },
      { key: 'snorkel', label: 'شنكل هواء', type: 'bool', def: true },
      { key: 'rack', label: 'حامل سقف', type: 'bool', def: false },
      { key: 'load', label: 'حمولة السقف', type: 'enum', options: [['none', 'بدون'], ['bags', 'أكياس وجالونات']], def: 'bags' }
    ]), presets: { 'جيب مقناص': { color: 'white', rack: true, tire: 1.12, dirt: 0.6, rims: 'steel' }, 'جيب نظيف': { color: 'black', dirt: 0, stripe: false, snorkel: false, bumper: 'chrome' } }, generate: jeep };
  A.pickup = { id: 'pickup', name: 'وانيت', nameEn: 'Pickup truck', category: 'vehicles',
    schema: [colorOpt('white')].concat(common, [
      { key: 'load', label: 'الحمولة', type: 'enum', options: [['none', 'فاضي'], ['sacks', 'أكياس'], ['crates', 'صناديق'], ['hay', 'برسيم'], ['water', 'خزانات ماء'], ['sheep', 'غنم']], def: 'sacks' },
      { key: 'cage', label: 'قفص حديد', type: 'bool', def: false }
    ]), presets: { 'وانيت غنم': { load: 'sheep', cage: true, dirt: 0.5 }, 'وانيت برسيم': { load: 'hay', color: 'red' }, 'وانيت ماء': { load: 'water', color: 'blue', rims: 'steel' } }, generate: pickup };
})(typeof window !== 'undefined' ? window : globalThis);
