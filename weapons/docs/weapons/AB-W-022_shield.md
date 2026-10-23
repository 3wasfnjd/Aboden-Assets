# AB-W-022 — الدرع (Shield Bubble)

[← فهرس الأسلحة](../CATALOG.md)

| | |
|---|---|
| ![Shield Bubble](../icons/shield.png) | ![Shield Bubble — لقطة](../shots/shield.png) |

| الحقل | القيمة |
|---|---|
| الرمز (code) | `AB-W-022` |
| الحزمة (pack) | مرحة (playful) |
| المعرّف (id) | `shield` |
| الاسم | الدرع (Shield Bubble) |
| الوصف | فقاعة درع أمام يدك تصد القذائف ثلاث ثوانٍ — *A shield bubble at your hand that stops projectiles for three seconds* |
| العائلة (category) | دفاع/حماية (defence) |
| طريقة الإيصال (delivery) | منطقة (area) |
| المسار (trajectory) | مع اليد (held) |
| نموذج الإصابة (hit) | منطقة باقية (lingering) |
| الدور (role) | دفاع/اعتراض (defence) |
| الفئة/الندرة (tier) | 2 متوسط (Medium) |
| شرط الفتح الأصلي (origin unlock) | لا شرط (سلاح جديد في v1.2، لم يكن في اللعبة الأصلية) |
| الأيقونة | `addons/aboden_blaster/icons/shield.png` (`shield`) |
| الحالة (status) | مستقر (stable) |
| الإصدار (version) | v1.2 |

## السلوك

فقاعة درع (نصف قطرها 0.45 م، `r`) تظهر 0.45 م (`ahead`) أمام اليد على اتجاه الإطلاق وتتبع اليد (`blaster_hand(hand)`؛ بلا مضيف تبقى حيث أُطلقت) مدة 3 ث. لا تصيب الأهداف ولا ترتطم بشيء. كل قذيفة خصم يبلغ عنها المضيف عبر **`blaster_threats()`** وتصل جلد الفقاعة تُوقف عبر **`blaster_block(threat, at)`** (`at` على سطح الفقاعة، والمضيف يدمرها)، مرة واحدة لكل قذيفة: تومض الفقاعة وتهتز اليد ويُسمع `shield_block` ويُحتسب `blaster_credit("shield", 1)` ويُبث `shot_hit("shield", threat)`. فقاعة واحدة لكل يد: الجديدة تأخذ مكان السابقة (والطلقة الثلاثية فقاعة واحدة). في النهاية تفرقع (`start_pop`). بلا `blaster_threats` تبقى فقاعة تُرى فقط. لأنها لا تصيب، تستثنيها الفحوص العامة «تفرقع هدفًا ناعمًا» و«تصيب هدف مسرح».

**مشترك بين كل الأسلحة:** تُطلق بـ `fire(hand, origin, dir)` أو `fire_at(origin, target_point, hand)` (يصوّب الاتجاه نحو النقطة)؛ الفوهة 0.08 م أمام نقطة الإطلاق؛ لكل يد مؤقّت `cool` خاص بها؛ الطلقة الثلاثية (`shot_fan()` = 3) تدوّر الاتجاه ±0.11 راديان (`FAN_STEP`) حول المحور العمودي؛ كل الأطوال × `blaster_scale()`.

## المعاملات (`AbodenShotCatalog.SHOT_STYLE["shield"]`)

| المعامل | القيمة | المعنى | الوحدة |
|---|---|---|---|
| `speed` | 0.0 | السرعة الابتدائية | م/ث |
| `grav` | 0.0 | الجاذبية (مضاعف g = 9.8 م/ث²؛ السالب يطفو) | × g |
| `life` | 3.0 | العمر الأقصى | ث |
| `r` | 0.45 | نصف قطر الإصابة | م |
| `cool` | 4.0 | أقل فاصل بين طلقتين لليد نفسها (معدل الإطلاق عند الضغط المستمر) | ث |
| `ahead` | 0.45 | بعد مركز الفقاعة أمام اليد (و`r` نصف قطرها) | م |
| `sk` | 0.6 | قيمة k لصوت الإطلاق (الشدة/الطبقة) | — |

## المظهر

- **المجسم:** كرة بـ `SHIELD_SHADER` (`AbodenShotLooks.shield_material()`، مادة لكل فقاعة): سماوية، شبه شفافة في وسطها ولامعة عند حافتها (Fresnel)، بشبكة خلايا خفيفة؛ تومض (`flash`) عند كل صدّ، تظهر خلال 0.15 ث وتخبو في آخر 0.3 ث، وتهتز قليلًا عند الفتح والصدّ.
- **الصدّ:** حلقة من 12 شرارة سماوية من نقطة الصدّ. **بلا وميض فوهة.**

## الأصوات

- shield_up — وتر صاعد متلألئ حين تنفتح الفقاعة (k 0.6) ← **صوت الإطلاق**
- shield_block — «بوونغ» رنان وضربة خفيفة عند صدّ قذيفة (3 نسخ، k 0.9)
- start_pop — فرقعة

الأصوات الجديدة في v1.2 مُركّبة بالكود (ضوضاء ومرشحات ومسارات تردد وأغلفة، بلا تسجيل) عبر `tools/gen_sounds.py`، بصيغة الملفات الأخرى (أحادية 22050 هرتز 16 بت).

## ملاحظات الضبط

`r` حجم الفقاعة، و`ahead` بعدها عن اليد، و`life` مدتها، و`cool` = 4 ث يمنع إبقاءها دائمًا.

## الاختبارات (`tests/run_tests.gd`)

- shield: a bubble opens 0.45 m in front of the hand (shield_up)
- shield: it rides the hand (blaster_hand)
- shield: a projectile reaching it is stopped at its skin (blaster_block, shield_block), one out of reach is not
- shield: it pops nothing (a defence only)
- shield: one bubble a hand (a new one takes the last one's place)
- shield: they pop after 3 s
- shield: with no host it still opens and draws, where it was fired

## سجل التغييرات

| الإصدار | التاريخ | التغيير |
|---|---|---|
| v1.2 | 2026-10-23 | جديد: من الرموز المحجوزة إلى سلاح مستقر (أرقامه ومجسمه وأصواته وأيقونته واختباراته؛ انظر CHANGELOG). |
