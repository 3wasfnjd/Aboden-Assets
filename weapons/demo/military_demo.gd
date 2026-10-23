extends Node3D
## The military pack's demo: a small war table (land with a hill and a few toy blocks, a
## sea strip with a target boat, the launch ship, a target drone circling overhead) as the
## launcher's host (military_surface / military_water_depth / military_roof /
## military_air_target / military_scan). Click to fire the current weapon at the table,
## 1..9, 0, -, = and Q W E R T Y pick the eighteen weapons, Tab cycles them, S toggles
## slow motion. The recon drone's scan lights a ring on the ground; the anti-air missile
## goes for the target drone (which comes back a few seconds after it is hit).
## Screenshots: godot --rendering-driver opengl3 --path blaster-kit res://demo/military_demo.tscn \
##   -- --weapon=<id> --screenshot=<path.png>   (fires it, saves a 1280x720 PNG and quits).
##   --all=<dir> renders every weapon into <dir>/mil_<id>.png.

const Launcher := preload("res://addons/aboden_blaster/military/military_launcher.gd")
const Catalog := preload("res://addons/aboden_blaster/military/military_catalog.gd")
const Ship := preload("res://addons/aboden_blaster/military/military_ship.gd")
const MB := preload("res://addons/aboden_blaster/military/military_mesh.gd")

const DT := 1.0 / 60.0
const TARGET := Vector3(0.10, 0.0, 0.02)
const SHIP_AT := Vector3(-0.30, 0.0, -0.04)
const KEYS := [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9, KEY_0, KEY_MINUS, KEY_EQUAL,
	KEY_Q, KEY_W, KEY_E, KEY_R, KEY_T, KEY_Y]
## The torpedo's target: a boat out at sea.
const BOAT := Vector3(-0.24, 0.0, 0.17)
## The target drone circles here (centre, radius, height, angular speed).
const DRONE_C := Vector3(0.0, 0.0, 0.05)
const DRONE_R := 0.14
const DRONE_Y := 0.13
const DRONE_W := 0.35
## Per weapon, for the screenshots: [capture time (s after firing; < 0: that fraction of the
## flight), camera: "flight" (the shot in the air), "close" (right by it, at the third
## value's distance), "target" (the target area), "jet" / "load" (an aircraft: the third
## value s after its release; "load" frames only what it released, at the fourth value's
## distance), "recon" (over the scanned area) or "nuke"].
const SHOOT := {
	"ballistic": [-0.8, "close", 0.07], "cruise": [-0.7, "flight"], "artillery": [-0.55, "close", 0.06],
	"mlrs": [1.75, "target"], "cluster": [-0.7, "close", 0.12], "hypersonic": [-0.85, "flight"],
	"bunker": [-1.0, "load", 0.45, 0.08], "drone": [-0.6, "close", 0.06], "antiship": [-0.6, "flight"],
	"jet": [-1.0, "jet", 0.35], "nuke": [4.6, "nuke"],
	"swarm": [-0.5, "flight"], "aa": [0.45, "flight"], "recon": [-0.4, "recon"],
	"atgm": [-0.8, "close", 0.1], "glide": [-1.0, "jet", 0.9], "torpedo": [-0.75, "close", 0.12],
	"heli": [-1.0, "load", 0.12, 0.09],
}

var ml: Launcher
var ship: Ship
var cam: Camera3D
var weapon := "ballistic"
var shot_path := ""
var all_dir := ""
var _t := -1.0
var _capture := 0.0
var _done := false
var air_drone: MeshInstance3D
var _drone_t := 0.0
var _drone_down := 0.0
var scan_ring: MeshInstance3D
var _scan_fade := 0.0


func military_surface(x: float, z: float) -> float:
	if absf(x) > 0.5 or absf(z) > 0.32:
		return -INF
	return maxf(ground(x, z), 0.0)


func military_water_depth(x: float, z: float) -> float:
	return maxf(0.0, -ground(x, z))


## The toy blocks are buildings: low flyers climb over them.
func military_roof(x: float, z: float) -> float:
	var top := -INF
	for b in BLOCKS:
		var p: Vector3 = b[0]
		var sz: Vector3 = b[1]
		if absf(x - p.x) < sz.x * 0.5 + 0.003 and absf(z - p.z) < sz.z * 0.5 + 0.003:
			top = maxf(top, ground(p.x, p.z) + sz.y)
	return top


## The anti-air missile goes for the target drone while it is up.
func military_air_target(_from: Vector3, _aim: Vector3) -> Variant:
	return air_drone if air_drone.visible else null


## The recon drone looks down: a ring on the ground under it.
func military_scan(p: Vector3, r: float) -> void:
	var g := maxf(ground(p.x, p.z), 0.0)
	scan_ring.transform = Transform3D(Basis().scaled(Vector3(r, 1.0, r)), Vector3(p.x, g + 0.001, p.z))
	scan_ring.visible = true
	_scan_fade = 0.3


func _on_impact(_p: Vector3, info: Dictionary) -> void:
	if info.kind == "air" and info.get("target") == air_drone:
		air_drone.visible = false
		_drone_down = 4.0


## Land east of x = -0.17 (a low plateau with a hill), the sea floor west of it.
func ground(x: float, z: float) -> float:
	var shore := smoothstep(-0.21, -0.13, x)
	var hill := 0.055 * exp(-((x - 0.22) * (x - 0.22) + (z + 0.12) * (z + 0.12)) / 0.006)
	var dunes := 0.003 * sin(x * 40.0) * sin(z * 33.0)
	return lerpf(-0.012, 0.012 + hill + dunes, shore)


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--weapon="):
			weapon = a.trim_prefix("--weapon=")
		elif a.begins_with("--screenshot="):
			shot_path = a.trim_prefix("--screenshot=")
		elif a.begins_with("--all="):
			all_dir = a.trim_prefix("--all=")
			weapon = Catalog.ids()[0]
	_build_world()
	ml = Launcher.new()
	ml.name = "MilitaryLauncher"
	ml.auto_step = shot_path == "" and all_dir == ""
	ml.unlimited = true
	add_child(ml)
	ml.setup(self)
	ml.set_seed(5)
	ship = Ship.new()
	ship.position = SHIP_AT
	ml.add_child(ship)
	ml.ship = ship
	ml.weapon = weapon
	ml.impacted.connect(_on_impact)
	_build_air_drone()
	cam = Camera3D.new()
	cam.fov = 40.0
	cam.near = 0.002
	cam.far = 20.0
	add_child(cam)
	cam.look_at_from_position(Vector3(-0.05, 0.42, 0.62), Vector3(-0.05, 0.02, 0.0))
	if shot_path != "" or all_dir != "":
		_start_shot()


func _target() -> Vector3:
	var t := BOAT if weapon == "torpedo" else TARGET
	return Vector3(t.x, military_surface(t.x, t.z), t.z)


func _start_shot() -> void:
	ml.clear()
	ml.weapon = weapon
	air_drone.visible = true
	_drone_down = 0.0
	scan_ring.visible = false
	var tgt := _target()
	var pl := ml.plan(tgt, weapon)
	ml.fire(tgt, weapon)
	var c: float = SHOOT[weapon][0]
	_capture = -c * float(pl.T) if c < 0.0 else c
	if SHOOT[weapon][1] in ["jet", "load"]:
		_capture = float(pl.release_t) + float(SHOOT[weapon][2])
	_t = 0.0
	_done = false


func _process(delta: float) -> void:
	var dt := DT if _t >= 0.0 else delta * (ml.slow_factor if ml.slow_motion else 1.0)
	if not _done:
		_step_world(dt)
	if _t < 0.0 or _done:
		return
	ml.step(DT)
	_t += DT
	if _t >= _capture:
		_done = true
		_frame()
		_save.call_deferred()


## The target drone circles; the scan ring fades.
func _step_world(dt: float) -> void:
	_drone_t += dt
	if _drone_down > 0.0:
		_drone_down -= dt
		if _drone_down <= 0.0:
			air_drone.visible = true
	var a := _drone_t * DRONE_W
	air_drone.position = DRONE_C + Vector3(cos(a) * DRONE_R, DRONE_Y, sin(a) * DRONE_R)
	air_drone.basis = Basis(Vector3.UP, -a - PI)
	_scan_fade -= dt
	if _scan_fade <= 0.0:
		scan_ring.visible = false


## The camera on the newest shot in the air, or on the target area.
func _frame() -> void:
	var mode: String = SHOOT[weapon][1]
	var tgt := _target()
	var at := tgt + Vector3(0, 0.01, 0)
	var dist := 0.3
	if mode == "recon":
		at = tgt + Vector3(0, 0.05, 0)
		dist = 0.42
	elif mode in ["flight", "jet", "close", "load"]:
		var sum := Vector3.ZERO
		var n := 0
		for f in ml.flights:
			if mode == "load" and not f.sub:
				continue
			sum += (f.slot.node as Node3D).position
			n += 1
		if n > 0:
			at = sum / n
		elif weapon == "aa":
			at = air_drone.position
		at = at.lerp(tgt, 0.3 if mode in ["flight", "jet"] else 0.0)
		dist = 0.3 if mode in ["flight", "jet"] else float(SHOOT[weapon][3 if mode == "load" else 2])
	elif mode == "nuke":
		at = tgt + Vector3(0, 0.08, 0)
		dist = 0.62
	cam.look_at_from_position(at + Vector3(-0.55, 0.42, 0.95).normalized() * dist, at)


func _save() -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := shot_path if all_dir == "" else all_dir.path_join("mil_%s.png" % weapon)
	if path.begins_with("res://"):
		path = ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var err := img.save_png(path)
	print("military_demo: %s %s -> %s" % [weapon, error_string(err), path])
	if all_dir != "":
		var i := Catalog.ids().find(weapon)
		if i + 1 < Catalog.ids().size():
			weapon = Catalog.ids()[i + 1]
			_start_shot()
			return
	get_tree().quit(0 if err == OK else 1)


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed:
		var k := KEYS.find((e as InputEventKey).keycode)
		if k >= 0:
			weapon = Catalog.ids()[k]
		elif (e as InputEventKey).keycode == KEY_TAB:
			weapon = Catalog.next_id(weapon)
		elif (e as InputEventKey).keycode == KEY_S:
			ml.slow_motion = not ml.slow_motion
		ml.weapon = weapon
	elif e is InputEventMouseButton and e.pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mp: Vector2 = (e as InputEventMouseButton).position
		var o := cam.project_ray_origin(mp)
		var d := cam.project_ray_normal(mp)
		# march the ray to the table
		for i in 400:
			var p := o + d * (i * 0.004)
			var s := military_surface(p.x, p.z)
			if s > -INF and p.y <= s:
				ml.fire(Vector3(p.x, s, p.z), weapon)
				break


# --- the world ---------------------------------------------------------------------

## Toy blocks (buildings): [centre, size, colour].
const BLOCKS := [[Vector3(0.10, 0, 0.02), Vector3(0.03, 0.012, 0.02), Color("6f7883")], [Vector3(0.14, 0, 0.06), Vector3(0.016, 0.008, 0.016), Color("98a0a8")],
	[Vector3(0.06, 0, -0.03), Vector3(0.02, 0.018, 0.02), Color("8c7a5f")], [Vector3(0.15, 0, -0.02), Vector3(0.012, 0.03, 0.012), Color("5f6870")],
	[Vector3(0.03, 0, 0.07), Vector3(0.026, 0.007, 0.014), Color("78846b")], [Vector3(0.19, 0, 0.09), Vector3(0.018, 0.01, 0.024), Color("878e96")]]


## The target drone (red, the anti-air missile's air target) and the recon scan ring.
func _build_air_drone() -> void:
	var dm := MB.new()
	dm.box(Vector3.ZERO, Vector3(0.007, 0.0012, 0.0012), Color("c0392b"))
	dm.box(Vector3(0.0005, 0, 0), Vector3(0.0018, 0.0003, 0.011), Color("c0392b"))
	dm.box(Vector3(-0.003, 0.0008, 0), Vector3(0.0012, 0.0016, 0.0003), Color("8e2a20"))
	air_drone = MeshInstance3D.new()
	air_drone.name = "TargetDrone"
	air_drone.mesh = dm.commit(null, MB.vc_material(0.6))
	add_child(air_drone)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 48:
		var a0 := TAU * i / 48.0
		var a1 := TAU * (i + 1) / 48.0
		var q := [Vector3(cos(a0) * 0.93, 0, sin(a0) * 0.93), Vector3(cos(a0), 0, sin(a0)), Vector3(cos(a1) * 0.93, 0, sin(a1) * 0.93), Vector3(cos(a1), 0, sin(a1))]
		for v in [q[0], q[1], q[2], q[2], q[1], q[3]]:
			st.add_vertex(v)
	scan_ring = MeshInstance3D.new()
	scan_ring.name = "ScanRing"
	scan_ring.mesh = st.commit()
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.cull_mode = BaseMaterial3D.CULL_DISABLED
	rm.albedo_color = Color(1.0, 0.74, 0.18, 0.8)
	scan_ring.material_override = rm
	scan_ring.visible = false
	add_child(scan_ring)

func _build_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color("6f9fd8")
	sm.sky_horizon_color = Color("cfe0ee")
	sm.ground_bottom_color = Color("262b36")
	sm.ground_horizon_color = Color("4a5263")
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.35
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.9
	env.glow_enabled = true
	env.glow_intensity = 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -35, 0)
	sun.light_energy = 0.85
	add_child(sun)
	# the table top (wood) under the model
	var top := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.3, 0.04, 0.9)
	top.mesh = bm
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color("6b4a2f")
	top.material_override = wm
	top.position = Vector3(0, -0.04, 0)
	add_child(top)
	# terrain: a vertex-coloured height grid, toon shaded
	var mb := MB.new()
	var n := 160
	var X := 0.5
	var Z := 0.32
	for i in n:
		for j in n:
			var x0 := lerpf(-X, X, float(i) / n)
			var x1 := lerpf(-X, X, float(i + 1) / n)
			var z0 := lerpf(-Z, Z, float(j) / n)
			var z1 := lerpf(-Z, Z, float(j + 1) / n)
			var q := [Vector3(x0, ground(x0, z0), z0), Vector3(x1, ground(x1, z0), z0), Vector3(x1, ground(x1, z1), z1), Vector3(x0, ground(x0, z1), z1)]
			var h: float = (q[0] as Vector3).y * 0.5 + (q[2] as Vector3).y * 0.5
			var c := Color("b39a64")
			if h > 0.03:
				c = Color("8f7f55").lerp(Color("6f6448"), clampf((h - 0.03) / 0.03, 0.0, 1.0))
			elif h > 0.004:
				c = Color("a68e5c")
			elif h < 0.0:
				c = Color("9c8a62").darkened(0.15)
			mb.tri_out(q[0], q[2], q[1], c, Vector3.UP)
			mb.tri_out(q[0], q[3], q[2], c, Vector3.UP)
	# toy blocks: a depot, sheds, tanks and a tower near the target
	for b in BLOCKS:
		var p: Vector3 = b[0]
		var s: Vector3 = b[1]
		mb.box(Vector3(p.x, ground(p.x, p.z) + s.y * 0.5, p.z), s, b[2])
	for k in 3:
		var tp := Vector3(-0.02 + k * 0.016, 0, -0.08)
		mb.cylinder(Vector3(tp.x, ground(tp.x, tp.z), tp.z), 0.006, 0.006, 0.008, 14, Color("b9b6ad"))
	# the target boat at sea (the torpedo's)
	mb.box(Vector3(BOAT.x, 0.0015, BOAT.z), Vector3(0.03, 0.004, 0.008), Color("7d848c"))
	mb.box(Vector3(BOAT.x - 0.003, 0.0045, BOAT.z), Vector3(0.008, 0.004, 0.005), Color("a9b0b8"))
	var land := MeshInstance3D.new()
	land.mesh = mb.commit(null, MB.vc_material(0.9))
	add_child(land)
	# the sea surface (y = 0)
	var sea := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(0.45, 0.64)
	sea.mesh = pm
	sea.position = Vector3(-0.275, 0.0, 0.0)
	var sw := StandardMaterial3D.new()
	sw.albedo_color = Color(0.20, 0.52, 0.70, 0.82)
	sw.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sw.roughness = 0.15
	sea.material_override = sw
	add_child(sea)
