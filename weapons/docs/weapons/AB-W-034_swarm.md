# AB-W-034 — سرب مسيّرات (Drone swarm)

[← الحزمة العسكرية](../MILITARY.md) · [فهرس الأسلحة](../CATALOG.md)

<img src="../icons/mil_swarm.png" width="128">

| الحقل | القيمة |
|---|---|
| الرمز (code) | `AB-W-034` |
| الحزمة (pack) | عسكرية (military) |
| المعرّف (id) | `swarm` |
| الاسم | سرب مسيّرات (Drone swarm) |
| الاسم القصير | سرب مسيّرات |
| مثال حقيقي (example) | Lancet |
| الوصف | 6 مسيّرات صغيرة متتالية تتوزع على الهدف · دقيقة · انفجارات صغيرة — *6 small drones one after another, spread over the target; precise, small blasts* |
| طريقة الإيصال (delivery) | قذيفة (projectile) |
| المسار (trajectory) | نقاط مسار منخفضة (waypoints) |
| نموذج الإصابة (hit) | انفجار/رذاذ (splash) |
| الدور (role) | هجوم (attack) |
| الفئة (tier) | 2 متوسط (Medium) |
| المطلق (launcher) | منحدر المسيّرات (`ramp`) |
| احتمال الاعتراض في اللعبة (intercept) | 0.6 |
| الأيقونة | `addons/aboden_blaster/military/icons/swarm.png` |
| الحالة (status) | مستقر (stable) |
| الإصدار (version) | v1.2 |

## المعاملات (`AbodenMilitaryCatalog.WEAPONS["swarm"]`)

| المعامل | القيمة |
|---|---|
| `arc` | cruise |
| `flight` | [2, 9] |
| `speed` | 0.26 |
| `cruise_alt` | 0.016 |
| `blast` | 0.35 |
| `ejecta` | 8 |
| `cooldown` | 6 |
| `ammo` | 3 |
| `reload` | 12 |
| `salvo` | 6 |
| `salvo_gap` | 0.22 |
| `spread` | 0.022 |
| `glow` | false |
| `wings` | true |
| `trail` | 0.3 |
| `length` | 0.0017 |
| `radius` | 0.0003 |
| `col` | `#bdc2b8` |

## السلوك

دفعة 6 مسيّرات (كل 220 م.ث) ضمن 0.022.

يخرج من القاذف وينزل بميل محدود إلى ارتفاع `cruise_alt` فوق التضاريس أو البحر، وينظر 4 سم أمامه ليصعد قبل التلال (أقصى ميل صعود 0.9)، ثم ينقضّ على الهدف في آخر 2.2 سم. إن كان التل أشد انحدارًا من حد الصعود اصطدم به وانفجر هناك (`crash` في المسار).

مع `military_roof` يصعد فوق المباني القائمة في طريقه في الوقت المناسب (برج أشد انحدارًا من أي تل) وينقضّ على هدف خلفها. وينفجر في نهاية مساره دائمًا حتى لو حفر المضيف الأرض هناك.

## المظهر

- **الصورة:** ![Drone swarm](../shots/mil_swarm.png)
- **المجسم:** `AbodenMilitaryLooks.body()`، أسطوانة بمخروط مقدمة باللون `col`، وأجنحة.
- **الأثر:** نفخة دخان كل `trail` ثانية باللون `trail_col`.
- **الارتطام:** على اليابسة وميض وكرة نار وحلقة غبار وعمود دخان؛ في الماء عمود ماء ورذاذ ورغوة وتموجات.

## الأصوات

- `launch` عند الإطلاق، `boom` عند الانفجار على اليابسة، `thump` في الماء (عبر `military_sfx` أو المشغّل المدمج: whoosh و boom و splash).
