// Aboden Assets — animals/camel.js
// الجمل العربي (ذو السنام الواحد) بالكود: جسم بسنام، رقبة منحنية، أرجل بمفاصل وثفنات، ذيل.
// هيكل عظمي (24 عظمة) وثلاث حركات: وقوف، مشي رهوان (رجلا الجنب الواحد معاً)، رعي.
// تصميم أصلي — جمال مفاتيح كانت من مشروع خارجي (Motri / Bruno Simon) فلم تُنقل كما هي.
(function (g) {
  'use strict';
  const AA = g.AA;
  const V = AA.v, hex = AA.hex, mixc = AA.mixc, vary = AA.vary, lerp = AA.lerp, smooth = AA.smooth, clamp = AA.clamp;

  const COATS = {
    majaheem: ['#2a221d', '#3b3029', '#1c1714'],   // مجاهيم: سود
    wadh:     ['#e6dbc9', '#f2eadb', '#cfc1aa'],   // وضح: بيض
    shael:    ['#c79a64', '#d9b483', '#a87a48'],   // شعل: أشقر محمر
    humr:     ['#93593a', '#a96b47', '#7a4630'],   // حمر
    sufr:     ['#d4b17c', '#e2c696', '#b8955f']    // صفر
  };
  const Q = { high: { s: 16, n: 26, legN: 5 }, med: { s: 11, n: 18, legN: 4 }, low: { s: 7, n: 11, legN: 2 } };

  function skeleton(S) {
    const k = new AA.Skeleton(), P = (x, y, z) => [x * S, y * S, z * S];
    k.add('root', null, P(0, 1.42, 0), P(0, 1.45, -0.4));
    k.add('rear', 'root', P(0, 1.45, -0.5), P(0, 1.4, -1.1));
    k.add('chest', 'root', P(0, 1.42, 0.4), P(0, 1.4, 0.95));
    k.add('neck1', 'chest', P(0, 1.5, 0.86), P(0, 1.3, 1.25));
    k.add('neck2', 'neck1', P(0, 1.3, 1.25), P(0, 1.62, 1.6));
    k.add('neck3', 'neck2', P(0, 1.62, 1.6), P(0, 2.08, 1.7));
    k.add('head', 'neck3', P(0, 2.08, 1.7), P(0, 2.0, 2.2));
    k.add('tail', 'rear', P(0, 1.42, -1.12), P(0, 0.95, -1.25));
    for (const [sd, x] of [['L', 1], ['R', -1]]) {
      const fx = 0.2 * x, hx = 0.22 * x;
      k.add('upF' + sd, 'chest', P(fx, 1.45, 0.66), P(fx, 0.92, 0.7));
      k.add('lowF' + sd, 'upF' + sd, P(fx, 0.92, 0.7), P(fx, 0.28, 0.7));
      k.add('footF' + sd, 'lowF' + sd, P(fx, 0.28, 0.7), P(fx, 0.05, 0.78));
      k.add('thighB' + sd, 'rear', P(hx, 1.5, -0.78), P(hx, 1.0, -0.52));
      k.add('shankB' + sd, 'thighB' + sd, P(hx, 1.0, -0.52), P(hx, 0.72, -0.86));
      k.add('cannonB' + sd, 'shankB' + sd, P(hx, 0.72, -0.86), P(hx, 0.22, -0.84));
      k.add('footB' + sd, 'cannonB' + sd, P(hx, 0.22, -0.84), P(hx, 0.05, -0.78));
    }
    return k;
  }

  // مسار متعدد النقاط → n نقطة موزعة بالتساوي على المقاطع
  function polyline(pts, per) {
    const out = [];
    for (let i = 0; i < pts.length - 1; i++) for (let k = 0; k < per; k++) out.push(V.lerp(pts[i], pts[i + 1], k / per));
    out.push(pts[pts.length - 1]); return out;
  }
  function radiusAlong(rs, t) { // rs: [[t, r], ...]
    for (let i = 0; i < rs.length - 1; i++) if (t <= rs[i + 1][0]) return lerp(rs[i][1], rs[i + 1][1], smooth(rs[i][0], rs[i + 1][0], t));
    return rs[rs.length - 1][1];
  }

  function camel(p, quality) {
    const q = Q[quality] || Q.med, S = p.size, rng = AA.rng(p.seed);
    const sk = skeleton(S), coat = (COATS[p.coat] || COATS.shael).map(hex);
    const B = new AA.Builder(), D = new AA.Builder(), SD = new AA.Builder(), W = new AA.Builder();
    const col = (base, k) => vary(mixc(coat[0], base, k), rng, 0.06);
    const P3 = (x, y, z) => [x * S, y * S, z * S];

    // الجسم + السنام
    const spine = AA.bezier([P3(0, 1.38, -1.14), P3(0, 1.47, -0.4), P3(0, 1.46, 0.4), P3(0, 1.36, 1.0)], q.n);
    const humpAt = t => p.hump * Math.exp(-Math.pow((t - 0.47) / 0.2, 2));
    const bodyR = (t, ang) => {
      const rx = radiusAlong([[0, 0.18], [0.14, 0.37], [0.5, 0.42], [0.86, 0.36], [1, 0.2]], t) * S;
      let ry = radiusAlong([[0, 0.2], [0.14, 0.4], [0.5, 0.45], [0.86, 0.43], [1, 0.24]], t) * S;
      const c = Math.cos(ang), h = humpAt(t) * S;
      if (c > 0) ry += h * Math.pow(c, 1.15); else ry *= 1 + 0.05 * -c;
      return [rx * (1 - 0.25 * (h / S) * Math.pow(Math.max(0, c), 3)), ry];
    };
    B.skinFn = AA.autoSkin(sk, ['root', 'rear', 'chest', 'neck1', 'upFL', 'upFR', 'thighBL', 'thighBR'], 4);
    AA.loft(B, { path: spine, sides: q.s, radius: bodyR, capStart: true, capEnd: true, uvU: 3, uvV: 2,
      color: (t, ang) => { const c = Math.cos(ang); return col(c > 0.6 ? coat[1] : c < -0.4 ? coat[2] : coat[0], 0.6 + 0.4 * Math.abs(c)); } });

    // الرقبة
    const neck = AA.bezier([P3(0, 1.52, 0.78), P3(0, 1.2, 1.3), P3(0, 1.62, 1.6), P3(0, 2.12, 1.7)], q.n);
    B.skinFn = AA.autoSkin(sk, ['chest', 'neck1', 'neck2', 'neck3', 'head'], 5);
    AA.loft(B, { path: neck, sides: q.s, up: () => [0, 1, -1], uvU: 2, uvV: 2,
      radius: t => { const r = radiusAlong([[0, 0.24], [0.35, 0.15], [0.75, 0.12], [1, 0.12]], t) * S; return [r * 0.78, r]; },
      color: (t, ang) => col(Math.cos(ang) > 0.5 ? coat[1] : coat[0], 0.7) });

    // الرأس
    const head = polyline([P3(0, 2.08, 1.62), P3(0, 2.12, 1.82), P3(0, 2.04, 2.08), P3(0, 1.98, 2.22)], q.legN);
    B.skinFn = AA.autoSkin(sk, ['neck3', 'head'], 6);
    AA.loft(B, { path: head, sides: q.s, up: () => [0, 1, 0], capStart: true, capEnd: true, uvU: 1, uvV: 2,
      radius: (t, ang) => { const r = radiusAlong([[0, 0.12], [0.3, 0.135], [0.7, 0.1], [1, 0.07]], t) * S; return [r * 0.85, r * (Math.cos(ang) < 0 && t > 0.6 ? 1.18 : 1)]; },
      color: (t) => col(coat[0], 0.85 - 0.15 * t) });
    // آذان صغيرة
    B.setSkin([[sk.id('head'), 1]]);
    for (const x of [1, -1]) AA.loft(B, { path: [P3(0.07 * x, 2.18, 1.7), P3(0.11 * x, 2.27, 1.66)], sides: 5, radius: t => [0.035 * S * (1 - t * 0.8), 0.02 * S], capEnd: true, color: () => col(coat[2], 0.8) });
    // عيون ومنخران
    D.setSkin([[sk.id('head'), 1]]);
    for (const x of [1, -1]) {
      AA.blob(D, P3(0.105 * x, 2.16, 1.86), [0.02 * S, 0, 0], [0, 0.026 * S, 0], [0, 0, 0.03 * S], () => [0.05, 0.035, 0.03], 0, 0, 0, null, 0, quality === 'low');
      AA.blob(D, P3(0.035 * x, 2.03, 2.23), [0.012 * S, 0, 0], [0, 0.02 * S, 0], [0, 0, 0.01 * S], () => [0.1, 0.07, 0.06], 0, 0, 0, null, 0, true);
    }

    // الأرجل
    const legRad = (rs, t) => radiusAlong(rs, t) * S;
    for (const [sd, x] of [['L', 1], ['R', -1]]) {
      const fx = 0.2 * x, hx = 0.22 * x;
      B.skinFn = AA.autoSkin(sk, ['chest', 'upF' + sd, 'lowF' + sd, 'footF' + sd], 6);
      const fp = polyline([P3(fx, 1.42, 0.64), P3(fx, 0.92, 0.7), P3(fx, 0.28, 0.7), P3(fx, 0.07, 0.75)], q.legN);
      AA.loft(B, { path: fp, sides: Math.max(6, q.s - 3), up: () => [0, 0, 1], uvU: 1, uvV: 2,
        radius: t => legRad([[0, 0.17], [0.12, 0.13], [0.25, 0.09], [0.33, 0.075], [0.4, 0.06], [0.55, 0.045], [0.85, 0.05], [1, 0.06]], t),
        color: t => t > 0.28 && t < 0.38 ? mixc(col(coat[0], 0.8), [0.35, 0.32, 0.3], 0.6) : col(coat[0], 0.85 - 0.3 * t) });
      B.skinFn = AA.autoSkin(sk, ['rear', 'thighB' + sd, 'shankB' + sd, 'cannonB' + sd, 'footB' + sd], 6);
      const hp = polyline([P3(hx, 1.48, -0.8), P3(hx, 1.0, -0.52), P3(hx, 0.72, -0.86), P3(hx, 0.22, -0.84), P3(hx, 0.07, -0.79)], q.legN);
      AA.loft(B, { path: hp, sides: Math.max(6, q.s - 3), up: () => [0, 0, 1], uvU: 1, uvV: 2,
        radius: t => legRad([[0, 0.26], [0.12, 0.19], [0.24, 0.11], [0.3, 0.085], [0.5, 0.07], [0.6, 0.05], [0.85, 0.05], [1, 0.06]], t),
        color: t => col(coat[0], 0.85 - 0.3 * t) });
      // الخف: وسادة عريضة مسطحة
      for (const [z, foot] of [[0.8, 'footF' + sd], [-0.77, 'footB' + sd]]) {
        B.setSkin([[sk.id(foot), 1]]);
        AA.blob(B, P3(x > 0 ? (z > 0 ? fx : hx) : (z > 0 ? fx : hx), 0.045, z), [0.085 * S, 0, 0], [0, 0.045 * S, 0], [0, 0, 0.12 * S], () => col(coat[2], 0.7), 0, 0, 0, rng, 0.05, quality === 'low');
      }
    }
    // الذيل
    B.skinFn = AA.autoSkin(sk, ['rear', 'tail'], 6);
    AA.loft(B, { path: AA.bezier([P3(0, 1.4, -1.1), P3(0, 1.22, -1.25), P3(0, 0.82, -1.24)], 7), sides: 6, capEnd: true,
      radius: t => 0.04 * S * (1 - 0.45 * t) + 0.035 * S * smooth(0.7, 0.9, t) * (1 - smooth(0.95, 1, t)), color: t => col(t > 0.7 ? coat[2] : coat[0], 0.8) });

    // الشداد والسدو
    if (p.saddle) {
      SD.skinFn = AA.autoSkin(sk, ['root', 'rear', 'chest'], 3);
      const t0 = 0.34, t1 = 0.62, nu = q.s, nv = 6, ids = [];
      const at = (t, ang, out) => {
        const f = t * (spine.length - 1), i = Math.min(spine.length - 2, Math.floor(f)), c = V.lerp(spine[i], spine[i + 1], f - i);
        const [rx, ry] = bodyR(t, ang);
        return [c[0] - Math.sin(ang) * (rx + out), c[1] + Math.cos(ang) * (ry + out), c[2]];
      };
      for (let j = 0; j <= nv; j++) { ids.push([]); for (let i = 0; i <= nu; i++) {
        const ang = lerp(-1.95, 1.95, i / nu), t = lerp(t0, t1, j / nv);
        ids[j].push(SD.v(at(t, ang, 0.025 * S), [1, 1, 1], 0, 0, 0, [i / nu, j / nv]));
      } }
      for (let j = 0; j < nv; j++) for (let i = 0; i < nu; i++) { SD.t(ids[j][i], ids[j + 1][i + 1], ids[j][i + 1]); SD.t(ids[j][i], ids[j + 1][i], ids[j + 1][i + 1]); }
      W.skinFn = AA.autoSkin(sk, ['root', 'rear', 'chest'], 3);
      for (const t of [0.37, 0.59]) { // قوسا الشداد: كل قوس عودان يتصالبان فوق السنام ويبرزان
        const top = at(t, 0, 0.2 * S);
        for (const sgn of [1, -1]) {
          const foot = at(t, sgn * 1.15, 0.04 * S), mid = at(t, sgn * 0.55, 0.11 * S);
          const tip = V.add(top, [-sgn * 0.13 * S, 0.17 * S, 0]);
          AA.tube(W, [foot, mid, top, tip], [0.03 * S, 0.028 * S, 0.026 * S, 0.022 * S], 6, () => [0.9, 0.9, 0.9], () => 0, 0, null, true);
        }
      }
      { // عارضتان طوليتان تربطان القوسين
        for (const sgn of [1, -1]) AA.tube(W, [at(0.35, sgn * 0.75, 0.1 * S), at(0.61, sgn * 0.75, 0.1 * S)], [0.022 * S, 0.022 * S], 5, () => [0.85, 0.85, 0.85], () => 0, 0, null, true);
      }
    }

    const H = 1.42 * S, clips = {}, T = sk;
    // وقوف: تنفّس، اجترار، تلويح الذيل
    clips.idle = AA.clip(T, 4, 30, true, t => {
      const w = t / 4 * Math.PI * 2;
      return { move: [0, 0.006 * S * Math.sin(w * 2), 0], neck3: [0, 6 * Math.sin(w), 0], head: [2.5 * Math.sin(w * 6), 0, 0], neck1: [1.5 * Math.sin(w * 2), 0, 0], tail: [0, 0, 14 * Math.sin(w * 3)] };
    });
    // مشي رهوان: رجلا الجنب الواحد معاً — هذه مشية الجمل الحقيقية
    clips.walk = AA.clip(T, 1.25, 30, true, t => {
      const ph = t / 1.25 * Math.PI * 2, pose = { move: [0, 0.03 * S * Math.abs(Math.cos(ph)), 0] };
      for (const [sd, off] of [['L', 0], ['R', Math.PI]]) {
        const a = ph + off, s = Math.sin(a), lift = Math.pow(Math.max(0, Math.sin(a + 1.3)), 1.5);
        pose['upF' + sd] = [-20 * s, 0, 0]; pose['lowF' + sd] = [38 * lift, 0, 0]; pose['footF' + sd] = [-18 * lift + 6 * s, 0, 0];
        pose['thighB' + sd] = [-16 * s, 0, 0]; pose['shankB' + sd] = [-22 * lift, 0, 0]; pose['cannonB' + sd] = [30 * lift, 0, 0]; pose['footB' + sd] = [-12 * lift, 0, 0];
      }
      pose.rear = [0, 0, 4 * Math.sin(ph)]; pose.chest = [0, 0, 4 * Math.sin(ph)];
      pose.neck1 = [5 * Math.sin(ph * 2), 0, 0]; pose.head = [-5 * Math.sin(ph * 2), 0, 0]; pose.tail = [0, 0, 12 * Math.sin(ph)];
      return pose;
    });
    // رعي: تنزل الرقبة للأرض وتأكل
    clips.graze = AA.clip(T, 3, 30, true, t => {
      const w = t / 3 * Math.PI * 2;
      return { neck1: [62, 0, 0], neck2: [28, 0, 0], neck3: [22 + 3 * Math.sin(w * 3), 0, 0], head: [-15 + 4 * Math.sin(w * 6), 4 * Math.sin(w), 0], tail: [0, 0, 10 * Math.sin(w * 2)] };
    });

    return AA.finalize('camel', {
      body:   { builder: B,  material: { kind: 'fur', texture: 'fur', roughness: 0.92 } },
      dark:   { builder: D,  material: { kind: 'dark', roughness: 0.35, color: [1, 1, 1] } },
      saddle: { builder: SD, material: { kind: 'cloth', texture: 'sadu', roughness: 0.9, doubleSided: true } },
      wood:   { builder: W,  material: { kind: 'wood', texture: 'wood', roughness: 0.8 } }
    }, { stiffness: 0, height: 2.3 * S, radius: 1.3 * S, collider: { type: 'capsule', radius: 0.45 * S, height: 2.2 * S, axis: 'z' },
      skeleton: sk.toJSON(), clips, seat: p.saddle ? [0, 1.95 * S + p.hump * S * 0.5, -0.05 * S] : null, walkSpeed: 1.3 * S });
  }

  AA.assets.camel = {
    id: 'camel', name: 'جمل', nameEn: 'Arabian camel', category: 'animals',
    schema: [
      { key: 'coat', label: 'اللون', type: 'enum', options: [['shael', 'شعل'], ['majaheem', 'مجاهيم'], ['wadh', 'وضح'], ['humr', 'حمر'], ['sufr', 'صفر']], def: 'shael' },
      { key: 'size', label: 'الحجم', min: 0.55, max: 1.15, step: 0.05, def: 1, pct: true },
      { key: 'hump', label: 'السنام', min: 0.15, max: 0.6, step: 0.05, def: 0.38, unit: 'م' },
      { key: 'saddle', label: 'شداد وسدو', type: 'bool', def: false }
    ],
    presets: { 'ناقة ركوب': { coat: 'wadh', saddle: true }, 'حوار (صغير)': { size: 0.6, hump: 0.18, coat: 'shael' }, 'فحل مجاهيم': { coat: 'majaheem', size: 1.1, hump: 0.5 } },
    clips: [['idle', 'وقوف'], ['walk', 'مشي'], ['graze', 'رعي']],
    generate: camel
  };
})(typeof window !== 'undefined' ? window : globalThis);
