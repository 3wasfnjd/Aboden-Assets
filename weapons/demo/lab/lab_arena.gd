extends Node3D
## The weapon lab's playful arena: a small bright room (floor, a back wall, side walls and two
## pillars, all a stage the shots bounce off) with soft targets that move about and come back
## after a pop: balloons drifting in the air and jelly blobs hopping on the floor. It is the
## AbodenBlaster's host; every host call is optional, and the ones here are:
##   blaster_targets, blaster_hit, blaster_stage, blaster_floor_y, blaster_eye, blaster_hand,
##   blaster_credit, and the effect calls newer weapons may make (each harmless until one
##   does): blaster_slow(target, factor, seconds), blaster_pull(target, to, strength),
##   blaster_freeze(target, seconds), blaster_push(target, velocity).
## The lab fires with aim_at(screen point) / trigger(pressed).

const Blaster := preload("res://addons/aboden_blaster/blaster.gd")

const BALLOONS := 6
const BLOBS := 3
const RESPAWN := 1.6
const COLS := ["ff5c8a", "ffd23f", "3ec7ff", "7ee05a", "b98cff", "ff8a3d", "4fd1ff", "ff69b4"]
const ICY := Color("bfeaff")
const BOX := AABB(Vector3(-3.4, 0.0, -7.6), Vector3(6.8, 3.0, 4.8))  # where targets roam

var blaster: Blaster
var cam: Camera3D
var stage: Node3D
var hand: Node3D
var muzzle: Node3D
var targets_list: Array = []  # {ref, p, r, color, node, mat, base, kind, home, vel, phase, slow_k, slow_t, freeze_t, alive, back_t}
var hits := 0
var aim_point := Vector3(0, 1.4, -5)
var held := false
var _rng := RandomNumberGenerator.new()
# Hostile balls lobbed at the player while the shield or the magnet is chosen, so the two
# defensive weapons have something to stop (blaster_threats / blaster_block).
var threats_list: Array = []  # {ref, p, r, metal, node, vel}
var _lob_t := 0.0
const LOB_EVERY := 1.4
const DEFENDERS := ["shield", "magnet"]


## The stage's walls: visible meshes take a shot (they bounce the bouncy ones), shoot() says
## no hit counted (the soft targets are the host's).
class LabStage:
	extends Node3D
	func shoot(_obj: Node, _point: Vector3, _dir: Vector3) -> bool:
		return false


func _ready() -> void:
	_rng.seed = 7
	_build()
	blaster = Blaster.new()
	blaster.name = "Blaster"
	add_child(blaster)
	blaster.setup(self)
	blaster.auto_step = true


func set_weapon(id: String) -> void:
	blaster.style = id
	if not DEFENDERS.has(id):
		_clear_threats()


func reset() -> void:
	blaster.clear()
	hits = 0
	_clear_threats()
	for t: Dictionary in targets_list:
		_respawn(t)


# --- firing ------------------------------------------------------------------------

## Points the hand at what is under a screen point (a target, the floor, else far ahead).
func aim_at(screen: Vector2) -> void:
	var o := cam.project_ray_origin(screen)
	var d := cam.project_ray_normal(screen)
	var best := 40.0
	for t: Dictionary in targets_list:
		if not t.alive:
			continue
		var oc: Vector3 = o - t.p
		var b := oc.dot(d)
		var c := oc.length_squared() - pow(float(t.r) * 1.15, 2)
		var h := b * b - c
		if h >= 0.0:
			var dist := -b - sqrt(h)
			if dist > 0.0 and dist < best:
				best = dist
	if best >= 40.0 and d.y < -0.01:
		best = minf(best, -o.y / d.y)
	if best >= 40.0:
		best = 12.0
	aim_point = o + d * best


func trigger(on: bool) -> void:
	held = on
	if on:
		_fire()


func _fire() -> void:
	blaster.fire_at(muzzle.global_position, aim_point)


# --- the host ----------------------------------------------------------------------

func blaster_targets() -> Array:
	var live := targets_list.filter(func(t: Dictionary) -> bool: return t.alive)
	# Under the magnet every target counts as metal, so its pull shows.
	var metal := blaster.style == "magnet"
	for t: Dictionary in live:
		t.metal = metal
	return live


func blaster_threats() -> Array:
	return threats_list


## The shield or the magnet stopped a hostile ball: it bursts where it was stopped.
func blaster_block(th: Dictionary, _at: Vector3) -> bool:
	var i := -1
	for k in threats_list.size():
		if is_same(threats_list[k], th):
			i = k
	if i < 0:
		return false
	(th.node as Node3D).queue_free()
	threats_list.remove_at(i)
	hits += 1
	return true


func blaster_hit(t: Dictionary, _dir: Vector3) -> bool:
	var r := _rec(t)
	if r.is_empty() or not r.alive:
		return false
	r.alive = false
	(r.node as Node3D).visible = false
	r.back_t = RESPAWN
	hits += 1
	return true


func blaster_stage() -> Node3D:
	return stage


func blaster_floor_y() -> float:
	return 0.0


func blaster_eye() -> Vector3:
	return cam.global_position


func blaster_hand(_hand: String) -> Vector3:
	return muzzle.global_position


func blaster_credit(_kind: String, _n: int) -> void:
	pass


## Slows a target: its speed times `factor` for `seconds`.
func blaster_slow(t: Variant, factor := 0.4, seconds := 2.0) -> void:
	var r := _rec(t)
	if r.is_empty():
		return
	r.slow_k = clampf(float(factor), 0.0, 1.0)
	r.slow_t = maxf(float(r.slow_t), float(seconds))


## Pulls a target toward `to` by `strength` (game units this call, never past `to`).
func blaster_pull(t: Variant, to: Vector3, strength := 0.1) -> void:
	# The magnet also drags hostile balls: they lose their speed and drift to it.
	if t is Dictionary and threats_list.has(t):
		var off_t: Vector3 = to - t.p
		t.p += off_t.normalized() * minf(off_t.length(), absf(float(strength)))
		t.vel = (t.vel as Vector3) * 0.9
		return
	var r := _rec(t)
	if r.is_empty() or not r.alive:
		return
	var off: Vector3 = to - r.p
	var step := minf(off.length(), absf(float(strength)))
	if off.length() > 1e-5:
		r.p += off.normalized() * step
		r.home = r.p
	_place(r)


## Freezes a target: it stops and turns icy for `seconds`.
func blaster_freeze(t: Variant, seconds := 3.0) -> void:
	var r := _rec(t)
	if r.is_empty():
		return
	r.freeze_t = maxf(float(r.freeze_t), float(seconds))


## Pushes a target: adds `v` (units/s) to its drift.
func blaster_push(t: Variant, v: Vector3, _strength := 1.0) -> void:
	var r := _rec(t)
	if r.is_empty():
		return
	r.vel += v


## Our own record for whatever the blaster hands back (the Dictionary we gave, its ref, or its id).
func _rec(t: Variant) -> Dictionary:
	if t is Dictionary:
		for r: Dictionary in targets_list:
			if is_same(r, t):
				return r
		t = (t as Dictionary).get("ref", (t as Dictionary).get("id", null))
	for r: Dictionary in targets_list:
		if is_same(r.ref, t) or (t is int and r.get("id", -1) == t):
			return r
	return {}


# --- motion ------------------------------------------------------------------------

func _process(delta: float) -> void:
	if held:
		_fire()
	if hand:
		_pose_hand()
	for t: Dictionary in targets_list:
		_move(t, delta)
	_threats(delta)


func _threats(dt: float) -> void:
	if DEFENDERS.has(blaster.style):
		_lob_t -= dt
		if _lob_t <= 0.0:
			_lob_t = LOB_EVERY
			_lob()
	for th: Dictionary in threats_list.duplicate():
		th.vel = (th.vel as Vector3) + Vector3(0, -4.0, 0) * dt
		th.p = (th.p as Vector3) + (th.vel as Vector3) * dt
		(th.node as Node3D).position = th.p
		if float((th.p as Vector3).y) < 0.0 or float((th.p as Vector3).z) > cam.global_position.z + 0.5:
			(th.node as Node3D).queue_free()
			threats_list.erase(th)


## A red ball from the far wall towards the player's hand, on a gentle arc.
func _lob() -> void:
	var from := Vector3(_rng.randf_range(-2.4, 2.4), 1.6, BOX.position.z + 0.3)
	var to := muzzle.global_position + Vector3(_rng.randf_range(-0.25, 0.25), _rng.randf_range(0.0, 0.3), 0)
	var tt := 1.6
	var vel := (to - from) / tt + Vector3(0, 0.5 * 4.0 * tt, 0)
	var m := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.11
	sm.height = 0.22
	m.mesh = sm
	m.material_override = _mat(Color("e8483b"), 0.35)
	m.position = from
	add_child(m)
	threats_list.append({"ref": m, "p": from, "r": 0.11, "metal": true, "node": m, "vel": vel})


func _clear_threats() -> void:
	for th: Dictionary in threats_list:
		(th.node as Node3D).queue_free()
	threats_list.clear()


func _move(t: Dictionary, dt: float) -> void:
	if not t.alive:
		t.back_t = float(t.back_t) - dt
		if float(t.back_t) <= 0.0:
			_respawn(t)
		return
	t.slow_t = maxf(0.0, float(t.slow_t) - dt)
	t.freeze_t = maxf(0.0, float(t.freeze_t) - dt)
	var k := 0.0 if float(t.freeze_t) > 0.0 else (float(t.slow_k) if float(t.slow_t) > 0.0 else 1.0)
	t.phase = float(t.phase) + dt * k
	var ph: float = t.phase
	if t.kind == "balloon":
		# drift round a wandering home, bobbing
		t.home += (t.vel as Vector3) * dt * k
		var h: Vector3 = t.home
		if h.x < BOX.position.x or h.x > BOX.end.x:
			t.vel.x = -t.vel.x
		if h.z < BOX.position.z or h.z > BOX.end.z:
			t.vel.z = -t.vel.z
		h.x = clampf(h.x, BOX.position.x, BOX.end.x)
		h.z = clampf(h.z, BOX.position.z, BOX.end.z)
		h.y = clampf(h.y, 0.8, 2.9)
		t.home = h
		t.p = h + Vector3(sin(ph * 0.9) * 0.25, sin(ph * 1.7) * 0.18, 0.0)
	else:
		# a jelly blob hopping along the floor
		t.home += (t.vel as Vector3) * dt * k
		var h: Vector3 = t.home
		if h.x < BOX.position.x or h.x > BOX.end.x:
			t.vel.x = -t.vel.x
		if h.z < BOX.position.z or h.z > BOX.end.z:
			t.vel.z = -t.vel.z
		h.x = clampf(h.x, BOX.position.x, BOX.end.x)
		h.z = clampf(h.z, BOX.position.z, BOX.end.z)
		t.home = h
		var hop := absf(sin(ph * 2.6))
		t.p = Vector3(h.x, float(t.r) * 0.8 + hop * 0.45, h.z)
		var sq := 1.0 + (1.0 - hop) * 0.25
		(t.node as Node3D).scale = Vector3(sq, 1.0 / sq, sq) * 1.0
	# drag the push away
	var v: Vector3 = t.vel
	var base_speed: float = t.speed
	var flat := Vector2(v.x, v.z)
	if flat.length() > base_speed:
		flat = flat.normalized() * maxf(base_speed, flat.length() - dt * 2.0)
		t.vel = Vector3(flat.x, 0.0, flat.y)
	_place(t)
	var m: StandardMaterial3D = t.mat
	var icy := float(t.freeze_t) > 0.0
	m.albedo_color = ICY if icy else (t.base as Color).lerp(Color("8fa3b8"), 0.35 if float(t.slow_t) > 0.0 else 0.0)
	m.emission = ICY if icy else (t.base as Color)
	m.emission_energy_multiplier = 0.6 if icy else 0.12


func _place(t: Dictionary) -> void:
	(t.node as Node3D).position = t.p


func _respawn(t: Dictionary) -> void:
	t.alive = true
	t.slow_t = 0.0
	t.freeze_t = 0.0
	var h := Vector3(_rng.randf_range(BOX.position.x + 0.3, BOX.end.x - 0.3), _rng.randf_range(1.0, 2.6), _rng.randf_range(BOX.position.z + 0.4, BOX.end.z - 0.6))
	t.home = h
	var a := _rng.randf() * TAU
	t.vel = Vector3(cos(a), 0.0, sin(a)) * float(t.speed)
	t.phase = _rng.randf() * 10.0
	t.p = h
	var nd: Node3D = t.node
	nd.visible = true
	nd.scale = Vector3.ONE * 0.2
	_place(t)
	if is_inside_tree():
		create_tween().tween_property(nd, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## The toy blaster sits low in the view and turns to the aim.
func _pose_hand() -> void:
	var vp := get_viewport().get_visible_rect().size
	var at := cam.project_position(Vector2(vp.x * 0.64, vp.y * 0.8), 0.6)
	hand.global_position = at
	var to := aim_point
	if to.distance_to(at) > 0.05:
		hand.look_at(to, Vector3.UP)
	hand.scale = Vector3.ONE * 0.5


# --- the world ---------------------------------------------------------------------

func _mat(c: Color, rough := 0.6) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m


func _build() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color("6fb6ff")
	sm.sky_horizon_color = Color("d8f0ff")
	sm.ground_bottom_color = Color("f3e6d0")
	sm.ground_horizon_color = Color("e8f4ff")
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 30, 0)
	sun.light_energy = 1.0
	add_child(sun)
	# the floor: a soft pastel checker
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(16, 16)
	floor_mi.mesh = pm
	floor_mi.position = Vector3(0, 0, -4)
	var fm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
varying vec3 wp;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 c = floor(wp.xz);
	float k = mod(c.x + c.y, 2.0);
	ALBEDO = mix(vec3(0.80, 0.70, 0.58), vec3(0.70, 0.62, 0.84), k);
	ROUGHNESS = 0.9;
}
"""
	fm.shader = sh
	floor_mi.material_override = fm
	add_child(floor_mi)
	# the walls (a stage: the shots hit and bounce off them)
	stage = LabStage.new()
	stage.name = "Stage"
	add_child(stage)
	_wall(Vector3(0, 1.6, -9.0), Vector3(9.0, 3.2, 0.3), Color("ffb3c7"))
	_wall(Vector3(-4.5, 0.6, -5.0), Vector3(0.3, 1.2, 8.0), Color("9fe0ff"))
	_wall(Vector3(4.5, 0.6, -5.0), Vector3(0.3, 1.2, 8.0), Color("b9f5a0"))
	_wall(Vector3(-2.0, 0.9, -6.6), Vector3(0.5, 1.8, 0.5), Color("ffe07a"))
	_wall(Vector3(2.2, 0.9, -5.4), Vector3(0.5, 1.8, 0.5), Color("d0b8ff"))
	_wall(Vector3(0.2, 0.25, -4.2), Vector3(1.6, 0.5, 0.4), Color("ffc58a"))
	# the soft targets
	for i in BALLOONS + BLOBS:
		var kind := "balloon" if i < BALLOONS else "blob"
		var col := Color(COLS[i % COLS.size()])
		var r := 0.34 if kind == "balloon" else 0.3
		var nd := Node3D.new()
		add_child(nd)
		var body := MeshInstance3D.new()
		var sp := SphereMesh.new()
		sp.radius = r
		sp.height = r * (2.3 if kind == "balloon" else 1.7)
		body.mesh = sp
		var m := _mat(col, 0.25)
		m.rim_enabled = true
		m.rim = 0.6
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = 0.12
		body.material_override = m
		nd.add_child(body)
		if kind == "balloon":
			var knot := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.004
			cm.bottom_radius = 0.004
			cm.height = 0.55
			knot.mesh = cm
			knot.position = Vector3(0, -r * 1.15 - 0.27, 0)
			knot.material_override = _mat(Color("f4f4f4"))
			nd.add_child(knot)
		else:
			for s in [-1, 1]:
				var eye := MeshInstance3D.new()
				var em := SphereMesh.new()
				em.radius = 0.04
				em.height = 0.08
				eye.mesh = em
				eye.material_override = _mat(Color("1d1d2a"), 0.2)
				eye.position = Vector3(0.09 * s, 0.07, r * 0.78)
				nd.add_child(eye)
		var t := {"ref": nd, "id": i, "p": Vector3.ZERO, "r": r, "color": COLS[i % COLS.size()], "node": nd, "mat": m, "base": col,
			"kind": kind, "home": Vector3.ZERO, "vel": Vector3.ZERO, "phase": 0.0, "speed": 0.35 if kind == "balloon" else 0.6,
			"slow_k": 1.0, "slow_t": 0.0, "freeze_t": 0.0, "alive": true, "back_t": 0.0}
		targets_list.append(t)
		_respawn(t)
		nd.scale = Vector3.ONE
	# the camera and the toy blaster in hand
	cam = Camera3D.new()
	cam.fov = 62.0
	add_child(cam)
	cam.look_at_from_position(Vector3(0, 1.6, 0.4), Vector3(0, 1.15, -5.0))
	hand = Node3D.new()
	hand.name = "Hand"
	add_child(hand)
	var body2 := MeshInstance3D.new()
	var bx := BoxMesh.new()
	bx.size = Vector3(0.07, 0.08, 0.2)
	body2.mesh = bx
	body2.material_override = _mat(Color("ff7a45"), 0.35)
	hand.add_child(body2)
	var barrel := MeshInstance3D.new()
	var bc := CylinderMesh.new()
	bc.top_radius = 0.022
	bc.bottom_radius = 0.026
	bc.height = 0.16
	barrel.mesh = bc
	barrel.rotation_degrees = Vector3(90, 0, 0)
	barrel.position = Vector3(0, 0.015, -0.16)
	barrel.material_override = _mat(Color("3ec7c0"), 0.3)
	hand.add_child(barrel)
	var grip := MeshInstance3D.new()
	var gb := BoxMesh.new()
	gb.size = Vector3(0.05, 0.11, 0.06)
	grip.mesh = gb
	grip.position = Vector3(0, -0.08, 0.05)
	grip.rotation_degrees = Vector3(-15, 0, 0)
	grip.material_override = _mat(Color("6b4cff"), 0.4)
	hand.add_child(grip)
	for c in hand.get_children():
		(c as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	muzzle = Node3D.new()
	muzzle.position = Vector3(0, 0.015, -0.25)
	hand.add_child(muzzle)


func _wall(p: Vector3, size: Vector3, c: Color) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.position = p
	mi.material_override = _mat(c, 0.8)
	stage.add_child(mi)
