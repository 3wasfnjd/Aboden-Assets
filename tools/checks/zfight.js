// يكشف الطبقات المتنافسة (z-fighting) داخل كل أصل: مثلثان من جزأين مختلفين (أو نفس الجزء) في نفس المستوى تقريباً
// ويتداخلان في المساحة وكلاهما ظاهر من نفس الجهة (أو أحدهما مزدوج الوجه). الاستخدام: node zfight.js [prefix|ids]
const AA = require('./load.js'), V = AA.v;
const arg = process.argv[2] || '', ids = Object.keys(AA.assets).filter(id => !arg || (arg.includes(',') ? arg.split(',').includes(id) : id.startsWith(arg)));
const EPS_D = 0.0025, EPS_N = 0.9995, MIN_AREA = 2e-4;
function tris(out) {
  const T = [];
  for (const [pn, p] of Object.entries(out.parts)) {
    const P = p.positions, I = p.indices, ds = !!(p.material && p.material.doubleSided), skip = p.material && (p.material.opacity != null || /flame|smoke|glass|water/.test(p.material.kind || ''));
    if (skip) continue;
    for (let t = 0; t < I.length; t += 3) {
      const a = [P[I[t] * 3], P[I[t] * 3 + 1], P[I[t] * 3 + 2]], b = [P[I[t + 1] * 3], P[I[t + 1] * 3 + 1], P[I[t + 1] * 3 + 2]], c = [P[I[t + 2] * 3], P[I[t + 2] * 3 + 1], P[I[t + 2] * 3 + 2]];
      const cr = V.cross(V.sub(b, a), V.sub(c, a)), ar = V.len(cr) / 2; if (ar < MIN_AREA) continue;
      const n = V.scale(cr, 1 / (2 * ar)); if (n[1] < -0.9 && a[1] < 0.02) { T.push({ pn, a, b, c, n, d: V.dot(n, a), ds, ar, ground: true }); continue; } T.push({ pn, a, b, c, n, d: V.dot(n, a), ds, ar });
    }
  }
  return T;
}
// تداخل مثلثين في نفس المستوى: إسقاط ثنائي الأبعاد + فصل المحاور (مع هامش داخلي حتى لا نعدّ الحواف المتلاصقة)
function overlap2D(A, B, n) {
  const ax = Math.abs(n[0]) > Math.abs(n[1]) ? (Math.abs(n[0]) > Math.abs(n[2]) ? 0 : 2) : (Math.abs(n[1]) > Math.abs(n[2]) ? 1 : 2), u = (ax + 1) % 3, w = (ax + 2) % 3;
  const pa = [A.a, A.b, A.c].map(p => [p[u], p[w]]), pb = [B.a, B.b, B.c].map(p => [p[u], p[w]]);
  for (const poly of [pa, pb]) for (let i = 0; i < 3; i++) {
    const e = [poly[(i + 1) % 3][0] - poly[i][0], poly[(i + 1) % 3][1] - poly[i][1]], nn = [-e[1], e[0]], L = Math.hypot(nn[0], nn[1]) || 1;
    const pr = q => q.map(p => (p[0] * nn[0] + p[1] * nn[1]) / L), A1 = pr(pa), B1 = pr(pb);
    if (Math.max(...A1) - 0.004 <= Math.min(...B1) || Math.max(...B1) - 0.004 <= Math.min(...A1)) return false;
  }
  return true;
}
// هل النقطة داخل جسم مغلق؟ (تقاطع شعاع في ثلاثة اتجاهات، والأغلبية تحكم) — لتجاهل الأوجه المدفونة داخل الكتل
function rayHits(T, o, d) {
  let n = 0;
  for (const t of T) { const e1 = V.sub(t.b, t.a), e2 = V.sub(t.c, t.a), pv = V.cross(d, e2), det = V.dot(e1, pv); if (Math.abs(det) < 1e-12) continue; const iv = 1 / det, tv = V.sub(o, t.a), u = V.dot(tv, pv) * iv; if (u < 0 || u > 1) continue; const qv = V.cross(tv, e1), v = V.dot(d, qv) * iv; if (v < 0 || u + v > 1) continue; if (V.dot(e2, qv) * iv > 1e-5) n++; }
  return n;
}
// مخفي إذا كل الأشعة من النقطة (في نصف الكرة باتجاه الوجه) تصطدم بشيء: الوجه مدفون أو مغطّى
const DIRS = []; for (let i = 0; i < 24; i++) { const y = 1 - (i + 0.5) / 24 * 2, r = Math.sqrt(1 - y * y), a = i * 2.39996; DIRS.push([Math.cos(a) * r, y, Math.sin(a) * r]); }
function inside(T, p, n) { for (const d of DIRS) { if (V.dot(d, n) < 0.05) continue; if (rayHits(T, p, d) === 0) return false; } return true; }
let total = 0;
for (const id of ids) {
  const a = AA.assets[id]; let out; try { out = a.generate(AA.params(a, { seed: 3 }), 'med'); } catch (e) { console.log(id, 'ERR', e.message); continue; }
  const T = tris(out), TT = T.filter(t => !t.ground), buckets = new Map(), hits = new Map();
  for (const t of TT) { const key = [Math.round(t.n[0] * 20), Math.round(t.n[1] * 20), Math.round(t.n[2] * 20), Math.round(t.d / EPS_D)].join(); for (const s of [-1, 0, 1]) { const k2 = key.replace(/,[-\d]+$/, ',' + (Math.round(t.d / EPS_D) + s)); if (!buckets.has(k2)) buckets.set(k2, []); } buckets.get(key).push(t); }
  const seen = new Set();
  for (const [key, list] of buckets) {
    const parts = key.split(','), base = parts.slice(0, 3).join(), dk = +parts[3], cands = [];
    for (const s of [0, 1]) { const l2 = buckets.get(base + ',' + (dk + s)); if (l2) cands.push(...l2); }
    // ومقلوب الاتجاه (ظهر لظهر) عند وجود مادة مزدوجة الوجه
    const inv = buckets.get([-parts[0], -parts[1], -parts[2]].join() + ',' + (-dk)); if (inv) cands.push(...inv.filter(t => t.ds));
    for (let i = 0; i < list.length; i++) for (const B of cands) {
      const A = list[i]; if (A === B) continue;
      const same = V.dot(A.n, B.n) > EPS_N, opp = V.dot(A.n, B.n) < -EPS_N && (A.ds || B.ds);
      if (!same && !opp) continue;
      if (Math.abs(A.d - (same ? B.d : -B.d)) > EPS_D) continue;
      { const cA = V.scale(V.add(V.add(A.a, A.b), A.c), 1 / 3), cB = V.scale(V.add(V.add(B.a, B.b), B.c), 1 / 3); if (Math.abs(V.dot(A.n, cB) - A.d) > EPS_D || Math.abs(V.dot(B.n, cA) - B.d) > EPS_D) continue; } // المسافة الفعلية بين المستويين عند المثلثين
      const k = [A, B].map(t => T.indexOf(t)).sort((x, y) => x - y).join('-'); if (seen.has(k)) continue; seen.add(k);
      if (!overlap2D(A, B, A.n)) continue;
      if (opp) continue; // ظهر لظهر: الوجه الآخر مخفي عادة تحت جسم يغطيه
      { const cA = V.scale(V.add(V.add(A.a, A.b), A.c), 1 / 3), cB = V.scale(V.add(V.add(B.a, B.b), B.c), 1 / 3), pt = V.add(V.scale(V.add(cA, cB), 0.5), V.scale(A.n, 0.004)); if (inside(T, pt, A.n)) continue; }
      const pk = [A.pn, B.pn].sort().join(' × '); hits.set(pk, (hits.get(pk) || 0) + 1); if (process.env.ZV && (hits.get(pk) <= 3)) { const c = V.scale(V.add(V.add(A.a, A.b), A.c), 1 / 3); if (process.env.ZV === '2') console.log('      A', [A.a, A.b, A.c].map(q => q.map(v => v.toFixed(3)).join(' ')).join(' | '), '\n      B', [B.a, B.b, B.c].map(q => q.map(v => v.toFixed(3)).join(' ')).join(' | ')); console.log('   ', id, pk, 'at', c.map(v => v.toFixed(2)).join(','), 'n', A.n.map(v => v.toFixed(2)).join(','), same ? 'same' : 'back'); }
    }
  }
  if (hits.size) { total++; console.log(id + ': ' + [...hits].map(([k, v]) => k + ' (' + v + ')').join(' ، ')); }
}
console.log(total ? `أصول فيها طبقات متنافسة: ${total}` : 'لا طبقات متنافسة');
