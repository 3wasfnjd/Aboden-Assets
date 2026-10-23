# AB-W-030 — مسيّرة انتحارية (Kamikaze drone)

[← الحزمة العسكرية](../MILITARY.md) · [فهرس الأسلحة](../CATALOG.md)

<img src="../icons/mil_drone.png" width="128">

| الحقل | القيمة |
|---|---|
| الرمز (code) | `AB-W-030` |
| الحزمة (pack) | عسكرية (military) |
| المعرّف (id) | `drone` |
| الاسم | مسيّرة انتحارية (Kamikaze drone) |
| الاسم القصير | مسيّرة انتحارية |
| مثال حقيقي (example) | Shahed-136 |
| الوصف | بطيئة على ارتفاع فوق التضاريس · دقيقة · انفجار صغير — *Slow, high over the terrain; precise, a small blast* |
| طريقة الإيصال (delivery) | قذيفة (projectile) |
| المسار (trajectory) | نقاط مسار منخفضة (waypoints) |
| نموذج الإصابة (hit) | انفجار/رذاذ (splash) |
| الدور (role) | هجوم (attack) |
| الفئة (tier) | 1 سهل (Easy) |
| المطلق (launcher) | منحدر المسيّرات (`ramp`) |
| احتمال الاعتراض في اللعبة (intercept) | 0.75 |
| الأيقونة | `addons/aboden_blaster/military/icons/drone.png` |
| الحالة (status) | مستقر (stable) |
| الإصدار (version) | v1.2 |

## المعاملات (`AbodenMilitaryCatalog.WEAPONS["drone"]`)

| المعامل | القيمة |
|---|---|
| `arc` | cruise |
| `flight` | [2.5, 8] |
| `speed` | 0.22 |
| `cruise_alt` | 0.02 |
| `blast` | 0.7 |
| `ejecta` | 30 |
| `cooldown` | 2.5 |
| `ammo` | 10 |
| `reload` | 5 |
| `glow` | false |
| `wings` | true |
| `trail` | 0.25 |
| `length` | 0.0026 |
| `radius` | 0.0004 |
| `col` | `#dbdbd1` |

## السلوك

—.

يخرج من القاذف وينزل بميل محدود إلى ارتفاع `cruise_alt` فوق التضاريس أو البحر، وينظر 4 سم أمامه ليصعد قبل التلال (أقصى ميل صعود 0.9)، ثم ينقضّ على الهدف في آخر 2.2 سم. إن كان التل أشد انحدارًا من حد الصعود اصطدم به وانفجر هناك (`crash` في المسار).

مع `military_roof` يصعد فوق المباني القائمة في طريقه في الوقت المناسب (برج أشد انحدارًا من أي تل) وينقضّ على هدف خلفها. وينفجر في نهاية مساره دائمًا حتى لو حفر المضيف الأرض هناك.

## المظهر

- **الصورة:** ![Kamikaze drone](../shots/mil_drone.png)
- **المجسم:** `AbodenMilitaryLooks.body()`، أسطوانة بمخروط مقدمة باللون `col`، وأجنحة.
- **الأثر:** نفخة دخان كل `trail` ثانية باللون `trail_col`.
- **الارتطام:** على اليابسة وميض وكرة نار وحلقة غبار وعمود دخان؛ في الماء عمود ماء ورذاذ ورغوة وتموجات.

## الأصوات

- `launch` عند الإطلاق، `boom` عند الانفجار على اليابسة، `thump` في الماء (عبر `military_sfx` أو المشغّل المدمج: whoosh و boom و splash).
