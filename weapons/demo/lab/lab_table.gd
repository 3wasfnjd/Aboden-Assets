extends Node3D
## The weapon lab's military diorama: a small island in a sea strip on a wooden table, a few
## toy target blocks (knocked over by a blast, back on reset), the launch ship off the coast.
## It is the AbodenMilitaryLauncher's host (military_surface / military_water_depth); its
## camera orbits (drag), zooms (pinch / wheel) and a tap on the island fires there.

const Launcher := preload("res://addons/aboden_blaster/military/military_launcher.gd")
const Catalog := preload("res://addons/aboden_blaster/military/military_catalog.gd")
const Ship := preload("res://addons/aboden_blaster/military/military_ship.gd")
const MB := preload("res://addons/aboden_blaster/military/military_mesh.gd")

const HALF := Vector2(0.5, 0.32)
const SHIP_AT := Vector3(-0.32, 0.0, -0.04)
const ISLAND := Vector3(0.1, 0.0, 0.0)
const SCORCH_MAX := 40

var ml: Launcher
var ship: Ship
var cam: Camera3D
var weapon := ""
var yaw := 0.0
var pitch := 0.8
var dist := 0.72
var center := Vector3(-0.04, 0.01, 0.0)
var blocks: Array = []  # {node, p, size, down}
var hits := 0
var portrait := true
var _scorch: Array = []
var _preview_t := 0.0
var _zoomed := false


func _ready() -> void:
	_build()
	ml = Launcher.new()
	ml.name = "MilitaryLauncher"
	ml.unlimited = false
	add_child(ml)
	ml.setup(self)
	ship = Ship.new()
	ship.position = SHIP_AT
	ship.rotation.y = 0.25
	ml.add_child(ship)
	ml.ship = ship
	ml.refill()
	ml.impacted.connect(_on_impact)
	cam = Camera3D.new()
	cam.near = 0.002
	cam.far = 20.0
	add_child(cam)
	_cam_update()


func set_weapon(id: String) -> void:
	weapon = id
	ml.weapon = id


func reset() -> void:
	ml.clear()
	ml.refill()
	ml.hide_preview()
	hits = 0
	for b: Dictionary in blocks:
		b.down = false
		var nd: Node3D = b.node
		nd.rotation = Vector3.ZERO
		nd.position = b.p
		nd.visible = true
		(nd.material_override as StandardMaterial3D).albedo_color = b.col
	for s: Node in _scorch:
		s.queue_free()
	_scorch.clear()


# --- the host ----------------------------------------------------------------------

func military_surface(x: float, z: float) -> float:
	if absf(x) > HALF.x or absf(z) > HALF.y:
		return -INF
	return maxf(ground(x, z), 0.0)


func military_water_depth(x: float, z: float) -> float:
	return maxf(0.0, -ground(x, z))


## An island round ISLAND with a hill on it; the sea floor (below y = 0) around it.
func ground(x: float, z: float) -> float:
	var d := Vector2((x - ISLAND.x) / 0.3, (z - ISLAND.z) / 0.22).length()
	d += 0.06 * sin(atan2(z, x - ISLAND.x) * 5.0)
	var land := 1.0 - smoothstep(0.82, 1.04, d)
	var hill := 0.05 * exp(-((x - 0.2) * (x - 0.2) + (z + 0.08) * (z + 0.08)) / 0.005)
	var dunes := 0.0025 * sin(x * 40.0) * sin(z * 33.0)
	return lerpf(-0.014, 0.011 + hill + dunes, land)


# --- firing ------------------------------------------------------------------------

## The point on the table under a screen point (Vector3.INF if none).
func pick(screen: Vector2) -> Vector3:
	var o := cam.project_ray_origin(screen)
	var d := cam.project_ray_normal(screen)
	var step := 0.002
	var t := 0.0
	var prev := o
	for i in 1500:
		var p := o + d * t
		var s := military_surface(p.x, p.z)
		if s > -INF and p.y <= s:
			# refine between the last two samples
			var a := prev
			var b := p
			for k in 8:
				var m := (a + b) * 0.5
				var sm := military_surface(m.x, m.z)
				if sm > -INF and m.y <= sm:
					b = m
				else:
					a = m
			return Vector3(b.x, military_surface(b.x, b.z), b.z)
		prev = p
		t += step * (1.0 + t * 2.0)
		if t > 6.0:
			break
	return Vector3.INF


## Fires the weapon at a screen point; false (and nothing) if not on the table or not ready.
func fire_at_screen(screen: Vector2) -> bool:
	var p := pick(screen)
	if p == Vector3.INF:
		return false
	return fire_at(p)


func fire_at(p: Vector3) -> bool:
	if not ml.can_fire(weapon):
		return false
	ml.aim(p, weapon)
	_preview_t = 1.2
	return ml.fire(p, weapon)


func _on_impact(p: Vector3, info: Dictionary) -> void:
	var r := float(info.get("blast_r", 0.02))
	if info.has("nuke_r"):
		r = maxf(r, float(info.nuke_r))
	for b: Dictionary in blocks:
		if b.down:
			continue
		var bp: Vector3 = b.p
		var size: Vector3 = b.size
		if Vector2(bp.x - p.x, bp.z - p.z).length() < r + maxf(size.x, size.z) * 0.5:
			b.down = true
			hits += 1
			var nd: Node3D = b.node
			var away := Vector2(bp.x - p.x, bp.z - p.z).normalized()
			var tw := create_tween().set_parallel(true)
			tw.tween_property(nd, "rotation", Vector3(away.y * 1.3, randf_range(-0.6, 0.6), -away.x * 1.3), 0.35)
			tw.tween_property(nd, "position", bp + Vector3(away.x * 0.01, -size.y * 0.3, away.y * 0.01), 0.35)
			(nd.material_override as StandardMaterial3D).albedo_color = (b.col as Color).darkened(0.65)
	if String(info.get("kind", "land")) in ["land", "nuke"]:
		_add_scorch(p, maxf(float(info.get("crater_r", 0.012)), 0.006) * (4.0 if info.get("kind") == "nuke" else 1.4))


func _add_scorch(p: Vector3, r: float) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = 0.0006
	cm.radial_segments = 20
	cm.rings = 1
	mi.mesh = cm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.12, 0.10, 0.08, 0.75)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = p + Vector3(0, 0.0012, 0)
	add_child(mi)
	_scorch.append(mi)
	if _scorch.size() > SCORCH_MAX:
		(_scorch.pop_front() as Node).queue_free()


func _process(delta: float) -> void:
	if _preview_t > 0.0:
		_preview_t -= delta
		if _preview_t <= 0.0:
			ml.hide_preview()


# --- the camera --------------------------------------------------------------------

func orbit(d: Vector2) -> void:
	yaw -= d.x * 0.008
	pitch = clampf(pitch + d.y * 0.006, 0.25, 1.45)
	_cam_update()


func zoom(f: float) -> void:
	_zoomed = true
	dist = clampf(dist * f, 0.12, 1.6)
	_cam_update()


func set_portrait(p: bool) -> void:
	portrait = p
	if not _zoomed:
		dist = 0.6 if p else 0.72
	_cam_update()


func _cam_update() -> void:
	if cam == null:
		return
	cam.keep_aspect = Camera3D.KEEP_WIDTH if portrait else Camera3D.KEEP_HEIGHT
	cam.fov = 62.0 if portrait else 40.0
	var dir := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
	cam.look_at_from_position(center + dir * dist, center)


# --- the world ---------------------------------------------------------------------

func _build() -> void:
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
	env.ambient_light_energy = 0.4
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.95
	env.glow_enabled = true
	env.glow_intensity = 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -35, 0)
	sun.light_energy = 0.9
	add_child(sun)
	# the table top (wood)
	var top := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.3, 0.04, 0.9)
	top.mesh = bm
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color("6b4a2f")
	top.material_override = wm
	top.position = Vector3(0, -0.04, 0)
	add_child(top)
	# the terrain: a vertex-coloured height grid
	var mb := MB.new()
	var n := 120
	for i in n:
		for j in n:
			var x0 := lerpf(-HALF.x, HALF.x, float(i) / n)
			var x1 := lerpf(-HALF.x, HALF.x, float(i + 1) / n)
			var z0 := lerpf(-HALF.y, HALF.y, float(j) / n)
			var z1 := lerpf(-HALF.y, HALF.y, float(j + 1) / n)
			var q := [Vector3(x0, ground(x0, z0), z0), Vector3(x1, ground(x1, z0), z0), Vector3(x1, ground(x1, z1), z1), Vector3(x0, ground(x0, z1), z1)]
			var h: float = (q[0] as Vector3).y * 0.5 + (q[2] as Vector3).y * 0.5
			var c := Color("c8b07a")
			if h > 0.03:
				c = Color("8f9a5a").lerp(Color("6f6448"), clampf((h - 0.03) / 0.03, 0.0, 1.0))
			elif h > 0.006:
				c = Color("9fae66")
			elif h < 0.0:
				c = Color("b8a77a").darkened(0.2)
			mb.tri_out(q[0], q[2], q[1], c, Vector3.UP)
			mb.tri_out(q[0], q[3], q[2], c, Vector3.UP)
	var land := MeshInstance3D.new()
	land.mesh = mb.commit(null, MB.vc_material(0.9))
	add_child(land)
	# the sea surface (y = 0)
	var sea := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(HALF.x * 2.0, HALF.y * 2.0)
	sea.mesh = pm
	var sw := StandardMaterial3D.new()
	sw.albedo_color = Color(0.20, 0.52, 0.72, 0.8)
	sw.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sw.roughness = 0.15
	sea.material_override = sw
	add_child(sea)
	# toy target blocks: a depot, sheds, a tower, tanks
	var defs := [[Vector3(0.10, 0, 0.02), Vector3(0.03, 0.012, 0.02), Color("6f7883")], [Vector3(0.15, 0, 0.07), Vector3(0.016, 0.008, 0.016), Color("98a0a8")],
		[Vector3(0.05, 0, -0.04), Vector3(0.02, 0.018, 0.02), Color("8c7a5f")], [Vector3(0.16, 0, -0.01), Vector3(0.012, 0.03, 0.012), Color("5f6870")],
		[Vector3(0.02, 0, 0.08), Vector3(0.026, 0.007, 0.014), Color("78846b")], [Vector3(0.24, 0, 0.09), Vector3(0.018, 0.01, 0.024), Color("878e96")],
		[Vector3(-0.04, 0, 0.01), Vector3(0.014, 0.014, 0.014), Color("a0574a")], [Vector3(0.27, 0, -0.07), Vector3(0.02, 0.012, 0.02), Color("6d7a8a")]]
	for d in defs:
		var p: Vector3 = d[0]
		var s: Vector3 = d[1]
		var mi := MeshInstance3D.new()
		var bx := BoxMesh.new()
		bx.size = s
		mi.mesh = bx
		var m := StandardMaterial3D.new()
		m.albedo_color = d[2]
		m.roughness = 0.8
		mi.material_override = m
		var at := Vector3(p.x, ground(p.x, p.z) + s.y * 0.5, p.z)
		mi.position = at
		add_child(mi)
		blocks.append({"node": mi, "p": at, "size": s, "col": d[2], "down": false})
