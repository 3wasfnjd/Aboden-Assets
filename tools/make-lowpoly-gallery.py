# يبني lowpoly/index.html من معرض الحزمة الواقعية (index.html) بنفس الكود، مع سكربتات ومشاهد حزمة لو-بولي
import re, os
R = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
src = open(os.path.join(R, 'index.html'), encoding='utf-8').read()
# السكربتات: الأساس + ملفات الحزمة فقط
core = ['core/math.js', 'core/builder.js', 'core/tree.js', 'core/texture.js', 'core/mud.js', 'core/skeleton.js']
lp = sorted(f for f in os.listdir(os.path.join(R, 'lowpoly')) if f.startswith('lp-') and f.endswith('.js'))
lp = ['lp-schemas.js', 'lp-core.js'] + [f for f in lp if f not in ('lp-core.js', 'lp-schemas.js')]
tags = '\n'.join(f'<script src="../{c}"></script>' for c in core) + '\n' + '\n'.join(f'<script src="{f}"></script>' for f in lp) + '\n<script src="../core/viewer-three.js"></script>'
a = src.index('<script src="core/math.js"></script>'); b = src.index('<script src="core/viewer-three.js"></script>') + len('<script src="core/viewer-three.js"></script>')
src = src[:a] + tags + src[b:]
# العنوان والوصف والتبويبات
src = src.replace('<title>مستودع عبودين</title>', '<title>عبودين لو-بولي</title>')
src = src.replace('عبودين قيمز · مستودع الأصول', 'عبودين قيمز · حزمة لو-بولي')
src = re.sub(r'<p>كل أصل هنا مبني بالكود[^<]*</p>', '<p>نفس أصول المستودع ونفس المشاهد بأسلوب لو-بولي: أوجه مسطحة وألوان صريحة وعدد مثلثات قليل جداً، والشخصيات تشيبي. كل أصل هنا له نفس معاملات الأصل الواقعي المقابل.</p>', src)
# المشاهد: نفس مشاهد الحزمة الواقعية، وكل أصل X يُستبدل بنظيره lp_X (ويُتجاهل ما ليس له نظير بعد)
a = src.index('let ENTRIES = [];')
remap = """// حزمة لو-بولي: كل أصل في المشاهد يُستبدل بنظيره lp_
for (const s of Object.values(SCENES)) s.entries = s.entries.map(e => Object.assign(e, { id: 'lp_' + e.id.replace(/^lp_/, '') })).filter(e => A[e.id]);
"""
src = src[:a] + remap + src[a:]
src = src.replace("e.id === 'palm'", "e.id === 'lp_palm'")
src = src.replace("A.najdi_house.generate(AA.params(A.najdi_house, over)", "A.lp_najdi_house.generate(AA.params(A.lp_najdi_house, over)")
# الأرض: مثلثات كبيرة مسطحة بدون خامة
src = src.replace("const g = new T.PlaneGeometry(180, 180, 220, 220); g.rotateX(-Math.PI / 2);", "const g = new T.PlaneGeometry(180, 180, 60, 60).toNonIndexed(); g.rotateX(-Math.PI / 2);")
src = re.sub(r"const m = new T\.Mesh\(g, X\.style === 'toon'[\s\S]*?\}\)\);", "const m = new T.Mesh(g, new T.MeshStandardMaterial({ vertexColors: true, roughness: 1, flatShading: true }));", src, count=1)
src = src.replace("const a = lin('#dcbc8c'), b = lin('#c9a36e'),", "const a = lin('#ecc993'), b = lin('#ddb075'),")
open(os.path.join(R, 'lowpoly', 'index.html'), 'w', encoding='utf-8').write(src)
print('lowpoly/index.html', len(src))
