# AB-W-029 — خارق التحصينات (Bunker buster)

[← الحزمة العسكرية](../MILITARY.md) · [فهرس الأسلحة](../CATALOG.md)

<img src="../icons/mil_bunker.png" width="128">

| الحقل | القيمة |
|---|---|
| الرمز (code) | `AB-W-029` |
| الحزمة (pack) | عسكرية (military) |
| المعرّف (id) | `bunker` |
| الاسم | خارق التحصينات (Bunker buster) |
| الاسم القصير | خارقة تحصينات |
| مثال حقيقي (example) | GBU-57 |
| الوصف | قنبلة ثقيلة تحملها طائرة هجومية وتلقيها فوق الهدف · حفرة عميقة للمخابئ — *A heavy bomb a strike jet carries and drops over the target; a deep crater for bunkers* |
| طريقة الإيصال (delivery) | ضربة مُستدعاة (called) |
| المسار (trajectory) | من الأعلى (vertical) |
| نموذج الإصابة (hit) | انفجار/رذاذ (splash) |
| الدور (role) | هجوم (attack) |
| الفئة (tier) | 3 متقدم (Advanced) |
| المطلق (launcher) | سطح الطيران (`deck`) |
| احتمال الاعتراض في اللعبة (intercept) | 0.35 |
| الأيقونة | `addons/aboden_blaster/military/icons/bunker.png` |
| الحالة (status) | مستقر (stable) |
| الإصدار (version) | v1.2 |

## المعاملات (`AbodenMilitaryCatalog.WEAPONS["bunker"]`)

| المعامل | القيمة |
|---|---|
| `arc` | sortie |
| `speed` | 0.14 |
| `cruise_alt` | 0.1 |
| `blast` | 1.15 |
| `crater_k` | 2.2 |
| `ejecta` | 110 |
| `cooldown` | 2 |
| `ammo` | 2 |
| `reload` | 0 |
| `bombs` | 1 |
| `bomb` | bunkerbomb |
| `spread` | 0 |
| `glow` | false |
| `wings` | true |
| `trail` | 0.05 |
| `length` | 0.0038 |
| `radius` | 0.0006 |
| `col` | `#808a94` |

## السلوك

1 قنبلة خارقة (`bunkerbomb`) ضمن 0 قبل الهدف بـ 0.035 ثم تعود وتهبط، حفرة أعمق × 2.2.

تقلع من سطح الطيران، تصعد إلى `cruise_alt` فوق أعلى نقطتي الإقلاع والهدف، تطلق حمولتها (`bunkerbomb`) قبل الهدف بـ 0.035، تكمل وتستدير وتعود من الخلف لتهبط على السطح، فتعود ذخيرتها (`sortie_landed`). لا تلمس التضاريس، وتبقى تحت السقف إن وُجد. إن أسقطها المضيف (`shoot_down`) ضاعت (`sortie_lost`) ووصلت بديلة بعد 25 ث.

القنبلة الخارقة تسقط شبه عمودية من ارتفاع الطائرة (0.8–0.9 ث) وتحفر حفرة أعمق × 2.2 (`crater_d`).

## المظهر

- **الصورة:** ![Bunker buster](../shots/mil_bunker.png)
- **المجسم:** `AbodenMilitaryLooks.body()`، أسطوانة بمخروط مقدمة باللون `col`، وأجنحة، وذيل وموازن وقمرة.
- **الأثر:** نفخة دخان كل `trail` ثانية باللون `trail_col`.
- **الارتطام:** على اليابسة وميض وكرة نار وحلقة غبار وعمود دخان؛ في الماء عمود ماء ورذاذ ورغوة وتموجات.

## الأصوات

- `launch` عند الإطلاق، `boom` عند الانفجار على اليابسة، `thump` في الماء (عبر `military_sfx` أو المشغّل المدمج: whoosh و boom و splash).
