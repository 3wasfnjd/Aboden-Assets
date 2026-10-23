// Aboden Assets — core/texture.js
// خامات مولّدة بالكود (بدون صور): لياسة طين بطوب ظاهر، أعلى الجدار، خشب، باب نجدي ملوّن، جص أبيض.
// كل خامة تُخرج: { size, albedo: Uint8Array RGBA, normal: Uint8Array RGBA } — قابلة للتكرار (tileable).
// منقولة من house_textures.py في مستودع مفاتيح، بعد إعادة كتابتها بدون مكتبات.
(function (g) {
  'use strict';
  const AA = g.AA;
  const clamp = AA.clamp;

  // ضجيج قابل للتكرار عند الحواف (fbm)
  function tileNoise(n, seed, octaves, falloff) {
    const rng = AA.rng(seed), acc = new Float32Array(n * n);
    let amp = 1;
    for (const s of octaves) {
      const grid = new Float32Array(s * s);
      for (let i = 0; i < grid.length; i++) grid[i] = rng();
      for (let y = 0; y < n; y++) {
        const fy = y / n * s, y0 = Math.floor(fy), ty = fy - y0, sy = ty * ty * (3 - 2 * ty);
        const r0 = (y0 % s) * s, r1 = ((y0 + 1) % s) * s;
        for (let x = 0; x < n; x++) {
          const fx = x / n * s, x0 = Math.floor(fx), tx = fx - x0, sx = tx * tx * (3 - 2 * tx);
          const c0 = x0 % s, c1 = (x0 + 1) % s;
          const a = grid[r0 + c0] + (grid[r0 + c1] - grid[r0 + c0]) * sx;
          const b = grid[r1 + c0] + (grid[r1 + c1] - grid[r1 + c0]) * sx;
          acc[y * n + x] += (a + (b - a) * sy) * amp;
        }
      }
      amp /= falloff;
    }
    let mn = Infinity, mx = -Infinity;
    for (const v of acc) { if (v < mn) mn = v; if (v > mx) mx = v; }
    for (let i = 0; i < acc.length; i++) acc[i] = (acc[i] - mn) / (mx - mn || 1);
    return acc;
  }
  // تنعيم يلتف عند الحواف
  function blur(a, n, r, passes) {
    let src = a, tmp = new Float32Array(n * n);
    for (let p = 0; p < (passes || 2); p++) {
      for (let y = 0; y < n; y++) {
        let s = 0;
        for (let k = -r; k <= r; k++) s += src[y * n + ((k % n) + n) % n];
        for (let x = 0; x < n; x++) {
          tmp[y * n + x] = s / (2 * r + 1);
          s += src[y * n + (x + r + 1) % n] - src[y * n + ((x - r) % n + n) % n];
        }
      }
      const out = new Float32Array(n * n);
      for (let x = 0; x < n; x++) {
        let s = 0;
        for (let k = -r; k <= r; k++) s += tmp[(((k % n) + n) % n) * n + x];
        for (let y = 0; y < n; y++) {
          out[y * n + x] = s / (2 * r + 1);
          s += tmp[((y + r + 1) % n) * n + x] - tmp[(((y - r) % n + n) % n) * n + x];
        }
      }
      src = out;
    }
    return src;
  }
  // تنعيم أفقي فقط (يجعل بقع الطوب الظاهر عريضة مثل المراجع)
  function blurX(a, n, r) {
    const out = new Float32Array(n * n);
    for (let y = 0; y < n; y++) {
      let s = 0;
      for (let k = -r; k <= r; k++) s += a[y * n + ((k % n) + n) % n];
      for (let x = 0; x < n; x++) { out[y * n + x] = s / (2 * r + 1); s += a[y * n + (x + r + 1) % n] - a[y * n + ((x - r) % n + n) % n]; }
    }
    return out;
  }
  const at = (a, n, x, y) => a[(((y % n) + n) % n) * n + (((x % n) + n) % n)];

  // خريطة اتجاهات السطح من خريطة الارتفاع
  function normalFrom(h, n, strength) {
    const out = new Uint8Array(n * n * 4);
    for (let y = 0; y < n; y++) for (let x = 0; x < n; x++) {
      const dx = (at(h, n, x + 1, y) - at(h, n, x - 1, y)) * strength;
      const dy = (at(h, n, x, y + 1) - at(h, n, x, y - 1)) * strength;
      // الصف 0 = v=0 (أسفل الخامة) — y في الصورة يزيد مع الارتفاع
      const nx = -dx, ny = -dy, nz = 1, l = Math.hypot(nx, ny, nz);
      const i = (y * n + x) * 4;
      out[i] = (nx / l * 0.5 + 0.5) * 255; out[i + 1] = (ny / l * 0.5 + 0.5) * 255; out[i + 2] = (nz / l * 0.5 + 0.5) * 255; out[i + 3] = 255;
    }
    return out;
  }
  function pack(rgb, n) {
    const out = new Uint8Array(n * n * 4);
    for (let i = 0; i < n * n; i++) { out[i * 4] = clamp(rgb[i * 3], 0, 255); out[i * 4 + 1] = clamp(rgb[i * 3 + 1], 0, 255); out[i * 4 + 2] = clamp(rgb[i * 3 + 2], 0, 255); out[i * 4 + 3] = 255; }
    return out;
  }

  // ألوان مأخوذة من برج الطين في مفاتيح (sRGB)
  const PLASTER = [200, 124, 60], PLASTER_HI = [214, 140, 74], BRICK = [168, 94, 40], SHADOW = [112, 56, 20];

  // لياسة طين سقطت في أماكن فظهر الطوب تحتها. الخامة تغطي 4 أمتار، والطوب نحو 28 × 9 سم
  function mudWall(n, seed, o) {
    o = o || {};
    const metres = 4, px = n / metres, rng = AA.rng(seed);
    const bh = Math.max(3, Math.round(0.09 * px)), bw = Math.max(6, Math.round(0.28 * px)), mt = Math.max(1, Math.round(n / 512));
    const fine = tileNoise(n, seed + 7, [32, 64, 128, Math.min(256, n / 2)], 1.3);
    const big = tileNoise(n, seed + 1, [4, 8, 16, 32, 64], 1.7);
    const mid = tileNoise(n, seed + 2, [16, 32, 64, 128], 1.4);
    const pits = tileNoise(n, seed + 11, [Math.min(128, n / 4), Math.min(256, n / 2)], 1.1);
    const lumps = blur(tileNoise(n, seed + 13, [8, 16, 32, 64], 1.45), n, Math.max(1, Math.round(n / 340)));
    let mask = tileNoise(n, seed + 3, [8, 16, 32, 64, 128], 1.35);
    mask = blurX(mask, n, Math.round(n / 50));
    { let mn = 1, mx = 0; for (const v of mask) { mn = Math.min(mn, v); mx = Math.max(mx, v); } for (let i = 0; i < mask.length; i++) mask[i] = (mask[i] - mn) / (mx - mn); }
    const tints = []; for (let i = 0; i < 4096; i++) tints.push(rng());
    const rgb = new Float32Array(n * n * 3), hgt = new Float32Array(n * n), hole = new Uint8Array(n * n);
    const exposure = o.exposure == null ? 1 : o.exposure;
    for (let y = 0; y < n; y++) {
      const row = Math.floor(y / bh), off = (row % 2) * (bw >> 1) + (row * 37) % 11;
      const ly = y % bh, v = y / n, foot = Math.pow(clamp(1 - v / 0.22, 0, 1), 1.5);
      for (let x = 0; x < n; x++) {
        const i = y * n + x, col = Math.floor((x + off) / bw), lx = (x + off) % bw;
        const isHole = mask[i] < (0.33 + 0.2 * foot) * exposure;
        hole[i] = isHole ? 1 : 0;
        let r, gg, b, h;
        if (isHole) {
          const mortar = ly < mt || lx < mt;
          if (mortar) { r = SHADOW[0]; gg = SHADOW[1]; b = SHADOW[2]; h = 0.15; }
          else {
            const bt = tints[(row * 131 + col * 17) & 4095];
            const k = (0.86 + 0.2 * bt) * (0.9 + 0.14 * fine[i]) * (ly > bh - mt * 2 ? 1.12 : 1) * (ly < mt * 2 ? 0.82 : 1);
            r = (BRICK[0] + 22) * k; gg = (BRICK[1] + 22) * k; b = (BRICK[2] + 22) * k;
            h = 0.35 + 0.08 * fine[i];
          }
        } else {
          const lit = lumps[i] - at(lumps, n, x, y + Math.round(n / 200));
          const k = (0.9 + 0.14 * big[i]) * (0.95 + 0.08 * mid[i]) * (1 + 1.5 * lit) * (pits[i] > 0.78 ? 0.92 : 1);
          r = PLASTER[0] * k + 6 * (fine[i] - 0.5); gg = PLASTER[1] * k + 6 * (fine[i] - 0.5); b = PLASTER[2] * k + 6 * (fine[i] - 0.5);
          h = 0.8 + 0.25 * lumps[i] + 0.03 * fine[i] - (pits[i] > 0.78 ? 0.04 : 0);
        }
        rgb[i * 3] = r; rgb[i * 3 + 1] = gg; rgb[i * 3 + 2] = b; hgt[i] = h;
      }
    }
    // حواف اللياسة: ظل على الطوب تحت الحافة
    const sd = Math.max(1, Math.round(n / 500));
    for (let y = 0; y < n; y++) for (let x = 0; x < n; x++) {
      const i = y * n + x;
      if (hole[i] && !at(hole, n, x, y + sd * 2)) for (let k = 0; k < 3; k++) rgb[i * 3 + k] *= 0.68;
      if (!hole[i] && at(hole, n, x, y - sd)) for (let k = 0; k < 3; k++) rgb[i * 3 + k] += 22;
    }
    // شقوق دقيقة
    for (let c = 0; c < Math.round(22 * n / 1024) + 6; c++) {
      let x = rng() * n, y = rng() * n, a = rng() * Math.PI;
      const steps = 6 + Math.floor(rng() * 9), seg = n / 140;
      for (let s = 0; s < steps; s++) {
        a += (rng() - 0.5) * 1.0;
        for (let t = 0; t < seg; t++) {
          x += Math.cos(a); y += Math.sin(a);
          const i = (((Math.round(y) % n) + n) % n) * n + (((Math.round(x) % n) + n) % n);
          if (hole[i]) continue;
          rgb[i * 3] = SHADOW[0]; rgb[i * 3 + 1] = SHADOW[1]; rgb[i * 3 + 2] = SHADOW[2]; hgt[i] -= 0.08;
        }
      }
    }
    return { size: n, albedo: pack(rgb, n), normal: normalFrom(hgt, n, n / 64), repeat: metres };
  }

  // لياسة ناعمة لأعلى الجدران والسلالم
  function mudTop(n, seed) {
    const big = tileNoise(n, seed, [4, 8, 16, 32, 64], 1.7), fine = tileNoise(n, seed + 1, [32, 64, 128], 1.3);
    const rgb = new Float32Array(n * n * 3), h = new Float32Array(n * n);
    for (let i = 0; i < n * n; i++) {
      const k = (0.86 + 0.14 * big[i]) * (0.95 + 0.07 * fine[i]);
      rgb[i * 3] = PLASTER_HI[0] * k; rgb[i * 3 + 1] = PLASTER_HI[1] * k; rgb[i * 3 + 2] = PLASTER_HI[2] * k;
      h[i] = big[i] * 0.6 + fine[i] * 0.2;
    }
    return { size: n, albedo: pack(rgb, n), normal: normalFrom(h, n, n / 160), repeat: 2 };
  }

  // جص أبيض (الشرفات البيضاء)
  function gypsum(n, seed) {
    const big = tileNoise(n, seed, [4, 8, 16, 32], 1.6), fine = tileNoise(n, seed + 1, [32, 64, 128], 1.3);
    const rgb = new Float32Array(n * n * 3), h = new Float32Array(n * n);
    for (let i = 0; i < n * n; i++) {
      const k = (0.9 + 0.08 * big[i]) * (0.97 + 0.05 * fine[i]);
      rgb[i * 3] = 238 * k; rgb[i * 3 + 1] = 230 * k; rgb[i * 3 + 2] = 216 * k;
      h[i] = big[i] * 0.5 + fine[i] * 0.3;
    }
    return { size: n, albedo: pack(rgb, n), normal: normalFrom(h, n, n / 180), repeat: 2 };
  }

  // خشب أثل: عروق طولية (الخامة تغطي متراً)
  function wood(n, seed) {
    const g0 = tileNoise(n, seed, [4, 8, 16], 1.5), f = tileNoise(n, seed + 3, [64, 128], 1.2), rng = AA.rng(seed);
    const rgb = new Float32Array(n * n * 3), h = new Float32Array(n * n);
    for (let y = 0; y < n; y++) for (let x = 0; x < n; x++) {
      const i = y * n + x;
      const grain = 0.5 + 0.5 * Math.sin((x / n * 6 + g0[i] * 5) * Math.PI * 2);
      const k = (0.78 + 0.27 * grain) * (0.94 + 0.12 * f[i]);
      rgb[i * 3] = 118 * k; rgb[i * 3 + 1] = 80 * k; rgb[i * 3 + 2] = 50 * k;
      h[i] = grain * 0.6 + f[i] * 0.4;
    }
    return { size: n, albedo: pack(rgb, n), normal: normalFrom(h, n, n / 200), repeat: 1 };
  }

  // باب نجدي ملوّن: ألواح، صفوف مثلثات، معيّنات ونقاط بيضاء (الخامة تغطي الباب كاملاً)
  function najdiDoor(n, seed) {
    const W = n >> 1, H = n; // نصف عرض: الباب أطول من عرضه
    const nz = tileNoise(n, seed, [4, 8, 16, 32], 1.6);
    const rgb = new Float32Array(n * n * 3), h = new Float32Array(n * n);
    const sx = n / 256, sy = n / 512; // مقياس رسم النسخة الأصلية 256×512 إلى مربع n×n
    const RED = [196, 64, 52], YEL = [232, 184, 75], TEAL = [42, 140, 135], WHITE = [244, 237, 224];
    const put = (i, c) => { rgb[i * 3] = c[0]; rgb[i * 3 + 1] = c[1]; rgb[i * 3 + 2] = c[2]; h[i] += 0.15; };
    for (let y = 0; y < n; y++) for (let x = 0; x < n; x++) {
      const i = y * n + x, k = 0.85 + 0.2 * nz[i];
      const plank = (x / sx) % 32 < 2;
      const c = plank ? [86, 58, 38] : [126 * k, 86 * k, 56 * k];
      rgb[i * 3] = c[0]; rgb[i * 3 + 1] = c[1]; rgb[i * 3 + 2] = c[2]; h[i] = plank ? 0 : 0.5;
    }
    const inTri = (px, py, ax, ay, bx, by, cx, cy) => {
      const d = (by - cy) * (ax - cx) + (cx - bx) * (ay - cy);
      const l1 = ((by - cy) * (px - cx) + (cx - bx) * (py - cy)) / d, l2 = ((cy - ay) * (px - cx) + (ax - cx) * (py - cy)) / d;
      return l1 >= 0 && l2 >= 0 && l1 + l2 <= 1;
    };
    for (let y = 0; y < n; y++) for (let x = 0; x < n; x++) {
      const X = x / sx, Y = (n - 1 - y) / sy, i = y * n + x;
      for (const [ty, col] of [[30, RED], [150, YEL], [330, TEAL], [460, RED]]) {
        if (Y < ty || Y > ty + 14) continue;
        const k = Math.floor((X - 6) / 24), x0 = 6 + k * 24;
        if (k >= 0 && x0 < 246 && inTri(X, Y, x0, ty + 14, x0 + 10, ty, x0 + 20, ty + 14)) put(i, col);
      }
      for (const cy of [100, 250, 400]) for (const cx of [64, 192]) {
        const d = Math.abs(X - cx) / 30 + Math.abs(Y - cy) / 36;
        if (d <= 1 && d > 0.85) put(i, YEL);
        if (Math.abs(X - cx) / 13 + Math.abs(Y - cy) / 16 <= 1) put(i, TEAL);
        if (Math.hypot(X - cx, Y - cy) < 4) put(i, WHITE);
      }
      for (const dy of [192, 372]) { const cx = 12 + Math.round((X - 12) / 20) * 20; if (Math.hypot(X - cx, Y - dy) < 3.2) put(i, WHITE); }
    }
    return { size: n, albedo: pack(rgb, n), normal: normalFrom(h, n, n / 100), repeat: 1, aspect: [W, H] };
  }

  const GEN = { mud_wall: mudWall, mud_wall_worn: (n, s) => mudWall(n, s, { exposure: 1.5 }), mud_top: mudTop, gypsum, wood, najdi_door: najdiDoor };
  const SIZES = { high: 1024, med: 512, low: 256 };
  const cache = {};
  // AA.texture('mud_wall', 'med') — تُبنى مرة واحدة وتُشارك
  AA.texture = function (id, quality, seed) {
    const n = SIZES[quality] || 512, key = id + ':' + n + ':' + (seed || 0);
    if (!cache[key]) cache[key] = Object.assign({ id }, GEN[id](n, seed || 3));
    return cache[key];
  };
  AA.TEXTURES = Object.keys(GEN);
})(typeof window !== 'undefined' ? window : globalThis);
