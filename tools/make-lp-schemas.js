// يولّد lowpoly/lp-schemas.js: نفس المعاملات والقوالب والحركات وأسماء أصول الحزمة الواقعية،
// حتى تقبل أصول لو-بولي نفس المشاهد والإعدادات (الأصل lp_X يطابق X).
const fs = require('fs'), path = require('path');
const AA = require('./checks/load.js');
const out = {};
for (const [id, a] of Object.entries(AA.assets)) {
  if (id.startsWith('lp_')) continue;
  out[id] = { name: a.name, nameEn: a.nameEn, category: a.category, schema: a.schema, presets: a.presets || {}, clips: a.clips || null };
}
const src = '// مولَّد بـ tools/make-lp-schemas.js — لا تعدّله يدوياً\n(function (g) {\n  g.AA.lpSchemas = ' + JSON.stringify(out) + ';\n})(typeof window !== \'undefined\' ? window : globalThis);\n';
fs.writeFileSync(path.join(__dirname, '..', 'lowpoly', 'lp-schemas.js'), src);
console.log('lp-schemas.js', Object.keys(out).length, 'assets', src.length, 'bytes');
