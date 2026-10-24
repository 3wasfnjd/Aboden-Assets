// Aboden Assets — lowpoly/lp-animals.js — جمل لو-بولي بنفس هيكل جمل الحزمة الواقعية ومشيه
(function (g) {
  'use strict';
  const AA = g.AA, LP = AA.lp, V = AA.v, lerp = AA.lerp, mixc = AA.mixc;
  const COATS = { shael: ['camel', 'camelDark', 'camelLight'], wadh: ['#efe4d0', '#ddd0b8', '#f8f0e2'], majaheem: ['#3a2e27', '#2c231e', '#4a3c33'], humr: ['#a96a42', '#8f5634', '#c08258'], sufr: ['#d6b47f', '#c7a26b', '#e6cc9e'] };
  const J = {
    front: { sh: [0.19, 1.42, 0.56], el: [0.2, 1.12, 0.6], kn: [0.2, 0.62, 0.62], fe: [0.2, 0.2, 0.62], ft: [0.2, 0.05, 0.71] },
    hind:  { hp: [0.21, 1.55, -0.72], st: [0.22, 1.08, -0.52], hk: [0.22, 0.64, -0.84], fe: [0.22, 0.2, -0.82], ft: [0.22, 0.05, -0.74] }
  };
  function skeleton() {
    const k = new AA.Skeleton(), X = (a, x) => [a[0] * x, a[1], a[2]];
    k.add('root', null, [0, 1.5, 0], [0, 1.52, -0.4]);
    k.add('rear', 'root', [0, 1.52, -0.45], [0, 1.42, -0.95]);
    k.add('chest', 'root', [0, 1.5, 0.35], [0, 1.46, 0.8]);
    k.add('neck1', 'chest', [0, 1.55, 0.78], [0, 1.38, 1.15]);
    k.add('neck2', 'neck1', [0, 1.38, 1.15], [0, 1.66, 1.48]);
    k.add('neck3', 'neck2', [0, 1.66, 1.48], [0, 2.12, 1.6]);
    k.add('head', 'neck3', [0, 2.12, 1.6], [0, 2.0, 2.12]);
    k.add('tail', 'rear', [0, 1.46, -1.0], [0, 0.78, -1.1]);
    for (const [sd, x] of [['L', 1], ['R', -1]]) {
      const f = J.front, h = J.hind;
      k.add('upF' + sd, 'chest', X(f.sh, x), X(f.el, x)); k.add('lowF' + sd, 'upF' + sd, X(f.el, x), X(f.kn, x));
      k.add('canF' + sd, 'lowF' + sd, X(f.kn, x), X(f.fe, x)); k.add('footF' + sd, 'canF' + sd, X(f.fe, x), X(f.ft, x));
      k.add('thighB' + sd, 'rear', X(h.hp, x), X(h.st, x)); k.add('shankB' + sd, 'thighB' + sd, X(h.st, x), X(h.hk, x));
      k.add('canB' + sd, 'shankB' + sd, X(h.hk, x), X(h.fe, x)); k.add('footB' + sd, 'canB' + sd, X(h.fe, x), X(h.ft, x));
    }
    return k;
  }

  function camel(p, q) {
    const sk = skeleton(), id = n => sk.id(n), rng = AA.rng(p.seed), C = (COATS[p.coat] || COATS.shael).map(LP.c);
    const Bd = new AA.Builder(), Dk = new AA.Builder(), Sd = new AA.Builder(), jit = c => AA.vary(c, rng, 0.07), HS = (p.hump == null ? 0.34 : p.hump) / 0.34;
    // الجسم والسنام في قطعة واحدة: مقاطع بعشرة أضلاع، نصفها العلوي يرتفع ويضيق عند السنام
    // [z، نصف العرض، الارتفاع للأعلى، العمق للأسفل، مركز y]
    const rows = [[-1.02, 0.1, 0.1, 0.12, 1.47], [-0.86, 0.26, 0.23, 0.3, 1.46], [-0.62, 0.33, 0.3, 0.36, 1.45], [-0.42, 0.35, 0.42, 0.38, 1.46], [-0.22, 0.36, 0.6, 0.4, 1.47],
      [0.0, 0.36, 0.68, 0.41, 1.47], [0.18, 0.35, 0.62, 0.42, 1.48], [0.36, 0.34, 0.45, 0.44, 1.48], [0.56, 0.32, 0.32, 0.43, 1.49], [0.76, 0.28, 0.27, 0.4, 1.5], [0.95, 0.19, 0.2, 0.3, 1.53]];
    Bd.skinFn = AA.autoSkin(sk, ['root', 'rear', 'chest'], 3);
    AA.loft(Bd, { path: rows.map(r => [0, r[4], r[0]]), sides: q === 'low' ? 8 : 10, up: () => [0, 1, 0], capStart: true, capEnd: true,
      radius: (t, a) => { const r = rows[Math.round(t * (rows.length - 1))], c = Math.cos(a), top = r[2] > 0.32 ? 0.32 + (r[2] - 0.32) * HS : r[2], hump = AA.clamp((top - 0.32) / 0.36, 0, 1);
        return [r[1] * (1 - 0.42 * hump * Math.max(0, c) ** 2), c > 0 ? top : r[3]]; },
      color: (t, a) => { const c = Math.cos(a), r = rows[Math.round(t * (rows.length - 1))]; return jit(c < -0.5 ? C[2] : c > 0.75 && r[2] > 0.45 ? C[1] : C[0]); } });
    // الرقبة: ثلاث قطع سميكة متناقصة مع مفاصل كروية تخفي الفواصل
    const nb = [['neck1', [0, 1.58, 0.74], [0, 1.38, 1.15], 0.2, 0.16], ['neck2', [0, 1.38, 1.15], [0, 1.66, 1.48], 0.16, 0.125], ['neck3', [0, 1.66, 1.48], [0, 2.12, 1.6], 0.12, 0.1]];
    for (const [b, a, e, r0, r1] of nb) { Bd.setSkin([[id(b), 1]]); LP.prism(Bd, a, e, r0, r1, 6, jit(C[0]), { noCaps: true, rot: 0.26 }); }
    Bd.setSkin([[id('neck2'), 1]]); LP.ico(Bd, [0, 1.38, 1.15], 0.158, 0, () => jit(C[0]));
    Bd.setSkin([[id('neck3'), 1]]); LP.ico(Bd, [0, 1.66, 1.48], 0.125, 0, () => jit(C[0]));
    // الرأس: جمجمة + خطم طويل منحدر + شفة متدلية + أذنان صغيرتان
    Bd.setSkin([[id('head'), 1]]);
    LP.ico(Bd, [0, 2.15, 1.67], [0.11, 0.115, 0.14], 0, d => jit(d[1] > 0.5 ? C[1] : C[0]));
    LP.prism(Bd, [0, 2.13, 1.74], [0, 2.01, 2.12], 0.1, 0.075, 6, jit(C[0]), { sx: 0.82, rot: 0.26 });
    LP.prism(Bd, [0, 2.02, 2.1], [0, 1.99, 2.17], 0.07, 0.05, 6, C[2], { sx: 0.95, rot: 0.26 });
    LP.prism(Bd, [0, 1.985, 1.9], [0, 1.965, 2.11], 0.05, 0.045, 5, C[2], { sx: 1.2 });
    for (const s of [1, -1]) LP.prism(Bd, [s * 0.075, 2.22, 1.62], [s * 0.11, 2.31, 1.55], 0.035, 0.0, 4, C[1]);
    Dk.setSkin([[id('head'), 1]]);
    for (const s of [1, -1]) {
      AA.box(Dk, [s * 0.09, 2.165, 1.76], [0.014, 0.034, 0.04], LP.c('black'), 1, {});
      AA.box(Dk, [s * 0.035, 2.0, 2.165], [0.025, 0.018, 0.02], LP.c('black'), 1, {});
    }
    // الأرجل: أفخاذ عريضة تدخل الجسم، مفاصل كروية، ثفنات الركبة أغمق، وخف عريض مفلطح
    const leg = [['upF', 'sh', 'el', 0.12, 0.092], ['lowF', 'el', 'kn', 0.09, 0.07], ['canF', 'kn', 'fe', 0.064, 0.054], ['thighB', 'hp', 'st', 0.16, 0.11], ['shankB', 'st', 'hk', 0.1, 0.07], ['canB', 'hk', 'fe', 0.064, 0.054]];
    const balls = [['lowF', 'el', 0.098, 0], ['canF', 'kn', 0.085, 1], ['footF', 'fe', 0.06, 0], ['shankB', 'st', 0.112, 0], ['canB', 'hk', 0.08, 1], ['footB', 'fe', 0.06, 0]];
    for (const [sd, x] of [['L', 1], ['R', -1]]) {
      const X = a => [a[0] * x, a[1], a[2]];
      for (const [b, ja, jb, r0, r1] of leg) { const JJ = b.endsWith('F') ? J.front : J.hind; Bd.setSkin([[id(b + sd), 1]]); LP.prism(Bd, X(JJ[ja]), X(JJ[jb]), r0, r1, 6, jit(C[0]), { noCaps: true }); }
      for (const [b, j, r, dark] of balls) { const JJ = b.endsWith('F') ? J.front : J.hind; Bd.setSkin([[id(b + sd), 1]]); LP.ico(Bd, X(JJ[j]), r, 0, () => dark ? jit(C[1]) : jit(C[0])); }
      for (const [b, JJ] of [['footF', J.front], ['footB', J.hind]]) {
        Bd.setSkin([[id(b + sd), 1]]); LP.prism(Bd, X(JJ.fe), [JJ.ft[0] * x, 0.07, JJ.ft[2]], 0.052, 0.08, 6, C[1], { noCaps: true });
        Dk.setSkin([[id(b + sd), 1]]); LP.ico(Dk, [JJ.ft[0] * x, 0.05, JJ.ft[2] + 0.01], [0.105, 0.05, 0.13], 0, d => mixc(C[1], [0, 0, 0], d[1] > 0 ? 0.15 : 0.4));
      }
    }
    // الذيل: ذيل رفيع وخصلة شعر في طرفه
    Bd.setSkin([[id('tail'), 1]]); LP.prism(Bd, [0, 1.48, -1.0], [0, 0.95, -1.1], 0.04, 0.022, 4, C[1]);
    Dk.setSkin([[id('tail'), 1]]); LP.ico(Dk, [0, 0.9, -1.1], [0.05, 0.11, 0.04], 0, () => mixc(C[1], [0, 0, 0], 0.4));
    // الشداد (اختياري): بطانية حمراء فوق السنام بأطراف صفراء، وجنبتان متدليتان، وعودان
    if (p.saddle) {
      Sd.skinFn = AA.autoSkin(sk, ['root', 'rear', 'chest'], 3);
      LP.ico(Sd, [0, 1.98 + 0.36 * (HS - 1), -0.06], [0.42, 0.31, 0.56], 1, d => Math.abs(d[2]) > 0.72 ? LP.c('yellow') : d[1] > 0.85 ? LP.c('teal') : LP.c('red'), { keep: d => d[1] > -0.05 });
      for (const s of [1, -1]) {
        AA.box(Sd, [s * 0.4, 1.8, -0.06], [0.03, 0.34, 0.56], LP.c('red'), 1, {});
        AA.box(Sd, [s * 0.405, 1.61, -0.06], [0.035, 0.06, 0.58], LP.c('yellow'), 1, {});
      }
      for (const z of [-0.42, 0.3]) { AA.box(Sd, [0, 2.32 + 0.36 * (HS - 1), z], [0.06, 0.34, 0.06], LP.c('wood'), 1, {}); AA.box(Sd, [0, 2.5 + 0.36 * (HS - 1), z], [0.1, 0.05, 0.1], LP.c('woodDark'), 1, {}); }
    }
    // الحركة: نفس مشية الجمل (رهوان بقدم مثبّتة)
    const clips = {};
    clips.idle = AA.clip(sk, 5, 30, true, t => { const w = t / 5 * Math.PI * 2; return { neck1: [2 * Math.sin(w), 0, 0], neck3: [0, 8 * Math.sin(w), 0], head: [4 * Math.sin(w * 2), 6 * Math.sin(w), 0], tail: [0, 0, 12 * Math.sin(w * 2)], move: [0, 0.006 * Math.sin(w * 2), 0] }; });
    const F = 'limits: 0', Lf = [[-40, 40], [-40, 20], [0, 105]], Lh = [[-40, 35], [-55, 25], [-95, 10]];
    clips.walk = AA.gaitClip(sk, { duration: 1.3, speed: 1.25, extra: t => { const ph = t / 1.3 * Math.PI * 2; return { move: [0, 0.02 * Math.cos(ph * 2), 0], rear: [0, 0, 4 * Math.sin(ph)], chest: [0, 0, 4 * Math.sin(ph)], neck1: [5 * Math.sin(ph * 2), 0, 0], neck3: [-3 * Math.sin(ph * 2), 0, 0], tail: [0, 0, 12 * Math.sin(ph)] }; },
      legs: [['L', 0, 0.94], ['R', 0.5, 0.44]].flatMap(([sd, hp, fp]) => [
        { chain: ['upF' + sd, 'lowF' + sd, 'canF' + sd], foot: 'footF' + sd, phase: fp, duty: 0.62, lift: 0.16, footSwing: 30, limits: Lf, init: [0, 0, 0], pref: [0, 0, 0], swingPref: [-8, -18, 75] },
        { chain: ['thighB' + sd, 'shankB' + sd, 'canB' + sd], foot: 'footB' + sd, phase: hp, duty: 0.62, lift: 0.14, footSwing: 25, limits: Lh, init: [0, 0, 0], pref: [0, 0, 0], swingPref: [12, -10, -55] }]) });
    clips.graze = AA.clip(sk, 3.4, 30, true, t => { const w = t / 3.4 * Math.PI * 2; return { neck1: [58, 0, 0], neck2: [30, 0, 0], neck3: [18 + 3 * Math.sin(w * 3), 0, 0], head: [-12 + 4 * Math.sin(w * 6), 5 * Math.sin(w), 0], upFL: [-4, 0, 0], upFR: [-4, 0, 0], tail: [0, 0, 10 * Math.sin(w * 2)] }; });
    return LP.scaleOut(LP.finalize('lp_camel', {
      body:   { builder: Bd, material: LP.mat('fur') },
      dark:   { builder: Dk, material: LP.mat('dark') },
      saddle: { builder: Sd, material: LP.mat('cloth') }
    }, { stiffness: 0, height: 2.3, radius: 1.3, collider: { type: 'capsule', radius: 0.45, height: 2.2, axis: 'z' }, skeleton: sk.toJSON(), clips, walkSpeed: 1.25, seat: null }), p.size || 1);
  }


  // ---------- الخيل والحمار: نفس هيكل الحزمة الواقعية ومشيها، بأجسام لو-بولي ----------
  const ECOATS = { bay: ['#8a4e2c', '#74401f', '#9c613b', '#221a17', '#2a201c', '#4a2e1e'], chestnut: ['#a8663a', '#92542c', '#b97a4a', '#c88a4e', '#8a5028', '#6a3e24'],
    grey: ['#dcd8d2', '#c9c5bf', '#ebe7e1', '#efedea', '#b8b4ae', '#7a7672'], black: ['#2a2523', '#1f1b1a', '#383230', '#151212', '#1a1615', '#2c2522'], donkey: ['#948e88', '#837d77', '#ddd7cd', '#3e3834', '#7c766f', '#e6e1d8'] };
  function eSkeleton(S) {
    const k = new AA.Skeleton(), P = a => a.map(v => v * S), X = (a, x) => P([a[0] * x, a[1], a[2]]);
    k.add('root', null, P([0, 1.42, 0]), P([0, 1.44, -0.35])); k.add('rear', 'root', P([0, 1.44, -0.35]), P([0, 1.4, -0.78]));
    k.add('chest', 'root', P([0, 1.42, 0.3]), P([0, 1.42, 0.62])); k.add('neck1', 'chest', P([0, 1.5, 0.58]), P([0, 1.72, 0.82]));
    k.add('neck2', 'neck1', P([0, 1.72, 0.82]), P([0, 1.95, 1.0])); k.add('head', 'neck2', P([0, 1.95, 1.0]), P([0, 1.55, 1.42]));
    k.add('tail', 'rear', P([0, 1.42, -0.8]), P([0, 0.8, -0.92]));
    for (const [sd, x] of [['L', 1], ['R', -1]]) {
      k.add('upF' + sd, 'chest', X([0.16, 1.32, 0.52], x), X([0.17, 1.02, 0.48], x)); k.add('lowF' + sd, 'upF' + sd, X([0.17, 1.02, 0.48], x), X([0.17, 0.52, 0.5], x));
      k.add('canF' + sd, 'lowF' + sd, X([0.17, 0.52, 0.5], x), X([0.17, 0.14, 0.52], x)); k.add('hoofF' + sd, 'canF' + sd, X([0.17, 0.14, 0.52], x), X([0.17, 0.02, 0.58], x));
      k.add('thighB' + sd, 'rear', X([0.17, 1.42, -0.6], x), X([0.18, 1.0, -0.42], x)); k.add('shankB' + sd, 'thighB' + sd, X([0.18, 1.0, -0.42], x), X([0.17, 0.58, -0.72], x));
      k.add('canB' + sd, 'shankB' + sd, X([0.17, 0.58, -0.72], x), X([0.17, 0.14, -0.68], x)); k.add('hoofB' + sd, 'canB' + sd, X([0.17, 0.14, -0.68], x), X([0.17, 0.02, -0.63], x));
    }
    return k;
  }
  function equine(p, q, donkey, outId) {
    const S = p.size, sk = eSkeleton(S), id = n => sk.id(n), rng = AA.rng(p.seed), C = (ECOATS[donkey ? 'donkey' : p.coat] || ECOATS.bay).map(LP.c), jit = c => AA.vary(c, rng, 0.06);
    const Bd = new AA.Builder(), Mn = new AA.Builder(), Dk = new AA.Builder(), Tk = new AA.Builder(), P = a => a.map(v => v * S), HK = donkey ? 1.2 : 1;
    // الجسم: [z، نصف العرض، الأعلى، الأسفل، y]
    const rows = [[-0.86, 0.12, 0.12, 0.15, 1.38], [-0.72, 0.27, 0.17, 0.3, 1.42], [-0.45, 0.31, 0.19, 0.4, 1.44], [-0.1, 0.3, 0.16, 0.45, 1.41], [0.25, 0.3, 0.18, 0.45, 1.41], [0.5, 0.27, 0.22, 0.42, 1.43], [0.68, 0.16, 0.2, 0.26, 1.45]];
    const wd = donkey ? 1.1 : 1;
    Bd.skinFn = AA.autoSkin(sk, ['root', 'rear', 'chest'], 3);
    AA.loft(Bd, { path: rows.map(r => P([0, r[4], r[0]])), sides: q === 'low' ? 8 : 10, up: () => [0, 1, 0], capStart: true, capEnd: true,
      radius: (t, a) => { const r = rows[Math.round(t * (rows.length - 1))]; return [r[1] * S * wd, (Math.cos(a) > 0 ? r[2] : r[3] * wd) * S]; },
      color: (t, a) => jit(Math.cos(a) < -0.5 && donkey ? C[2] : Math.cos(a) > 0.7 ? C[1] : C[0]) });
    // الرقبة المقوّسة والرأس
    const nb = [['neck1', [0, 1.46, 0.56], [0, 1.74, 0.84], 0.2, 0.15], ['neck2', [0, 1.72, 0.82], [0, 1.95, 1.0], 0.15, 0.12]];
    for (const [b, a, e, r0, r1] of nb) { Bd.setSkin([[id(b), 1]]); LP.prism(Bd, P(a), P(e), r0 * S * HK, r1 * S * HK, 6, jit(C[0]), { noCaps: true, rot: 0.26, sx: 0.8 }); }
    Bd.setSkin([[id('neck2'), 1]]); LP.ico(Bd, P([0, 1.73, 0.83]), 0.155 * S * HK, 0, () => jit(C[0]));
    Bd.setSkin([[id('head'), 1]]);
    LP.ico(Bd, P([0, 1.95, 1.04]), [0.1 * S * HK, 0.12 * S * HK, 0.13 * S * HK], 0, d => jit(d[1] > 0.5 ? C[1] : C[0]));
    LP.prism(Bd, P([0, 1.92, 1.08]), P([0, 1.62, 1.38]), 0.095 * S * HK, 0.07 * S * HK, 6, jit(C[0]), { sx: 0.85, rot: 0.26 });
    LP.prism(Bd, P([0, 1.66, 1.34]), P([0, 1.57, 1.43]), 0.075 * S * HK, 0.06 * S * HK, 6, C[5], { sx: 0.95, rot: 0.26 });
    const earL = donkey ? 0.26 : 0.13;
    for (const s of [1, -1]) LP.prism(Bd, P([s * 0.05 * HK, 2.03 * (donkey ? 1.01 : 1), 0.98]), P([s * 0.08 * HK, 2.03 + earL, 0.93]), 0.035 * S * HK, 0.0, 4, donkey ? C[3] : C[1], { sx: donkey ? 1.4 : 1 });
    Dk.setSkin([[id('head'), 1]]);
    for (const s of [1, -1]) { AA.box(Dk, P([s * 0.088 * HK, 1.95, 1.1]), [0.014 * S, 0.035 * S, 0.04 * S], LP.c('black'), 1, {}); AA.box(Dk, P([s * 0.035, 1.6, 1.43]), [0.022 * S, 0.018 * S, 0.02 * S], LP.c('black'), 1, {}); }
    // المعرفة: شريط مثلثات على أعلى الرقبة، وناصية بين الأذنين
    Mn.setSkin([[id('neck2'), 0.5], [id('neck1'), 0.5]]);
    const mane = donkey ? 0.06 : 0.14, mp = [[0, 1.5, 0.48], [0, 1.68, 0.62], [0, 1.86, 0.76], [0, 2.0, 0.92]];
    for (let i = 0; i < mp.length - 1; i++) { const a = P(mp[i]), b = P(mp[i + 1]), side = [0.05 * S, 0, 0];
      LP.tri(Mn, V.add(a, [0, 0.02 * S, -0.02 * S]), V.add(b, [0, 0.02 * S, -0.02 * S]), V.add(V.lerp(a, b, 0.7), [0, -mane * S * 0.3, -mane * S]), C[3]);
      LP.tri(Mn, V.add(a, side), V.add(b, side), V.add(V.lerp(a, b, 0.8), [0.07 * S, -mane * S, -0.03 * S]), C[3], [1, 0, 0]);
      LP.tri(Mn, V.sub(a, side), V.sub(b, side), V.add(V.lerp(a, b, 0.8), [-0.07 * S, -mane * S, -0.03 * S]), C[3], [-1, 0, 0]); }
    // الأرجل: منشورات وتمفصلات وحوافر
    const leg = [['upF', [0.16, 1.32, 0.52], [0.17, 1.02, 0.48], 0.12, 0.085], ['lowF', [0.17, 1.02, 0.48], [0.17, 0.52, 0.5], 0.075, 0.055], ['canF', [0.17, 0.52, 0.5], [0.17, 0.14, 0.52], 0.05, 0.045],
      ['thighB', [0.17, 1.42, -0.6], [0.18, 1.0, -0.42], 0.17, 0.11], ['shankB', [0.18, 1.0, -0.42], [0.17, 0.58, -0.72], 0.085, 0.06], ['canB', [0.17, 0.58, -0.72], [0.17, 0.14, -0.68], 0.05, 0.045]];
    for (const [sd, x] of [['L', 1], ['R', -1]]) {
      const X = a => P([a[0] * x, a[1], a[2]]);
      for (const [b, a, e, r0, r1] of leg) { Bd.setSkin([[id(b + sd), 1]]); LP.prism(Bd, X(a), X(e), r0 * S * wd, r1 * S * wd, 6, jit(b.startsWith('can') && !donkey ? C[4] : C[0]), { noCaps: true }); LP.ico(Bd, X(e), r1 * S * wd * 1.08, 0, () => jit(b.startsWith('can') && !donkey ? C[4] : C[0])); }
      for (const [b, a, e] of [['hoofF', [0.17, 0.14, 0.52], [0.17, 0.02, 0.58]], ['hoofB', [0.17, 0.14, -0.68], [0.17, 0.02, -0.63]]]) {
        Dk.setSkin([[id(b + sd), 1]]); LP.prism(Dk, V.add(X(a), [0, 0.02 * S, 0]), [a[0] * x * S, 0.02 * S, e[2] * S - 0.01 * S], 0.05 * S, 0.065 * S, 6, LP.c('#2e2622'));
      }
    }
    // الذيل
    Mn.setSkin([[id('tail'), 1]]);
    LP.prism(Mn, P([0, 1.42, -0.84]), P([0, donkey ? 1.0 : 0.82, -0.96]), 0.06 * S, donkey ? 0.02 * S : 0.09 * S, 5, C[3], { sway: () => 0.2 });
    if (donkey) LP.ico(Mn, P([0, 0.96, -0.97]), [0.04 * S, 0.09 * S, 0.04 * S], 0, () => C[3]);
    // عُدّة الجر (اختيارية): طوق جلد على الكتف، حزام البطن، ولجام
    if (p.harness) {
      Tk.skinFn = AA.autoSkin(sk, ['chest', 'neck1'], 4);
      AA.loft(Tk, { path: [P([0, 1.38, 0.5]), P([0, 1.52, 0.6])], sides: 10, up: () => [0, 1, 0], radius: () => [0.26 * S * wd, 0.3 * S], color: () => LP.c('#5e3b22') });
      Tk.skinFn = AA.autoSkin(sk, ['root'], 3);
      AA.loft(Tk, { path: [P([0, 1.4, 0.08]), P([0, 1.4, 0.16])], sides: 10, up: () => [0, 1, 0], radius: (t, a) => [0.31 * S * wd, (Math.cos(a) > 0 ? 0.18 : 0.46 * wd) * S], color: () => LP.c('#6e4a2c') });
      Tk.skinFn = null; Tk.setSkin([[id('head'), 1]]);
      AA.loft(Tk, { path: [P([0, 1.7, 1.24]), P([0, 1.68, 1.29])], sides: 8, up: () => [0, 1, 0], radius: () => [0.085 * S * HK, 0.075 * S * HK], color: () => LP.c('#5e3b22') });
    }
    const clips = {};
    clips.idle = AA.clip(sk, 4.6, 30, true, t => { const w = t / 4.6 * Math.PI * 2; return { move: [0, 0.004 * S * Math.sin(w * 2), 0], neck1: [2 * Math.sin(w), 0, 0], neck2: [0, 6 * Math.sin(w), 0], head: [3 * Math.sin(w * 3), 0, 0], tail: [0, 0, 14 * Math.sin(w * 2)], hoofBL: [-14 * Math.max(0, Math.sin(w * 0.5 + 1)), 0, 0], canBL: [10 * Math.max(0, Math.sin(w * 0.5 + 1)), 0, 0] }; });
    const wdur = donkey ? 0.85 : 1.05;
    clips.walk = AA.gaitClip(sk, { duration: wdur, speed: (donkey ? 0.95 : 1.4) * S, extra: t => { const ph = t / wdur * Math.PI * 2; return { move: [0, 0.012 * S * Math.cos(ph * 4), 0], neck1: [4 * Math.sin(ph * 2), 0, 0], head: [-3 * Math.sin(ph * 2), 0, 0], tail: [0, 0, 10 * Math.sin(ph)] }; },
      legs: [['L', 0, 0.75], ['R', 0.5, 0.25]].flatMap(([sd, hp, fp]) => [
        { chain: ['upF' + sd, 'lowF' + sd, 'canF' + sd], foot: 'hoofF' + sd, phase: fp, duty: 0.64, lift: 0.13 * S, footSwing: 35, limits: [[-40, 40], [-40, 20], [0, 105]], init: [0, 0, 0], pref: [0, 0, 0], swingPref: [-8, -18, 75] },
        { chain: ['thighB' + sd, 'shankB' + sd, 'canB' + sd], foot: 'hoofB' + sd, phase: hp, duty: 0.64, lift: 0.12 * S, footSwing: 25, limits: [[-40, 35], [-55, 25], [-95, 10]], init: [0, 0, 0], pref: [0, 0, 0], swingPref: [12, -10, -55] }]) });
    clips.graze = AA.clip(sk, 3.2, 30, true, t => { const w = t / 3.2 * Math.PI * 2; return { neck1: [55, 0, 0], neck2: [22, 4 * Math.sin(w), 0], head: [10 + 6 * Math.sin(w * 6), 0, 0], upFL: [-6, 0, 0], tail: [0, 0, 12 * Math.sin(w * 2)] }; });
    return LP.finalize(outId, { body: { builder: Bd, material: LP.mat('fur') }, mane: { builder: Mn, material: LP.mat('hair', { doubleSided: true }) }, dark: { builder: Dk, material: LP.mat('dark') }, tack: { builder: Tk, material: LP.mat('leather') } },
      { stiffness: 0, height: 2.0 * S, radius: 1.1 * S, collider: { type: 'capsule', radius: 0.32 * S, height: 1.9 * S, axis: 'z' }, skeleton: sk.toJSON(), clips,
        walkSpeed: (donkey ? 0.95 : 1.4) * S, seat: [0, 1.62 * S, -0.05 * S], hitch: { shaftY: 1.02 * S, halfWidth: 0.27 * S * (donkey ? 1.06 : 1), rump: -0.85 * S, shoulder: 0.5 * S } });
  }
  LP.def('horse', (p, q) => equine(p, q, false, 'lp_horse'));
  LP.def('donkey', (p, q) => equine(p, q, true, 'lp_donkey'));

  // ---------- الغنم والماعز ----------
  const SBREEDS = { najdi: { body: '#2a2624', head: '#2a2624', face: '#efe9df', legs: '#2a2624', ears: 0.2, tail: 'long', wool: true },
    naimi: { body: '#ece5d6', head: '#7a4a2c', face: '#7a4a2c', legs: '#7a4a2c', ears: 0.12, tail: 'fat', wool: true },
    goat: { body: '#221e1c', head: '#221e1c', face: '#221e1c', legs: '#221e1c', ears: 0.17, tail: 'goat', wool: false, horns: true, beard: true } };
  function sheep(p, q) {
    const S = p.size, br = SBREEDS[p.breed] || SBREEDS.najdi, rng = AA.rng(p.seed), P3 = (x, y, z) => [x * S, y * S, z * S], sk = new AA.Skeleton(), id = n => sk.id(n);
    sk.add('root', null, P3(0, 0.62, 0), P3(0, 0.63, -0.25)); sk.add('rear', 'root', P3(0, 0.63, -0.25), P3(0, 0.62, -0.5)); sk.add('chest', 'root', P3(0, 0.63, 0.25), P3(0, 0.62, 0.45));
    sk.add('neck', 'chest', P3(0, 0.68, 0.42), P3(0, 0.86, 0.6)); sk.add('head', 'neck', P3(0, 0.86, 0.6), P3(0, 0.74, 0.86)); sk.add('tail', 'rear', P3(0, 0.66, -0.5), P3(0, 0.35, -0.56));
    for (const [sd, x] of [['L', 1], ['R', -1]]) {
      const fx = 0.1 * x, hx = 0.11 * x;
      sk.add('upF' + sd, 'chest', P3(fx, 0.55, 0.36), P3(fx, 0.32, 0.38)); sk.add('lowF' + sd, 'upF' + sd, P3(fx, 0.32, 0.38), P3(fx, 0.02, 0.39));
      sk.add('thighB' + sd, 'rear', P3(hx, 0.6, -0.36), P3(hx, 0.38, -0.3)); sk.add('shankB' + sd, 'thighB' + sd, P3(hx, 0.38, -0.3), P3(hx, 0.22, -0.42)); sk.add('cannonB' + sd, 'shankB' + sd, P3(hx, 0.22, -0.42), P3(hx, 0.02, -0.4));
    }
    const Bd = new AA.Builder(), Dk = new AA.Builder(), Hn = new AA.Builder(), cB = LP.c(br.body), cH = LP.c(br.head), cF = LP.c(br.face), cL = LP.c(br.legs), jit = c => AA.vary(c, rng, 0.09);
    // الجسم: صوف متكتل (كتل كرات أوجه) أو شعر الماعز (منشور بأطراف متدلية)
    Bd.skinFn = AA.autoSkin(sk, ['root', 'rear', 'chest'], 3);
    if (br.wool) {
      LP.clump(Bd, P3(0, 0.6, -0.02), [0.3 * S, 0.28 * S, 0.5 * S], [jit(cB), jit(cB), cB, AA.mixc(cB, [1, 1, 1], 0.08)], rng, { detail: q === 'low' ? 1 : 2, jitter: 0.1, flatBottom: 1 });
      for (let k = 0; k < (q === 'low' ? 4 : 8); k++) { const a = k * 2.39996, z = (k / 8 - 0.5) * 0.7; LP.clump(Bd, P3(Math.cos(a) * 0.17, 0.7 + Math.sin(a) * 0.06, z), 0.13 * S, [jit(cB), jit(cB)], rng, { detail: 0, jitter: 0.2 }); }
    } else {
      const rows = [[-0.48, 0.12, 0.12, 0.16], [-0.38, 0.2, 0.17, 0.3], [0, 0.21, 0.16, 0.34], [0.32, 0.2, 0.17, 0.32], [0.44, 0.13, 0.13, 0.18]];
      AA.loft(Bd, { path: rows.map(r => P3(0, 0.64, r[0])), sides: 8, up: () => [0, 1, 0], capStart: true, capEnd: true, radius: (t, a) => { const r = rows[Math.round(t * (rows.length - 1))]; return [r[1] * S, (Math.cos(a) > 0 ? r[2] : r[3]) * S]; }, color: () => jit(cB) });
    }
    Bd.skinFn = null;
    // الرقبة والرأس
    Bd.setSkin([[id('neck'), 1]]); LP.prism(Bd, P3(0, 0.64, 0.3), P3(0, 0.84, 0.56), 0.13 * S, 0.08 * S, 6, br.wool ? jit(cB) : jit(cH), { rot: 0.26 });
    if (br.wool) LP.clump(Bd, P3(0, 0.74, 0.44), [0.13 * S, 0.13 * S, 0.12 * S], [jit(cB), jit(cB)], rng, { detail: 0, jitter: 0.15 });
    Bd.setSkin([[id('head'), 1]]);
    LP.ico(Bd, P3(0, 0.86, 0.62), [0.09 * S, 0.1 * S, 0.105 * S], 0, () => jit(cH));
    LP.prism(Bd, P3(0, 0.86, 0.65), P3(0, 0.79, 0.77), 0.075 * S, 0.055 * S, 6, cF, { sx: 0.85, rot: 0.26 });
    for (const s of [1, -1]) { // الأذنان: النجدية طويلة متدلية
      const a = P3(s * 0.075, 0.9, 0.6), e = br.ears > 0.18 ? P3(s * 0.14, 0.75, 0.63) : P3(s * (0.08 + br.ears * 0.8), 0.88, 0.58);
      LP.prism(Bd, a, e, 0.03 * S, 0.018 * S, 4, cH, { sx: 0.5 });
    }
    Dk.setSkin([[id('head'), 1]]);
    for (const s of [1, -1]) { AA.box(Dk, P3(s * 0.08, 0.885, 0.68), [0.01 * S, 0.026 * S, 0.03 * S], LP.c('black'), 1, {}); }
    AA.box(Dk, P3(0, 0.8, 0.79), [0.03 * S, 0.016 * S, 0.016 * S], LP.c('black'), 1, {});
    if (br.horns) { Hn.setSkin([[id('head'), 1]]); for (const s of [1, -1]) LP.chain(Hn, [P3(s * 0.035, 0.93, 0.6), P3(s * 0.06, 1.0, 0.54), P3(s * 0.08, 1.03, 0.45)], [0.022 * S, 0.016 * S, 0.004 * S], 5, () => LP.c('#8a7a64')); }
    if (br.beard) { Hn.setSkin([[id('head'), 1]]); LP.prism(Hn, P3(0, 0.77, 0.73), P3(0, 0.66, 0.71), 0.025 * S, 0.004 * S, 4, LP.c('#3a3330')); }
    // الأرجل
    const legs = [['upF', [0.1, 0.55, 0.36], [0.1, 0.32, 0.38], 0.045], ['lowF', [0.1, 0.32, 0.38], [0.1, 0.02, 0.39], 0.03], ['thighB', [0.11, 0.6, -0.36], [0.11, 0.38, -0.3], 0.06], ['shankB', [0.11, 0.38, -0.3], [0.11, 0.22, -0.42], 0.035], ['cannonB', [0.11, 0.22, -0.42], [0.11, 0.02, -0.4], 0.028]];
    for (const [sd, x] of [['L', 1], ['R', -1]]) for (const [b, a, e, r] of legs) {
      Bd.setSkin([[id(b + sd), 1]]); LP.prism(Bd, P3(a[0] * x, a[1], a[2]), P3(e[0] * x, Math.max(e[1], 0.04), e[2]), r * S, r * 0.85 * S, 5, jit(cL), { noCaps: true }); LP.ico(Bd, P3(e[0] * x, Math.max(e[1], 0.04), e[2]), r * 0.95 * S, 0, () => jit(cL));
      if (e[1] < 0.05) { Dk.setSkin([[id(b + sd), 1]]); LP.prism(Dk, P3(e[0] * x, 0.06, e[2]), P3(e[0] * x, 0.022, e[2] + 0.01), 0.03 * S, 0.034 * S, 5, LP.c('#2b2726')); }
    }
    // الذيل: طويل للنجدية، إلية للنعيمية، قصير مرفوع للماعز
    Bd.setSkin([[id('tail'), 1]]);
    if (br.tail === 'fat') LP.ico(Bd, P3(0, 0.55, -0.5), [0.12 * S, 0.12 * S, 0.07 * S], 0, () => jit(cB));
    else if (br.tail === 'goat') LP.prism(Bd, P3(0, 0.7, -0.46), P3(0, 0.8, -0.52), 0.03 * S, 0.01 * S, 4, cB);
    else LP.prism(Bd, P3(0, 0.66, -0.48), P3(0, 0.3, -0.56), 0.05 * S, 0.03 * S, 5, jit(cB));
    const clips = {};
    clips.idle = AA.clip(sk, 4, 30, true, t => { const w = t / 4 * Math.PI * 2; return { move: [0, 0.004 * S * Math.sin(w * 2), 0], neck: [3 * Math.sin(w), 8 * Math.sin(w * 0.5), 0], head: [2 * Math.sin(w * 7), 0, 0], tail: [0, 0, 10 * Math.sin(w * 4)] }; });
    clips.graze = AA.clip(sk, 3, 30, true, t => { const w = t / 3 * Math.PI * 2; return { neck: [58, 6 * Math.sin(w), 0], head: [10 + 5 * Math.sin(w * 8), 0, 0], chest: [8, 0, 0], tail: [0, 0, 8 * Math.sin(w * 3)] }; });
    clips.walk = AA.gaitClip(sk, { duration: 0.9, speed: 0.8 * S, extra: t => { const ph = t / 0.9 * Math.PI * 2; return { move: [0, 0.008 * S * Math.cos(ph * 4), 0], neck: [4 * Math.sin(ph * 2), 0, 0], tail: [0, 0, 8 * Math.sin(ph)] }; },
      legs: [['L', 0, 0.75], ['R', 0.5, 0.25]].flatMap(([sd, hp, fp]) => [
        { chain: ['upF' + sd, 'lowF' + sd], foot: null, phase: fp, duty: 0.64, lift: 0.1 * S, limits: [[-40, 40], [0, 100]], init: [0, 0], pref: [0, 0], swingPref: [-10, 60] },
        { chain: ['thighB' + sd, 'shankB' + sd, 'cannonB' + sd], foot: null, phase: hp, duty: 0.64, lift: 0.09 * S, limits: [[-40, 35], [-55, 25], [-95, 10]], init: [0, 0, 0], pref: [0, 0, 0], swingPref: [12, -10, -50] }]) });
    return LP.finalize('lp_sheep', { body: { builder: Bd, material: LP.mat('fur') }, dark: { builder: Dk, material: LP.mat('dark') }, horns: { builder: Hn, material: LP.mat('horn') } },
      { stiffness: 0, height: 0.95 * S, radius: 0.55 * S, collider: { type: 'capsule', radius: 0.22 * S, height: 1.0 * S, axis: 'z' }, skeleton: sk.toJSON(), clips, walkSpeed: 0.8 * S });
  }
  LP.def('sheep', sheep);

  LP.def('camel', camel);
})(typeof window !== 'undefined' ? window : globalThis);
