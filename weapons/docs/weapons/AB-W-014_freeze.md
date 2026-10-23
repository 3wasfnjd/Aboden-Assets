# AB-W-014 — الثلج (Freeze Ray)

[← فهرس الأسلحة](../CATALOG.md)

| | |
|---|---|
| ![Freeze Ray](../icons/freeze.png) | ![Freeze Ray — لقطة](../shots/freeze.png) |

| الحقل | القيمة |
|---|---|
| الرمز (code) | `AB-W-014` |
| الحزمة (pack) | مرحة (playful) |
| المعرّف (id) | `freeze` |
| الاسم | الثلج (Freeze Ray) |
| الوصف | شعاع جليدي فوري يجمّد الهدف ثلاث ثوانٍ — *An instant icy beam that freezes a target for three seconds* |
| العائلة (category) | فورية/شعاع (instant) |
| طريقة الإيصال (delivery) | شعاع فوري (hitscan) |
| المسار (trajectory) | مستقيم (straight) |
| نموذج الإصابة (hit) | هدف واحد (single) |
| الدور (role) | إسناد (support) |
| الفئة/الندرة (tier) | 2 متوسط (Medium) |
| شرط الفتح الأصلي (origin unlock) | لا شرط (سلاح جديد في v1.2، لم يكن في اللعبة الأصلية) |
| الأيقونة | `addons/aboden_blaster/icons/freeze.png` (`freeze`) |
| الحالة (status) | مستقر (stable) |
| الإصدار (version) | v1.2 |

## السلوك

شعاع جليدي فوري (hitscan) بمدى 12 م: شعاع الليزر نفسه (`_laser(..., "freeze")`) لهدف واحد (`pierce` 1). عند هدف ناعم: إن كان للمضيف **النداء الجديد `blaster_freeze(target, seconds)`** يُجمَّد الهدف 3 ث (`frost`) بدل أن يُصاب (ويُبث `shot_hit`)؛ وبدونه يُصاب كأي طلقة (`blaster_hit` ثم فرقعة). هدف المسرح يأخذ الإصابة عبر `shoot()` كالعادة. في الحالتين: صوت تكسّر جليد (`ice_crack`) وبلورات صقيع وقشرة ثلج فوق الهدف طوال التجميد (تختفي إن اختفى الهدف). يتوقف عند جدار أو الأرض. يُحتسب عبر `blaster_credit("freeze", n)`.

**مشترك بين كل الأسلحة:** تُطلق بـ `fire(hand, origin, dir)` أو `fire_at(origin, target_point, hand)` (يصوّب الاتجاه نحو النقطة)؛ الفوهة 0.08 م أمام نقطة الإطلاق؛ لكل يد مؤقّت `cool` خاص بها؛ الطلقة الثلاثية (`shot_fan()` = 3) تدوّر الاتجاه ±0.11 راديان (`FAN_STEP`) حول المحور العمودي؛ كل الأطوال × `blaster_scale()`.

## المعاملات (`AbodenShotCatalog.SHOT_STYLE["freeze"]`)

| المعامل | القيمة | المعنى | الوحدة |
|---|---|---|---|
| `speed` | 0.0 | السرعة الابتدائية | م/ث |
| `grav` | 0.0 | الجاذبية (مضاعف g = 9.8 م/ث²؛ السالب يطفو) | × g |
| `life` | 0.3 | العمر الأقصى | ث |
| `r` | 0.02 | نصف قطر الإصابة | م |
| `cool` | 0.5 | أقل فاصل بين طلقتين لليد نفسها (معدل الإطلاق عند الضغط المستمر) | ث |
| `range` | 12.0 | المدى | م |
| `pierce` | 1 | أقصى عدد أهداف يخترقها الشعاع | عدد |
| `frost` | 3.0 | مدة التجميد التي تُعطى للمضيف (`blaster_freeze`) | ث |
| `sk` | 0.6 | قيمة k لصوت الإطلاق (الشدة/الطبقة) | — |

## المظهر

- **الشعاع:** خط ‎#9fe8ff بعرض 0.016 م يخبو خلال 0.3 ث، وبريق صقيع (رقائق بيضاء وزرقاء ترفرف) على امتداده.
- **عند الهدف (`_frost`):** 14 بلورة تتطاير، وقشرة ثلج شفافة (شفافية 0.38) بحجم 1.12 من الهدف مع لمعات بيضاء، تخبو في آخر 0.4 ث (`auras`).
- **وميض الفوهة:** ‎#bfefff.

## الأصوات

- ice_zap — طلقة زجاجية هابطة ببريق (3 نسخ، k 0.6) ← **صوت الإطلاق**
- ice_crack — تكسّر جليد: نقرات حادة وطقطقة ورنين (3 نسخ، k 0.8)
- thump — ارتطام بجسم صلب لا يُحتسب (k 0.25)

الأصوات الجديدة في v1.2 مُركّبة بالكود (ضوضاء ومرشحات ومسارات تردد وأغلفة، بلا تسجيل) عبر `tools/gen_sounds.py`، بصيغة الملفات الأخرى (أحادية 22050 هرتز 16 بت).

## ملاحظات الضبط

`frost` مدة التجميد التي تُعطى للمضيف، و`range` المدى (أقصر من الليزر). الشعاع لا يملك قذيفة (`shot_count()` يبقى 0؛ الخط في `arcs`).

## الاختبارات (`tests/run_tests.gd`)

- freeze: the beam freezes the first target for 3 s (blaster_freeze), instead of popping it
- freeze: an instant icy beam (ice_zap), the ice cracks (ice_crack) and a frost shell covers it
- freeze: the frost shell lasts while it is frozen
- freeze: a short beam: nothing beyond 12 m
- freeze: a stage target takes it (shoot) and frosts over
- freeze: without blaster_freeze the beam hits (pops) the target

## سجل التغييرات

| الإصدار | التاريخ | التغيير |
|---|---|---|
| v1.2 | 2026-10-23 | جديد: من الرموز المحجوزة إلى سلاح مستقر (أرقامه ومجسمه وأصواته وأيقونته واختباراته؛ انظر CHANGELOG). |
