extends Node3D
## The kit's demo: a camera, a floor, a back wall, a stage of target spheres (hidden layers = 0
## hit spheres under visible balls) and a few soft targets the
## demo itself hands the blaster (it is the blaster's host: blaster_targets / blaster_hit /
## blaster_stage). Every host call the demo does not make keeps its default. For the v1.2
## weapons it also freezes its soft targets (blaster_freeze: they turn icy), lets them be
## pulled and pushed (blaster_pull: they drift home after) and, while the shield or the magnet
## is picked, sends little red hostile shots at you (blaster_threats / blaster_block). Its
## targets stand still, so it has no blaster_slow (the bakhoor's smoke is only the look here).
##
## Interactive: click (or Space) to fire toward the mouse, 1..9, 0, -, = pick the first twelve
## styles, Tab cycles them all, F toggles the triple shot. The mouse fires with fire_at().
## Screenshots: godot --rendering-driver opengl3 --path blaster-kit res://demo/blaster_demo.tscn \
##   -- --style=<id> --screenshot=<path.png>   (fires that style a few times at the targets,
##   saves a 1280x720 PNG and quits). --all=<dir> renders every style into <dir>/<id>.png.

const Blaster := preload("res://addons/aboden_blaster/blaster.gd")
const Catalog := preload("res://addons/aboden_blaster/shot_catalog.gd")

const MUZZLE := Vector3(0.3, 1.35, 0.4)
const KEYS := [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9, KEY_0, KEY_MINUS, KEY_EQUAL]
const DT := 1.0 / 60.0
const WIDE_FROM := Vector3(1.25, 1.75, 1.35)
const WIDE_AT := Vector3(-0.25, 1.3, -3.2)
## Per style, for the screenshots: [shots, seconds between them, capture time after the first,
## aim (which targets, "soft" too), aim lift (m), camera distance from the shots at capture
## (0 = the wide view; the shots are life size, 2 to 6 cm, so most are framed up close),
## and optionally where the camera looks from (else from behind and to the right)].
const SHOOT := {
	"bolt": [3, 0.13, 0.31, [0, 2, 4], 0.0, 0.75],
	"mini": [4, 0.13, 0.5, [1, 0, 2, 4], 0.6, 0.32],
	"bubble": [6, 0.17, 1.0, [0, 1, 2, 3, 4, 0], 0.3, 0.8],
	"firework": [1, 0.0, 0.93, [2], 2.6, 1.5],
	"confetti": [2, 0.31, 0.5, [0, 3], 0.3, 0.0],
	"bouncy": [4, 0.23, 1.25, [0, 2, 4, 1], -0.9, 0.55],
	"laser": [3, 0.17, 0.4, [0, 2, 4], 0.0, 0.0],
	"boomerang": [1, 0.0, 0.45, [2], 0.0, 0.55],
	"glob": [2, 0.36, 0.75, [1, 3], 0.7, 0.7],
	"rocket": [3, 0.2, 0.75, [5, 6, 7], 1.2, 0.0],
	"lightning": [1, 0.0, 0.07, [1], 0.0, 0.0],
	"dallah": [2, 0.26, 0.62, [0, 2], 1.0, 0.75],
	"falcon": [1, 0.0, 0.62, [5], 0.0, 0.42, Vector3(0.9, 0.3, -1.0)],
	"freeze": [1, 0.0, 0.12, [6], 0.0, 0.0],
	"blackhole": [1, 0.0, 1.5, [2], 0.0, 1.1],
	"dates": [6, 0.1, 0.53, [0, 2, 4, 1, 3, 0], 0.3, 0.3, Vector3(1.0, 0.35, -0.4)],
	"bakhoor": [1, 0.0, 2.4, [2], -0.5, 0.9],
	"lasso": [1, 0.0, 1.0, [5], 1.0, 0.0],
	"hose": [8, 0.12, 0.95, [2], 0.4, 1.8],
	"cluster": [1, 0.0, 0.9, [2], 0.6, 1.3],
	"magnet": [1, 0.0, 1.1, [2], 0.0, 0.5, Vector3(0.6, 0.4, 1.0)],
	"shield": [1, 0.0, 1.15, [2], 0.0, 1.9],
}
## Hostile shots (for the shield and the magnet): where they leave from, how fast (m/s), how big.
const HOSTILE_FROM := [Vector3(-1.2, 1.6, -7.5), Vector3(0.9, 1.2, -7.5), Vector3(0.0, 2.0, -7.5), Vector3(1.8, 1.7, -7.5)]
const HOSTILE_SPEED := 5.0
const HOSTILE_R := 0.04

var blaster: Blaster
var cam: Camera3D
var stage_node: DemoStage
var soft: Array = []  # {ref, p, r, color, node, home, frozen}
var hostile: Array = []  # {ref (its node), p, v, r}
var _hostile_t := 0.0
var hud: Label
var shot_style := "bolt"
var fan := 1
var shot_path := ""
var all_dir := ""
var _t := -1.0
var _plan: Array = []  # [time, hand, dir]
var _capture := -1.0
var _done := false


## The stage: proxies (hidden, layers = 0) that take a shot, the balls you see over them
## (in "blaster_ignore", so the ray sees only the proxy), and a back wall that does not.
class DemoStage:
	extends Node3D
	var proxies: Array = []
	var looks: Dictionary = {}  # proxy -> visible MeshInstance3D
	var flash: Dictionary = {}  # proxy -> seconds left
	var sturdy := false
	var fan := 1
	func shot_fan() -> int:
		return fan
	func add_target(p: Vector3, r: float, color: Color) -> void:
		var proxy := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = r
		sm.height = r * 2.0
		proxy.mesh = sm
		proxy.layers = 0
		proxy.position = p
		add_child(proxy)
		var look := MeshInstance3D.new()
		var vm := SphereMesh.new()
		vm.radius = r
		vm.height = r * 2.0
		look.mesh = vm
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 0.45
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = 0.0
		look.material_override = m
		look.add_to_group(&"blaster_ignore")
		proxy.add_child(look)
		# A ring stand under it.
		var stand := MeshInstance3D.new()
		var cy := CylinderMesh.new()
		cy.top_radius = 0.02
		cy.bottom_radius = 0.05
		cy.height = p.y - r
		stand.mesh = cy
		stand.position = Vector3(p.x, (p.y - r) * 0.5, p.z)
		var sm2 := StandardMaterial3D.new()
		sm2.albedo_color = Color("6b6f80")
		stand.material_override = sm2
		stand.add_to_group(&"blaster_ignore")
		add_child(stand)
		proxies.append(proxy)
		looks[proxy] = look
	func add_wall(p: Vector3, size: Vector3, color: Color) -> void:
		var mi := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = size
		mi.mesh = b
		mi.position = p
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 0.9
		mi.material_override = m
		add_child(mi)
	func shoot(obj: Node, _point: Vector3, _dir: Vector3) -> bool:
		if not obj in proxies or not (obj as Node3D).visible:
			return false
		flash[obj] = 0.35
		if not sturdy:
			(obj as Node3D).visible = false
			get_tree().create_timer(1.5).timeout.connect(func() -> void: (obj as Node3D).visible = true)
		return true
	func _process(delta: float) -> void:
		for p: Node in flash.keys():
			flash[p] = float(flash[p]) - delta
			var m := (looks[p] as MeshInstance3D).material_override as StandardMaterial3D
			m.emission_energy_multiplier = maxf(0.0, float(flash[p])) * 6.0
			if float(flash[p]) <= 0.0:
				flash.erase(p)


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--style="):
			shot_style = a.trim_prefix("--style=")
		elif a.begins_with("--screenshot="):
			shot_path = a.trim_prefix("--screenshot=")
		elif a.begins_with("--all="):
			all_dir = a.trim_prefix("--all=")
	_build_world()
	blaster = Blaster.new()
	blaster.name = "Blaster"
	add_child(blaster)
	blaster.setup(self)
	blaster.style = shot_style
	if shot_path != "" or all_dir != "":
		_start_shots()
	else:
		blaster.auto_step = true
	_hud()


# --- the host (AbodenBlaster calls these; everything else keeps its default) ---------

func blaster_targets() -> Array:
	return soft.filter(func(t: Dictionary) -> bool: return (t.node as Node3D).visible)


func blaster_hit(t: Dictionary, _dir: Vector3) -> bool:
	var nd: Node3D = t.node
	if not nd.visible:
		return false
	if shot_path == "" and all_dir == "":
		nd.visible = false
		get_tree().create_timer(2.0).timeout.connect(func() -> void: nd.visible = true)
	return true


func blaster_stage() -> Node3D:
	return stage_node


## The freeze ray froze a ball: it turns icy for that long.
func blaster_freeze(t: Dictionary, seconds: float) -> void:
	t.frozen = seconds


## Pulled (the black hole, the lasso, the magnet) or pushed (the hose): the ball moves (it
## drifts back home afterwards, _drift); a hostile shot the magnet draws in moves too.
func blaster_pull(t: Dictionary, to: Vector3, strength: float) -> void:
	t.p = (t.p as Vector3).move_toward(to, strength)
	var nd: Variant = t.get("node", t.get("ref"))
	if nd is Node3D and is_instance_valid(nd):
		(nd as Node3D).position = t.p


func blaster_threats() -> Array:
	return hostile


func blaster_block(th: Dictionary, _at: Vector3) -> bool:
	if is_instance_valid(th.ref):
		(th.ref as Node3D).queue_free()
	hostile.erase(th)
	return true


## The soft balls drift home and thaw; the hostile shots fly at you (one every 0.6 s while the
## shield or the magnet is picked, and a volley at the start of their screenshots).
func _drift(dt: float) -> void:
	for t: Dictionary in soft:
		var home: Vector3 = t.home
		if (t.p as Vector3).distance_to(home) > 1e-4:
			t.p = (t.p as Vector3).move_toward(home, 0.4 * dt)
			(t.node as Node3D).position = t.p
		t.frozen = maxf(0.0, float(t.frozen) - dt)
		var m := (t.node as MeshInstance3D).material_override as StandardMaterial3D
		m.albedo_color = Color("ff69b4").lerp(Color("bfeeff"), clampf(float(t.frozen) / 0.3, 0.0, 1.0))
	var want := blaster.style_for() in ["shield", "magnet"]
	if want and shot_path == "" and all_dir == "":
		_hostile_t -= dt
		if _hostile_t <= 0.0:
			_hostile_t = 0.6
			_add_hostile(HOSTILE_FROM[randi() % HOSTILE_FROM.size()])
	for j in range(hostile.size() - 1, -1, -1):
		var th: Dictionary = hostile[j]
		th.p += (th.v as Vector3) * dt
		if is_instance_valid(th.ref):
			(th.ref as Node3D).position = th.p
		if (th.p as Vector3).z > 2.0 or not want:
			if is_instance_valid(th.ref):
				(th.ref as Node3D).queue_free()
			hostile.remove_at(j)


func _add_hostile(from: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = HOSTILE_R
	sm.height = HOSTILE_R * 2.0
	mi.mesh = sm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("ff3030")
	m.emission_enabled = true
	m.emission = Color("ff3030")
	m.emission_energy_multiplier = 1.5
	mi.material_override = m
	mi.position = from
	add_child(mi)
	hostile.append({"ref": mi, "p": from, "v": (MUZZLE - from).normalized() * HOSTILE_SPEED, "r": HOSTILE_R})


# --- the world ---------------------------------------------------------------------

func _build_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color("1b2038")
	sm.sky_horizon_color = Color("4a5274")
	sm.ground_bottom_color = Color("1a1c24")
	sm.ground_horizon_color = Color("3a3f55")
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, 35, 0)
	sun.light_energy = 0.9
	add_child(sun)
	# The floor (y = 0, the blaster's default floor) with a grid for depth.
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(40, 40)
	floor_mi.mesh = pm
	var fm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
varying vec3 wp;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 g = abs(fract(wp.xz) - 0.5);
	float line = 1.0 - smoothstep(0.0, 0.02 + fwidth(wp.x) * 1.5, 0.5 - max(g.x, g.y));
	ALBEDO = mix(vec3(0.16, 0.17, 0.21), vec3(0.34, 0.36, 0.44), line);
	ROUGHNESS = 0.95;
}
"""
	fm.shader = sh
	floor_mi.material_override = fm
	add_child(floor_mi)
	stage_node = DemoStage.new()
	stage_node.name = "Stage"
	stage_node.sturdy = true
	add_child(stage_node)
	var cols := [Color("ff5c8a"), Color("ffd23f"), Color("3ec7ff"), Color("7ee05a"), Color("b98cff")]
	var at := [Vector3(-1.6, 1.3, -4.5), Vector3(-0.5, 1.7, -5.5), Vector3(0.6, 1.2, -4.2), Vector3(1.7, 1.6, -5.8), Vector3(0.0, 0.9, -6.8)]
	for i in at.size():
		stage_node.add_target(at[i], 0.22, cols[i])
	stage_node.add_wall(Vector3(0, 1.5, -9.0), Vector3(10, 3, 0.3), Color("3d4258"))
	# Soft targets (the host's own): floating pink balls for the homing and chaining shots.
	for p: Vector3 in [Vector3(-2.6, 2.4, -6.0), Vector3(2.8, 2.6, -6.4), Vector3(0.2, 3.0, -7.2)]:
		var ball := MeshInstance3D.new()
		var bm := SphereMesh.new()
		bm.radius = 0.24
		bm.height = 0.48
		ball.mesh = bm
		var m := StandardMaterial3D.new()
		m.albedo_color = Color("ff69b4")
		m.roughness = 0.3
		m.rim_enabled = true
		ball.material_override = m
		ball.position = p
		add_child(ball)
		soft.append({"ref": ball, "p": p, "r": 0.24, "color": "ff69b4", "node": ball, "home": p, "frozen": 0.0})
	cam = Camera3D.new()
	cam.fov = 62.0
	add_child(cam)
	cam.look_at_from_position(WIDE_FROM, WIDE_AT)


func _hud() -> void:
	var cl := CanvasLayer.new()
	add_child(cl)
	var icon := TextureRect.new()
	icon.position = Vector2(24, 20)
	icon.size = Vector2(72, 72)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.name = "Icon"
	cl.add_child(icon)
	hud = Label.new()
	hud.position = Vector2(108, 30)
	hud.add_theme_font_size_override("font_size", 26)
	hud.add_theme_color_override("font_color", Color.WHITE)
	hud.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	hud.add_theme_constant_override("outline_size", 8)
	cl.add_child(hud)
	_update_hud()


func _update_hud() -> void:
	var info := Catalog.info(blaster.style_for())
	var line := "%s  (%s)" % [info.get("en", ""), blaster.style_for()]
	if shot_path == "" and all_dir == "":
		line += "\nclick / space: fire   1-0 - =, Tab: style   F: triple (%d)" % fan
	hud.text = line
	var path := "res://addons/aboden_blaster/icons/%s.png" % info.get("icon", "bolt")
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	if img != null:
		(hud.get_parent().get_node("Icon") as TextureRect).texture = ImageTexture.create_from_image(img)


# --- interactive -------------------------------------------------------------------

func _unhandled_input(e: InputEvent) -> void:
	if shot_path != "" or all_dir != "":
		return
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		_fire_at(e.position)
	elif e is InputEventKey and e.pressed and not e.echo:
		var i := KEYS.find(e.keycode)
		if i >= 0:
			blaster.style = Catalog.ORDER[i]
		elif e.keycode == KEY_TAB:
			blaster.style = Catalog.ORDER[(Catalog.ORDER.find(blaster.style_for()) + 1) % Catalog.ORDER.size()]
		elif e.keycode == KEY_F:
			fan = 3 if fan == 1 else 1
			stage_node.fan = fan
		elif e.keycode == KEY_SPACE:
			_fire_at(get_viewport().get_mouse_position())
		_update_hud()


func _fire_at(screen: Vector2) -> void:
	var to := cam.project_ray_origin(screen) + cam.project_ray_normal(screen) * 8.0
	blaster.fire_at(MUZZLE, to)


# --- screenshots -------------------------------------------------------------------

func _aim(i: int) -> Vector3:
	var pts: Array = []
	for p: MeshInstance3D in stage_node.proxies:
		pts.append(p.position)
	for t: Dictionary in soft:
		pts.append(t.p)
	return pts[i % pts.size()]


func _start_shots() -> void:
	blaster.set_seed(11)
	seed(11)
	blaster.clear()
	blaster.style = shot_style
	for t: Dictionary in soft:
		t.p = t.home
		t.frozen = 0.0
		(t.node as Node3D).position = t.p
	for th: Dictionary in hostile:
		if is_instance_valid(th.ref):
			(th.ref as Node3D).queue_free()
	hostile.clear()
	if shot_style in ["shield", "magnet"]:
		for i in HOSTILE_FROM.size():
			_add_hostile(HOSTILE_FROM[i] + Vector3(0.0, 0.0, 1.6 * i))
	var plan: Array = SHOOT.get(blaster.style_for(), SHOOT.bolt)
	_plan.clear()
	var lift: float = plan[4]
	for j in int(plan[0]):
		var to: Vector3 = _aim(int(plan[3][j % plan[3].size()])) + Vector3.UP * lift
		_plan.append([j * float(plan[1]), "left" if j % 2 else "right", (to - MUZZLE).normalized()])
	_capture = float(plan[2])
	_t = 0.0
	_done = false
	if hud:
		_update_hud()


func _process(delta: float) -> void:
	if _t < 0.0:
		_drift(delta)
		return
	if _done:
		return
	# Fixed steps, so a screenshot is the same every time.
	while not _plan.is_empty() and float(_plan[0][0]) <= _t + 1e-6:
		var s: Array = _plan.pop_front()
		blaster.last_shot[s[1]] = -10.0
		blaster.fire(s[1], MUZZLE, s[2])
	_drift(DT)
	blaster.step(DT)
	_t += DT
	if _t >= _capture:
		_done = true
		_frame()
		_save.call_deferred()


## Frames the camera on the newest shot of this style (or the sparks) at `dist`.
func _frame() -> void:
	var plan: Array = SHOOT.get(blaster.style_for(), SHOOT.bolt)
	var dist: float = plan[5]
	if dist <= 0.0:
		cam.look_at_from_position(WIDE_FROM, WIDE_AT)
		return
	var kind := blaster.style_for()
	# The newest shot of this style, else the middle of the sparks (a firework's bloom).
	var sum := Vector3.ZERO
	var n := 0
	for o: Dictionary in blaster.shots:
		if o.kind == kind:
			sum = o.p
			n = 1
	if n == 0:
		for sp: Dictionary in blaster.sparks:
			sum += sp.p
			n += 1
	if n == 0:
		cam.look_at_from_position(WIDE_FROM, WIDE_AT)
		return
	var at := sum / n
	var from: Vector3 = plan[6] if plan.size() > 6 else Vector3(0.75, 0.45, 1.25)
	cam.look_at_from_position(at + from.normalized() * dist, at)


func _save() -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := shot_path if all_dir == "" else all_dir.path_join(shot_style + ".png")
	if path.begins_with("res://"):
		path = ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var err := img.save_png(path)
	print("blaster_demo: %s %s -> %s (%dx%d)" % [shot_style, error_string(err), path, img.get_width(), img.get_height()])
	if all_dir != "":
		var i := Catalog.ORDER.find(shot_style)
		if i + 1 < Catalog.ORDER.size():
			shot_style = Catalog.ORDER[i + 1]
			_start_shots()
			return
	get_tree().quit(0 if err == OK else 1)
