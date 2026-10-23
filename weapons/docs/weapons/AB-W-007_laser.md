# AB-W-007 — ليزر (Laser)

[← فهرس الأسلحة](../CATALOG.md)

| | |
|---|---|
| ![Laser](../icons/laser.png) | ![Laser — لقطة](../shots/laser.png) |

| الحقل | القيمة |
|---|---|
| الرمز (code) | `AB-W-007` |
| الحزمة (pack) | مرحة (playful) |
| المعرّف (id) | `laser` |
| الاسم | ليزر (Laser) |
| الوصف | شعاع فوري يخترق حتى ٣ أهداف — *An instant beam through up to 3 targets* |
| العائلة (category) | فورية/شعاع (instant) |
| طريقة الإيصال (delivery) | شعاع فوري (hitscan) |
| المسار (trajectory) | مستقيم (straight) |
| نموذج الإصابة (hit) | اختراق (pierce) |
| الدور (role) | هجوم (attack) |
| الفئة/الندرة (tier) | 2 متوسط (Medium) |
| شرط الفتح الأصلي (origin unlock) | `skyPop5` — فجّر ٥ أهداف فوق رأسك (Pop 5 targets above your head)، الهدف 5 |
| الأيقونة | `addons/aboden_blaster/icons/laser.png` (`laser`) |
| الحالة (status) | مستقر (stable) |
| الإصدار (version) | v1.0 |

## السلوك

شعاع فوري (hitscan) بمدى 30 م: يصيب حتى 3 أهداف على امتداده بالترتيب (ناعمة أو أهداف مسرح) ويخترقها، ويتوقف عند أول جسم صلب لا يحتسب الإصابة (مع `thump`)، أو عند الأرض/جدار المضيف، أو داخل الهدف الثالث. يُحتسب عدد الأهداف عبر `blaster_credit("laser", n)`.

**مشترك بين كل الأسلحة:** تُطلق بـ `fire(hand, origin, dir)` أو `fire_at(origin, target_point, hand)` (يصوّب الاتجاه نحو النقطة)؛ الفوهة 0.08 م أمام نقطة الإطلاق؛ لكل يد مؤقّت `cool` خاص بها؛ الطلقة الثلاثية (`shot_fan()` = 3) تدوّر الاتجاه ±0.11 راديان (`FAN_STEP`) حول المحور العمودي؛ كل الأطوال × `blaster_scale()`.

## المعاملات (`AbodenShotCatalog.SHOT_STYLE["laser"]`)

| المعامل | القيمة | المعنى | الوحدة |
|---|---|---|---|
| `speed` | 0.0 | السرعة الابتدائية | م/ث |
| `grav` | 0.0 | الجاذبية (مضاعف g = 9.8 م/ث²؛ السالب يطفو) | × g |
| `life` | 0.25 | العمر الأقصى | ث |
| `r` | 0.015 | نصف قطر الإصابة | م |
| `cool` | 0.32 | أقل فاصل بين طلقتين لليد نفسها (معدل الإطلاق عند الضغط المستمر) | ث |
| `range` | 30.0 | المدى | م |
| `pierce` | 3 | أقصى عدد أهداف يخترقها الشعاع | عدد |
| `sk` | 0.5 | قيمة k لصوت الإطلاق (الشدة/الطبقة) | — |

## المظهر

- **الشعاع:** خط متوهج ‎#ff3b6b بعرض 0.022 م بطبقتين (هالة ملوّنة شفافية 0.6 ونواة فاتحة)، يخبو خلال 0.25 ث (عرضه ينكمش إلى 40%).
- **الإصابة:** `impact()` وردي عند كل هدف، وفي نهاية الشعاع إن لم يُحجب.
- **وميض الفوهة:** ‎#ff6b8f.

## الأصوات

- pew — طلقة (3 نسخ عشوائية) ← **صوت الإطلاق**
- thump — ارتطام بجسم صلب لا يُحتسب (k 0.25)

## ملاحظات الضبط

`pierce` هو عدد الأهداف المخترقة، و`range` المدى. الشعاع لا يتأثر بالجاذبية ولا يملك قذيفة (`shot_count()` يبقى 0؛ الخط في `arcs`).

## الاختبارات (`tests/run_tests.gd`)

- laser: an instant beam pierces three targets and stops in the third
- laser: its three hits are credited
- laser: the beam ends at the last one it went through
- laser: the glowing line fades
- laser: through two targets and a soft one, stopped by a wall
- walls: the laser's beam ends at it

## سجل التغييرات

| الإصدار | التاريخ | التغيير |
|---|---|---|
| v1.0 | 2026-10-17 | الإصدار الأول (الأرقام والسلوك مطابقة للأصل؛ انظر CHANGELOG). |
