extends Node
## مختبر الأسلحة — the Aboden Blaster Kit's weapon lab (the web build's main scene; on a
## desktop: godot --path . res://demo/lab/weapon_lab.tscn -- --w=AB-W-010 --lang=en).
##
## Every weapon of both catalogues (lab_weapons.gd reads them at run time), a picker grouped
## by pack, a card with the weapon's names, code, description and numbers, and the weapon in
## its own world: the playful ones in a bright arena of soft targets (lab_arena.gd), the
## military ones on a tabletop island (lab_table.gd).
##
## The page's query (web; on a desktop the same as user args): ?w=AB-W-0NN opens that weapon,
## ?lang=en switches the interface to English (Arabic by default). Phone first: the interface
## is laid out in a 360 x 640 (portrait) or 640 x 360 (landscape) canvas the window scales up.

const Weapons := preload("res://demo/lab/lab_weapons.gd")
const Arena := preload("res://demo/lab/lab_arena.gd")
const Table := preload("res://demo/lab/lab_table.gd")

const BG := Color(0.07, 0.09, 0.15, 0.82)
const PANEL := Color(0.09, 0.11, 0.19, 1.0)
const ACCENT := Color("ffc857")
const TEXT := Color("f4f6ff")
const DIM := Color("aab3cc")
const RED := Color("ff6b6b")
const GREEN := Color("7ee05a")

const UNITS_AR := {"m/s": "م/ث", "s": "ث", "m": "م", "rad": "راديان", "rad/s": "راديان/ث", "u/s": "و/ث", "u": "و", "g": "g", "×": "×", "": ""}
const T := {
	"title": ["مختبر الأسلحة", "Weapon Lab"],
	"sub": ["حزمة أسلحة عبودين · اختر سلاحًا", "Aboden Blaster Kit · pick a weapon"],
	"prev": ["السابق", "‹ Prev"], "next": ["التالي", "Next ›"], "list": ["الأسلحة", "Weapons"], "reset": ["إعادة", "Reset"],
	"close": ["إغلاق", "Close"],
	"hint_playful": ["المس للإطلاق · اسحب للتصويب · استمر بالضغط للإطلاق المتواصل", "Tap to fire · drag to aim · hold to keep firing"],
	"hint_military": ["انقر على الجزيرة للإطلاق · اسحب للتدوير · قرّب بإصبعين", "Tap the island to fire · drag to orbit · pinch to zoom"],
	"ammo": ["الذخيرة", "Ammo"], "ready": ["جاهز", "Ready"], "cool": ["تبريد", "Cooling"], "empty": ["نفدت الذخيرة", "Out of ammo"],
	"hits": ["أصبت", "Hits"], "landing": ["عند الهبوط", "on landing"], "missing": ["لا يوجد سلاح بهذا الرمز", "No weapon with this code"],
	"weapons_n": ["سلاح", "weapons"], "tap_card": ["المس البطاقة للتفاصيل", "Tap the card for details"],
}

var lang := "ar"
var list: Array = []
var index := -1
var arena: Arena
var table: Table
var world: Node3D  # the one in the tree now

var ui: Control
var pad: Control
var card: PanelContainer
var card_icon: TextureRect
var card_name: Label
var card_sub: Label
var card_desc: Label
var card_axes: Label
var card_nums: HFlowContainer
var card_details: VBoxContainer
var hint: Label
var status: Label
var bar: HBoxContainer
var picker: Control
var picker_grids: Array[GridContainer] = []
var picker_note: Label
var font: Font
var portrait := true
var details := true
var _icons := {}
var _fingers := {}  # index -> position
var _press_at := Vector2.ZERO
var _press_t := 0.0
var _press_frame := 0
var _dragged := false
var _pinch := 0.0
var _touch_seen := false
var _flash_t := 0.0
var _js_t := 0.0
var _bottom_y := 0.0
var fired_military := 0
var debug_input := false


func _ready() -> void:
	var q := _query()
	debug_input = q.has("debug")
	lang = "en" if str(q.get("lang", "ar")).to_lower().begins_with("en") else "ar"
	list = Weapons.all()
	font = _make_font()
	if OS.has_feature("web"):
		get_viewport().scaling_3d_scale = clampf(2.0 / maxf(DisplayServer.screen_get_scale(), 1.0), 0.5, 1.0)
	arena = Arena.new()
	arena.name = "Arena"
	table = Table.new()
	table.name = "Table"
	# build both (their _ready), keep only the current one in the tree
	add_child(arena)
	add_child(table)
	remove_child(table)
	world = arena
	_build_ui()
	get_tree().root.size_changed.connect(_layout)
	_layout()
	var code := str(q.get("w", "")).to_upper()
	var i := _find(code)
	if i >= 0:
		select(i)
	else:
		select(0)
		show_picker(true)
		if code != "":
			picker_note.text = "%s: %s" % [tr_("missing"), code]
			picker_note.visible = true
	if q.has("shot") and not OS.has_feature("web"):
		_shot(str(q.shot), q.has("fire"), str(q.get("tap", "")))


## The world not in the tree is ours to free.
func _exit_tree() -> void:
	for w: Node in [arena, table]:
		if is_instance_valid(w) and not w.is_inside_tree():
			w.free()


## Desktop only: --shot=<png> [--fire] saves a picture after 2.5 s (firing at the middle of the
## view first with --fire) and quits.
func _shot(path: String, fire: bool, tap := "") -> void:
	await get_tree().create_timer(0.5).timeout
	if tap != "":
		var xy := tap.split(",")
		var p := Vector2(float(xy[0]), float(xy[1]))
		_down(p)
		_up(p)
		print("tap ", p, " fired ", fired_military, " pick ", table.pick(p) if world == table else Vector3.ZERO)
	elif fire:
		var c := ui.get_viewport_rect().size * Vector2(0.5, 0.42)
		if world == arena:
			arena.aim_at(c)
			arena.trigger(true)
		else:
			table.fire_at(Vector3(0.1, table.military_surface(0.1, 0.02), 0.02))
	await get_tree().create_timer(2.0).timeout
	if world == arena:
		arena.trigger(false)
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	get_tree().quit()


func tr_(key: String) -> String:
	return str(T[key][1 if lang == "en" else 0])


## The page's query (?w=..&lang=..) on the web; the user args (--w=.. --lang=..) elsewhere.
func _query() -> Dictionary:
	var out := {}
	var s := ""
	if OS.has_feature("web"):
		var v: Variant = JavaScriptBridge.eval("window.location.search", true)
		s = str(v) if v != null else ""
	else:
		s = "&".join(Array(OS.get_cmdline_user_args()).map(func(a: String) -> String: return a.trim_prefix("--")))
	for part: String in s.trim_prefix("?").split("&", false):
		var kv := part.split("=", true, 1)
		out[kv[0].uri_decode()] = kv[1].uri_decode() if kv.size() > 1 else ""
	return out


func _find(code: String) -> int:
	if code == "":
		return -1
	for i in list.size():
		if str(list[i].code).to_upper() == code or str(list[i].id) == code.to_lower():
			return i
	return -1


# --- choosing a weapon --------------------------------------------------------------

func select(i: int) -> void:
	if list.is_empty():
		return
	index = posmod(i, list.size())
	var e: Dictionary = list[index]
	var want: Node3D = table if e.engine == "military" else arena
	if want != world:
		remove_child(world)
		add_child(want)
		move_child(want, 0)
		world = want
	(arena.cam if world == arena else table.cam).make_current()
	if world == arena:
		arena.trigger(false)
		arena.set_weapon(e.id)
	else:
		table.set_weapon(e.id)
		table.set_portrait(portrait)
	_fill_card(e)
	hint.text = tr_("hint_military" if e.engine == "military" else "hint_playful")
	_update_url(e)


func step(d: int) -> void:
	select(index + d)


func reset() -> void:
	if world == arena:
		arena.reset()
	else:
		table.reset()


func _update_url(e: Dictionary) -> void:
	if not OS.has_feature("web"):
		return
	var qs := "?w=" + str(e.code)
	if lang == "en":
		qs += "&lang=en"
	JavaScriptBridge.eval("try{history.replaceState(null,'','%s')}catch(e){}" % qs, true)


# --- the card -----------------------------------------------------------------------

func _fill_card(e: Dictionary) -> void:
	var en := lang == "en"
	card_icon.texture = _icon(str(e.icon))
	card_name.text = str(e.en if en else e.ar)
	card_sub.text = "%s  ·  %s  ·  %s" % [e.code, e.ar if en else e.en, Weapons.pack_name(e.pack, lang)]
	card_desc.text = str(e.en_desc if en else e.ar_desc)
	if str(e.get("example", "")) != "":
		card_desc.text += ("  · Real-world example: " if en else "  · مثال حقيقي: ") + str(e.example)
	card_axes.text = "  ·  ".join((e.axes as Array).map(func(a: Array) -> String: return str(a[1] if en else a[0])))
	for c in card_nums.get_children():
		c.queue_free()
	for n: Array in e.numbers:
		var unit := str(n[3])
		var val := str(n[2])
		if unit == "landing":
			val = tr_("landing")
			unit = ""
		elif not en:
			unit = str(UNITS_AR.get(unit, unit))
		var chip := PanelContainer.new()
		chip.add_theme_stylebox_override("panel", _box(Color(1, 1, 1, 0.08), 6, 6, 2))
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var l := _label("%s  %s %s" % [n[1] if en else n[0], val, unit], 11, TEXT)
		l.text = l.text.strip_edges()
		chip.add_child(l)
		card_nums.add_child(chip)


func _icon(path: String) -> Texture2D:
	if path == "":
		return null
	if not _icons.has(path):
		_icons[path] = load(path) as Texture2D
	return _icons[path]


# --- the picker ---------------------------------------------------------------------

func show_picker(on: bool) -> void:
	picker.visible = on
	if world == arena:
		arena.trigger(false)
	if not on:
		picker_note.visible = false


func _build_picker() -> void:
	picker = PanelContainer.new()
	picker.add_theme_stylebox_override("panel", _box(PANEL, 0, 0, 0))
	picker.set_anchors_preset(Control.PRESET_FULL_RECT)
	picker.mouse_filter = Control.MOUSE_FILTER_STOP
	picker.layout_direction = _dir()
	picker.visible = false
	ui.add_child(picker)
	var m := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 10)
	picker.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	m.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var tv := VBoxContainer.new()
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.add_theme_constant_override("separation", -2)
	head.add_child(tv)
	tv.add_child(_label(tr_("title"), 22, ACCENT))
	tv.add_child(_label("%s  ·  %d %s" % [tr_("sub"), list.size(), tr_("weapons_n")], 12, DIM))
	var close := _button(tr_("close"), func() -> void: show_picker(false))
	close.custom_minimum_size = Vector2(76, 40)
	head.add_child(close)
	picker_note = _label("", 13, RED)
	picker_note.visible = false
	v.add_child(picker_note)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.scroll_deadzone = 8
	v.add_child(sc)
	var lv := VBoxContainer.new()
	lv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lv.add_theme_constant_override("separation", 8)
	sc.add_child(lv)
	for pk: String in Weapons.packs(list):
		var ids := list.filter(func(e: Dictionary) -> bool: return e.pack == pk)
		var hdr := _label("%s  ·  %d" % [Weapons.pack_name(pk, lang), ids.size()], 16, ACCENT)
		lv.add_child(hdr)
		var g := GridContainer.new()
		g.columns = 3
		g.add_theme_constant_override("h_separation", 6)
		g.add_theme_constant_override("v_separation", 6)
		lv.add_child(g)
		picker_grids.append(g)
		for e: Dictionary in ids:
			g.add_child(_tile(e))


## A weapon's tile: a tap opens it; a drag scrolls the list (the tile passes its events on
## to the ScrollContainer, which scrolls by touch).
func _tile(e: Dictionary) -> Control:
	var b := PanelContainer.new()
	b.custom_minimum_size = Vector2(106, 100)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var normal := _box(Color(1, 1, 1, 0.06), 10, 4, 4)
	var lit := _box(Color(1, 0.78, 0.34, 0.25), 10, 4, 4)
	b.add_theme_stylebox_override("panel", normal)
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	b.name = str(e.code)
	var i := list.find(e)
	var st := {"at": Vector2.INF}
	b.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			var mb := ev as InputEventMouseButton
			if mb.pressed:
				st.at = mb.global_position
				b.add_theme_stylebox_override("panel", lit)
			else:
				b.add_theme_stylebox_override("panel", normal)
				if st.at != Vector2.INF and mb.global_position.distance_to(st.at) < 12.0:
					select(i)
					show_picker(false)
				st.at = Vector2.INF
		elif ev is InputEventMouseMotion and st.at != Vector2.INF and (ev as InputEventMouseMotion).global_position.distance_to(st.at) >= 12.0:
			st.at = Vector2.INF
			b.add_theme_stylebox_override("panel", normal))
	b.mouse_exited.connect(func() -> void: b.add_theme_stylebox_override("panel", normal))
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var ic := TextureRect.new()
	ic.texture = _icon(str(e.icon))
	ic.custom_minimum_size = Vector2(44, 44)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(ic)
	var n := _label(str(e.en if lang == "en" else e.ar), 13, TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	n.custom_minimum_size.x = 94
	v.add_child(n)
	v.add_child(_label(str(e.code), 10, DIM, HORIZONTAL_ALIGNMENT_CENTER))
	return b


# --- the interface --------------------------------------------------------------------

func _make_font() -> Font:
	var latin: FontFile = load("res://demo/lab/fonts/cairo-latin-500-normal.woff2")
	var arabic: FontFile = load("res://demo/lab/fonts/cairo-arabic-500-normal.woff2")
	if latin == null:
		return null
	var f := latin.duplicate() as FontFile
	f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	f.hinting = TextServer.HINTING_LIGHT
	if arabic:
		var ar := arabic.duplicate() as FontFile
		ar.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		ar.hinting = TextServer.HINTING_LIGHT
		f.fallbacks = [ar]
	return f


func _dir() -> Control.LayoutDirection:
	return Control.LAYOUT_DIRECTION_RTL if lang == "ar" else Control.LAYOUT_DIRECTION_LTR


func _box(c: Color, radius: int, pad_h: int, pad_v: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = c
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad_h
	s.content_margin_right = pad_h
	s.content_margin_top = pad_v
	s.content_margin_bottom = pad_v
	return s


func _label(t: String, size: int, c: Color, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", c)
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _button(t: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.add_theme_font_size_override("font_size", 15)
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", TEXT)
	b.add_theme_color_override("font_pressed_color", ACCENT)
	b.add_theme_stylebox_override("normal", _box(BG, 10, 8, 4))
	b.add_theme_stylebox_override("hover", _box(Color(0.16, 0.19, 0.3, 0.9), 10, 8, 4))
	b.add_theme_stylebox_override("pressed", _box(Color(0.24, 0.2, 0.1, 0.95), 10, 8, 4))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	return b


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.layout_direction = Control.LAYOUT_DIRECTION_LTR
	var th := Theme.new()
	if font:
		th.default_font = font
	th.default_font_size = 14
	ui.theme = th
	layer.add_child(ui)
	# the touch pad behind everything: the world's taps, drags and pinches
	pad = Control.new()
	pad.set_anchors_preset(Control.PRESET_FULL_RECT)
	pad.mouse_filter = Control.MOUSE_FILTER_STOP
	pad.gui_input.connect(_pad_input)
	ui.add_child(pad)
	# the card
	card = PanelContainer.new()
	card.add_theme_stylebox_override("panel", _box(BG, 12, 10, 8))
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.layout_direction = _dir()
	card.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			details = not details
			card_details.visible = details)
	ui.add_child(card)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 4)
	cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(cv)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cv.add_child(head)
	card_icon = TextureRect.new()
	card_icon.custom_minimum_size = Vector2(48, 48)
	card_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	card_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	card_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(card_icon)
	var nv := VBoxContainer.new()
	nv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nv.alignment = BoxContainer.ALIGNMENT_CENTER
	nv.add_theme_constant_override("separation", -4)
	nv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(nv)
	card_name = _label("", 22, ACCENT)
	nv.add_child(card_name)
	card_sub = _label("", 11, DIM)
	card_sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	card_sub.clip_text = true
	nv.add_child(card_sub)
	card_details = VBoxContainer.new()
	card_details.add_theme_constant_override("separation", 4)
	card_details.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cv.add_child(card_details)
	card_desc = _label("", 13, TEXT)
	card_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_details.add_child(card_desc)
	card_axes = _label("", 11, Color("8fd3ff"))
	card_axes.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_details.add_child(card_axes)
	card_nums = HFlowContainer.new()
	card_nums.add_theme_constant_override("h_separation", 4)
	card_nums.add_theme_constant_override("v_separation", 4)
	card_nums.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_details.add_child(card_nums)
	# the hint and the status over the bottom bar
	hint = _label("", 11, Color(1, 1, 1, 0.85), HORIZONTAL_ALIGNMENT_CENTER)
	hint.add_theme_stylebox_override("normal", _box(Color(0.05, 0.06, 0.1, 0.55), 8, 8, 2))
	ui.add_child(hint)
	status = _label("", 15, TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	status.add_theme_stylebox_override("normal", _box(Color(0.05, 0.06, 0.1, 0.55), 8, 8, 1))
	ui.add_child(status)
	# the bottom bar
	bar = HBoxContainer.new()
	bar.layout_direction = _dir()
	bar.add_theme_constant_override("separation", 6)
	ui.add_child(bar)
	for spec: Array in [["prev", func() -> void: step(-1)], ["list", func() -> void: show_picker(true)], ["reset", reset], ["next", func() -> void: step(1)]]:
		var b := _button(tr_(spec[0]), spec[1])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.y = 44
		b.name = String(spec[0])
		bar.add_child(b)
	_build_picker()


## Phone first: a 360 x 640 / 640 x 360 virtual canvas scaled to the window.
func _layout() -> void:
	var win := get_tree().root
	var real := Vector2(win.size)
	var was := portrait
	portrait = real.y >= real.x
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	win.content_scale_size = Vector2i(360, 640) if portrait else Vector2i(640, 360)
	if was != portrait or index < 0:
		details = portrait
	card_details.visible = details
	arena.cam.keep_aspect = Camera3D.KEEP_WIDTH if portrait else Camera3D.KEEP_HEIGHT
	arena.cam.fov = 70.0 if portrait else 58.0
	table.set_portrait(portrait)
	var vis := ui.get_viewport_rect().size
	var vw := vis.x
	var vh := vis.y
	var cw := minf(vw - 16.0, 400.0)
	card.position = Vector2(8, 8) if lang == "en" else Vector2(vw - 8.0 - cw, 8)
	card.size = Vector2(cw, 0)
	card.custom_minimum_size.x = cw
	card.reset_size()
	var bw := minf(vw - 16.0, 460.0)
	bar.position = Vector2((vw - bw) * 0.5, vh - 8.0 - 44.0)
	bar.size = Vector2(bw, 44)
	_bottom_y = vh - 8.0 - 44.0
	_center_labels()
	for g in picker_grids:
		g.columns = 3 if portrait else 5


## The hint and the status sit centred over the bottom bar, as wide as their text.
func _center_labels() -> void:
	var vw := ui.get_viewport_rect().size.x
	for pair: Array in [[hint, 26.0], [status, 52.0]]:
		var l: Label = pair[0]
		l.reset_size()
		l.position = Vector2((vw - l.size.x) * 0.5, _bottom_y - float(pair[1]))


func _process(delta: float) -> void:
	if card and card.size.x > 0.0:
		card.reset_size()
	if hint:
		_center_labels()
	_js_t -= delta
	if OS.has_feature("web") and _js_t <= 0.0 and index >= 0:
		# the page can read the lab's state (window.abodenLab): handy for tests and embedding
		_js_t = 0.5
		var e: Dictionary = list[index]
		var st := {"weapon": e.code, "id": e.id, "engine": e.engine, "lang": lang, "picker": picker.visible, "count": list.size(),
			"hits": table.hits if world == table else arena.hits, "fired": fired_military if world == table else arena.blaster.fired,
			"fps": Engine.get_frames_per_second()}
		JavaScriptBridge.eval("window.abodenLab=%s" % JSON.stringify(st), true)
	_flash_t = maxf(0.0, _flash_t - delta)
	if world == table and index >= 0:
		var id := str(list[index].id)
		var ml := table.ml
		var full := int(Table.Catalog.WEAPONS[id].get("ammo", 0)) if Table.Catalog.WEAPONS.has(id) else 0
		var cd := ml.cooldown_left(id)
		var a := ml.ammo(id)
		var state := tr_("ready")
		var c := GREEN
		if a <= 0:
			state = tr_("empty")
			c = RED
		elif cd > 0.0:
			state = "%s %.1f%s" % [tr_("cool"), cd, "s" if lang == "en" else " ث"]
			c = ACCENT
		status.text = "%s %d/%d  ·  %s  ·  %s %d" % [tr_("ammo"), a, full, state, tr_("hits"), table.hits]
		status.add_theme_color_override("font_color", RED if _flash_t > 0.0 else c)
	else:
		status.text = "%s %d" % [tr_("hits"), arena.hits]
		status.add_theme_color_override("font_color", TEXT)


# --- the world's input (the pad) ----------------------------------------------------------

func _pad_input(ev: InputEvent) -> void:
	if debug_input and not ev is InputEventMouseMotion:
		print("pad: ", ev.as_text(), " dev=", ev.device)
	if ev is InputEventScreenTouch:
		_touch_seen = true
		var t := ev as InputEventScreenTouch
		if t.pressed:
			_fingers[t.index] = t.position
			if _fingers.size() == 1:
				_down(t.position)
			else:
				_dragged = true
				_pinch = _spread()
				if world == arena:
					arena.trigger(false)
		else:
			_fingers.erase(t.index)
			if _fingers.is_empty():
				_up(t.position)
		pad.accept_event()
	elif ev is InputEventScreenDrag:
		_touch_seen = true
		var d := ev as InputEventScreenDrag
		_fingers[d.index] = d.position
		if _fingers.size() >= 2:
			var s := _spread()
			if _pinch > 0.0 and s > 0.0 and world == table:
				table.zoom(_pinch / s)
			_pinch = s
		else:
			_move(d.position, d.relative)
		pad.accept_event()
	elif ev is InputEventMouseButton:
		var b := ev as InputEventMouseButton
		if b.device == InputEvent.DEVICE_ID_EMULATION and _touch_seen:
			return
		if b.button_index == MOUSE_BUTTON_WHEEL_UP and b.pressed and world == table:
			table.zoom(0.9)
		elif b.button_index == MOUSE_BUTTON_WHEEL_DOWN and b.pressed and world == table:
			table.zoom(1.1)
		elif b.button_index == MOUSE_BUTTON_LEFT:
			if b.pressed:
				_down(b.position)
			else:
				_up(b.position)
	elif ev is InputEventMouseMotion:
		var mm := ev as InputEventMouseMotion
		if mm.device == InputEvent.DEVICE_ID_EMULATION and _touch_seen:
			return
		if mm.button_mask & MOUSE_BUTTON_MASK_LEFT:
			_move(mm.position, mm.relative)


func _spread() -> float:
	var ps: Array = _fingers.values()
	return (ps[0] as Vector2).distance_to(ps[1]) if ps.size() >= 2 else 0.0


func _down(p: Vector2) -> void:
	_press_at = p
	_press_t = Time.get_ticks_msec() / 1000.0
	_press_frame = Engine.get_process_frames()
	_dragged = false
	if world == arena:
		arena.aim_at(p)
		arena.trigger(true)


func _move(p: Vector2, rel: Vector2) -> void:
	if debug_input:
		print("move ", p, " ", rel)
	if p.distance_to(_press_at) > 10.0:
		_dragged = true
	if world == arena:
		arena.aim_at(p)
	elif _dragged:
		table.orbit(rel)


func _up(p: Vector2) -> void:
	if debug_input:
		print("up dragged=", _dragged, " dt=", Time.get_ticks_msec() / 1000.0 - _press_t, " frames=", Engine.get_process_frames() - _press_frame, " pick=", table.pick(p) if world == table else Vector3.ZERO)
	if world == arena:
		arena.trigger(false)
	elif not _dragged and (Time.get_ticks_msec() / 1000.0 - _press_t < 0.8 or Engine.get_process_frames() - _press_frame <= 6):
		var ok := table.fire_at_screen(p)
		if ok:
			fired_military += 1
		else:
			_flash_t = 0.6
	_dragged = false
	_pinch = 0.0


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and (ev as InputEventKey).pressed and not (ev as InputEventKey).echo:
		match (ev as InputEventKey).keycode:
			KEY_RIGHT, KEY_TAB:
				step(1)
			KEY_LEFT:
				step(-1)
			KEY_R:
				reset()
			KEY_ESCAPE:
				show_picker(not picker.visible)
