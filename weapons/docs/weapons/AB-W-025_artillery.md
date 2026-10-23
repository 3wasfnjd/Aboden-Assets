# AB-W-025 — قذيفة مدفعية (Artillery shell)

[← الحزمة العسكرية](../MILITARY.md) · [فهرس الأسلحة](../CATALOG.md)

<img src="../icons/mil_artillery.png" width="128">

| الحقل | القيمة |
|---|---|
| الرمز (code) | `AB-W-025` |
| الحزمة (pack) | عسكرية (military) |
| المعرّف (id) | `artillery` |
| الاسم | قذيفة مدفعية (Artillery shell) |
| الاسم القصير | مدفعية |
| مثال حقيقي (example) | M777 |
| الوصف | قذائف سريعة كثيرة بقوس منخفض · انفجار صغير — *Fast, plentiful shells on a low arc; a small blast* |
| طريقة الإيصال (delivery) | قذيفة (projectile) |
| المسار (trajectory) | قوسي (ballistic) |
| نموذج الإصابة (hit) | انفجار/رذاذ (splash) |
| الدور (role) | هجوم (attack) |
| الفئة (tier) | 0 أساسي (Starter) |
| المطلق (launcher) | مدفع المقدمة (`gun`) |
| احتمال الاعتراض في اللعبة (intercept) | 0 |
| الأيقونة | `addons/aboden_blaster/military/icons/artillery.png` |
| الحالة (status) | مستقر (stable) |
| الإصدار (version) | v1.1 |

## المعاملات (`AbodenMilitaryCatalog.WEAPONS["artillery"]`)

| المعامل | القيمة |
|---|---|
| `arc` | low |
| `flight` | [1.5, 1.8] |
| `blast` | 0.6 |
| `ejecta` | 30 |
| `cooldown` | 0.8 |
| `ammo` | 30 |
| `reload` | 2 |
| `glow` | false |
| `trail` | 0.03 |
| `length` | 0.0018 |
| `radius` | 0.0006 |
| `col` | `#595c54` |

## السلوك

—.

قوس باليستي منخفض وسريع إلى الهدف بالضبط (زمن الرحلة بين حدّي `flight`).

## المظهر

- **الصورة:** ![Artillery shell](../shots/mil_artillery.png)
- **المجسم:** `AbodenMilitaryLooks.body()`، أسطوانة بمخروط مقدمة باللون `col`.
- **الأثر:** نفخة دخان كل `trail` ثانية باللون `trail_col`.
- **الارتطام:** على اليابسة وميض وكرة نار وحلقة غبار وعمود دخان؛ في الماء عمود ماء ورذاذ ورغوة وتموجات.

## الأصوات

- `launch` عند الإطلاق، `boom` عند الانفجار على اليابسة، `thump` في الماء (عبر `military_sfx` أو المشغّل المدمج: whoosh و boom و splash).
