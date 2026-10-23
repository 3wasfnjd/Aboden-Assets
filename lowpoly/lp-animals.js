// Aboden Assets — lowpoly/lp-animals.js — جمل لو-بولي بنفس هيكل جمل الحزمة الواقعية ومشيه
(function (g) {
  'use strict';
  const AA = g.AA, LP = AA.lp, V = AA.v, lerp = AA.lerp, mixc = AA.mixc;
  const COATS = { shael: ['camel', 'camelDark', 'camelLight'], wadh: ['#efe4d0', '#ddd0b8', '#f8f0e2'], majaheem: ['#3a2e27', '#2c231e', '#4a3c33'], humr: ['#a96a42', '#8f5634', '#c08258'] };
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
    const Bd = new AA.Builder(), Dk = new AA.Builder(), Sd = new AA.Builder();
    // الجسم: مقاطع مثمّنة (أعلى أقل من أسفل) من المؤخرة للصدر
    const rows = [[-1.0, 0.12, 0.12, 0.16, 1.47], [-0.8, 0.28, 0.2, 0.32, 1.44], [-0.4, 0.33, 0.24, 0.38, 1.46], [0.0, 0.35, 0.26, 0.42, 1.5], [0.4, 0.33, 0.26, 0.45, 1.5], [0.75, 0.27, 0.24, 0.38, 1.52], [0.95, 0.13, 0.13, 0.18, 1.55]];
    Bd.skinFn = AA.autoSkin(sk, ['root', 'rear', 'chest'], 3);
    AA.loft(Bd, { path: rows.map(r => [0, r[4], r[0]]), sides: 8, up: () => [0, 1, 0], capStart: true, capEnd: true,
      radius: (t, a) => { const r = rows[Math.round(t * (rows.length - 1))]; return [r[1], Math.cos(a) > 0 ? r[2] : r[3]]; }, color: (t, a) => Math.cos(a) < -0.5 ? C[2] : C[0] });
    // السنام
    LP.ico(Bd, [0, 1.72, -0.08], [0.27, 0.36, 0.4], 0, d => d[1] > 0.5 ? C[1] : C[0], { keep: d => d[1] > -0.35 });
    // الرقبة والرأس
    const nb = [['neck1', [0, 1.55, 0.78], [0, 1.38, 1.15], 0.19, 0.15], ['neck2', [0, 1.38, 1.15], [0, 1.66, 1.48], 0.14, 0.11], ['neck3', [0, 1.66, 1.48], [0, 2.12, 1.6], 0.11, 0.09]];
    for (const [b, a, e, r0, r1] of nb) { Bd.setSkin([[id(b), 1]]); LP.prism(Bd, a, e, r0, r1, 6, C[0], { noCaps: b !== 'neck3' }); }
    Bd.setSkin([[id('head'), 1]]);
    LP.prism(Bd, [0, 2.14, 1.56], [0, 1.99, 2.12], 0.115, 0.07, 6, C[0], { sx: 0.8 });
    LP.prism(Bd, [0, 2.0, 2.04], [0, 1.97, 2.16], 0.075, 0.055, 6, C[2], { sx: 0.9 });
    for (const s of [1, -1]) LP.prism(Bd, [s * 0.07, 2.2, 1.6], [s * 0.1, 2.3, 1.56], 0.03, 0.0, 4, C[1]);
    Dk.setSkin([[id('head'), 1]]);
    for (const s of [1, -1]) { AA.box(Dk, [s * 0.088, 2.13, 1.76], [0.02, 0.04, 0.05], LP.c('black'), 1, {}); AA.box(Dk, [s * 0.04, 1.97, 2.16], [0.02, 0.02, 0.02], LP.c('black'), 1, {}); }
    // الأرجل: منشورات لكل عظمة + خف عريض
    for (const [sd, x] of [['L', 1], ['R', -1]]) {
      const X = a => [a[0] * x, a[1], a[2]], f = J.front, h = J.hind;
      for (const [b, a, e, r0, r1] of [['upF', f.sh, f.el, 0.12, 0.085], ['lowF', f.el, f.kn, 0.075, 0.06], ['canF', f.kn, f.fe, 0.055, 0.048], ['thighB', h.hp, h.st, 0.17, 0.1], ['shankB', h.st, h.hk, 0.085, 0.06], ['canB', h.hk, h.fe, 0.052, 0.046]]) {
        Bd.setSkin([[id(b + sd), 1]]); LP.prism(Bd, X(a), X(e), r0, r1, 5, C[0]);
      }
      for (const [b, fe, ft] of [['footF', f.fe, f.ft], ['footB', h.fe, h.ft]]) {
        Bd.setSkin([[id(b + sd), 1]]); LP.prism(Bd, X(fe), X(ft), 0.05, 0.075, 5, C[1]);
        Dk.setSkin([[id(b + sd), 1]]); AA.box(Dk, [ft[0] * x, 0.02, ft[2] + 0.02], [0.15, 0.04, 0.2], mixc(C[1], [0, 0, 0], 0.3), 1, {});
      }
    }
    // الذيل
    Bd.setSkin([[id('tail'), 1]]); LP.prism(Bd, [0, 1.46, -1.0], [0, 0.9, -1.1], 0.035, 0.02, 4, C[1]);
    Dk.setSkin([[id('tail'), 1]]); LP.ico(Dk, [0, 0.86, -1.1], [0.04, 0.09, 0.04], 0, () => mixc(C[1], [0, 0, 0], 0.4));
    // الشداد (اختياري): بطانية حمراء وعودان
    if (p.saddle) {
      Sd.skinFn = AA.autoSkin(sk, ['root', 'rear', 'chest'], 3);
      LP.ico(Sd, [0, 1.84, -0.08], [0.36, 0.3, 0.46], 0, d => Math.abs(d[2]) > 0.6 ? LP.c('yellow') : d[1] > 0.6 ? LP.c('teal') : LP.c('red'), { keep: d => d[1] > -0.1 });
      for (const z of [-0.35, 0.22]) AA.box(Sd, [0, 2.12, z], [0.06, 0.3, 0.06], LP.c('wood'), 1, {});
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
    return LP.finalize('lp_camel', {
      body:   { builder: Bd, material: LP.mat('fur') },
      dark:   { builder: Dk, material: LP.mat('dark') },
      saddle: { builder: Sd, material: LP.mat('cloth') }
    }, { stiffness: 0, height: 2.3, radius: 1.3, collider: { type: 'capsule', radius: 0.45, height: 2.2, axis: 'z' }, skeleton: sk.toJSON(), clips, walkSpeed: 1.25 });
  }

  AA.assets.lp_camel = { id: 'lp_camel', name: 'جمل', nameEn: 'Low-poly camel', category: 'lowpoly',
    schema: [
      { key: 'coat', label: 'اللون', type: 'enum', options: [['shael', 'شعل'], ['wadh', 'وضح'], ['majaheem', 'مجاهيم'], ['humr', 'حمر']], def: 'shael' },
      { key: 'saddle', label: 'شداد', type: 'bool', def: false }
    ], presets: { 'ناقة ركوب': { coat: 'wadh', saddle: true } },
    clips: [['idle', 'وقوف'], ['walk', 'مشي'], ['graze', 'رعي']], generate: camel };
})(typeof window !== 'undefined' ? window : globalThis);
