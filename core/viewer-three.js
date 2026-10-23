// Aboden Assets — core/viewer-three.js
// الطبقة الرقيقة الخاصة بـ Three.js فقط: تحوّل بيانات الأصل إلى شبكات، وتضيف الرياح في كرت الشاشة.
// عند النقل لمحرك آخر يُكتب ملف مقابل لهذا (Godot: viewer-godot.gd، Roblox: viewer-roblox.lua).
(function (g) {
  'use strict';
  const AA = g.AA;
  const T = g.THREE;
  const three = AA.three = {};

  three.uniforms = {
    uTime: { value: 0 }, uWind: { value: 0.55 },
    uDir: { value: new T.Vector2(0.95, 0.31).normalize() }
  };

  const WIND_HEAD = `#include <common>
attribute float aSway; attribute float aPhase; attribute float aFlutter; attribute float aBend;
uniform float uTime; uniform float uWind; uniform vec2 uDir;`;
  const WIND_BODY = `vec3 transformed = vec3(position);
vec3 wdW = vec3(uDir.x, 0.0, uDir.y);
vec3 wdO = normalize(vec3(dot(modelMatrix[0].xyz, wdW), dot(modelMatrix[1].xyz, wdW), dot(modelMatrix[2].xyz, wdW)));
float gust = 0.65 + 0.35*sin(uTime*0.41)*sin(uTime*0.17+1.3);
float w = uWind*gust;
transformed += wdO * aBend * w * (0.55 + 0.45*sin(uTime*0.8));
float sw = aSway*w;
transformed += wdO * sw * (0.45 + 0.35*sin(uTime*1.6 + aPhase));
transformed.y += sw*0.18*sin(uTime*2.1 + aPhase*1.7);
transformed.y += aFlutter*w*0.035*sin(uTime*9.0 + aPhase*5.0 + position.x*4.0 + position.z*3.0);`;

  three.addWind = function (mat) {
    mat.onBeforeCompile = sh => {
      Object.assign(sh.uniforms, three.uniforms);
      sh.vertexShader = sh.vertexShader.replace('#include <common>', WIND_HEAD).replace('#include <begin_vertex>', WIND_BODY);
    };
    return mat;
  };
  let depthMat = null;
  three.depthMaterial = function () {
    if (!depthMat) depthMat = three.addWind(new T.MeshDepthMaterial({ depthPacking: T.RGBADepthPacking, side: T.DoubleSide }));
    return depthMat;
  };

  const toLinear = c => c <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4);

  // يبني الشبكات من بيانات الأصل (مرة واحدة) — يمكن مشاركتها بين نسخ كثيرة
  // خامات الكود → خامات Three (تُبنى مرة وتُشارك)
  const texCache = {};
  three.anisotropy = 4;
  three.texture = function (id, q) {
    const key = id + ':' + q;
    if (texCache[key]) return texCache[key];
    const t = AA.texture(id, q);
    const mk = (data, srgb) => {
      const tx = new T.DataTexture(data, t.size, t.size, T.RGBAFormat);
      tx.wrapS = tx.wrapT = T.RepeatWrapping; tx.generateMipmaps = true;
      tx.minFilter = T.LinearMipmapLinearFilter; tx.magFilter = T.LinearFilter; tx.anisotropy = three.anisotropy;
      if (srgb) tx.encoding = T.sRGBEncoding;
      tx.needsUpdate = true; return tx;
    };
    return (texCache[key] = { map: mk(t.albedo, true), normal: mk(t.normal, false) });
  };

  three.build = function (out, quality) {
    const parts = [];
    for (const name in out.parts) {
      const d = out.parts[name];
      const geo = new T.BufferGeometry();
      geo.setAttribute('position', new T.BufferAttribute(d.positions, 3));
      geo.setAttribute('normal', new T.BufferAttribute(d.normals, 3));
      const lin = new Float32Array(d.colors.length);
      for (let i = 0; i < lin.length; i++) lin[i] = toLinear(d.colors[i]);
      geo.setAttribute('color', new T.BufferAttribute(lin, 3));
      geo.setAttribute('aSway', new T.BufferAttribute(d.sway, 1));
      geo.setAttribute('aPhase', new T.BufferAttribute(d.phase, 1));
      geo.setAttribute('aFlutter', new T.BufferAttribute(d.flutter, 1));
      geo.setAttribute('aBend', new T.BufferAttribute(d.bend, 1));
      if (d.uvs) geo.setAttribute('uv', new T.BufferAttribute(d.uvs, 2));
      geo.setIndex(new T.BufferAttribute(d.indices, 1));
      geo.computeBoundingSphere();
      geo.boundingSphere.radius += 1.2; // هامش لحركة الريح حتى لا يختفي الشكل عند حافة الشاشة
      const m = d.material || {};
      const opts = { vertexColors: true, roughness: m.roughness == null ? 0.8 : m.roughness, side: m.doubleSided ? T.DoubleSide : T.FrontSide };
      if (m.color) opts.color = new T.Color(m.color[0], m.color[1], m.color[2]);
      if (m.texture) { const tx = three.texture(m.texture, quality || 'med'); opts.map = tx.map; opts.normalMap = tx.normal; }
      const mat = three.addWind(new T.MeshStandardMaterial(opts));
      parts.push({ name, geo, mat, kind: m.kind });
    }
    return { parts, triangles: out.triangles, meta: out.meta };
  };

  three.instance = function (built) {
    const grp = new T.Group();
    for (const p of built.parts) {
      const mesh = new T.Mesh(p.geo, p.mat);
      mesh.castShadow = true; mesh.receiveShadow = p.kind !== 'fruit' && p.kind !== 'flower';
      mesh.customDepthMaterial = three.depthMaterial();
      grp.add(mesh);
    }
    return grp;
  };

  three.dispose = function (built) {
    for (const p of built.parts) { p.geo.dispose(); p.mat.dispose(); }
  };
})(typeof window !== 'undefined' ? window : globalThis);
