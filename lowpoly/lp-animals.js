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
    const Bd = new AA.Builder(), Dk = new AA.Builder(), Sd = new AA.Builder(), jit = c => AA.vary(c, rng, 0.07);
    // الجسم والسنام في قطعة واحدة: مقاطع بعشرة أضلاع، نصفها العلوي يرتفع ويضيق عند السنام
    // [z، نصف العرض، الارتفاع للأعلى، العمق للأسفل، مركز y]
    const rows = [[-1.02, 0.1, 0.1, 0.12, 1.47], [-0.86, 0.26, 0.23, 0.3, 1.46], [-0.62, 0.33, 0.3, 0.36, 1.45], [-0.42, 0.35, 0.42, 0.38, 1.46], [-0.22, 0.36, 0.6, 0.4, 1.47],
      [0.0, 0.36, 0.68, 0.41, 1.47], [0.18, 0.35, 0.62, 0.42, 1.48], [0.36, 0.34, 0.45, 0.44, 1.48], [0.56, 0.32, 0.32, 0.43, 1.49], [0.76, 0.28, 0.27, 0.4, 1.5], [0.95, 0.19, 0.2, 0.3, 1.53]];
    Bd.skinFn = AA.autoSkin(sk, ['root', 'rear', 'chest'], 3);
    AA.loft(Bd, { path: rows.map(r => [0, r[4], r[0]]), sides: q === 'low' ? 8 : 10, up: () => [0, 1, 0], capStart: true, capEnd: true,
      radius: (t, a) => { const r = rows[Math.round(t * (rows.length - 1))], c = Math.cos(a), hump = AA.clamp((r[2] - 0.32) / 0.36, 0, 1);
        return [r[1] * (1 - 0.42 * hump * Math.max(0, c) ** 2), c > 0 ? r[2] : r[3]]; },
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
      LP.ico(Sd, [0, 1.98, -0.06], [0.42, 0.31, 0.56], 1, d => Math.abs(d[2]) > 0.72 ? LP.c('yellow') : d[1] > 0.85 ? LP.c('teal') : LP.c('red'), { keep: d => d[1] > -0.05 });
      for (const s of [1, -1]) {
        AA.box(Sd, [s * 0.4, 1.8, -0.06], [0.03, 0.34, 0.56], LP.c('red'), 1, {});
        AA.box(Sd, [s * 0.405, 1.61, -0.06], [0.035, 0.06, 0.58], LP.c('yellow'), 1, {});
      }
      for (const z of [-0.42, 0.3]) { AA.box(Sd, [0, 2.32, z], [0.06, 0.34, 0.06], LP.c('wood'), 1, {}); AA.box(Sd, [0, 2.5, z], [0.1, 0.05, 0.1], LP.c('woodDark'), 1, {}); }
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
