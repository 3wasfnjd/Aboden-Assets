# AB-W-NNN — الاسم العربي (English Name)

<!-- قالب صفحة سلاح جديد. انسخه إلى docs/weapons/AB-W-NNN_<id>.md واملأ كل حقل.
     الرمز من AbodenShotCatalog.RESERVED أو next_code()، ولا يُعاد استخدامه أبدًا. -->

[← فهرس الأسلحة](../CATALOG.md)

| | |
|---|---|
| ![English Name](../icons/<id>.png) | ![English Name — لقطة](../shots/<id>.png) |

| الحقل | القيمة |
|---|---|
| الرمز (code) | `AB-W-NNN` |
| الحزمة (pack) | مرحة (playful) / عسكرية (military) |
| المعرّف (id) | `<id>` |
| الاسم | الاسم العربي (English Name) |
| الوصف | سطر عربي — *one English line* |
| العائلة (category) | من: قذيفة مباشرة (direct)، باليستية (ballistic)، فورية/شعاع (instant)، منطقة تأثير/انفجار (area)، موجّهة (homing)، مرتدّة/عائدة (returning)، رشّ/متعدد (spray)، ارتداد/نطّ (bouncing) |
| طريقة الإيصال (delivery) | projectile / hitscan / area / called |
| المسار (trajectory) | straight / ballistic / homing / returning / floating / lofted / waypoints / vertical / intercept |
| نموذج الإصابة (hit) | single / pierce / chain / splash / bounce / falloff / lingering |
| الدور (role) | attack / defence / support |
| الفئة/الندرة (tier) | 0 أساسي … 4 نخبة |
| شرط الفتح (unlock) | لا شيء، أو معرّف تحدٍّ في `CHALLENGES` |
| الأيقونة | `addons/aboden_blaster/icons/<id>.png` |
| الحالة (status) | مخطط (planned) / تجريبي (experimental) / مستقر (stable) |
| الإصدار (version) | vX.Y |

## السلوك

كيف يطير أو يعمل، متى يتوقف، ماذا يحدث عند الإصابة وعند الارتطام وعند انتهاء العمر، وأي نداءات للمضيف يستعمل (`blaster_hit`، `blaster_credit`، نداء جديد إن وُجد مع قيمته الافتراضية).

## المعاملات (`AbodenShotCatalog.SHOT_STYLE["<id>"]`)

| المعامل | القيمة | المعنى | الوحدة |
|---|---|---|---|
| `speed` | | السرعة الابتدائية | م/ث |
| `grav` | | الجاذبية (مضاعف g) | × g |
| `life` | | العمر الأقصى | ث |
| `r` | | نصف قطر الإصابة | م |
| `cool` | | أقل فاصل بين طلقتين لليد | ث |
| `sk` | | قيمة k لصوت الإطلاق | — |
| `...` | | معاملاته الخاصة | |

## المظهر

- **المجسم:** (فرع `_shot_node` أو رسم مع الشرر/الحشد) والمواد في `MATS` بألوانها (hex).
- **الأثر:** (`_trail`).
- **الإصابة/النهاية:** (`impact` / دالة خاصة).
- **وميض الفوهة:** (`MUZZLE`).

## الأصوات

- `name` — متى يُسمع وبأي k (وإن كان ملفًا جديدًا: مصدره وطريقة صنعه).

## ملاحظات الضبط

أي المعاملات تغيّر ماذا، وحدود الأداء (عدد القذائف، الشرر).

## الاختبارات (`tests/run_tests.gd`)

- الفحوص العامة (كل سلاح يُطلق بصوته، يحترم cool لكل يد، يفرقع هدفًا ناعمًا، يصيب هدف مسرح) — تشمله تلقائيًا.
- فحوصه الخاصة: …

## سجل التغييرات

| الإصدار | التاريخ | التغيير |
|---|---|---|
| vX.Y | YYYY-MM-DD | … |
