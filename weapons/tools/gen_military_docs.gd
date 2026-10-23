extends SceneTree
## Writes the military pack's docs from AbodenMilitaryCatalog (the single source of truth):
## docs/MILITARY.md (guide + table), docs/weapons/AB-W-0NN_<id>.md (one page per weapon)
## and docs/weapons.json (every weapon of the kit, both packs, for the weapons page).
##
##   godot --headless --path blaster-kit -s res://tools/gen_military_docs.gd

const Mil := preload("res://addons/aboden_blaster/military/military_catalog.gd")
const Shots := preload("res://addons/aboden_blaster/shot_catalog.gd")

const ARC := {
	"lofted": ["قوس عالٍ", "lofted arc"], "low": ["قوس منخفض سريع", "low, fast arc"],
	"cruise": ["مسار يتبع التضاريس", "terrain-following path"], "sortie": ["طلعة ذهاب وعودة", "round-trip sortie"],
	"glide": ["انزلاق فرط صوتي متمايل", "weaving hypersonic glide"], "torpedo": ["تحت سطح الماء", "under the water surface"],
	"intercept": ["ملاحقة هدف جوي", "homing on an air target"],
}
## What an aircraft releases, in Arabic (SUB ids).
const LOAD := {"jetbomb": "قنابل", "gbomb": "قنابل انزلاقية", "hrocket": "صواريخ", "bunkerbomb": "قنبلة خارقة"}
const LAUNCHER := {
	"vls": ["خلايا الإطلاق العمودي", "vertical launch cells"], "box": ["قواذف الصناديق المائلة", "angled box launchers"],
	"gun": ["مدفع المقدمة", "bow gun"], "pod": ["حاضنة الراجمة", "rocket pod"], "ramp": ["منحدر المسيّرات", "drone ramp"],
	"silo": ["فتحة الصومعة النووية", "nuclear silo hatch"], "deck": ["سطح الطيران", "flight deck"],
	"tube": ["أنبوب الطوربيد", "torpedo tube"],
}


func _initialize() -> void:
	var root := ProjectSettings.globalize_path("res://")
	var err := _write(root + "docs/MILITARY.md", _guide())
	for id: String in Mil.ids():
		var w := Mil.get_weapon(id)
		err = maxi(err, _write(root + "docs/weapons/%s_%s.md" % [w.code, id], _page(w)))
	err = maxi(err, _write(root + "docs/weapons.json", JSON.stringify(_json(), "  ", false) + "\n"))
	print("gen_military_docs: ", error_string(err))
	quit(0 if err == OK else 1)


func _write(path: String, text: String) -> Error:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(text)
	return OK


static func _ax(axis: String, v: String) -> String:
	var t: Array = Shots.AXES[axis][v]
	return "%s (%s)" % [t[0], v]


static func _tier(t: int) -> String:
	return "%d %s (%s)" % [t, Shots.TIERS[t][0], Shots.TIERS[t][1]]


static func _num(x: float) -> String:
	var s := "%.4f" % x
	while s.ends_with("0"):
		s = s.trim_suffix("0")
	return s.trim_suffix(".")


## What a weapon does in one short line of numbers.
static func _special(w: Dictionary) -> String:
	var out: Array = []
	if w.has("salvo"):
		out.append("دفعة %d %s (كل %d م.ث) ضمن %s" % [int(w.salvo), "مسيّرات" if String(w.arc) == "cruise" else "صواريخ",
			int(round(float(w.get("salvo_gap", 0.09)) * 1000.0)), _num(w.spread)])
	if w.has("split"):
		out.append("%d قنيبلات عند %d٪ من الرحلة ضمن %s" % [int(w.split), int(Mil.SPLIT_AT * 100), _num(w.spread)])
	if w.has("orbit"):
		out.append("دورتان بنصف قطر %s حول الهدف، تكشف ضمن %s، بلا انفجار، ثم تعود وتهبط" % [_num(w.orbit), _num(w.scan_r)])
	elif int(w.get("bombs", 0)) > 0:
		out.append("%d %s (`%s`) ضمن %s قبل الهدف بـ %s ثم تعود وتهبط" % [int(w.bombs), LOAD.get(String(w.bomb), "قنابل"), w.bomb, _num(w.spread),
			_num(float(w.get("release_lead", 0.035)))])
	if String(w.arc) == "intercept":
		out.append("يلاحق هدفًا جويًا بسرعة %s وينفجر على بعد %s منه، يدمر نفسه بعد %s ث" % [_num(w.speed), _num(w.kill_r), _num(w.life)])
	if String(w.arc) == "torpedo":
		out.append("يجري تحت السطح بـ 1.6 مم ويتوقف عند الشاطئ")
	if bool(w.get("anti_armor", false)):
		out.append("يعطّل الدروع ضمن نصف قطر الانفجار × %s" % _num(w.armor_k))
	if bool(w.get("nuke", false)):
		out.append("نصف قطر التدمير %s، موجة صدمة إلى × %s في %s ث" % [_num(w.nuke_r), _num(w.wave_k), _num(w.wave_t)])
	if float(w.get("crater_k", 1.0)) != 1.0:
		out.append("حفرة أعمق × %s" % _num(w.crater_k))
	if bool(w.get("glow", false)):
		out.append("توهج إعادة الدخول")
	return "، ".join(out) if not out.is_empty() else "—"


static func _flight(w: Dictionary) -> String:
	match String(w.arc):
		"sortie":
			return "%s و/ث" % _num(w.speed)
		"intercept":
			return "%s و/ث" % _num(w.speed)
		"cruise", "glide", "torpedo":
			return "%s–%s ث، %s و/ث" % [_num(w.flight[0]), _num(w.flight[1]), _num(w.speed)]
	return "%s–%s ث" % [_num(w.flight[0]), _num(w.flight[1])]


func _guide() -> String:
	var t := "# الحزمة العسكرية — حزمة أسلحة عبودين (Military pack)\n\n"
	t += "أسلحة البارجة من لعبة «حرب البارجة» (Table War)، عامة لأي لعبة طاولة عسكرية مصغّرة في Godot 4.6. ثمانية عشر سلاحًا بالرموز الدائمة `AB-W-023` … `AB-W-040` (الأحد عشر الأولى منذ v1.1، والسبعة الأخيرة منذ v1.2)، ولكل سلاح مثال حقيقي من نوعه كما تعرضه اللعبة. الأرقام كلها من `addons/aboden_blaster/military/military_catalog.gd` (هذه الصفحة مولّدة منه بـ `tools/gen_military_docs.gd`).\n\n"
	t += "[← فهرس الأسلحة](CATALOG.md) · [الدليل](../README.md) · [السجل](CHANGELOG.md)\n\n"
	t += "| | | | | | |\n|---|---|---|---|---|---|\n"
	var ids: Array = Mil.ids()
	for row in range(0, ids.size(), 6):
		var a := "|"
		var b := "|"
		for k in range(row, mini(row + 6, ids.size())):
			var w := Mil.get_weapon(ids[k])
			a += " [![%s](icons/mil_%s.png)](weapons/%s_%s.md) |" % [w.en, w.id, w.code, w.id]
			b += " `%s` %s |" % [w.code, w.ar]
		t += a + "\n" + b + "\n"
	t += "\n## الجدول\n\n"
	t += "الوحدات: «وحدة طاولة» (نموذج عرضه نحو وحدة واحدة، مقياس المشهد الأصلي 1:2000) والثواني. الجاذبية مصغّرة `G = 0.5` حتى تبدو الأقواس «كبيرة وثقيلة». نصف قطر الانفجار = `BLAST_R` (0.022) × `blast`.\n\n"
	t += "| الرمز | الأيقونة | الاسم | مثال حقيقي | المعرّف | المسار | زمن الرحلة | الانفجار | الذخيرة | التبريد | إعادة التعبئة | المطلق | خاص | الفئة |\n"
	t += "|---|---|---|---|---|---|---|---|---|---|---|---|---|---|\n"
	for id: String in ids:
		var w := Mil.get_weapon(id)
		t += "| [`%s`](weapons/%s_%s.md) | <img src=\"icons/mil_%s.png\" width=\"40\"> | **%s** (%s) | %s | `%s` | %s | %s | × %s | %d | %s ث | %s | %s | %s | %s |\n" % [
			w.code, w.code, id, id, w.ar, w.en, w.example, id, ARC[w.arc][0], _flight(w), _num(w.blast), int(w.ammo), _num(w.cooldown),
			("%s ث" % _num(w.reload)) if float(w.reload) > 0.0 else "عند الهبوط", LAUNCHER[w.launcher][0], _special(w), _tier(int(w.tier))]
	t += """
## الاستعمال

```gdscript
var ml := AbodenMilitaryLauncher.new()
world.add_child(ml)              # كل المواقع بإحداثيات ml المحلية (وحدات طاولة)
ml.setup(self)                   # المضيف: أي Node فيه ما يحتاجه من النداءات أدناه
var ship := AbodenMilitaryShip.new()   # اختياري: سفينة الإطلاق
ml.add_child(ship)
ml.ship = ship
ml.impacted.connect(_on_impact) # الضرر على عالمك أنت: حفرة، مبانٍ، نقاط
ml.aim(target)                   # نقاط المسار وحلقة الهدف
ml.fire(target, "cruise")        # false إن كان في تبريد أو بلا ذخيرة
```

`step(dt)` يجري تلقائيًا في `_physics_process` (`auto_step`)، أو أوقفه ونادِه بنفسك (للحركة البطيئة `slow_motion` و`slow_factor`، وللقطات والاختبارات).

### واجهة المضيف (كلها اختيارية)

| النداء | ما يعيده | الافتراضي |
|---|---|---|
| `military_surface(x, z) -> float` | ارتفاع ما تصطدم به القذيفة (أرض أو سطح ماء)، و`-INF` حيث لا شيء | `0.0` (أرض مستوية) |
| `military_ceiling(x, z) -> float` | أعلى ما يصل إليه صاروخ أو دخان هناك (قبة زجاجية، سقف كهف). الأقواس تنخفض تحته والطائرات تطير تحته والدخان ينتشر تحته | سماء مفتوحة |
| `military_water_depth(x, z) -> float` | عمق الماء فوق الأرض هناك (أكثر من 1.5 مم: رذاذ ماء بلا انفجار) | `0.0` (يابسة) |
| `military_launch_point(id) -> Vector3` | من أين يخرج السلاح | قاذفه على `ship`، وإلا `origin` |
| `military_roof(x, z) -> float` | أعلى المباني القائمة هناك، و`-INF` حيث لا مبنى. الكروز والمسيّرات والمضاد للسفن والفرط صوتي تصعد فوقها في الوقت المناسب كما تصعد فوق التلال (v1.2) | بلا مبانٍ |
| `military_air_target(from, aim) -> Variant` | ما يلاحقه صاروخ الدفاع الجوي حين يُطلق نحو `aim`: عقدة `Node3D` يتبعها (تضيع إن حُذفت أو أُخفيت أو خرجت من الشجرة)، أو نقطة `Vector3`، أو `null` (لا شيء في الجو: لا يُطلق ولا تنقص ذخيرته) (v1.2) | النقطة `aim` نفسها: يطير إليها وينفجر في الجو هناك |
| `military_hit(point, info)` | انفجرت قذيفة (مثل الإشارة `impacted`) | — |
| `military_scan(point, radius)` | طائرة الاستطلاع تنظر إلى الأسفل من `point` (موضعها في الجو) ضمن `radius` أفقيًا، كل 0.1 ث وهي تدور؛ المضيف يقرر ما تراه ويعلّمه (مثل `recon_scan`) (v1.2) | — |
| `military_shock(point, r_from, r_to, k)` | تقدّمت جبهة موجة الصدمة النووية من `r_from` إلى `r_to` (`k` من 0 إلى 1 من مسيرها): المضيف يسقط ما في تلك الحلقة (مثل `shock_wave`) (v1.2) | — |
| `military_sfx(name, k, pos)` | صوت: `launch` و`boom` و`thump` | مشغّل الحزمة المدمج |

### الإشارات

- `launched(id, from, to, sub)`: خرجت قذيفة (`sub` صحيح لما يتبع الأولى في الدفعة والقنيبلات وحمولة الطائرات).
- `impacted(point, info)`: `info` = `{id, kind, blast_r, crater_r, crater_d, ejecta, nuke_r?, wave_r?, armor_r?, target?}` و`kind` واحد من `land` / `water` / `shallow` / `nuke` / `air`. `armor_r` للأسلحة المضادة للدروع (المضاد للدروع وصواريخ المروحية): كل مدرّعة ضمنه تتعطل. `air` انفجار صاروخ الدفاع الجوي على هدفه في الجو، و`target` ما أصابه.
- `sortie_landed(id)`: عادت طائرة (الهجومية، حاملة الخارق، حاملة القنابل الانزلاقية، المروحية، الاستطلاع) وهبطت (تعود ذخيرتها).
- `sortie_lost(id)`: أُسقطت طائرة (`shoot_down`): لا تعود، وتصل بديلة بعد `LOST_RELOAD` (25 ث).
- `shot_down(id, point, by_host)`: دُمّرت قذيفة في الجو؛ `by_host` صحيح إن أسقطها المضيف، وخطأ إن فقد صاروخ الدفاع الجوي هدفه فدمّر نفسه.
- `recon_scan(point, radius)`: طائرة الاستطلاع تنظر (مثل `military_scan`).
- `shock_wave(point, r_from, r_to, k)`: جبهة موجة الصدمة النووية (مثل `military_shock`).

### دفاع العدو الجوي (عند المضيف)

`air_shots()` يعيد كل ما في الجو الآن `[{serial, id, position, velocity, sub, aircraft, intercept}]` (`intercept` احتمال الاشتباك في اللعبة، تلميح من الكتالوج)، و`shoot_down(serial)` يدمّر واحدة منها في الجو (انفجار جوي بلا ارتطام). منصات صواريخ أرض-جو أو مدفع قريب في لعبتك تقرأ هذه القائمة وتقرر بنفسها. الطوربيد لا يظهر فيها.

`fire_at_air(target, "aa")` يطلق صاروخ الدفاع الجوي على عقدة أو نقطة مباشرة.

### الذخيرة

`ammo(id)` و`cooldown_left(id)` و`can_fire(id)` و`refill()`. لكل سلاح `ammo` طلقات و`cooldown` بين طلقتين، وتعود طلقة كل `reload` ثانية؛ كل طائرة تعود ذخيرتها حين تهبط (والمُسقطة بعد 25 ث). `unlimited = true` يتجاهل الذخيرة والتبريد.

### ما يبقى عند المضيف

مثل v1.1: الحفر وتكسّر المباني والحطام والسكان خاصة بعالمك عبر `impacted`. ومنذ v1.2: ما تكشفه طائرة الاستطلاع (اللعبة ترسم معيّنًا كهرمانيًا فوق كل موقع وسفينة ووحدة معادية تراها، 60 ث)، اعتراض العدو لقذائفك (`air_shots` و`shoot_down`)، الطائرات المعادية التي يلاحقها صاروخ الدفاع الجوي (`military_air_target`)، تعطيل المدرعات (`armor_r`)، السفن التي يصيبها الطوربيد (`kind` = `water` عند الهدف)، المباني التي تتجاوزها الصواريخ المنخفضة (`military_roof`)، وما تُسقطه موجة الصدمة النووية والحرائق في الأنقاض (`shock_wave`، و`fx.fire_at(p)` لإشعالها).

### الملفات

```
addons/aboden_blaster/military/
├── military_catalog.gd     AbodenMilitaryCatalog: الأسماء والرموز والأرقام (المصدر الوحيد)
├── military_flight.gd      AbodenMilitaryFlight: المسارات (باليستي، كروز يتبع التضاريس والمباني، طلعة جوية ودوران الاستطلاع، انزلاق فرط صوتي، قنبلة انزلاقية، طوربيد)
├── military_launcher.gd    AbodenMilitaryLauncher: الإطلاق والطيران والارتطام والذخيرة، الدفاع الجوي، موجة الصدمة
├── military_fx.gd          AbodenMilitaryFx: الدخان والنار والرذاذ والفطر النووي المتتابع والانفجار الجوي والحرائق (3 دفعات رسم)
├── military_looks.gd       AbodenMilitaryLooks: مجسمات القذائف والسفينة (بالكود)
├── military_ship.gd        AbodenMilitaryShip: سفينة الإطلاق
├── military_mesh.gd        AbodenMilitaryMesh: باني المجسمات
├── puff*.gdshader(inc)     ظلال الدخان والنار
├── icons/<id>.svg|png      الأيقونات (SVG المصدر، PNG 256 بكسل)
└── tools_bake_icons.gd     خبز الأيقونات من SVG
```

الاختبارات: `godot --headless --path . -s res://tests/run_military_tests.gd`.

العرض: `demo/military_demo.tscn` (طاولة صغيرة بقارب هدف في البحر وطائرة هدف تدور فوقها؛ 1..9 و0 و- و= ثم Q W E R T Y للأسلحة الثمانية عشر، Tab للتالي، S للحركة البطيئة). اللقطات: `-- --all=res://docs/shots` (بعرض رسومي، مثلًا `xvfb-run godot --rendering-driver opengl3`).
"""
	return t


func _page(w: Dictionary) -> String:
	var id: String = w.id
	var t := "# %s — %s (%s)\n\n" % [w.code, w.ar, w.en]
	t += "[← الحزمة العسكرية](../MILITARY.md) · [فهرس الأسلحة](../CATALOG.md)\n\n"
	t += "<img src=\"../icons/mil_%s.png\" width=\"128\">\n\n" % id
	t += "| الحقل | القيمة |\n|---|---|\n"
	t += "| الرمز (code) | `%s` |\n| الحزمة (pack) | عسكرية (military) |\n| المعرّف (id) | `%s` |\n" % [w.code, id]
	t += "| الاسم | %s (%s) |\n| الاسم القصير | %s |\n| مثال حقيقي (example) | %s |\n| الوصف | %s — *%s* |\n" % [w.ar, w.en, w.ar_short, w.example, w.ar_desc, w.en_desc]
	t += "| طريقة الإيصال (delivery) | %s |\n| المسار (trajectory) | %s |\n| نموذج الإصابة (hit) | %s |\n| الدور (role) | %s |\n| الفئة (tier) | %s |\n" % [
		_ax("delivery", w.delivery), _ax("trajectory", w.trajectory), _ax("hit", w.hit), _ax("role", w.role), _tier(int(w.tier))]
	t += "| المطلق (launcher) | %s (`%s`) |\n" % [LAUNCHER[w.launcher][0], w.launcher]
	t += "| احتمال الاعتراض في اللعبة (intercept) | %s |\n" % _num(w.intercept)
	t += "| الأيقونة | `addons/aboden_blaster/military/icons/%s.png` |\n| الحالة (status) | مستقر (stable) |\n| الإصدار (version) | v%s |\n\n" % [id, w.version]
	t += "## المعاملات (`AbodenMilitaryCatalog.WEAPONS[\"%s\"]`)\n\n| المعامل | القيمة |\n|---|---|\n" % id
	for key in ["arc", "flight", "speed", "cruise_alt", "turn", "kill_r", "life", "blast", "crater_k", "armor_k", "ejecta", "cooldown", "ammo", "reload", "salvo", "salvo_gap", "split",
			"bombs", "bomb", "release_lead", "orbit", "scan_r", "spread", "nuke_r", "wave_k", "wave_t", "cloud", "glow", "wings", "trail", "length", "radius"]:
		if w.has(key):
			var v: Variant = w[key]
			var s := str(v)
			if v is float:
				s = _num(v)
			elif v is Array:
				s = "[%s, %s]" % [_num(v[0]), _num(v[1])]
			t += "| `%s` | %s |\n" % [key, s]
	t += "| `col` | `#%s` |\n" % (w.col as Color).to_html(false)
	t += "\n## السلوك\n\n%s.\n\n" % _special(w)
	match String(w.arc):
		"lofted":
			t += "قوس باليستي مغلق الشكل يصل إلى الهدف بالضبط بعد زمن الرحلة (يُختار من المسافة بين حدّي `flight`). إن كان للمضيف سقف قُصّر زمن الرحلة (قوس أخفض) حتى يبقى القوس كله تحته.\n"
		"low":
			t += "قوس باليستي منخفض وسريع إلى الهدف بالضبط (زمن الرحلة بين حدّي `flight`).\n"
		"cruise":
			t += "يخرج من القاذف وينزل بميل محدود إلى ارتفاع `cruise_alt` فوق التضاريس أو البحر، وينظر 4 سم أمامه ليصعد قبل التلال (أقصى ميل صعود 0.9)، ثم ينقضّ على الهدف في آخر 2.2 سم. إن كان التل أشد انحدارًا من حد الصعود اصطدم به وانفجر هناك (`crash` في المسار).\n"
		"sortie":
			t += "تقلع من سطح الطيران، تصعد إلى `cruise_alt` فوق أعلى نقطتي الإقلاع والهدف، "
			if w.has("orbit"):
				t += "تدور حول الهدف دورتين بنصف قطر `orbit` وهي تبلّغ ما تراه تحتها ضمن `scan_r` كل 0.1 ث (`recon_scan` و`military_scan`؛ المضيف يقرر ما تكشفه)، ثم "
			elif int(w.get("bombs", 0)) > 0:
				t += "تطلق حمولتها (`%s`) قبل الهدف بـ %s، تكمل و" % [w.bomb, _num(float(w.get("release_lead", 0.035)))]
			t += "تستدير وتعود من الخلف لتهبط على السطح، فتعود ذخيرتها (`sortie_landed`). لا تلمس التضاريس، وتبقى تحت السقف إن وُجد. إن أسقطها المضيف (`shoot_down`) ضاعت (`sortie_lost`) ووصلت بديلة بعد 25 ث.\n"
			match String(w.get("bomb", "")):
				"bunkerbomb":
					t += "\nالقنبلة الخارقة تسقط شبه عمودية من ارتفاع الطائرة (0.8–0.9 ث) وتحفر حفرة أعمق × 2.2 (`crater_d`).\n"
				"gbomb":
					t += "\nالقنابل الانزلاقية تنفصل بعيدًا (16 سم قبل الهدف) وتنزلق بأجنحتها: مستوية أولًا ثم أشد انحدارًا في النهاية، بسرعة 0.2 و/ث.\n"
				"hrocket":
					t += "\nالصواريخ تنطلق رشقة واحدة من مسافة 7 سم بقوس منخفض سريع (0.4–0.55 ث)، وكل منها مضاد للدروع (`armor_r`).\n"
		"glide":
			t += "مركبة انزلاق فرط صوتية: اندفاع حاد قصير إلى قمة القوس (خُمس الطريق)، ثم انزلاق طويل منخفض يتمايل يمينًا ويسارًا (منعطفان على شكل S يصعّبان الاعتراض) وهو ينزل نحو الهدف بعيدًا عن الأرض والمباني وتحت السقف، ثم انقضاض حاد في الثُمن الأخير بتوهج إعادة الدخول. ينفجر في نهاية مساره دائمًا.\n"
		"torpedo":
			t += "يُلقى من أنبوب على جانب السفينة وينزل في أول نقطتين إلى 1.6 مم تحت سطح الماء ويجري مستقيمًا إلى الهدف، وأثره رغوة على السطح فوقه. لا يخرج من الماء: إن كان الهدف على اليابسة توقف وانفجر عند الشاطئ (أول نقطة بلا ماء، من `military_water_depth`). بلا `military_water_depth` تُحسب الطاولة كلها ماءً. عند سفينة في الماء `kind` = `water` والمضيف يقرر الضرر.\n"
		"intercept":
			t += "يخرج عموديًا ثم يوجّه نفسه نحو هدفه الجوي (عقدة يعطيها المضيف عبر `military_air_target`، أو النقطة نفسها) بسرعة `speed` ومعدل انعطاف `turn`، تحت السقف. ينفجر في الجو على بعد `kill_r` من الهدف (`kind` = `air` و`info.target`)، أو على الأرض إن لاقاها أولًا، ويدمّر نفسه بعد `life` ثانية أو إن ضاع الهدف (`shot_down` بـ `by_host` = false). مسار المعاينة خط مستقيم إلى نقطة التصويب.\n"
	if String(w.arc) in ["cruise"]:
		t += "\nمع `military_roof` يصعد فوق المباني القائمة في طريقه في الوقت المناسب (برج أشد انحدارًا من أي تل) وينقضّ على هدف خلفها. وينفجر في نهاية مساره دائمًا حتى لو حفر المضيف الأرض هناك.\n"
	if bool(w.get("nuke", false)):
		t += "\nعند الارتطام: تتابع نحو 10 ثوانٍ: وميض أبيض واسع، كرة نار بيضاء تصعد، ساق من الغبار والدخان تُسحب خلفها، قبعة فطر تتدحرج للخارج (تنتشر تحت السقف إن وُجد؛ في السماء المفتوحة أعلى وأوسع × `cloud`)، حلقة تكاثف قصيرة، موجة غبار قاعدية تجري على الأرض، وتموجات على الماء. `info.nuke_r` للمضيف ليدمر كل ما في الدائرة. ثم تمتد موجة الصدمة من `nuke_r` إلى `nuke_r × wave_k` (`info.wave_r`) في `wave_t` ثانية، سريعة أولًا ثم أبطأ، بجبهة غبار منخفضة؛ كل خطوة تبلّغ الحلقة التي اجتازتها (`shock_wave` و`military_shock`) ليُسقط المضيف ما فيها ويشعل الحرائق (`fx.fire_at`).\n"
	t += "\n## المظهر\n\n"
	t += "- **الصورة:** ![%s](../shots/mil_%s.png)\n" % [w.en, id] if FileAccess.file_exists("res://docs/shots/mil_%s.png" % id) else ""
	if bool(w.get("heli", false)):
		t += "- **المجسم:** `AbodenMilitaryLooks.body()`، جسم مروحية نحيل بقمرة أمامية وذراع ذيل وزعنفة وجناحين قصيرين بحاضنتي صواريخ ومروحة بشفرتين، باللون `col`"
	else:
		t += "- **المجسم:** `AbodenMilitaryLooks.body()`، أسطوانة بمخروط مقدمة باللون `col`"
		if bool(w.get("wings", false)):
			t += "، وأجنحة"
		if bool(w.get("aircraft", false)) and not w.has("orbit"):
			t += "، وذيل وموازن وقمرة"
	if String(w.arc) == "torpedo":
		t += ".\n- **الأثر:** رغوة على سطح الماء فوقه كل `trail` ثانية باللون `trail_col`"
	elif (w.trail_col as Color).a <= 0.0:
		t += ".\n- **الأثر:** بلا أثر دخان"
	else:
		t += ".\n- **الأثر:** نفخة دخان كل `trail` ثانية باللون `trail_col`"
	if bool(w.get("glow", false)):
		t += "، وتوهج إعادة دخول ساخن في النزول"
	if String(w.arc) == "intercept":
		t += ".\n- **الارتطام:** في الجو وميض قصير وكرة نار صغيرة ودخان رمادي معلّق وشرر يتساقط (`fx.air_burst`)؛ على الأرض كالبقية.\n\n"
	elif w.has("orbit"):
		t += ".\n- **الارتطام:** لا شيء (لا تنفجر).\n\n"
	else:
		t += ".\n- **الارتطام:** على اليابسة وميض وكرة نار وحلقة غبار وعمود دخان؛ في الماء عمود ماء ورذاذ ورغوة وتموجات.\n\n"
	t += "## الأصوات\n\n- `launch` عند الإطلاق، `boom` عند الانفجار على اليابسة، `thump` في الماء (عبر `military_sfx` أو المشغّل المدمج: whoosh و boom و splash).\n"
	return t


func _json() -> Array:
	var out: Array = []
	for id: String in Shots.ids():
		var s := Shots.info(id)
		var st := Shots.style(id)
		out.append({"code": s.code, "id": id, "pack": "playful", "ar": s.ar, "en": s.en, "ar_desc": s.get("ar_desc", ""),
			"en_desc": s.get("en_desc", ""), "delivery": s.delivery, "trajectory": s.trajectory, "hit": s.hit, "role": s.role,
			"tier": int(s.tier), "tags": s.get("tags", []), "icon": "icons/%s.png" % s.icon,
			"stats": {"speed": st.get("speed", 0.0), "cool": st.get("cool", 0.0), "r": st.get("r", 0.0), "life": st.get("life", 0.0)}})
	for id: String in Mil.ids():
		var w := Mil.get_weapon(id)
		var stats := {"blast": w.blast, "ammo": w.ammo, "cooldown": w.cooldown, "reload": w.reload, "arc": w.arc, "launcher": w.launcher}
		for k in ["flight", "speed", "salvo", "split", "bombs", "bomb", "orbit", "scan_r", "nuke_r", "wave_k", "crater_k", "armor_k"]:
			if w.has(k):
				stats[k] = w[k]
		out.append({"code": w.code, "id": id, "pack": "military", "ar": w.ar, "en": w.en, "example": w.example, "ar_desc": w.ar_desc, "en_desc": w.en_desc,
			"delivery": w.delivery, "trajectory": w.trajectory, "hit": w.hit, "role": w.role, "tier": int(w.tier),
			"icon": "icons/mil_%s.png" % id, "stats": stats})
	return out
