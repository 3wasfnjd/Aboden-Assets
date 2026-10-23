extends RefCounted
## The weapon lab's list: every weapon of both catalogues (AbodenShotCatalog.SHOTS for the
## playful pack and any other blaster pack, AbodenMilitaryCatalog.WEAPONS for the military
## pack), read at run time, never from a list of its own, so new weapons show up as soon as
## they are in a catalogue. Each entry:
##   {code, id, pack, engine ("blaster" | "military"), ar, en, ar_desc, en_desc, icon (path),
##    axes: [[ar, en]...], numbers: [[ar label, en label, value text, unit]...]}  (unit "landing": comes back on landing)

const Shots := preload("res://addons/aboden_blaster/shot_catalog.gd")
const Military := preload("res://addons/aboden_blaster/military/military_catalog.gd")

## Labels for the flight numbers we know: key -> [ar, en, unit]. Keys not here are shown by
## their own name (a new weapon's new number still shows).
const BLASTER_KEYS := {
	"speed": ["السرعة", "Speed", "m/s"], "cool": ["التبريد", "Cooldown", "s"], "life": ["العمر", "Life", "s"],
	"r": ["نصف القطر", "Radius", "m"], "grav": ["الجاذبية", "Gravity", "g"], "burst": ["الانفجار", "Blast", "m"],
	"pellets": ["الكرات", "Pellets", ""], "cone": ["المخروط", "Cone", "rad"], "bounces": ["الارتدادات", "Bounces", ""],
	"pops": ["الفرقعات", "Pops", ""], "range": ["المدى", "Range", "m"], "pierce": ["الاختراق", "Pierce", ""],
	"reach": ["المدى", "Reach", "m"], "swing": ["الالتفاف", "Swing", "m"], "splat": ["الرذاذ", "Splash", "m"],
	"turn": ["الانعطاف", "Turn", "rad/s"], "seek": ["البحث", "Seek", "m"], "chain": ["التسلسل", "Chain", ""],
	"hop": ["القفزة", "Hop", "m"], "spray": ["الرش", "Spray", "s"],
	"dive": ["مسافة الانقضاض", "Dive", "m"], "frost": ["مدة التجميد", "Freeze", "s"], "linger": ["البقاء", "Linger", "s"],
	"field": ["مجال الجذب", "Field", "m"], "tug": ["قوة السحب", "Pull", "m/s"], "cloud": ["نصف قطر الدخان", "Smoke", "m"],
	"slow": ["الإبطاء", "Slow", "×"], "drag": ["مدة السحب", "Drag", "s"], "push": ["قوة الدفع", "Push", "m/s"],
	"shove": ["الدفعة", "Shove", "m"], "ahead": ["البعد أمام اليد", "Ahead", "m"],
}
const BLASTER_SKIP := ["sk"]
const MILITARY_KEYS := {
	"flight": ["زمن الرحلة", "Flight", "s"], "speed": ["السرعة", "Speed", "u/s"], "blast": ["الانفجار", "Blast", "×"],
	"ammo": ["الذخيرة", "Ammo", ""], "cooldown": ["التبريد", "Cooldown", "s"], "reload": ["إعادة التعبئة", "Reload", "s"],
	"salvo": ["الدفعة", "Salvo", ""], "split": ["القنيبلات", "Bomblets", ""], "bombs": ["القنابل", "Bombs", ""],
	"nuke_r": ["نصف قطر التدمير", "Kill radius", "u"], "crater_k": ["عمق الحفرة", "Crater", "×"],
}


static func pack_name(pack: String, lang: String) -> String:
	var p: Array = Shots.PACKS.get(pack, [pack, pack])
	return str(p[1] if lang == "en" else p[0])


static func _num(v: Variant) -> String:
	if v is Array:
		var a: Array = v
		if a.size() == 2 and is_equal_approx(float(a[0]), float(a[1])):
			return _num(a[0])
		return "–".join(a.map(func(x: Variant) -> String: return _num(x)))
	var f := float(v)
	if f >= 1e8:
		return "∞"
	if is_equal_approx(f, roundf(f)):
		return str(int(roundf(f)))
	return str(snappedf(f, 0.001 if absf(f) < 0.1 else 0.01))


static func _axes(src: Dictionary) -> Array:
	var out: Array = []
	for axis: String in ["delivery", "trajectory", "hit"]:
		var v := str(src.get(axis, ""))
		var names: Dictionary = Shots.AXES.get(axis, {})
		if names.has(v):
			out.append(names[v])
	return out


static func _icon(paths: Array) -> String:
	for p: String in paths:
		if ResourceLoader.exists(p):
			return p
	return ""


## Every weapon: blaster packs first (in PACKS order), then the military pack; each pack
## in code order.
static func all() -> Array:
	var out: Array = []
	for id: String in Shots.SHOTS:
		var s: Dictionary = Shots.SHOTS[id]
		var e := {
			"code": str(s.get("code", "")), "id": id, "pack": str(s.get("pack", "playful")), "engine": "blaster",
			"ar": str(s.get("ar", id)), "en": str(s.get("en", id)),
			"ar_desc": str(s.get("ar_desc", "")), "en_desc": str(s.get("en_desc", "")),
			"icon": _icon(["res://addons/aboden_blaster/icons/%s.png" % str(s.get("icon", id)), "res://addons/aboden_blaster/icons/%s.png" % id]),
			"axes": _axes(s), "numbers": [],
		}
		var st: Dictionary = Shots.SHOT_STYLE.get(id, {})
		for k: String in st:
			if k in BLASTER_SKIP or not (st[k] is float or st[k] is int):
				continue
			if (k in ["bounces", "pops"] and float(st[k]) >= 1e8) or is_zero_approx(float(st[k])):
				continue
			var lab: Array = BLASTER_KEYS.get(k, [k, k, ""])
			e.numbers.append([lab[0], lab[1], _num(st[k]), str(lab[2])])
		out.append(e)
	for id: String in Military.WEAPONS:
		var w: Dictionary = Military.WEAPONS[id]
		var e := {
			"code": str(w.get("code", "")), "id": id, "pack": str(w.get("pack", "military")), "engine": "military",
			"ar": str(w.get("ar", id)), "en": str(w.get("en", id)),
			"ar_desc": str(w.get("ar_desc", "")), "en_desc": str(w.get("en_desc", "")),
			"example": str(w.get("example", "")),
			"icon": _icon(["res://addons/aboden_blaster/military/icons/%s.png" % str(w.get("icon", id)), "res://addons/aboden_blaster/military/icons/%s.png" % id]),
			"axes": _axes(w), "numbers": [],
		}
		for k: String in MILITARY_KEYS:
			if not w.has(k):
				continue
			var lab: Array = MILITARY_KEYS[k]
			if k == "reload" and float(w[k]) <= 0.0:
				e.numbers.append([lab[0], lab[1], "", "landing"])
			else:
				e.numbers.append([lab[0], lab[1], _num(w[k]), str(lab[2])])
		out.append(e)
	var packs: Array = Shots.PACKS.keys()
	for e: Dictionary in out:
		if not e.pack in packs:
			packs.append(e.pack)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var pa := packs.find(a.pack)
		var pb := packs.find(b.pack)
		if pa != pb:
			return pa < pb
		return str(a.code) < str(b.code))
	return out


## The packs present, in order.
static func packs(list: Array) -> Array:
	var out: Array = []
	for e: Dictionary in list:
		if not e.pack in out:
			out.append(e.pack)
	return out
