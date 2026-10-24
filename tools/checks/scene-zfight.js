// يُحمَّل في صفحة المعرض: window.__zfightScene(اسم_المشهد) يكشف الطبقات المتنافسة بين أصلين مختلفين في المشهد
// (مثل زولية فوق زولية بنفس الارتفاع، أو أرضية أصل فوق أرضية أصل آخر). يقارن المثلثات المتقاطعة الصناديق فقط.
window.__zfightScene = function (sceneId) {
  const T = window.THREE, api = window.__api; api.loadScene(sceneId);
  const ENT = api.ENTRIES(), items = [];
  for (const e of ENT) e.inst.forEach((i, k) => {
    const g = i.group; if (!g) return; g.updateMatrixWorld(true);
    const tris = [], box = new T.Box3();
    g.traverse(o => {
      if (!o.isMesh || o.isSkinnedMesh) return;
      const m = o.material; if (m.transparent || /outline/i.test(m.type)) return;
      const pos = o.geometry.attributes.position, idx = o.geometry.index, ds = m.side === T.DoubleSide, n = idx ? idx.count : pos.count;
      const v = [new T.Vector3(), new T.Vector3(), new T.Vector3()];
      for (let t = 0; t < n; t += 3) {
        for (let j = 0; j < 3; j++) { v[j].fromBufferAttribute(pos, idx ? idx.getX(t + j) : t + j).applyMatrix4(o.matrixWorld); }
        const nn = new T.Vector3().subVectors(v[1], v[0]).cross(new T.Vector3().subVectors(v[2], v[0])), ar = nn.length() / 2; if (ar < 4e-4) continue;
        nn.normalize(); if (nn.y < -0.5) continue; // الأوجه السفلية لا تُرى عادة
        const tri = { a: v[0].clone(), b: v[1].clone(), c: v[2].clone(), n: nn, d: nn.dot(v[0]), ds };
        tris.push(tri); box.expandByPoint(v[0]); box.expandByPoint(v[1]); box.expandByPoint(v[2]);
      }
    });
    items.push({ id: e.id.replace(/^lp_/, ''), k, tris, box });
  });
  const ov2 = (A, B, n) => {
    const ax = Math.abs(n.x) > Math.abs(n.y) ? (Math.abs(n.x) > Math.abs(n.z) ? 'x' : 'z') : (Math.abs(n.y) > Math.abs(n.z) ? 'y' : 'z'), [u, w] = ax === 'x' ? ['y', 'z'] : ax === 'y' ? ['x', 'z'] : ['x', 'y'];
    const pa = [A.a, A.b, A.c].map(p => [p[u], p[w]]), pb = [B.a, B.b, B.c].map(p => [p[u], p[w]]);
    for (const poly of [pa, pb]) for (let i = 0; i < 3; i++) { const e = [poly[(i + 1) % 3][0] - poly[i][0], poly[(i + 1) % 3][1] - poly[i][1]], nn = [-e[1], e[0]], L = Math.hypot(nn[0], nn[1]) || 1, pr = q => q.map(p => (p[0] * nn[0] + p[1] * nn[1]) / L), A1 = pr(pa), B1 = pr(pb); if (Math.max(...A1) - 0.004 <= Math.min(...B1) || Math.max(...B1) - 0.004 <= Math.min(...A1)) return false; }
    return true;
  };
  const out = [];
  for (let i = 0; i < items.length; i++) for (let j = i + 1; j < items.length; j++) {
    const A = items[i], B = items[j]; if (!A.box.intersectsBox(B.box)) continue;
    const ib = A.box.clone().intersect(B.box).expandByScalar(0.01), ta = A.tris.filter(t => ib.containsPoint(t.a) || ib.containsPoint(t.b) || ib.containsPoint(t.c)), tb = B.tris.filter(t => ib.containsPoint(t.a) || ib.containsPoint(t.b) || ib.containsPoint(t.c));
    let hits = 0, where = null;
    for (const x of ta) for (const y of tb) {
      const dot = x.n.dot(y.n); if (dot < 0.9995) continue;
      if (Math.abs(x.n.dot(y.a) - x.d) > 0.0025 || Math.abs(y.n.dot(x.a) - y.d) > 0.0025) continue;
      if (!ov2(x, y, x.n)) continue;
      hits++; if (!where) where = x.a;
      if (hits > 200) break;
    }
    if (hits) out.push(`${A.id}#${A.k} × ${B.id}#${B.k}: ${hits} عند (${where.x.toFixed(1)}, ${where.y.toFixed(2)}, ${where.z.toFixed(1)})`);
  }
  return out;
};
