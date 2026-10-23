// Aboden Assets — lowpoly/lp-characters.js — شخصيات تشيبي لو-بولي (رأس كبير وجسم قصير)
(function (g) {
  'use strict';
  const AA = g.AA, LP = AA.lp, V = AA.v, lerp = AA.lerp, smooth = AA.smooth, clamp = AA.clamp, mixc = AA.mixc;

  // نسب التشيبي: الطول 1.25 م، الرأس ثلث الطول تقريباً
  const B = { hip: 0.36, knee: 0.2, ankle: 0.06, chest: 0.55, sh: 0.67, neck: 0.74, head: [0, 0.98, 0.01], hr: 0.23, shX: 0.16, hipX: 0.075 };
  function skeleton() {
    const k = new AA.Skeleton();
    k.add('root', null, [0, 0, 0], [0, 0.1, 0]);
    k.add('hips', 'root', [0, B.hip, 0], [0, B.hip + 0.08, 0]);
    k.add('spine', 'hips', [0, B.hip + 0.08, 0], [0, B.chest, 0]);
    k.add('chest', 'spine', [0, B.chest, 0], [0, B.neck, 0]);
    k.add('neck', 'chest', [0, B.neck, 0], [0, B.neck + 0.06, 0]);
    k.add('head', 'neck', [0, B.neck + 0.06, 0], [0, 1.22, 0.01]);
    for (const [sd, x] of [['L', 1], ['R', -1]]) {
      k.add('clav' + sd, 'chest', [0.03 * x, B.sh, 0], [B.shX * x, B.sh, 0]);
      k.add('upArm' + sd, 'clav' + sd, [B.shX * x, B.sh, 0], [0.2 * x, 0.52, 0]);
      k.add('loArm' + sd, 'upArm' + sd, [0.2 * x, 0.52, 0], [0.22 * x, 0.39, 0.02]);
      k.add('hand' + sd, 'loArm' + sd, [0.22 * x, 0.39, 0.02], [0.225 * x, 0.32, 0.03]);
      k.add('thigh' + sd, 'hips', [B.hipX * x, B.hip, 0], [B.hipX * x, B.knee, 0.01]);
      k.add('shin' + sd, 'thigh' + sd, [B.hipX * x, B.knee, 0.01], [B.hipX * x, B.ankle, 0]);
      k.add('foot' + sd, 'shin' + sd, [B.hipX * x, B.ankle, 0], [B.hipX * x, 0.01, 0.09]);
    }
    return k;
  }
  const hash = v => { const s = Math.sin(v[0] * 127.1 + v[1] * 311.7 + v[2] * 74.7) * 43758.5; return s - Math.floor(s); };

  function shaib(p, q) {
    const sk = skeleton(), rng = AA.rng(p.seed), id = n => sk.id(n);
    const Cl = new AA.Builder(), Sk = new AA.Builder(), Sh = new AA.Builder(), Dk = new AA.Builder(), Hr = new AA.Builder(), Wd = new AA.Builder();
    const skin = LP.c(p.skin === 'dark' ? '#a8714a' : p.skin === 'light' ? '#efc19a' : 'skin'), white = LP.c('white'), bisht = p.bisht === 'none' ? null : LP.c(p.bisht === 'black' ? '#2a2422' : '#7a5232');
    // الثوب: منشور ثُماني متدرّج، أسفله يتبع الساقين
    Cl.skinFn = pt => {
      const y = pt[1];
      if (y > B.hip + 0.04) return AA.autoSkin(sk, ['hips', 'spine', 'chest', 'neck', 'clavL', 'clavR'], 4)(pt);
      const wl = smooth(-0.6, 0.6, clamp(pt[0] / 0.1, -1, 1)), lo = smooth(B.hip + 0.04, B.knee - 0.04, y), leg = y > B.knee ? 'thigh' : 'shin';
      return [[id('hips'), 1 - lo * 0.85], [id(leg + 'L'), lo * 0.85 * wl], [id(leg + 'R'), lo * 0.85 * (1 - wl)]];
    };
    const prof = [[0.04, 0.2, 0.17], [0.2, 0.185, 0.155], [0.36, 0.175, 0.15], [0.52, 0.185, 0.15], [0.66, 0.19, 0.14], [0.72, 0.13, 0.11], [0.76, 0.07, 0.07]];
    AA.loft(Cl, { path: prof.map(r => [0, r[0], 0.0]), sides: 8, up: () => [0, 0, 1], capStart: true, radius: (t) => { const i = Math.round(t * (prof.length - 1)); return [prof[i][1], prof[i][2]]; }, color: (t) => mixc(white, [0.8, 0.78, 0.74], 0.2 * (1 - t)) });
    // البشت (اختياري): غلاف أوسع مفتوح من الأمام
    if (bisht) {
      const rows = [[0.7, 0.2, 0.155], [0.5, 0.205, 0.17], [0.3, 0.21, 0.18], [0.1, 0.225, 0.19]], n = 8, open = 0.45, ids = [];
      for (const [y, rx, rz] of rows) { const r = []; for (let k = 0; k <= n; k++) { const a = lerp(open, Math.PI * 2 - open, k / n); r.push(Cl.v([Math.sin(a) * rx, y, Math.cos(a) * rz], bisht, 0, 0, 0)); } ids.push(r); }
      for (let i = 0; i < rows.length - 1; i++) for (let k = 0; k < n; k++) { Cl.t(ids[i][k], ids[i + 1][k], ids[i + 1][k + 1]); Cl.t(ids[i][k], ids[i + 1][k + 1], ids[i][k + 1]); Cl.t(ids[i][k], ids[i + 1][k + 1], ids[i + 1][k]); Cl.t(ids[i][k], ids[i][k + 1], ids[i + 1][k + 1]); }
    }
    // الأكمام واليدان
    for (const [sd, x] of [['L', 1], ['R', -1]]) {
      Cl.skinFn = AA.autoSkin(sk, ['clav' + sd, 'upArm' + sd, 'loArm' + sd, 'hand' + sd, 'chest'], 6);
      AA.loft(Cl, { path: [[0.13 * x, 0.68, 0], [0.2 * x, 0.52, 0], [0.22 * x, 0.4, 0.02]], sides: 6, up: () => [0, 0, 1], capStart: true, capEnd: true, radius: t => lerp(0.07, 0.058, t), color: () => bisht || white });
      Sk.setSkin([[id('hand' + sd), 1]]);
      LP.ico(Sk, [0.225 * x, 0.35, 0.03], [0.045, 0.055, 0.045], 0, () => skin);
      // القدمان والنعال
      Sk.setSkin([[id('foot' + sd), 1]]); LP.ico(Sk, [B.hipX * x, 0.04, 0.05], [0.045, 0.035, 0.07], 0, () => skin);
      Dk.setSkin([[id('foot' + sd), 1]]); AA.box(Dk, [B.hipX * x, 0.008, 0.05], [0.09, 0.016, 0.17], LP.c('woodDark'), 1, {});
    }
    // الرأس الكبير والوجه
    Sk.setSkin([[id('head'), 1]]);
    LP.ico(Sk, B.head, [B.hr, B.hr * 0.96, B.hr * 0.95], 1, d => mixc(skin, LP.c('skinShade'), d[1] < -0.3 ? 0.4 : 0));
    LP.ico(Sk, [0, 0.95, 0.225], 0.035, 0, () => LP.c('skinShade'));
    Dk.setSkin([[id('head'), 1]]);
    for (const s of [1, -1]) {
      AA.box(Dk, [s * 0.075, 1.0, 0.2], [0.04, 0.065, 0.02], LP.c('black'), 1, {});
    }
    Hr.setSkin([[id('head'), 1]]);
    for (const s of [1, -1]) { AA.box(Hr, [s * 0.067, 1.015, 0.212], [0.012, 0.014, 0.01], white, 1, {}); AA.box(Hr, [s * 0.08, 1.065, 0.2], [0.075, 0.022, 0.03], white, 1, {}, s * 0.15); }
    // اللحية البيضاء الكبيرة والشارب
    LP.ico(Hr, [0, 0.86, 0.1], [0.19 * p.beard + 0.02, 0.14 * p.beard + 0.02, 0.13], 1, () => white, { keep: d => d[1] < 0.35 && d[2] > -0.15 });
    AA.box(Hr, [0, 0.92, 0.225], [0.14, 0.035, 0.04], white, 1, {});
    // الشماغ: قطعة قماش واحدة متصلة (شبكة صفوف × أعمدة): تغطي الرأس، تنفتح حول الوجه،
    // وتنسدل على الكتفين والظهر، وطرفاها الأماميان على الصدر. نقشة مربعات حمراء وبيضاء وحاشية بيضاء.
    {
      const c0 = [0, 1.0, -0.005], R = B.hr + 0.03, nC = q === 'low' ? 12 : 18, crown = q === 'low' ? 4 : 6, drape = q === 'low' ? 4 : 6, nR = crown + drape;
      const phiEnd = 1.72, yTop = c0[1] + R * Math.cos(phiEnd);
      const openAt = phi => 0.9 * smooth(0.62, 1.15, phi); // نصف زاوية فتحة الوجه
      const grid = [];
      for (let i = 0; i <= nR; i++) {
        const j = i - crown, row = [], inCrown = i <= crown, phi = inCrown ? lerp(0.1, phiEnd, i / crown) : phiEnd, sD = inCrown ? 0 : j === drape ? 1 : 0.93 * j / (drape - 1); // آخر صف حاشية رفيعة
        const open = inCrown ? openAt(phi) : 0.9 + 0.1 * sD;
        for (let k = 0; k <= nC; k++) {
          const a = lerp(open, Math.PI * 2 - open, k / nC), sa = Math.sin(a), ca = Math.cos(a);
          let pt;
          if (inCrown) pt = [c0[0] + R * Math.sin(phi) * sa, c0[1] + R * Math.cos(phi), c0[2] + R * Math.sin(phi) * ca];
          else {
            const back = smooth(0.2, -0.9, ca), front = smooth(0.3, 0.7, ca), tip = Math.max(0, 1 - Math.abs(a - Math.PI) / 1.25); // ذيل مثلث في الظهر
            const r0 = R * Math.sin(phiEnd), r1 = 0.275 - 0.025 * back, rr = lerp(r0, r1, Math.pow(sD, 0.6));
            const y = lerp(yTop, 0.63 - 0.17 * tip - 0.12 * front, sD);
            pt = [sa * rr * (1 - 0.22 * front * sD), y, ca * rr * (1 + 0.08 * back * sD) + 0.05 * front * sD + c0[2]];
          }
          row.push(pt);
        }
        grid.push(row);
      }
      Sh.skinFn = pt => { const w = smooth(0.84, 0.64, pt[1]); return [[id('head'), 1 - w * 0.85], [id('chest'), w * 0.85]]; };
      const R1 = LP.c('red'), W1 = LP.c('white');
      for (let i = 0; i < nR; i++) for (let k = 0; k < nC; k++) {
        const hem = i === nR - 1 || k === 0 || k === nC - 1, col = hem ? W1 : ((i + k) % 3 === 0 ? W1 : R1);
        const p00 = grid[i][k], p01 = grid[i][k + 1], p10 = grid[i + 1][k], p11 = grid[i + 1][k + 1], sw = 0.012 * smooth(0.95, 0.6, p10[1]);
        const v = pt => Sh.v(pt, col, pt[1] < 0.9 ? sw : 0, 0.3 * k, 0);
        const A = v(p00), Bv = v(p01), C2 = v(p11), D2 = v(p10);
        Sh.t(A, C2, Bv); Sh.t(A, D2, C2);
      }
    }
    // العقال: حلقتان سوداوان
    Dk.setSkin([[id('head'), 1]]);
    for (const dy of [0, 0.034]) { const ring = []; for (let k = 0; k <= 12; k++) { const a = k / 12 * Math.PI * 2, y = 1.085 + dy + 0.025 * Math.cos(a), rr = Math.sqrt(Math.max(0, (B.hr + 0.026) ** 2 - (y - 1.0) ** 2)) + 0.012; ring.push([Math.sin(a) * rr, y, Math.cos(a) * rr - 0.005]); } LP.chain(Dk, ring, ring.map(() => 0.015), 4, () => LP.c('black')); }
    // العصا في اليد اليمنى
    Wd.setSkin([[id('handR'), 1]]);
    const g0 = [-0.225, 0.35, 0.06];
    LP.chain(Wd, [[g0[0], 0.01, g0[2] + 0.02], [g0[0], g0[1] + 0.05, g0[2]], [g0[0], g0[1] + 0.1, g0[2] + 0.04], [g0[0], g0[1] + 0.08, g0[2] + 0.09]], [0.016, 0.016, 0.016, 0.014], 5, () => LP.c('wood'));

    // ---------- الحركة ----------
    const clips = {};
    clips.idle = AA.clip(sk, 4, 30, true, t => { const w = t / 4 * Math.PI * 2, b = Math.sin(w * 1.5); return { chest: [1.5 * b, 0, 0], head: [3 * Math.sin(w * 0.5), 14 * Math.sin(w), 3 * Math.sin(w * 2)], upArmL: [4, 0, 8 + 2 * b], upArmR: [-14, 0, -6], loArmR: [-24, 0, 0], loArmL: [-10, 0, 0], move: [0, 0.004 * b, 0] }; });
    clips.walk = AA.gaitClip(sk, { duration: 0.8, speed: 0.55, extra: t => {
      const ph = t / 0.8 * Math.PI * 2, s = Math.sin(ph);
      return { hips: [0, 8 * s, 4 * Math.sin(ph)], chest: [0, -6 * s, 0], head: [-3, 0, -3 * Math.sin(ph)], upArmL: [26 * s, 0, 8], loArmL: [-16, 0, 0], upArmR: [-10 - 6 * s, 0, -6], loArmR: [-22, 0, 0], move: [0, 0.012 * Math.cos(ph * 2), 0] };
    }, legs: [['L', 0], ['R', 0.5]].map(([sd, ph]) => ({ chain: ['thigh' + sd, 'shin' + sd], foot: 'foot' + sd, phase: ph, duty: 0.6, lift: 0.085, limits: [[-70, 40], [0, 120]], init: [-5, 10], footSwing: 0 })) });
    clips.wave = AA.clip(sk, 1.4, 30, true, t => { const w = t / 1.4 * Math.PI * 2; return { upArmL: [-10, 0, 140], loArmL: [-20, 0, 30 + 25 * Math.sin(w * 2)], head: [0, 10, -6], chest: [0, 6, -3], upArmR: [-14, 0, -6], loArmR: [-24, 0, 0] }; });
    clips.sit_floor = AA.clip(sk, 4, 30, true, t => { const w = t / 4 * Math.PI * 2, b = Math.sin(w * 1.5); return { thighL: [-90, -10, 55], thighR: [-90, 10, -55], shinL: [170, 0, -30], shinR: [170, 0, 30], footL: [-30, 0, 0], footR: [-30, 0, 0], chest: [2 * b, 0, 0], head: [0, 12 * Math.sin(w), 0], upArmL: [-20, 0, 20], loArmL: [-45, 0, 0], upArmR: [-20, 0, -20], loArmR: [-45, 0, 0], handR: [60, 0, 0], move: [0, -B.hip + 0.1, -0.03] }; });

    return LP.finalize('lp_shaib', {
      cloth: { builder: Cl, material: LP.mat('cloth') },
      skin:  { builder: Sk, material: LP.mat('skin') },
      hair:  { builder: Hr, material: LP.mat('hair') },
      shem:  { builder: Sh, material: LP.mat('cloth', { doubleSided: true }) },
      dark:  { builder: Dk, material: LP.mat('dark') },
      wood:  { builder: Wd, material: LP.mat('wood') }
    }, { stiffness: 0, height: 1.25, radius: 0.3, collider: { type: 'capsule', radius: 0.22, height: 1.25, axis: 'y' }, skeleton: sk.toJSON(), clips, walkSpeed: 0.55 });
  }

  AA.assets.lp_shaib = { id: 'lp_shaib', name: 'الشايب', nameEn: 'Chibi elder', category: 'lowpoly',
    schema: [
      { key: 'bisht', label: 'البشت', type: 'enum', options: [['none', 'بدون'], ['brown', 'بني'], ['black', 'أسود']], def: 'none' },
      { key: 'beard', label: 'حجم اللحية', min: 0.5, max: 1.3, step: 0.05, def: 1, pct: true },
      { key: 'skin', label: 'البشرة', type: 'enum', options: [['mid', 'حنطي'], ['dark', 'أسمر'], ['light', 'فاتح']], def: 'mid' }
    ], presets: { 'شايب ببشت': { bisht: 'brown' } },
    clips: [['idle', 'وقوف'], ['walk', 'مشي'], ['wave', 'يلوّح'], ['sit_floor', 'متربّع']], generate: shaib };
})(typeof window !== 'undefined' ? window : globalThis);
