import re, os
import os; ROOT=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # the kit's root (this file is tools/gen_docs.py)
cat=open(ROOT+'/addons/aboden_blaster/shot_catalog.gd').read()
# SHOT_STYLE numbers
ss={}
block=cat[cat.index('const SHOT_STYLE := {'):]
block=block[:block.index('\n}\n')]
for m in re.finditer(r'"(\w+)": \{([^}]*)\}', block):
    d={}
    for kv in re.finditer(r'"(\w+)": ([\w.\-]+)', m.group(2)):
        d[kv.group(1)]=kv.group(2)
    ss[m.group(1)]=d
def const(name):
    return re.search(r'const %s := ([^\n]+)'%name, cat).group(1)
ss['dallah']['sk']=const('DALLAH_FIRE_K')
shots={}
sb=cat[cat.index('const SHOTS := {'):]
sb=sb[:sb.index('\n}\n')]
for m in re.finditer(r'\t"(\w+)": \{(.*?)\},?\n(?=\t"|$)', sb+'\n', re.S):
    body=m.group(2)
    d={}
    for kv in re.finditer(r'"(\w+)": ("([^"]*)"|\[[^\]]*\]|\d+)', body):
        v=kv.group(2)
        d[kv.group(1)]=kv.group(3) if kv.group(3) is not None else v
    shots[m.group(1)]=d
ORDER=eval(const('ORDER'))
assert len(shots)==22, shots.keys()
RES=re.findall(r'"(AB-W-\d+)": \["([^"]*)", "([^"]*)", "(\w+)"\]', cat[cat.index('const RESERVED'):cat.index('}',cat.index('const RESERVED'))])
assert len(RES)==0, RES  # every reserved code is a weapon since v1.2
UNL=dict(re.findall(r'"(\w+)": "(\w*)"', cat[cat.index('const SHOT_UNLOCKS'):cat.index('}',cat.index('const SHOT_UNLOCKS'))]))
CH={}
cb=cat[cat.index('const CHALLENGES := {'):]
cb=cb[:cb.index('\n}\n')]
for m in re.finditer(r'"(\w+)": \[(\d+), "([^"]*)", "([^"]*)", "(\w+)"\]', cb):
    CH[m.group(1)]=(int(m.group(2)),m.group(3),m.group(4),m.group(5))

PARAM={
 'speed':('السرعة الابتدائية','م/ث'),
 'grav':('الجاذبية (مضاعف g = 9.8 م/ث²؛ السالب يطفو)','× g'),
 'life':('العمر الأقصى','ث'),
 'r':('نصف قطر الإصابة','م'),
 'cool':('أقل فاصل بين طلقتين لليد نفسها (معدل الإطلاق عند الضغط المستمر)','ث'),
 'sk':('قيمة k لصوت الإطلاق (الشدة/الطبقة)','—'),
 'burst':('نصف قطر الانفجار (يفرقع ما حوله)','م'),
 'pellets':('عدد الأجسام في الطلقة (كرات، قطرات، قنابل صغيرة)','عدد'),
 'cone':('نصف زاوية المخروط','راديان'),
 'bounces':('أقصى عدد ارتدادات (1000000000 = بلا حد)','عدد'),
 'pops':('أقصى عدد إصابات قبل أن تتوقف (1000000000 = بلا حد)','عدد'),
 'range':('المدى','م'),
 'pierce':('أقصى عدد أهداف يخترقها الشعاع','عدد'),
 'reach':('أبعد مسافة يبلغها أمامك','م'),
 'swing':('الانحراف الجانبي للمسار','م'),
 'splat':('نصف قطر الرذاذ','م'),
 'turn':('سرعة الالتفاف نحو الهدف','راديان/ث'),
 'seek':('مدى البحث عن هدف','م'),
 'chain':('أقصى عدد أهداف في السلسلة','عدد'),
 'hop':('أبعد قفزة بين هدفين','م'),
 'spray':('الفاصل بين حبتي بن','ث'),
 'dive':('على هذا البعد من فريسته يصيح وينقضّ (أسرع وأحدّ التفافًا)','م'),
 'frost':('مدة التجميد التي تُعطى للمضيف (`blaster_freeze`)','ث'),
 'linger':('مدة البقاء بعد الاستقرار (هنا `life` هو زمن الطيران قبل الاستقرار)','ث'),
 'field':('نصف قطر الجذب','م'),
 'tug':('سرعة السحب نحو النقطة (`blaster_pull`)','م/ث'),
 'cloud':('نصف قطر سحابة الدخان','م'),
 'slow':('معامل السرعة داخل السحابة (`blaster_slow`)','× السرعة'),
 'drag':('مدة سحب ما التقطه','ث'),
 'push':('السرعة التي تعطيها كل قطرة للهدف (`blaster_push`)','م/ث'),
 'shove':('دفع كل قطرة للهدف إن لم يكن إلا `blaster_pull`','م'),
 'ahead':('بعد مركز الفقاعة أمام اليد (و`r` نصف قطرها)','م'),
}
IDEA={
 'AB-W-013':('موجّهة، مرتدّة/عائدة','صقر منخفض المضلعات يحلّق ويختار هدفًا لا يلاحقه غيره (بحث الصاروخ نفسه)، ينقضّ عليه ثم يعود إلى اليد ويُلتقط؛ أبطأ من الصاروخ، cool ≈ 1.2 ث، عمر ≈ 4 ث، جناحان يرفرفان، صوت whoosh وصيحة قصيرة.'),
 'AB-W-014':('فورية/شعاع','شعاع جليدي قصير فوري كالليزر (cool ≈ 0.5 ث) يجمّد الأهداف ≈ 3 ث عبر نداء اختياري جديد `blaster_freeze(target, seconds)`؛ بريق صقيع، شعاع أزرق ثلجي، صوت تكسّر جليد.'),
 'AB-W-015':('منطقة تأثير/انفجار','كرة بطيئة تتوقف بعد ≈ 0.8 ث، تجذب الأهداف الناعمة القريبة ≈ 1.5 ث عبر `blaster_pull(target, to, strength)`، ثم تنفجر للداخل وتفرقع ما في نصف قطرها؛ دوامة داكنة بحافة بنفسجية، صوت «ووومب» عميق.'),
 'AB-W-016':('رشّ/متعدد','رشاش يطلق حبات تمر بسرعة.'),
 'AB-W-017':('منطقة تأثير/انفجار','مبخرة تترك سحابة دخان بخور تُبطئ الأهداف فيها (منطقة باقية).'),
 'AB-W-018':('موجّهة','حبل شماغ يلتقط الهدف ويسحبه نحوك.'),
 'AB-W-019':('فورية/شعاع','خرطوم ماء: تيار متصل يدفع الأهداف.'),
 'AB-W-020':('منطقة تأثير/انفجار، رشّ/متعدد','قنبلة تنفجر إلى قنابل صغيرة تتناثر وتنفجر.'),
 'AB-W-021':('موجّهة','مغناطيس يجذب القذائف أو الأهداف المعدنية نحو نقطة.'),
 'AB-W-022':('دفاع','فقاعة درع تحمي اللاعب وتصد القذائف مدة قصيرة.'),
}
CAT={'direct':'قذيفة مباشرة (direct)','ballistic':'باليستية (ballistic)','instant':'فورية/شعاع (instant)','area':'منطقة تأثير/انفجار (area)',
 'homing':'موجّهة (homing)','returning':'مرتدّة/عائدة (returning)','spray':'رشّ/متعدد (spray)','bouncing':'ارتداد/نطّ (bouncing)',
 'defence':'دفاع/حماية (defence)'}
AX={'projectile':'قذيفة (projectile)','hitscan':'شعاع فوري (hitscan)','area':'منطقة (area)',
 'straight':'مستقيم (straight)','ballistic':'قوسي (ballistic)','homing':'موجّه (homing)','returning':'عائد (returning)','floating':'طافٍ (floating)',
 'held':'مع اليد (held)',
 'single':'هدف واحد (single)','pierce':'اختراق (pierce)','chain':'تسلسل (chain)','splash':'انفجار/رذاذ (splash)','bounce':'ارتداد (bounce)',
 'called':'ضربة مُستدعاة (called)','lofted':'قوس عالٍ وعودة للغلاف (lofted)','waypoints':'نقاط مسار (waypoints)','vertical':'من الأعلى (vertical)','intercept':'اعتراض (intercept)',
 'falloff':'تناقص الضرر (falloff)','lingering':'منطقة باقية (lingering)','attack':'هجوم (attack)','defence':'دفاع/اعتراض (defence)','support':'إسناد (support)','scan':'كشف واستطلاع (scan)'}
TIER=['0 أساسي (Starter)','1 سهل (Easy)','2 متوسط (Medium)','3 متقدم (Advanced)','4 نخبة (Elite)']
SND={'pew':'pew — طلقة (3 نسخ عشوائية)','thump':'thump — ارتطام بجسم صلب لا يُحتسب (k 0.25)','whoosh':'whoosh — اندفاع (k = الشدة: 0.2…1.0)',
 'start_pop':'start_pop — فرقعة','firework_launch':'firework_launch — انطلاق صاروخ ناري (3 نسخ بالتناوب)','firework_burst':'firework_burst — تفتّح الألعاب النارية (3 نسخ بالتناوب)',
 'swish':'swish — صفير (3 نسخ)','squeak':'squeak — صرير مطاطي (k = الطبقة: 0.7…1.35)','bricks_tink':'bricks_tink — رنّة (k = الشدة 0…1)',
 'splash':'splash — رشّة ماء (k 0.75، 3 نسخ)','boom':'boom — انفجار (3 نسخ)','cans_clang':'cans_clang — قرقعة صاعقة (k 1.0، 3 نسخ)',
 'fair_ding':'fair_ding — رنين دلّة (k = مستوى الصوت: 0.3 عند الإطلاق، 0.22 عند الانسكاب؛ لا يتكرر أسرع من كل 0.3 ث)',
 # v1.2: synthesised by tools/gen_sounds.py; k is the level (1 = as rendered).
 'flap':'flap — رفرفة جناحين: ضربتان أو ثلاث من هواء مكتوم (3 نسخ؛ k = المستوى؛ عند الإطلاق 0.6 وعند الالتقاط 0.5)',
 'screech':'screech — صيحة صقر قصيرة «كيي-ير» عند الانقضاض (نسختان، k 0.8)',
 'ice_zap':'ice_zap — طلقة زجاجية هابطة ببريق (3 نسخ، k 0.6)',
 'ice_crack':'ice_crack — تكسّر جليد: نقرات حادة وطقطقة ورنين (3 نسخ، k 0.8)',
 'whoomp':'whoomp — شهيق يعلو ثم ضربة عميقة هابطة: الانفجار للداخل (نسختان)',
 'put':'put — «بت» ناعمة مكتومة مع كل حبة (3 نسخ، k 0.5؛ هادئة لأنها 10 في الثانية)',
 'ember':'ember — طقطقة جمر وأزيز خافت حين تستقر المبخرة (k 0.9)',
 'snap':'snap — فرقعة حبل كالسوط وضربة منخفضة عند الالتقاط (3 نسخ)',
 'hose_hiss':'hose_hiss — فحيح تيار ماء يقرقر (3 نسخ، k 0.5؛ لا يتكرر أسرع من كل 0.12 ث)',
 'cluster_pop':'cluster_pop — فرقعة كرتونية وانفجار قصير لقنبلة صغيرة (3 نسخ، k 0.8؛ لا يتكرر أسرع من كل 0.06 ث)',
 'zing':'zing — رنين معدني ينزلق مع طنين كهربائي (نسختان، k 0.6)',
 'shield_up':'shield_up — وتر صاعد متلألئ حين تنفتح الفقاعة (k 0.6)',
 'shield_block':'shield_block — «بوونغ» رنان وضربة خفيفة عند صدّ قذيفة (3 نسخ، k 0.9)'}

W={}
W['bolt']=dict(
 beh='''طلقة مستقيمة سريعة جدًا بلا جاذبية. تنطلق من الفوهة (0.08 م أمام اليد) وتتوقف عند أول ما يقابلها: هدف ناعم (soft target) تفرقعه، أو هدف المسرح (`shoot()` يقرر)، أو جسم صلب، أو جدار المضيف، أو الأرض — أو بعد انتهاء عمرها. عند التوقف: رشّة شرر صغيرة مع وميض (`impact`).''',
 vis='''- **المجسم:** رأس أبيض متوهج (كرة 0.013 م، `head` غير مضاء) داخل هالة كهرمانية (كرة 0.03 م، `bolt_glow` ‎#ffb547 شفافية 0.55 بمزج إضافي)، وخلفه ذيلان مخروطيان: 0.52 م (`bolt_glow`) و0.42 م (`trail` ‎#ffe9a8). يتجه الرأس على اتجاه الطيران.
- **الأثر:** شرارات ‎#ffe9a8 صغيرة (0.006 م، عمر 0.16 ث) بنسبة 50% في كل إطار.
- **وميض الفوهة:** ‎#ffe9b0 بحجم 0.07 م.
- **الإصابة:** `impact()` — وميض أبيض ‎#fffaf2 و8 شرارات (‎#ffd27a عند الاحتساب، أبيض عند عدمه).''',
 tune='السرعة 45 م/ث تجعل المدى الفعلي ≈ 54 م (speed × life). لتقصير المدى قلّل `life`. `cool` = 0.12 ث يعني ≈ 8 طلقات في الثانية لكل يد.',
 tests=['shots: every style fires with its sound','shots: every style keeps its cooldown, per hand','shots: every style pops a soft target','shots: every style hits a stage target','walls: a bolt stops at the host\'s wall','shots: sizes and speeds scale with blaster_scale()','signals: shot_fired and shot_hit'])
W['mini']=dict(
 beh='''كرات صغيرة ملوّنة تُقذف بقوس الجاذبية الكاملة وتتشقلب. لا تتوقف عند الهدف الناعم: تفرقعه وتكمل بسرعة أبطأ (× 0.6). ترتد عن الأجسام الصلبة (تعكس نصف السرعة العمودية) وعن الأرض (× 0.45 إن كانت سريعة، وإلا تتدحرج مع احتكاك 0.55^dt). تتوقف فقط عند هدف مسرح يحتسب الإصابة أو عند انتهاء عمرها 3.2 ث. على جدران المضيف تأخذ الموقع والسرعة اللذين يعيدهما `blaster_collide`.''',
 vis='''- **المجسم:** كرة صغيرة (16×12 مقطعًا) يرسمها `shot_crowd` بدفعات MultiMesh، كل طلقة بالمظهر التالي من `MINI_STYLES` (jelly هلامية بلاصقة، fur فرو بشريطة، bubble فقاعة، clay صلصال، fabric قماش) ولون عشوائي من `MINI_COLORS` (أو لون المظهر نفسه `STYLE_COLORS`). لكل كرة حجمها (0.8–1.3 × r) ومحور تشقلب وتمطّط (±8%).
- **المواد:** الجلي: انكسار الضوء (`JELLY_SHADER`)، الفقاعة: غشاء صابون (`BUBBLE_SHADER`)، الفرو: نسيج `looks/fur.png`، الصلصال/القماش: StandardMaterial.
- **وميض الفوهة:** ‎#ffe9b0 بحجم 0.05 م. **الإصابة:** `impact()`.''',
 tune='لأنها تكمل بعد الفرقعة، عدد الأهداف لكل طلقة يحده العمر فقط. لجعلها تتوقف عند أول هدف اجعل `_on_pop` يرجع true لها.',
 tests=['shots: every style fires with its sound','shots: every style pops a soft target','shots: every style hits a stage target'])
W['bubble']=dict(
 beh='''فقاعات صابون بطيئة (4.2 م/ث) بجاذبية سالبة صغيرة (‎−0.06 g) فتصعد قليلًا، وتتمايل جانبيًا (تسارع جيبي 0.25 م/ث²). نصف قطرها كبير (0.06 م) فتصيب بسهولة. تتوقف عند أول هدف أو جسم، وإن انتهى عمرها (3.6 ث) دون أن تصيب تفرقع بصوت `start_pop`.''',
 vis='''- **المجسم:** كرة فقاعة (`BUBBLE_SHADER`: غشاء متلوّن يدور، نقاط بيضاء، حافة لامعة، شفافية) يرسمها `shot_crowd`. اللون من `BUBBLE_TINTS` يمتزج 60% مع لون غشاء يتغير مع الزمن، وتتمطّط (±12%).
- **لا وميض فوهة** واهتزاز اليد خفيف (0.12).
- **الإصابة:** `impact()`.''',
 tune='`grav` السالب هو ما يجعلها تطفو؛ اجعله 0 لتطير مستقيمة. التمايل ثابت في `_move` (0.25 × k).',
 tests=['shots: every style fires with its sound','shots: every style pops a soft target','shots: every style hits a stage target'])
W['firework']=dict(
 beh='''صاروخ ناري بقوس خفيف (0.35 g) ينفجر في السماء بعد 0.85 ث أو عند أول إصابة/ارتطام، فيتفتّح ويفرقع كل ما في نصف قطر 0.55 م (`pop_radius`). كل ما يصيبه الانفجار يُحتسب عبر `blaster_credit("firework", n)`.''',
 vis='''- **المجسم:** نواة برتقالية (0.017 م، `rocket` ‎#ffb347) في هالة (0.04 م، `fw_glow` ‎#ff9a3c إضافية).
- **الأثر:** بريق ذهبي ‎#ffd76a وجمر برتقالي ‎#ff8a3c (أحيانًا أبيض)، شرارتان كل إطار.
- **التفتّح (`bloom`):** وميض أبيض 0.07 م، 36 شرارة بلونين من `FIRE_COLS` تتطاير بسرعة 2.2–2.7 م/ث، و12 بريقًا أبيض.''',
 tune='`burst` يحدد قوة اللعب (منطقة التأثير)، و`life` يحدد ارتفاع/بعد التفتّح. اللون الأول لا يكون أبيض (آخر عنصر في FIRE_COLS).',
 tests=['shots: every style hits a stage target','shots: every style pops a soft target'])
W['confetti']=dict(
 beh='''مدفع قصاصات: خمس كرات في الطلقة الواحدة — واحدة في المنتصف وأربع في حلقة حولها على زاوية 0.12 راديان × (0.65–1.0) بدوران عشوائي. كل كرة قذيفة باليستية مستقلة (0.45 g) تصيب هدفًا واحدًا وتتوقف. مع الطلقة الثلاثية (fan) يصبح 15 كرة.''',
 vis='''- **المجسم:** كرات ملوّنة صغيرة (0.018 م) من `CONFETTI_COLS` تُرسم مع الشرر (MultiMesh واحد).
- **الأثر:** قصاصات مسطّحة تدور (flake: 0.01×0.0018×0.007 م تقريبًا) تتهادى نازلة ببطء (جاذبية 0.25 ومقاومة هواء 0.25^dt)، بنسبة 70% في كل إطار.
- **وميض الفوهة:** ‎#fff2c2.''',
 tune='`pellets` و`cone` يحددان الانتشار. الكرة الأولى دائمًا في المنتصف.',
 tests=['confetti: five pellets fan out in a cone','confetti: with confetti trails','shots: every style hits a stage target'])
W['bouncy']=dict(
 beh='''كرة مطاطية تنطّ في المكان طوال عمرها (10 ث): كل ارتطام بالأرض يعيدها بقفزة لا تقل عن `BOUNCY_HOP` = 3.2 م/ث (أو 0.8 من سرعة سقوطها)، ولا تقل سرعتها الأفقية عن `BOUNCY_ROLL` = 1.6 م/ث. تفرقع الأهداف الناعمة وتكمل (السرعة × 0.85)، وترتد عن أهداف المسرح والأجسام (معامل 1.8 على المركبة العمودية) وعن جدران المضيف (السرعة × 1.25). حدّ الإصابات والارتدادات مليار (بلا حد عمليًا). يبقى منها في الهواء `BOUNCY_MAX` = 20 كحد أقصى: الجديدة تحل محل الأقدم (بفرقعة صغيرة). عندما يقول المضيف `blaster_roam() == true` (لا جدران حولك) ترجع الكرة نحوك إذا ابتعدت أكثر من `BOUNCY_ROAM` = 6 م.''',
 vis='''- **المجسم:** كرة 0.03 م بلون من `BOUNCY_COLS` تُرسم مع الشرر.
- **بلا أثر ذيل.** وميض الفوهة ‎#ffe9b0.
- **الصوت:** `squeak` عالي الطبقة (1.35) عند الإطلاق، و`bricks_tink` بحسب قوة كل ارتطام.''',
 tune='`life` = 10 ث، والحد 20 كرة لحماية معدل الإطارات في النظارة. الإصابات المتعددة لكرة واحدة تُبلَّغ كـ `bouncy3` (أفضل قيمة).',
 tests=['bouncy: bounces off the floor and carries on','bouncy: pops on through more than one','bouncy: the hits of one ball are reported for bouncy3','bouncy: still bouncing about after 6 s','bouncy: gone after its ten seconds','bouncy: at most 20 at once, the oldest makes way','walls: a bouncy ball bounces back off it'])
W['laser']=dict(
 beh='''شعاع فوري (hitscan) بمدى 30 م: يصيب حتى 3 أهداف على امتداده بالترتيب (ناعمة أو أهداف مسرح) ويخترقها، ويتوقف عند أول جسم صلب لا يحتسب الإصابة (مع `thump`)، أو عند الأرض/جدار المضيف، أو داخل الهدف الثالث. يُحتسب عدد الأهداف عبر `blaster_credit("laser", n)`.''',
 vis='''- **الشعاع:** خط متوهج ‎#ff3b6b بعرض 0.022 م بطبقتين (هالة ملوّنة شفافية 0.6 ونواة فاتحة)، يخبو خلال 0.25 ث (عرضه ينكمش إلى 40%).
- **الإصابة:** `impact()` وردي عند كل هدف، وفي نهاية الشعاع إن لم يُحجب.
- **وميض الفوهة:** ‎#ff6b8f.''',
 tune='`pierce` هو عدد الأهداف المخترقة، و`range` المدى. الشعاع لا يتأثر بالجاذبية ولا يملك قذيفة (`shot_count()` يبقى 0؛ الخط في `arcs`).',
 tests=['laser: an instant beam pierces three targets and stops in the third','laser: its three hits are credited','laser: the beam ends at the last one it went through','laser: the glowing line fades','laser: through two targets and a soft one, stopped by a wall','walls: the laser\'s beam ends at it'])
W['boomerang']=dict(
 beh='''بوميرانغ خشبي يدور ويلتف ويعود: مساره بدلالة u = t / 1.5:
`p = o + dir·reach·sin(πu) + side·swing·sin(2πu) + up·0.25·sin(πu) + (hand − o)·u`
فيبلغ 6 م أمامك وينحرف 1.6 م جانبًا (إلى جهة اليد التي رمته) ثم يعود إلى اليد (`blaster_hand(hand)` إن وُجدت، وإلا مكان الإطلاق). يخترق الأهداف الناعمة ويصيب هدف المسرح مرة في الذهاب ومرة في العودة (لا يعيد إصابة الهدف نفسه قبل 0.3 ث). إذا اصطدم بجسم صلب أو بالأرض أو بجدار المضيف يرتد عائدًا مباشرة إلى اليد بسرعة 10 م/ث (ويُمنح ثانيتين إضافيتين). عند الالتقاط: `thump` واهتزاز، وإن أصاب شيئًا يُبلَّغ `boomerang3`.''',
 vis='''- **المجسم:** بوميرانغ مرسوم بالكود (`AbodenShotLooks.boomerang_mesh()`): ذراعان منحنيتان على شكل V بكوع مستدير، مقطع جناحي (مقبب من أعلى)، ≈ 0.3 م من طرف لطرف، خشب طبيعي بأطراف فيروزية وأشرطة حمراء وصفراء ونقاط بيضاء (`ACC_SHADER`).
- **الحركة:** يدور مسطّحًا 24 راديان/ث (`BOOMERANG_SPIN`) ويميل مع انعطافه (ميل 0.9 يقل إلى 0.25 مع العمر).
- **الأثر:** نقاط بيضاء خفيفة (35%).''',
 tune='`reach` و`swing` يحددان شكل الحلقة، و`life` زمن الرحلة كلها. `speed` لا تُستعمل إلا في العودة المباشرة بعد الارتطام.',
 tests=['boomerang: a curved V, about 0.3 tip to tip and thin','boomerang: curves out and comes back to the hand','boomerang: it spins and banks into its curve','boomerang: hits on both ways','boomerang: caught after a hit, it reports boomerang3','boomerang: knocked back by a wall, it flies home'])
W['glob']=dict(
 beh='''كرة ماء (يسمّيها الكود `glob`) تُقذف بقوس الجاذبية الكاملة. عند أي توقف — هدف، جسم، جدار، أرض أو انتهاء العمر 2.5 ث — تنفجر برذاذ يفرقع كل ما في نصف قطر 0.4 م (`pop_radius`)، فتصيب أيضًا ما بجانب نقطة الارتطام. لا تترك بركة خلفها (قرار المالك).''',
 vis='''- **المجسم:** كرة زرقاء شبه شفافة (0.045 م، `glob` ‎#3fb4ff شفافية 0.75 بحافة لامعة) ونواة فاتحة (‎#c9f1ff إضافية)، تتمطّط (18 راديان/ث، ±12%).
- **الأثر:** قطرات زرقاء (25%).
- **الرذاذ (`splat`):** 16 قطرة ‎#3fb4ff / ‎#c9f1ff تتطاير باتجاه سطح الارتطام. وميض الفوهة ‎#9fe3ff.''',
 tune='`splat` هو نصف قطر منطقة التأثير. الاسم «ماء (Water)» والمعرّف يبقى `glob` للتوافق مع الأصل.',
 tests=['water: the glob splashes on the floor','water: and the splash pops a target sitting there','water: the splash on a wall pops a target beside it'])
W['rocket']=dict(
 beh='''صاروخ موجّه: يبدأ بطيئًا (15% من السرعة) ويتسارع حتى السرعة الكاملة خلال 0.5 ث. كل 0.1 ث (إلى أن يجد هدفًا) يبحث عن أقرب هدف أمامه (ضمن 16 م، وبزاوية لا تتجاوز ≈ 72°) بدرجة `d × (1.6 − facing)`، ويتجنب الأهداف التي يلاحقها صاروخ آخر في الجو ما دام هناك غيرها — فصاروخان متتاليان أو ثلاثة صواريخ الطلقة الثلاثية تتوزع على أهداف مختلفة. بعد 0.1 ث يلتف نحو هدفه بسرعة 6 راديان/ث. ينفجر بجوار هدفه (R + 0.8 × نصف قطر الهدف)، أو عند أي ارتطام، أو بعد 2.6 ث، فيفرقع كل ما في 0.75 م.''',
 vis='''- **المجسم:** جسم أحمر أسطواني (‎#e8473c، 0.11 م)، رأس كريمي مخروطي (‎#f4efe6)، ثلاث زعانف زرقاء (‎#3a6fd8)، ولهب يرتعش (‎#ffcf6a إضافي)؛ يتجه مع سرعته.
- **الأثر:** لهب خلفه وكل إطار تقريبًا دخان رمادي ‎#bdb8b0 يتصاعد.
- **الانفجار (`explosion`):** وميض 0.09 م، 26 شرارة نار (‎#ff7a2e / ‎#ffd34d)، 10 كرات دخان ‎#8a8580. وميض الفوهة ‎#ffb347.''',
 tune='`turn` يحدد حدة الالتفاف (الأكبر = أدق)، و`seek` مدى البحث، و`burst` قوة الانفجار. الأهداف هي الأهداف الناعمة للمضيف وأهداف المسرح المخفية معًا.',
 tests=['rocket: starts slow','rocket: homes in on a target off to the side','rocket: explodes with a radius','rocket: what its blast hits is credited','rocket: two in the air pick different targets','rocket: the triple shot\'s three rockets go for three targets'])
W['lightning']=dict(
 beh='''صاعقة فورية: تختار أول هدف داخل مخروط 0.32 راديان حول اتجاه التصويب وضمن 22 م (الأقرب إلى خط التصويب أولًا: `زاوية × 4 + بعد / مدى`)، ثم تقفز إلى أقرب هدف لم تُصبه ضمن 3 م من الهدف الأخير، حتى 4 أهداف. إن لم تجد هدفًا: فرقعة مستقيمة حتى نصف المدى تصيب أول جسم في المسرح. يُبلَّغ عدد الأهداف في السلسلة كـ `chain4` (أفضل قيمة).''',
 vis='''- **الأقواس:** خطوط متعرّجة زرقاء ‎#5aa8ff (عرض 0.016 م، تعرّج 0.12) بنواة فاتحة، تتغيّر تعرّجاتها 30 مرة في الثانية وتخبو خلال 0.32 ث.
- **عند كل هدف:** وميض ‎#e8f4ff 0.04 م، و`bricks_tink` لكل قفزة بعد الأولى.
- **وميض الفوهة:** ‎#cfe8ff.''',
 tune='`chain` عدد الأهداف، و`hop` أبعد قفزة، و`cone` سماحية التصويب.',
 tests=['lightning: chains through four targets, one hop at a time','lightning: a chain of four is reported for chain4','lightning: along jagged arcs','lightning: from a stage target on to a soft one'])
W['dallah']=dict(
 beh='''دلّة قهوة عربية تدور (14 راديان/ث) وتطير بقوس خفيف (0.55 g)، ترشّ حبة بن كل 0.08 ث في اتجاه يدور معها (مخروط 0.5 راديان، وتأخذ الحبة نصف سرعة الدلّة). تخترق الأهداف الناعمة ولا تتوقف عندها، وعند التوقف أو بعد 1.1 ث تنسكب: 6 حبات بن تتطاير للأعلى (مخروط 1.1) مع شرر ذهبي. **حبة البن (`bean`):** 7 م/ث، g كاملة، عمر 0.6 ث، نصف قطر 0.014 م، تصيب هدفًا واحدًا (وتُحتسب كـ `bean`). الحبات تأخذ الأماكن الشاغرة فقط من ميزانية 48 قذيفة.
**الأصوات هادئة ومتباعدة:** رنين `fair_ding` بمستوى 0.3 عند الإطلاق و0.22 عند الانسكاب، ولا يتكرر أسرع من كل 0.3 ث (`DALLAH_DING_GAP`) حتى مع اليدين والضغط المستمر، وارتطام الحبات `thump` لا يتكرر أسرع من كل 0.15 ث (`BEAN_THUMP_GAP`).''',
 vis='''- **المجسم:** دلّة نحاسية (`brass` ‎#dcaa48 معدني و`brass_dark` ‎#9c6b22): بطن مستدير، قاعدة، عنق، غطاء مقبب بزرّ، صنبور طويل مائل، ومقبض حلقي، داخل هالة دافئة ‎#ffd98a، بمقياس 1.3.
- **الحبوب:** كرات صغيرة من `BEAN_COLS` (بني ذهبي إلى داكن، وحبّة هيل خضراء أحيانًا).
- **الأثر:** بخار أبيض خفيف يتصاعد. وميض الفوهة ‎#ffe3a0.''',
 tune='`spray` كثافة الرش. مستوى الرنين في `DALLAH_FIRE_K` / `DALLAH_SPILL_K` والفاصل في `DALLAH_DING_GAP`.',
 tests=['dallah: the pot sprays coffee beans as it flies','dallah: it spills its beans where it lands','dallah: its dings are soft and spaced','dallah: its ding plays -10.5 dB under the full bell'])
# --- v1.2: AB-W-013 ... 022 ---
W['falcon']=dict(
 beh='''صقر منخفض المضلعات يخرج من اليد بـ 60% من سرعته ويبلغ 9 م/ث خلال 0.4 ث، ويرتفع قليلًا في أول نصف ثانية. كل 0.1 ث (حتى يجد فريسة) يبحث بطريقة الصاروخ نفسها (`_seek`: الأقرب أمامه ضمن 14 م) متجاوزًا الهدف الذي يلاحقه صقر آخر ما دام غيره موجودًا. بعد 0.2 ث يلتف نحو فريسته بـ 4 راديان/ث، وعلى بعد 2.5 م (`dive`) يصيح (`screech`) وينقضّ: يطوي جناحيه، وتزيد سرعته × 1.6 والتفافه × 2.5، وفي آخر 0.6 م يتجه إليها مباشرة. يفرقع الهدف الناعم (`blaster_hit`) أو يصيب هدف المسرح (`shoot`)، ثم يعود إلى اليد (`blaster_hand(hand)` إن وُجدت، وإلا مكان الإطلاق) ويُلتقط بصوت رفرفة واهتزاز. يعود أيضًا إذا ارتطم بجسم أو جدار أو الأرض، أو اختفت فريسته، أو لم يجد شيئًا خلال 1.5 ث (`FALCON_PATIENCE`)، أو مضى 75% من عمره (4 ث، و+2 ث للعودة). لا يصيب شيئًا في طريق العودة. لا يحتاج نداءً جديدًا من المضيف.''',
 vis='''- **المجسم:** صقر من أشكال بسيطة (`_falcon_node`): جسم بني ‎#7a4a2a وصدر كريمي ‎#efe6d2، رأس داكن ‎#4a2e1a بخدّين فاتحين وعينين ومنقار أصفر ‎#e0b84a، ذيل مروحي بشريط فاتح، وجناحان من شريحتين منخفضتي المضلعات لكل منهما (`_slab`): الذراع بنية من فوق كريمية من تحت، والكف داكنة مدببة مائلة للخلف. طوله ≈ 0.2 م وباع جناحيه ≈ 0.4 م.
- **الحركة:** يرفرف 14 راديان/ث (`FALCON_FLAP`)، أبطأ وأهدأ في العودة، ويطوي جناحيه عند الانقضاض؛ يتجه مع سرعته.
- **البرقع:** غطاء رأس جلدي ‎#8b5a2b بريشة حمراء ‎#c9302c وزرّ ذهبي، يسقط بعد 0.12 ث من الإطلاق: يتقلب ويسقط إلى الأرض ويختفي بعد 0.9 ث (`props`).
- **الأثر:** خطوط هواء بيضاء خفيفة أثناء الانقضاض. **وميض الفوهة:** ‎#f1e3c8.''',
 tune='`turn` و`dive` يحددان حدة الانقضاض، و`seek` مدى البحث، و`speed` أقل من نصف سرعة الصاروخ عمدًا (تراه يطير). مع `cool` = 1.2 ث لا يكون في الجو أكثر من صقرين أو ثلاثة لكل يد.',
 tests=['falcon: a hooded falcon, its hood drops off once it flies','falcon: it beats its wings','falcon: stoops on a target off to the side (with a screech) and takes it','falcon: then flies back to the hand (blaster_hand) and is caught','falcon: two in the air hunt different targets','falcon: both take theirs and come home','falcon: with nothing to hunt it circles back to where it left','shots: every style fires with its sound / keeps its cooldown / pops a soft target / hits a stage target','no host: every style fires, hits the `stage` target and is gone in time'])
W['freeze']=dict(
 beh='''شعاع جليدي فوري (hitscan) بمدى 12 م: شعاع الليزر نفسه (`_laser(..., "freeze")`) لهدف واحد (`pierce` 1). عند هدف ناعم: إن كان للمضيف **النداء الجديد `blaster_freeze(target, seconds)`** يُجمَّد الهدف 3 ث (`frost`) بدل أن يُصاب (ويُبث `shot_hit`)؛ وبدونه يُصاب كأي طلقة (`blaster_hit` ثم فرقعة). هدف المسرح يأخذ الإصابة عبر `shoot()` كالعادة. في الحالتين: صوت تكسّر جليد (`ice_crack`) وبلورات صقيع وقشرة ثلج فوق الهدف طوال التجميد (تختفي إن اختفى الهدف). يتوقف عند جدار أو الأرض. يُحتسب عبر `blaster_credit("freeze", n)`.''',
 vis='''- **الشعاع:** خط ‎#9fe8ff بعرض 0.016 م يخبو خلال 0.3 ث، وبريق صقيع (رقائق بيضاء وزرقاء ترفرف) على امتداده.
- **عند الهدف (`_frost`):** 14 بلورة تتطاير، وقشرة ثلج شفافة (شفافية 0.38) بحجم 1.12 من الهدف مع لمعات بيضاء، تخبو في آخر 0.4 ث (`auras`).
- **وميض الفوهة:** ‎#bfefff.''',
 tune='`frost` مدة التجميد التي تُعطى للمضيف، و`range` المدى (أقصر من الليزر). الشعاع لا يملك قذيفة (`shot_count()` يبقى 0؛ الخط في `arcs`).',
 tests=['freeze: the beam freezes the first target for 3 s (blaster_freeze), instead of popping it','freeze: an instant icy beam (ice_zap), the ice cracks (ice_crack) and a frost shell covers it','freeze: the frost shell lasts while it is frozen','freeze: a short beam: nothing beyond 12 m','freeze: a stage target takes it (shoot) and frosts over','freeze: without blaster_freeze the beam hits (pops) the target'])
W['blackhole']=dict(
 beh='''كرة دوامة تنطلق بـ 6 م/ث وتتباطأ خطيًا حتى تقف بعد 0.8 ث (`life`) على بعد ≈ 2.4 م، أو عند أول جسم أو جدار أو الأرض. تفرقع ما تمر به من أهداف ناعمة في طريقها. ثم تبقى 1.5 ث (`linger`): كل هدف ناعم ضمن 2.5 م (`field`) يُسحب نحو مركزها عبر **النداء الجديد `blaster_pull(target, to, strength)`** بسرعة 2 م/ث (`tug`) تزيد حتى الضعف قرب المركز، وما يلمس النواة يفرقع. في النهاية تنفجر للداخل وتفرقع كل ما في 0.9 م (`burst`، `pop_radius`) ويُحتسب `blaster_credit("blackhole", n)`. بلا `blaster_pull` السحب شكل فقط، والانفجار يعمل كما هو.''',
 vis='''- **المجسم:** نواة سوداء ‎#050208 (0.05 م) في هالة بنفسجية ‎#6d28d9، وحافة متوهجة ‎#8b5cf6 وثلاث حلقات قرص مسطحة ‎#c084fc (إضافية) مائلة تدور 7 راديان/ث.
- **أثناء البقاء:** تكبر × 1.6 وترتعش، وشرر بنفسجي (`VOID_COLS`) يلتف حلزونيًا نحو المركز، وخطوط من الأهداف المسحوبة إليه؛ تنكمش في آخر 0.25 ث.
- **الانفجار للداخل (`implode`):** وميض فاتح ثم داكن، وحلقة من 30 شرارة، وصوت `whoomp`. **وميض الفوهة:** ‎#b48cff.''',
 tune='`field` و`tug` قوة الجذب، و`burst` الانفجار الأخير، و`life` يحدد أين تقف (المسافة ≈ speed × life ÷ 2).',
 tests=['blackhole: slows to a stop 2.5 m out and stays','blackhole: pulls a target within its field toward it (blaster_pull)','blackhole: then implodes (whoomp) and pops what it pulled in','blackhole: without blaster_pull its implosion pops what is within 0.9 m, nothing else moves'])
W['dates']=dict(
 beh='''أسرع سلاح في الحزمة: `cool` = 0.1 ث، أقل `cool` في الكتالوج (≈ 10 طلقات في الثانية لكل يد عند الضغط المستمر). كل طلقة حبة تمر واحدة بسرعة 16 م/ث وجاذبية خفيفة (0.3 g)، منحرفة عشوائيًا حتى 0.035 راديان (`cone`). تصيب هدفًا واحدًا وتتوقف؛ عند ارتطامها بجسم أو جدار أو الأرض تتفتت إلى فتات. صوت `put` ناعم مع كل طلقة.''',
 vis='''- **المجسم:** حبة تمر لامعة: كرة 0.012 م ممطوطة × 1.75 على اتجاه الطيران، مادة لامعة (`gloss`) ‎#5a2a12 أو كهرمانية ‎#7b3d1a، بقمعها الفاتح ‎#c9a36a في مؤخرتها؛ تدور حول محورها.
- **التفتت (`crumble`):** 9 فتات بنية (`CRUMB_COLS`)، أغلبها قطع مسطحة تتقلب نازلة.
- **وميض الفوهة:** ‎#ffe0b0 صغير (0.03 م)، واهتزاز اليد خفيف (0.12).''',
 tune='عمرها 1.2 ث فيبقى في الجو ≈ 12 حبة لكل يد (الحد 48 قذيفة). مع الطلقة الثلاثية تصبح 30 حبة في الثانية لليد.',
 tests=['catalog: the date blaster fires fastest of all','dates: twelve in 1.2 s, each a little off the aim, each with its soft put','dates: each a long glossy date','dates: one crumbles into bits on a wall'])
W['bakhoor']=dict(
 beh='''مبخرة تُقذف بقوس الجاذبية الكاملة (7 م/ث) وهي تتقلب. إن أصابت هدفًا ناعمًا في طريقها فرقعته وأكملت. تستقر حين تبلغ الأرض أو سطحًا أفقيًا (n.y > 0.5) فتقف معتدلة وتتوهج (`ember`)؛ وعن الجدران ترتد ساقطة. إن لم تبلغ شيئًا خلال 2.5 ث (`life`) تستقر حيث هي. بعد الاستقرار تبقى 4 ث (`linger`) تطلق دخان بخور يتصاعد ويلتف مع جمر برتقالي، ولا تصيب شيئًا. كل 0.25 ث (`BAKHOOR_TICK`) كل هدف ناعم داخل السحابة (كرة نصف قطرها 0.9 م `cloud`، مركزها 0.45 م فوق المبخرة) يُبطَّأ عبر **النداء الجديد `blaster_slow(target, factor, seconds)`** بمعامل 0.4 (`slow`) لمدة 0.5 ث (`BAKHOOR_HOLD`)، فيعود الهدف إلى سرعته بعد خروجه بقليل. بلا `blaster_slow` الدخان شكل فقط.''',
 vis='''- **المجسم:** مبخرة مربعة: قاعدة وساق مخصّرة ووعاء متسع (أسطوانات بأربعة أضلاع) من خشب داكن بنقش معيّنات ونقاط ذهبية (`BAKHOOR_SHADER` في `AbodenShotLooks`)، وأشرطة ذهبية ‎#d4a640 وأزرار ذهبية في الأركان، وفحم ‎#2a1a12 بتوهج برتقالي ‎#ff7a2e يرتعش.
- **الطيران:** تتقلب، ويتبعها خيط دخان رفيع.
- **الدخان:** نفثة كل 0.06 ث: رمادي فاتح شفاف (0.28)، 0.035–0.065 م تكبر × 3.2 خلال 1.8–2.6 ث (`grow`) وتلتف (`curl`) وهي تصعد وتنتشر؛ وجمر ‎#ff8a3c / ‎#ffc46b يصعد ويسقط. **وميض الفوهة:** ‎#ffcf8a.''',
 tune='`cloud` و`slow` و`linger` شكل المنطقة وقوتها ومدتها. في السحابة ≈ 35 نفثة في الوقت نفسه (الحد 320 شرارة).',
 tests=['bakhoor: lobbed, it lands upright on the floor and glows (ember)','bakhoor: a lingering cloud of rising smoke','bakhoor: slows what is in the cloud (blaster_slow x0.4, every 0.25 s), not what is outside, and pops nothing','bakhoor: gone after its 4 s of smoke','bakhoor: without blaster_slow the smoke is only the look'])
W['lasso']=dict(
 beh='''حبل بنقشة الشماغ يُرمى بقوس (11 م/ث، 0.5 g). إن بلغت حلقته هدفًا ناعمًا وللمضيف **`blaster_pull(target, to, strength)`**: تلتقطه (صوت `snap`، بلا فرقعة، ويُبث `shot_hit`)، وتبقى عليه وتسحبه نحو اليد بـ 3 م/ث (`tug`) مدة 1.2 ث (`drag`) أو حتى يصل 0.35 م من اليد أو يختفي، ثم تفلته وتُلفّ عائدة. بلا `blaster_pull` الالتقاط إصابة عادية (`blaster_hit`، فرقعة) ثم يعود الحبل. هدف المسرح يأخذ الإصابة عبر `shoot()` ويعود الحبل. إن لم يلتقط شيئًا خلال 0.9 ث (`life`)، أو ارتطم بجسم أو جدار أو الأرض، يعود إلى اليد (`blaster_hand` أو مكان الإطلاق) بسرعة 15.4 م/ث ولا يصيب شيئًا في العودة.''',
 vis='''- **الحلقة:** حلقة (Torus) بنسيج الشماغ: قماش أبيض ‎#f4f1ea بخطوط ومربعات حمراء ‎#c8102e (`AbodenShotLooks.shemagh_texture()`، يُرسم بالكود)، وعقدة؛ تدور مفتوحة في الطيران، وتضيق حول الهدف الملتقط على قدر نصف قطره، وتصغر في العودة.
- **الحبل:** 40 مقطعًا (`ROPE_SEGS`) أحمر وأبيض بالتناوب من اليد إلى الحلقة، يتدلى (12% من طوله) ويشتد (3%) وهو يسحب؛ يُرسم مع الأشعة (`_draw_ropes`).''',
 tune='`drag` و`tug` مدة السحب وقوته؛ ما يحدث للهدف حين يصل إلى اليد قرار المضيف.',
 tests=['lasso: its loop catches the target (snap), no pop','lasso: and pulls it toward the hand along its red-and-white rope','lasso: then lets go and reels back into the hand','lasso: a miss comes back to the hand','lasso: without blaster_pull it pops what it reaches, and comes back'])
W['hose']=dict(
 beh='''خرطوم ماء: الضغط المستمر تيار واحد. كل 0.12 ث (`cool`) تخرج 6 قطرات (`pellets`) بانحراف حتى 0.03 راديان، موزعة على امتداد التيار كأنها خرجت واحدة بعد أخرى خلال تلك الـ 0.12 ث، بسرعة 12 م/ث وجاذبية كاملة (مدى ≈ 4–5 م). كل قطرة تصل هدفًا ناعمًا تدفعه بعيدًا عنك دون أن تفرقعه: عبر **النداء الجديد `blaster_push(target, velocity)`** بسرعة 1.5 م/ث (`push`) على اتجاه القطرة، وإن لم يكن للمضيف إلا `blaster_pull` فبتحريكه 0.03 م (`shove`) نحو نقطة خلفه؛ وبلا أيهما تصيبه كأي طلقة. القطرات تأخذ الأماكن الشاغرة فقط، فلا تُخرج طلقات أخرى من الجو.''',
 vis='''- **القطرات:** كرات زرقاء (`HOSE_COLS`) بأحجام 0.7–1.3، ممطوطة × 4.5 على اتجاه طيرانها فيبدو التيار متصلًا؛ تُرسم مع الشرر.
- **الأثر:** رذاذ خفيف. **الإصابة:** رشّات صغيرة (`_droplets`) وصوت `splash` خافت متباعد.
- **وميض الفوهة:** ‎#9fe3ff صغير، واهتزاز خفيف.''',
 tune='`push` (أو `shove`) قوة الدفع لكل قطرة، و`pellets` كثافة التيار. الفحيح `hose_hiss` لا يتكرر أسرع من كل 0.12 ث (`HOSE_HISS_GAP`).',
 tests=['hose: the stream pushes the target away, no pop','hose: its hiss is spaced','hose: its drops only take free places','hose: with blaster_push each drop gives it a velocity away from you, no pull, no pop','shots: every style pops a soft target (without blaster_pull)'])
W['cluster']=dict(
 beh='''قنبلة مرحة تُقذف بقوس (10 م/ث، 0.8 g) وفتيلها يئز. بعد 0.7 ث (`life`) أو عند أول إصابة أو ارتطام تتفرق (`start_pop`) إلى 6 قنابل صغيرة (`pellets`) تنطلق للأعلى وحولها (مخروط 0.9–1.4 راديان حول الأعلى بسرعة 2.5 م/ث، مع 35% من سرعة القنبلة)، كل واحدة بلون من `CONFETTI_COLS`. كل قنبلة صغيرة تطير بالجاذبية حتى 0.9 ث وتنفجر عند أول ما تلمسه أو عند الأرض أو في نهاية عمرها، فتفرقع ما في 0.35 م (`bomblet.burst`، `pop_radius`) ويُحتسب `blaster_credit("bomblet", n)` (كحبات البن للدلّة).''',
 vis='''- **المجسم:** قنبلة كروية لامعة بنفسجية ‎#6c3cff (0.04 م) بنقاط صفراء ‎#ffd23f، وعنق أصفر، وفتيل ‎#c9b38a بشرارة ‎#ffd34d ترتعش وترش شررًا، تتدحرج في الطيران.
- **القنابل الصغيرة:** كرات ملوّنة 0.022 م تُرسم مع الشرر.
- **انفجار الصغيرة (`bomblet_pop`):** وميض و12 شرارة بلونها، وصوت `cluster_pop` (لا يتكرر أسرع من كل 0.06 ث، `BOMBLET_POP_GAP`). **وميض الفوهة:** ‎#fff2c2.''',
 tune='`life` وقت الفتيل، و`pellets` العدد، و`bomblet.*` طيران الصغيرة وانفجارها. المعرّف `cluster` كما حُجز، ولا يتعارض مع `cluster` العسكري (AB-W-027): المعرّفات لكل حزمة في كتالوجها، والفريد هو الرمز.',
 tests=['cluster: after its fuse it bursts into 6 bomblets','cluster: each bomblet goes off where it lands','cluster: its bomblets\' blasts pop targets around it','catalog: the playful "cluster" (AB-W-020) and the military one (AB-W-027) are told apart by code'])
W['magnet']=dict(
 beh='''مغناطيس حدوة يطير مستقيمًا (9 م/ث) ويتباطأ حتى يقف بعد 0.7 ث (≈ 3.2 م) أو عند أول جسم أو جدار أو الأرض، ويصيب ما يلمسه في طريقه. ثم يعلق في الهواء 3 ث (`linger`) ومجاله 2.2 م (`field`):

- الأهداف الناعمة المعدنية (`"metal": true` في قاموس الهدف) تُسحب نحوه بـ 2.5 م/ث (`tug`) عبر `blaster_pull`، وما يلمسه منها يُصاب؛
- قذائف الخصم التي يبلغ عنها المضيف بـ **النداء الجديد `blaster_threats()`** (كلها معدنية ما لم تقل `"metal": false`) تُسحب نحوه عبر `blaster_pull`، وما يبلغه منها يُوقف عبر **`blaster_block(threat, at)`** (صوت `cans_clang`، ويُحتسب `blaster_credit("magnet", 1)`)؛
- طلقات الحزمة نفسها المعدنية (`MAGNET_PULLS`: الكرات الصغيرة والقصاصات والنطّاطة وحبات البن والتمر والقنابل الصغيرة) تنحني نحوه بتسارع 10 م/ث² (`tug × MAGNET_BEND`).

بلا هذه النداءات يبقى الشكل وانحناء طلقات الحزمة. في النهاية يسقط (`thump`).''',
 vis='''- **المجسم:** حدوة حمراء لامعة ‎#e53935 من ذراعين وانحناءة من 7 قطع، بقطبين فضيين معدنيين ‎#d8dde3؛ يتجه بقطبيه إلى الأمام في الطيران، ويتمايل صعودًا ونزولًا ويدور وهو معلق.
- **المجال:** ذرات حمراء ‎#ff6b6b وفضية ‎#e6eef5 تدور حول القطبين. **وميض الفوهة:** ‎#ff9a9a، وصوت `zing` عند الإطلاق وعند التعليق.''',
 tune='`field` و`tug` و`linger` المجال وقوته ومدته؛ `MAGNET_BEND` قوة ثني طلقات الحزمة.',
 tests=['magnet: it flies 3.2 m and hangs there (zing)','magnet: it bends the kit\'s own shots toward it','magnet: pulls the metal target in (blaster_pull), leaves the other','magnet: draws a hostile projectile in and stops it (blaster_threats, blaster_block)','magnet: gone after 3 s'])
W['shield']=dict(
 beh='''فقاعة درع (نصف قطرها 0.45 م، `r`) تظهر 0.45 م (`ahead`) أمام اليد على اتجاه الإطلاق وتتبع اليد (`blaster_hand(hand)`؛ بلا مضيف تبقى حيث أُطلقت) مدة 3 ث. لا تصيب الأهداف ولا ترتطم بشيء. كل قذيفة خصم يبلغ عنها المضيف عبر **`blaster_threats()`** وتصل جلد الفقاعة تُوقف عبر **`blaster_block(threat, at)`** (`at` على سطح الفقاعة، والمضيف يدمرها)، مرة واحدة لكل قذيفة: تومض الفقاعة وتهتز اليد ويُسمع `shield_block` ويُحتسب `blaster_credit("shield", 1)` ويُبث `shot_hit("shield", threat)`. فقاعة واحدة لكل يد: الجديدة تأخذ مكان السابقة (والطلقة الثلاثية فقاعة واحدة). في النهاية تفرقع (`start_pop`). بلا `blaster_threats` تبقى فقاعة تُرى فقط. لأنها لا تصيب، تستثنيها الفحوص العامة «تفرقع هدفًا ناعمًا» و«تصيب هدف مسرح».''',
 vis='''- **المجسم:** كرة بـ `SHIELD_SHADER` (`AbodenShotLooks.shield_material()`، مادة لكل فقاعة): سماوية، شبه شفافة في وسطها ولامعة عند حافتها (Fresnel)، بشبكة خلايا خفيفة؛ تومض (`flash`) عند كل صدّ، تظهر خلال 0.15 ث وتخبو في آخر 0.3 ث، وتهتز قليلًا عند الفتح والصدّ.
- **الصدّ:** حلقة من 12 شرارة سماوية من نقطة الصدّ. **بلا وميض فوهة.**''',
 tune='`r` حجم الفقاعة، و`ahead` بعدها عن اليد، و`life` مدتها، و`cool` = 4 ث يمنع إبقاءها دائمًا.',
 tests=['shield: a bubble opens 0.45 m in front of the hand (shield_up)','shield: it rides the hand (blaster_hand)','shield: a projectile reaching it is stopped at its skin (blaster_block, shield_block), one out of reach is not','shield: it pops nothing (a defence only)','shield: one bubble a hand (a new one takes the last one\'s place)','shield: they pop after 3 s','shield: with no host it still opens and draws, where it was fired'])

EXTRA={
 'bouncy':[('BOUNCY_MAX','20','أقصى عدد كرات في الجو','عدد'),('BOUNCY_HOP','3.2','أقل سرعة قفزة بعد ارتطام الأرض','م/ث'),('BOUNCY_ROLL','1.6','أقل سرعة أفقية','م/ث'),('BOUNCY_ROAM','6.0','مسافة العودة نحو اللاعب (مع blaster_roam)','م')],
 'boomerang':[('BOOMERANG_SPIN','24.0','سرعة الدوران','راديان/ث')],
 'dallah':[('DALLAH_FIRE_K','0.3','مستوى رنين الإطلاق','—'),('DALLAH_SPILL_K','0.22','مستوى رنين الانسكاب','—'),('DALLAH_DING_GAP','0.3','أقل فاصل بين رنينين','ث'),('BEAN_THUMP_GAP','0.15','أقل فاصل بين ارتطامين للحبوب','ث')],
 'falcon':[('FALCON_FLAP','14.0','سرعة رفرفة الجناحين','راديان/ث'),('FALCON_PATIENCE','1.5','إن لم يجد فريسة خلال هذه المدة يعود','ث')],
 'bakhoor':[('BAKHOOR_TICK','0.25','كل كم يُعاد إبطاء ما في السحابة','ث'),('BAKHOOR_HOLD','0.5','مدة كل إبطاء (`seconds` في `blaster_slow`)','ث')],
 'hose':[('HOSE_HISS_GAP','0.12','أقل فاصل بين صوتي فحيح','ث')],
 'cluster':[('BOMBLET_POP_GAP','0.06','أقل فاصل بين صوتي فرقعة','ث')],
 'magnet':[('MAGNET_BEND','4.0','ثني طلقات الحزمة المعدنية نحوه (× tug)','× م/ث²')],
}
for k,v in EXTRA.items():
    for c in v:
        assert c[1]==const(c[0]), (c, const(c[0]))
FAN=const('FAN_STEP')

def ptable(id):
    rows=['| المعامل | القيمة | المعنى | الوحدة |','|---|---|---|---|']
    for k,v in ss[id].items():
        n,u=PARAM[k]
        rows.append('| `%s` | %s | %s | %s |'%(k,v,n,u))
    for c in EXTRA.get(id,[]):
        rows.append('| `%s` | %s | %s | %s |'%c)
    if id=='dallah':
        rows.append('| `bean.*` | '+', '.join('%s %s'%(k,v) for k,v in ss['bean'].items())+' | حبة البن (معاملات `SHOT_STYLE.bean`) | كما سبق |')
    if id=='cluster':
        rows.append('| `bomblet.*` | '+', '.join('%s %s'%(k,v) for k,v in ss['bomblet'].items())+' | القنبلة الصغيرة (معاملات `SHOT_STYLE.bomblet`؛ `speed` سرعة تفرقها، `burst` انفجارها) | كما سبق |')
    return '\n'.join(rows)

def unlock(id):
    u=UNL[id]
    if not u and shots[id]['version']!='1.0': return 'لا شرط (سلاح جديد في v1.2، لم يكن في اللعبة الأصلية)'
    if not u: return 'مفتوح من البداية (أساسي)'
    g,ar,en,_=CH[u]
    return '`%s` — %s (%s)، الهدف %d'%(u,ar,en,g)

CHG={'1.0':'| v1.0 | 2026-10-17 | الإصدار الأول (الأرقام والسلوك مطابقة للأصل؛ انظر CHANGELOG). |',
 '1.2':'| v1.2 | 2026-10-23 | جديد: من الرموز المحجوزة إلى سلاح مستقر (أرقامه ومجسمه وأصواته وأيقونته واختباراته؛ انظر CHANGELOG). |'}
NEWSND='\n\nالأصوات الجديدة في v1.2 مُركّبة بالكود (ضوضاء ومرشحات ومسارات تردد وأغلفة، بلا تسجيل) عبر `tools/gen_sounds.py`، بصيغة الملفات الأخرى (أحادية 22050 هرتز 16 بت).'
pages=[]
for i,id in enumerate(ORDER):
    s=shots[id]; code=s['code']
    tags=eval(s['tags'].replace('"','"'))
    fn='%s_%s.md'%(code,id)
    pages.append(fn)
    snds=eval(s['sounds'])
    w=W[id]
    txt=f'''# {code} — {s["ar"]} ({s["en"]})

[← فهرس الأسلحة](../CATALOG.md)

| | |
|---|---|
| ![{s["en"]}](../icons/{id}.png) | ![{s["en"]} — لقطة](../shots/{id}.png) |

| الحقل | القيمة |
|---|---|
| الرمز (code) | `{code}` |
| الحزمة (pack) | مرحة (playful) |
| المعرّف (id) | `{id}` |
| الاسم | {s["ar"]} ({s["en"]}) |
| الوصف | {s["ar_desc"]} — *{s["en_desc"]}* |
| العائلة (category) | {"، ".join(CAT[t] for t in tags)} |
| طريقة الإيصال (delivery) | {AX[s["delivery"]]} |
| المسار (trajectory) | {AX[s["trajectory"]]} |
| نموذج الإصابة (hit) | {AX[s["hit"]]} |
| الدور (role) | {AX[s["role"]]} |
| الفئة/الندرة (tier) | {TIER[int(s["tier"])]} |
| شرط الفتح الأصلي (origin unlock) | {unlock(id)} |
| الأيقونة | `addons/aboden_blaster/icons/{id}.png` (`{s["icon"]}`) |
| الحالة (status) | مستقر (stable) |
| الإصدار (version) | v{s["version"]} |

## السلوك

{w["beh"]}

**مشترك بين كل الأسلحة:** تُطلق بـ `fire(hand, origin, dir)` أو `fire_at(origin, target_point, hand)` (يصوّب الاتجاه نحو النقطة)؛ الفوهة 0.08 م أمام نقطة الإطلاق؛ لكل يد مؤقّت `cool` خاص بها؛ الطلقة الثلاثية (`shot_fan()` = 3) تدوّر الاتجاه ±{FAN} راديان (`FAN_STEP`) حول المحور العمودي؛ كل الأطوال × `blaster_scale()`.

## المعاملات (`AbodenShotCatalog.SHOT_STYLE["{id}"]`)

{ptable(id)}

## المظهر

{w["vis"]}

## الأصوات

{chr(10).join("- " + SND[x] + (" ← **صوت الإطلاق**" if x == s["sound"] else "") for x in snds)}{NEWSND if s["version"] != "1.0" else ""}

## ملاحظات الضبط

{w["tune"]}

## الاختبارات (`tests/run_tests.gd`)

{chr(10).join("- " + t for t in w["tests"])}

## سجل التغييرات

| الإصدار | التاريخ | التغيير |
|---|---|---|
{CHG[s["version"]]}
'''
    open(ROOT+'/docs/weapons/'+fn,'w').write(txt)

# CATALOG.md
rows=[]
for id in ORDER:
    s=shots[id]; tags=eval(s['tags'])
    rows.append(f'| [`{s["code"]}`](weapons/{s["code"]}_{id}.md) | <img src="icons/{id}.png" width="40"> | **{s["ar"]}** ({s["en"]}) | `{id}` | مرحة | {"، ".join(CAT[t].split(" (")[0] for t in tags)} | {AX[s["delivery"]]} | {AX[s["trajectory"]]} | {AX[s["hit"]]} | {AX[s["role"]]} | {TIER[int(s["tier"])]} | مستقر | v{s["version"]} |')
fams=[('direct','قذيفة لها جسم تطير في خط شبه مستقيم وتتوقف عند أول إصابة.'),
 ('ballistic','قذيفة تتأثر بالجاذبية (`grav` > 0) فترسم قوسًا.'),
 ('instant','لا قذيفة: الإصابة تُحسب في لحظة الإطلاق على امتداد شعاع أو قوس (hitscan)، ويُرسم الخط ثم يخبو.'),
 ('area','تؤذي كل ما في نصف قطر حول نقطة الانفجار أو الرذاذ (`pop_radius`).'),
 ('homing','تختار هدفها بنفسها وتتجه إليه (بحث + التفاف) أو تقفز إليه.'),
 ('returning','تعود إلى اليد التي رمتها بعد رحلة محددة.'),
 ('spray','تطلق أكثر من جسم في الطلقة الواحدة أو ترشّ قذائف ثانوية أثناء الطيران.'),
 ('bouncing','ترتد عن الأرض والأجسام وتكمل بدل أن تتوقف.'),
 ('defence','تحمي اللاعب: تصدّ قذائف الخصم التي يبلغ عنها المضيف (`blaster_threats`) بدل أن تصيب الأهداف.')]
famtab=['| العائلة | المعرّف | التعريف | الأسلحة |','|---|---|---|---|']
for f,d in fams:
    ws=[f'[{shots[i]["ar"]}](weapons/{shots[i]["code"]}_{i}.md)' for i in ORDER if f in eval(shots[i]['tags'])]
    famtab.append(f'| {CAT[f].split(" (")[0]} | `{f}` | {d} | {"، ".join(ws)} |')
def axtab(axis, defs):
    t=['| القيمة | المعرّف | التعريف | الأسلحة |','|---|---|---|---|']
    for v,d in defs:
        ws=[f'{shots[i]["ar"]}' for i in ORDER if shots[i][axis]==v]
        t.append(f'| {AX[v].split(" (")[0]} | `{v}` | {d} | {"، ".join(ws) or "—"} |')
    return '\n'.join(t)
catmd=f'''# فهرس الأسلحة — حزمة أسلحة عبودين (Aboden Blaster Kit)

المرجع الدائم لكل أسلحة الحزمة. لكل سلاح **رمز دائم** `AB-W-NNN` لا يتغير ولا يُعاد استخدامه، وصفحة كاملة في `docs/weapons/`. الأرقام كلها من `addons/aboden_blaster/shot_catalog.gd` (المصدر الوحيد للحقيقة)، والأطوال بالمتر قبل الضرب في `blaster_scale()`.

- [الجدول الملخص](#الجدول-الملخص) · [التصنيف](#التصنيف-taxonomy) · [محاور الوسوم](#محاور-الوسوم-tag-axes) · [إضافة سلاح](#إضافة-سلاح-جديد) · [قائمة الأفكار](#قائمة-الأفكار--roadmap)
- القالب: [`weapons/_TEMPLATE.md`](weapons/_TEMPLATE.md) · السجل: [`CHANGELOG.md`](CHANGELOG.md) · الدليل: [`../README.md`](../README.md)

## الجدول الملخص

يمكن فرز هذا الجدول أو تصفيته بأي عمود (انسخه إلى جدول بيانات، أو ابحث بالمعرّف الإنجليزي مثل `homing` أو `splash`).

| الرمز | الأيقونة | الاسم | المعرّف | الحزمة | العائلة | الإيصال | المسار | الإصابة | الدور | الفئة | الحالة | الإصدار |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
{chr(10).join(rows)}

### المعرض

| | | | |
|---|---|---|---|
''' 
for r in range((len(ORDER)+3)//4):
    cells=[]; caps=[]
    for id in ORDER[r*4:r*4+4]:
        s=shots[id]
        cells.append(f'[![{s["en"]}](shots/{id}.png)](weapons/{s["code"]}_{id}.md)')
        caps.append(f'`{s["code"]}` {s["ar"]} ({s["en"]})')
    while len(cells)<4:
        cells.append(' '); caps.append(' ')
    catmd+='| '+' | '.join(cells)+' |\n| '+' | '.join(caps)+' |\n'
catmd+=f'''
## التصنيف (taxonomy)

**العائلة** (category، الحقل `tags` في الكتالوج) تصف طبيعة السلاح، وقد يكون للسلاح أكثر من عائلة. تعريفات العائلات في `AbodenShotCatalog.CATEGORIES`.

{chr(10).join(famtab)}

## محاور الوسوم (tag axes)

إلى جانب العائلة، لكل سلاح قيمة واحدة على كل محور (الحقول `pack` و`delivery` و`trajectory` و`hit` و`role` و`tier` و`status` و`version`؛ القيم المسموحة في `AbodenShotCatalog.PACKS` و`AXES` و`TIERS` و`STATUS`). القيم المعلّمة «مخطط» محجوزة للحزم القادمة ولا يستعملها أي سلاح حاليًا؛ قيم `called` و`lofted` و`waypoints` و`vertical` و`intercept` و`falloff` و`scan` و`defence` و`support` تستعملها [الحزمة العسكرية](MILITARY.md)، وأسلحة v1.2 المرحة أول من استعمل الإيصال `area` و`lingering`، وأضافت المسار `held` والعائلة `defence`.

### الحزمة (pack)

| الحزمة | المعرّف | المعنى | الأسلحة |
|---|---|---|---|
| مرحة | `playful` | الأسلحة المرحة الملوّنة: الاثنا عشر الأولى من دحروج (v1.0) والعشرة الجديدة (v1.2). | AB-W-001 … AB-W-022 |
| عسكرية | `military` | أسلحة البارجة في «حرب البارجة» لألعاب الطاولة العسكرية المصغّرة، بمطلقها الخاص `AbodenMilitaryLauncher`. فهرسها في [`MILITARY.md`](MILITARY.md). | AB-W-023 … AB-W-040 |

المعرّفات (id) لكل حزمة في كتالوجها: `cluster` المرحة (AB-W-020، قنبلة عنقودية) و`cluster` العسكرية (AB-W-027، صاروخ عنقودي) سلاحان مختلفان؛ الفريد في الحزمة كلها هو الرمز `AB-W-NNN`.

### طريقة الإيصال (delivery)

{axtab("delivery",[("projectile","جسم يطير في العالم خطوة بخطوة (له عمر ونصف قطر)."),("hitscan","حساب فوري على امتداد شعاع/قوس لحظة الإطلاق."),("area","تأثير يظهر في منطقة دون قذيفة تطير (فقاعة الدرع)."),("called","ضربة تُطلب على نقطة وتصل من خارج المشهد، كالغارة الجوية أو المدفعية البعيدة (الطائرة الهجومية AB-W-032).")])}

### المسار (trajectory)

{axtab("trajectory",[("straight","خط مستقيم بلا جاذبية."),("ballistic","قوس تحت الجاذبية."),("homing","يتجه إلى هدف يختاره."),("returning","يعود إلى اليد."),("floating","يطفو ويتمايل ببطء."),("held","لا يطير: يبقى أمام اليد ويتبعها (فقاعة الدرع)."),("lofted","قوس عالٍ جدًا ثم هبوط حاد نحو النقطة، كالصاروخ الباليستي المصغّر وعودته للغلاف (الحزمة العسكرية)."),("waypoints","يتبع نقاط مسار منخفضًا فوق التضاريس، كصاروخ كروز (الحزمة العسكرية)."),("vertical","يسقط من الأعلى على النقطة (خارق التحصينات AB-W-029)."),("intercept","يلاحق هدفًا جويًا لاعتراضه (صاروخ الدفاع الجوي AB-W-035).")])}

### نموذج الإصابة (hit model)

{axtab("hit",[("single","يصيب هدفًا واحدًا ويتوقف."),("pierce","يخترق أكثر من هدف ويكمل."),("chain","يقفز من هدف إلى الذي يليه."),("splash","يصيب كل ما في نصف قطر عند الانفجار/الرذاذ."),("bounce","يرتد ويكمل بعد الإصابة أو الارتطام."),("falloff","انفجار كبير يقل ضرره مع البعد عن المركز (مخطط)."),("lingering","منطقة تبقى وتؤثر مدة: دخان البخور، مجال المغناطيس، فقاعة الدرع."),("scan","لا ينفجر: يكشف ما تحته ويبلّغ المضيف (طائرة الاستطلاع AB-W-036).")])}

### الدور (role)

{axtab("role",[("attack","يصيب الأهداف."),("defence","يعترض قذائف الخصم أو طائراته أو يحمي (فقاعة الدرع، صاروخ الدفاع الجوي AB-W-035)."),("support","يعين ولا يؤذي مباشرة: كشف، تجميد، إبطاء، سحب، دفع، جذب (طائرة الاستطلاع AB-W-036؛ والمرحة تصيب كأي طلقة إن لم يعرف المضيف النداء الخاص).")])}

### الفئة / الندرة (tier)

مستوى الفتح كما رُتّب في اللعبة الأصلية (التحديات بالترتيب من الأسهل). الحزمة نفسها لا تقفل أي سلاح؛ الفئة بيانات للعبة التي تريد ذلك (`AbodenShotCatalog.available()`).

| الفئة | المعنى | الأسلحة |
|---|---|---|
''' 
TIERDEF=['مفتوح من البداية','أول التحديات','تحديات وسطى','تحديات متقدمة','آخر التحديات']
for t in range(5):
    ws=[f'{shots[i]["ar"]} — {unlock(i) if t else "—"}' for i in ORDER if int(shots[i]['tier'])==t]
    catmd+=f'| {TIER[t]} | {TIERDEF[t]} | {"<br>".join(ws)} |\n'
catmd+='''
### الحالة (status) والإصدار (version)

| الحالة | المعرّف | المعنى |
|---|---|---|
| مستقر | `stable` | مكتمل ومختبر (والاثنا عشر الأولى مطابقة لما في اللعبة). |
| تجريبي | `experimental` | يعمل ويمكن تجربته، لكن أرقامه أو شكله قد يتغيران. |
| مخطط | `planned` | فكرة محجوز لها رمز، غير مبرمجة بعد (انظر قائمة الأفكار). |

`version` هو إصدار الحزمة الذي غيّر السلاح آخر مرة (AB-W-001 … 012: v1.0، وAB-W-013 … 022: v1.2).

## نداءات المضيف الجديدة (v1.2)

كلها اختيارية كالبقية (`has_method`). الهدف فيها قاموس الهدف الناعم نفسه الذي أعطاه المضيف (أهداف المسرح تبقى عبر `shoot()`).

| النداء | من يستعمله | بدونه |
|---|---|---|
| `blaster_freeze(target, seconds)` | الثلج: جمّد الهدف `seconds` (3) بدل أن يُصاب | الشعاع يصيب الهدف (فرقعة) |
| `blaster_slow(target, factor, seconds)` | المبخرة: ما في السحابة يتحرك بـ `factor` (0.4) من سرعته `seconds` (0.5، يتجدد كل 0.25 ث) | الدخان شكل فقط |
| `blaster_pull(target, to, strength)` | حرّك الهدف نحو `to` (محلي) بـ `strength` وحدة لعبة في هذه الخطوة: الثقب الأسود والمغناطيس يسحبان، حبل الشماغ يسحب بدل الإصابة (والخرطوم إن لم يكن `blaster_push`: `to` خلف الهدف)؛ والمغناطيس يسحب به قذائف الخصم أيضًا | الثقب والمغناطيس: شكل فقط؛ الحبل: إصابة عادية |
| `blaster_push(target, velocity)` | خرطوم الماء: كل قطرة تعطي الهدف هذه السرعة (وحدات لعبة/ث) بعيدًا عنك، بدل الإصابة | `blaster_pull`، وإلا إصابة عادية |
| `blaster_threats() -> Array` | قذائف الخصم: `[{ref` أو `id, p: Vector3, r?, metal?}]` للدرع والمغناطيس | لا قذائف |
| `blaster_block(threat, at) -> bool` | أوقف الدرع أو المغناطيس هذه القذيفة عند `at`: دمّرها | لا شيء |

## إضافة سلاح جديد

1. **الرمز:** إن كانت الفكرة في [قائمة الأفكار](#قائمة-الأفكار--roadmap) فرمزها محجوز في `RESERVED` (انقله منها)، وإلا خذ `AbodenShotCatalog.next_code()` (الآن `AB-W-041`) وسجّلها أولًا. الرموز لا تُعاد أبدًا، حتى لو حُذف سلاح.
2. **مدخل الكتالوج:** أضف المعرّف إلى `ORDER` ومدخلًا في `SHOTS` (code, pack, ar, en, icon, sound, sounds, ar_desc, en_desc, tags, delivery, trajectory, hit, role, tier, status, version) واحذف رمزه من `RESERVED`.
3. **المعاملات:** أضف `SHOT_STYLE["<id>"]` بالوحدات الموثقة (speed, grav, life, r, cool, sk + معاملاته الخاصة).
4. **المجسم والمادة:** فرع في `_shot_node()` (أو رسم مع الشرر/الحشد) ومواصفات مواد في `MATS`.
5. **السلوك في `blaster.gd`:** الحركة في `_move()`، الأثر في `_trail()`، ما يحدث عند الإصابة في `_on_pop()` / `_on_solid()`، النهاية في `_finish()` (وأضفه إلى قائمة الأسلحة التي تنتهي بـ `_finish` في `step_blast`)، أو دالة فورية مثل `_laser()` تُستدعى من `fire()`.
6. **الأيقونة:** فرع في `shapes()` في `shot_icons.gd` وأضف المعرّف إلى `IDS`، ثم `godot --headless --path blaster-kit -s res://addons/aboden_blaster/tools/bake_icons.gd -- --docs=res://docs/icons`.
7. **الصوت:** ملف(ات) في `sounds/` ومدخل في `AbodenBlasterAudio.SFX` (أو استعمل صوتًا موجودًا). الأصوات المركّبة بالكود في `tools/gen_sounds.py` (`python3 tools/gen_sounds.py`).
8. **الاختبار:** أضف فحوصه في `tests/run_tests.gd` (الفحوص العامة لكل الأسلحة تشمله تلقائيًا) وتأكد من PASS.
9. **اللقطة:** أضف خطة في `SHOOT` في `demo/blaster_demo.gd` ثم `xvfb-run -a godot --rendering-driver opengl3 --path blaster-kit res://demo/blaster_demo.tscn -- --style=<id> --screenshot=res://docs/shots/<id>.png` وافتح الصورة للتأكد.
10. **التوثيق:** انسخ [`weapons/_TEMPLATE.md`](weapons/_TEMPLATE.md) إلى `weapons/AB-W-NNN_<id>.md` واملأه، وأضف صفًا في الجدول الملخص وفي جداول التصنيف، وانقل الفكرة من قائمة الأفكار.
11. **السجل:** سطر في [`CHANGELOG.md`](CHANGELOG.md) وارفع `version` في `plugin.cfg` عند الإصدار.

## الحزمة العسكرية

أسلحة البارجة من لعبة «حرب البارجة» (Table War) صارت حزمة عامة: ثمانية عشر سلاحًا بالرموز `AB-W-023` … `AB-W-040` (صاروخ باليستي، كروز، مدفعية، راجمة، عنقودي، فرط صوتي انزلاقي، خارق تحصينات تلقيه طائرة، مسيّرة انتحارية، مضاد للسفن، طائرة هجومية، قنبلة نووية، ومنذ v1.2: سرب مسيّرات، دفاع جوي، استطلاع، مضاد للدروع، قنابل انزلاقية، طوربيد، مروحية هجومية). لها كتالوجها `AbodenMilitaryCatalog` ومطلقها `AbodenMilitaryLauncher` (مسارات محسوبة إلى نقطة، تتبع تضاريس، سقف اختياري كالقبة الزجاجية، ذخيرة وتبريد وإعادة تعبئة، دفعات وقنيبلات وطلعات جوية، دخان وانفجارات ورذاذ ماء وفطر نووي) وسفينة إطلاق اختيارية `AbodenMilitaryShip`. الدليل الكامل والجدول وصفحة لكل سلاح: [`MILITARY.md`](MILITARY.md).

## قائمة الأفكار / Roadmap

أسلحة مخططة، لكل واحدة رمزها الدائم المحجوز في `AbodenShotCatalog.RESERVED`. الرموز العشرة التي حُجزت في v1.0 (`AB-W-013` … `AB-W-022`) صارت كلها أسلحة مستقرة في v1.2، فلا رمز محجوزًا الآن؛ الفكرة الجديدة تأخذ `AB-W-041` (023 إلى 040 للحزمة العسكرية) وتُسجّل هنا أولًا.

| الرمز المحجوز | الاسم | المعرّف المقترح | الحزمة | العائلة | الفكرة | الحالة |
|---|---|---|---|---|---|---|
'''
for code,ar,en,rid in RES:
    catmd+=f'| `{code}` | {ar} ({en}) | `{rid}` | مرحة | {IDEA[code][0]} | {IDEA[code][1]} | مخطط |\n'
catmd+='''| | | | | | | مخطط |
| | | | | | | مخطط |
| | | | | | | مخطط |
'''
open(ROOT+'/docs/CATALOG.md','w').write(catmd)
print(pages)
