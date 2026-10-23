// يُحمَّل في صفحة المعرض: window.__overlap(اسم_المشهد) يرجع قائمة بالتداخلات بين الأصول وبين مسارات المشاة والأصول الثابتة
window.__overlap = function(sceneId){
  const T = window.THREE, api = window.__api; api.loadScene(sceneId);
  const ENT = api.ENTRIES(), items = [];
  const SMALL = new Set(['shaib','woman','girl','boy','child','worker','sheep','fire_pit','coffee_set','mabkhara','pottery','dallah','zir','lantern','sack','crate','basket','firewood']);
  const CONTAINER = new Set(['carpet','majlis_seat','pen','bait_shaar','khaima','mosque','kiosk','shop']);
  const ARCH = new Set(['najdi_house','wall','sur','tower','gate','mosque','wall_corner','wall_door','shop','kiosk','fence','pen','dakka','water_channel','water_basin','well']);
  const PLANT = new Set(['palm','fasila','sidr','talh','athl','arfaj','thumam']);
  for (const e of ENT) e.inst.forEach((i, k) => {
    const g = i.group; if (!g) return;
    // صندوق محلي (بدون دوران) — نستبعد الحبال والأوتاد
    const pos = g.position.clone(), rot = g.rotation.y, sc = g.scale.x; g.position.set(0,0,0); g.rotation.y = 0; g.scale.setScalar(1); g.updateMatrixWorld(true);
    const box = new T.Box3(); g.traverse(o => { if (!o.isMesh) return; if (/rope/.test(o.name) || ((e.id==='bait_shaar'||e.id==='khaima') && o.name==='woodDark')) return; o.geometry.computeBoundingBox(); const b = o.geometry.boundingBox.clone().applyMatrix4(o.matrixWorld); box.union(b); });
    g.position.copy(pos); g.rotation.y = rot; g.scale.setScalar(sc); g.updateMatrixWorld(true);
    let mn = box.min.clone().multiplyScalar(sc), mx = box.max.clone().multiplyScalar(sc);
    const col = (i.built || e.built).meta.collider;
    if (col && col.type === 'box' && col.size && /najdi_house|shop|kiosk|wall|sur|cart|jeep|pickup|lorry|wayt|crate/.test(e.id)) { const [sx, sy, sz] = col.size; mn.set(-sx / 2 * sc, 0, -sz / 2 * sc); mx.set(sx / 2 * sc, sy * sc, sz / 2 * sc); if (/cart/.test(e.id)) { mn.x = box.min.x * sc; mx.x = box.max.x * sc; mn.z = box.min.z * sc; mx.z = box.max.z * sc; } }
    if (PLANT.has(e.id.replace(/^lp_/, ''))) { const r = e.id==='arfaj'||e.id==='thumam' ? 0.5 : 0.35; mn.set(-r, 0, -r); mx.set(r, 2, r); } // جذع فقط
    items.push({ id: e.id, k, x: pos.x, z: pos.z, rot, mn, mx, walk: i.walk || i.loop ? (i.walk || i.loop) : null, loop: !!i.loop, y0: pos.y });
  });
  const corners = it => [[it.mn.x,it.mn.z],[it.mx.x,it.mn.z],[it.mx.x,it.mx.z],[it.mn.x,it.mx.z]].map(([x,z]) => [it.x + x*Math.cos(it.rot) + z*Math.sin(it.rot), it.z - x*Math.sin(it.rot) + z*Math.cos(it.rot)]);
  const axes = it => [[Math.cos(it.rot), -Math.sin(it.rot)], [Math.sin(it.rot), Math.cos(it.rot)]];
  function depth(A, B){ // SAT: أقل تداخل على المحاور
    const ca = corners(A), cb = corners(B); let d = Infinity;
    for (const ax of axes(A).concat(axes(B))) { const pa = ca.map(c => c[0]*ax[0]+c[1]*ax[1]), pb = cb.map(c => c[0]*ax[0]+c[1]*ax[1]); const o = Math.min(Math.max(...pa), Math.max(...pb)) - Math.max(Math.min(...pa), Math.min(...pb)); if (o <= 0) return 0; d = Math.min(d, o); }
    const yo = Math.min(A.y0 + A.mx.y, B.y0 + B.mx.y) - Math.max(A.y0 + A.mn.y, B.y0 + B.mn.y); if (yo <= 0.02) return 0;
    return d;
  }
  const out = [];
  const st = items.filter(i => !i.walk);
  for (let a = 0; a < st.length; a++) for (let b = a + 1; b < st.length; b++) {
    const A = st[a], B = st[b];
    if (ARCH.has(A.id) && ARCH.has(B.id)) continue;
    if ((CONTAINER.has(A.id) && SMALL.has(B.id)) || (CONTAINER.has(B.id) && SMALL.has(A.id))) continue;
    if ((A.id==='lantern' && ARCH.has(B.id)) || (B.id==='lantern' && ARCH.has(A.id))) continue;
    if ((A.id==='carpet') || (B.id==='carpet')) continue;
    if ((A.id==='dakka' && SMALL.has(B.id)) || (B.id==='dakka' && SMALL.has(A.id))) continue;
    const d = depth(A, B); if (d > 0.08) out.push(`${A.id}#${A.k}(${A.x.toFixed(1)},${A.z.toFixed(1)}) × ${B.id}#${B.k}(${B.x.toFixed(1)},${B.z.toFixed(1)}) عمق ${d.toFixed(2)}`);
  }
  // المسارات: نعيّن المتحرك على طول مساره ونفحص التصادم مع الثابت
  for (const W of items.filter(i => i.walk)) {
    const hits = {};
    for (let s = 0; s <= 200; s++) {
      let x, z, r;
      if (W.loop) { const [cx, cz, rx, rz] = W.walk, t = s / 200 * Math.PI * 2; x = cx + rx * Math.cos(t); z = cz + rz * Math.sin(t); r = Math.atan2(-rx * Math.sin(t), rz * Math.cos(t)); }
      else { const [x0, z0, x1, z1] = W.walk, t = s / 200; x = x0 + (x1 - x0) * t; z = z0 + (z1 - z0) * t; r = Math.atan2(x1 - x0, z1 - z0); }
      const P = Object.assign({}, W, { x, z, rot: r });
      for (const B of st) { if (B.id === 'carpet' || B.id === 'water_channel' || B.id === 'gate') continue; const d = depth(P, B); if (d > 0.1) { const key = B.id + '#' + B.k; hits[key] = Math.max(hits[key] || 0, d); } }
    }
    const h = Object.entries(hits); if (h.length) out.push(`مسار ${W.id}#${W.k}: ` + h.map(([k, d]) => k + ' ' + d.toFixed(2)).join('، '));
  }
  return out;
};
