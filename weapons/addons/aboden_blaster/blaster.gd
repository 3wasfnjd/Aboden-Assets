class_name AbodenBlaster
extends Node3D
## حزمة أسلحة عبودين — the blaster, as a standalone node: the twelve shot styles (AbodenShotCatalog), their flight, meshes,
## materials, trails, sparks, arcs, impacts, blooms, explosions and splashes, homing and
## chaining, the laser and the lightning, and the ray test against a stage's hidden targets.
##
## Every position, direction and radius is in this node's local space ("game units");
## blaster_scale() says how many of them make a metre. Put the blaster where your game's
## world is (a child of the world root, identity transform, is the simplest).
##
## Fire with fire(hand, origin, dir) or fire_at(origin, target_point, hand); call step(dt)
## each frame (or set auto_step).
##
## The host is any Node passed to setup(host). Every call on it is optional (README.md has
## the table); with no host at all the blaster still flies, draws and sounds its shots:
##   blaster_scale() -> float                game units per metre (1.0)
##   blaster_look_scale() -> float           visual size of shots and sparks (blaster_scale())
##   blaster_targets() -> Array              soft targets [{ref | id, p: Vector3, r: float, color?, burst?}] ([])
##   blaster_hit(target, dir) -> bool        a soft target was reached: did it count? (true)
##   blaster_stage() -> Node3D               a stage: hidden layers = 0 meshes are its targets,
##                                           its shoot(obj, point, dir) -> bool decides a hit (`stage`)
##   shot_fan() -> int                       shots per trigger, 1..5 (the stage's, else 1)
##   blaster_floor_y() -> float              the floor's height; -INF for none (`floor_y`)
##   blaster_collide(p, v, r[, prev]) -> {hit, p, v, n?}   the world's walls (none)
##   blaster_eye() -> Vector3                the player's eye (the camera)
##   blaster_roam() -> bool                  bouncy balls turn back past BOUNCY_ROAM from the eye (false)
##   blaster_hand(hand) -> Variant           where a boomerang comes back to (where it left)
##   blaster_sfx(name, k, pos)               a sound (the built-in AbodenBlasterAudio)
##   blaster_buzz(hand, amp, ms)             haptics (nothing)
##   blaster_credit(kind, n)                 n targets hit by a `kind` shot (nothing)
##   blaster_challenge(id, value)            challenge progress (AbodenShotCatalog.CHALLENGES) (nothing)
## v1.2 (the falcon ... shield). Each target they get is the host's own soft target Dictionary
## (as in blaster_hit; the stage's targets keep going through its shoot()):
##   blaster_freeze(target, seconds)         the freeze ray froze it, instead of a hit (none: it is hit)
##   blaster_slow(target, factor, seconds)   it is in the bakhoor's smoke: factor x its speed (none: only smoke)
##   blaster_pull(target, to, strength)      move it toward `to` (local) by `strength` game units this
##                                           step (speed x dt): the black hole and the magnet pull (none:
##                                           only the look); the lasso pulls instead of a hit (none: a hit)
##   blaster_push(target, velocity)          a hose drop shoves it: give it this velocity (game units/s);
##                                           instead of a hit (none: blaster_pull to behind it, else a hit)
##   blaster_threats() -> Array              hostile projectiles [{ref | id, p: Vector3, r?, metal?}] (none)
##   blaster_block(threat, at) -> bool       the shield or the magnet stopped one at `at`: destroy it (nothing)

## A shot fired (once per trigger pull that fired, whatever the fan).
signal shot_fired(kind: String, hand: String)
## A shot hit something that counted: target is the soft target's Dictionary (as the host
## gave it) or the stage's MeshInstance3D.
signal shot_hit(kind: String, target: Variant)

const Catalog := preload("shot_catalog.gd")
const Looks := preload("shot_looks.gd")
const ShotCrowd := preload("shot_crowd.gd")
const BlasterAudio := preload("blaster_audio.gd")

const SHOT_STYLE := Catalog.SHOT_STYLE
const DALLAH_FIRE_K := Catalog.DALLAH_FIRE_K
const DALLAH_SPILL_K := Catalog.DALLAH_SPILL_K
const DALLAH_DING_GAP := Catalog.DALLAH_DING_GAP
const BEAN_THUMP_GAP := Catalog.BEAN_THUMP_GAP
const BOUNCY_MAX := Catalog.BOUNCY_MAX
const BOUNCY_HOP := Catalog.BOUNCY_HOP
const BOUNCY_ROLL := Catalog.BOUNCY_ROLL
const BOUNCY_ROAM := Catalog.BOUNCY_ROAM
const FAN_STEP := Catalog.FAN_STEP
const BOOMERANG_SPIN := Catalog.BOOMERANG_SPIN
const FIRE_COLS := Catalog.FIRE_COLS
const CONFETTI_COLS := Catalog.CONFETTI_COLS
const BOUNCY_COLS := Catalog.BOUNCY_COLS
const BEAN_COLS := Catalog.BEAN_COLS
const MUZZLE := Catalog.MUZZLE
const MINI_STYLES := Catalog.MINI_STYLES
const MINI_COLORS := Catalog.MINI_COLORS
const BUBBLE_TINTS := Catalog.BUBBLE_TINTS
const STYLE_COLORS := Catalog.STYLE_COLORS
const PARKS := Catalog.PARKS
const NO_MUZZLE := Catalog.NO_MUZZLE
const DATE_COLS := Catalog.DATE_COLS
const CRUMB_COLS := Catalog.CRUMB_COLS
const SHEMAGH_COLS := Catalog.SHEMAGH_COLS
const HOSE_COLS := Catalog.HOSE_COLS
const VOID_COLS := Catalog.VOID_COLS

const REAL_G := 9.8
const SPARKS_MAX := 320
const SHOTS_MAX := 48
const ARCS_MAX := 24
const BEAM_SEGS_MAX := 512
## Frost shells drawn over frozen targets, and bits that fall off shots (the falcon's hood).
const AURAS_MAX := 16
const PROPS_MAX := 8
## Segments of a lasso's rope (drawn with the beams, red and white in turn).
const ROPE_SEGS := 40
## How big a target is when nobody says (game units): a soft target
## without "r", and the stage's hidden targets for a rocket going off beside them.
const TARGET_R := 0.24

## The current shot style (an AbodenShotCatalog id; anything else fires the bolt).
@export var style := "bolt"
## Run step(delta) from _process. Leave it off when you call step() yourself.
@export var auto_step := false
## The built-in player's switch (when the host has no blaster_sfx).
@export var sound_on := true
## Used when the host has no blaster_stage() / blaster_floor_y().
@export var stage: Node3D = null
@export var floor_y := 0.0

var host: Node = null
var audio: BlasterAudio = null
var shots: Array = []  # {kind, node, p, v, dir, t, r, k, style, color, spin, wob, ...}
var sparks: Array = []  # {p, v, t, max, flash, color, size, k, flake}
var arcs: Array = []  # laser beams and lightning arcs: {a, b, n, jit, w, color, t, max, k, pts, tick}
var auras: Array = []  # frozen targets' frost: {target (a targets() entry), r, t, max}
var props: Array = []  # bits falling off shots: {node, p, v, t, max, axis}
var popped := 0
var fired := 0
var last_shot := {"left": -10.0, "right": -10.0}
var clock := 0.0
var _next_ambient_pop := 0.0
var _rng := RandomNumberGenerator.new()
var _spark_mm: MultiMesh
var _beam_mm: MultiMesh
var _hand_sign := 1.0
var _tri_cache := {}  # Mesh -> TriangleMesh
var _shot_mats := {}
var _sound_at := {}  # sound -> clock when the dallah last played it (_dallah_sfx)
## Mini and bubble shots: one crowd (a few MultiMesh draws for every shot in flight).
var shot_crowd: ShotCrowd
var _crowd_drawn := 0
## fire_at()'s point while it fires (kept on each shot as "aim"); null otherwise.
var _aim: Variant = null


func _init() -> void:
	Looks.base_dir = (get_script() as Script).resource_path.get_base_dir()
	_rng.randomize()
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Sparks"
	_spark_mm = MultiMesh.new()
	_spark_mm.transform_format = MultiMesh.TRANSFORM_3D
	_spark_mm.use_colors = true
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 8
	sm.rings = 6
	_spark_mm.mesh = sm
	# The sparks, then the round shots (confetti pellets, bouncy balls, coffee beans, hose
	# drops, bomblets), then the frost shells.
	_spark_mm.instance_count = SPARKS_MAX + SHOTS_MAX + AURAS_MAX
	_spark_mm.visible_instance_count = 0
	mmi.multimesh = _spark_mm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_BACK
	mmi.material_override = m
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.custom_aabb = AABB(Vector3(-500, -500, -500), Vector3(1000, 1000, 1000))
	add_child(mmi)
	# Laser beams and lightning arcs: glowing stretched boxes.
	var bmi := MultiMeshInstance3D.new()
	bmi.name = "Beams"
	_beam_mm = MultiMesh.new()
	_beam_mm.transform_format = MultiMesh.TRANSFORM_3D
	_beam_mm.use_colors = true
	var bx := BoxMesh.new()
	bx.size = Vector3.ONE
	_beam_mm.mesh = bx
	_beam_mm.instance_count = BEAM_SEGS_MAX
	_beam_mm.visible_instance_count = 0
	bmi.multimesh = _beam_mm
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.vertex_color_use_as_albedo = true
	# Plain alpha, not added light: the colours must read on a bright day and in passthrough.
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.cull_mode = BaseMaterial3D.CULL_DISABLED
	bmi.material_override = bm
	bmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bmi.custom_aabb = AABB(Vector3(-500, -500, -500), Vector3(1000, 1000, 1000))
	add_child(bmi)
	shot_crowd = ShotCrowd.new(SHOTS_MAX)
	shot_crowd.name = "ShotCrowd"
	add_child(shot_crowd)
	audio = BlasterAudio.new()
	audio.name = "BlasterAudio"
	audio.dir = Looks.base_dir.path_join("sounds") + "/"
	add_child(audio)


## The host (any Node; every call on it optional). null: no host.
func setup(h: Node) -> void:
	host = h


func _process(delta: float) -> void:
	if auto_step:
		step(delta)


func rnd() -> float:
	return _rng.randf()


## Seeds the blaster's randomness (tests, repeatable screenshots).
func set_seed(s: int) -> void:
	_rng.seed = s


# --- the host (every call optional) ---------------------------------------------------

func _has(m: String) -> bool:
	return host != null and is_instance_valid(host) and host.has_method(m)


## Game units per metre: how far and fast the shots go.
func reach_k() -> float:
	return float(host.blaster_scale()) if _has("blaster_scale") else 1.0


## The size of the shots, their sparks and bursts: blaster_look_scale(),
## else blaster_scale().
func blast_k() -> float:
	return float(host.blaster_look_scale()) if _has("blaster_look_scale") else reach_k()


## The stage whose hidden meshes are targets (host.blaster_stage(), else `stage`), or null.
func current_stage() -> Node3D:
	var st: Node3D = host.blaster_stage() if _has("blaster_stage") else stage
	return st if st != null and is_instance_valid(st) else null


func _floor_y() -> float:
	return float(host.blaster_floor_y()) if _has("blaster_floor_y") else floor_y


## The player's eye (local): host.blaster_eye(), else the viewport's camera, else 1.6 m up.
func _eye() -> Vector3:
	if _has("blaster_eye"):
		return host.blaster_eye()
	var vp := get_viewport() if is_inside_tree() else null
	var cam: Camera3D = vp.get_camera_3d() if vp != null else null
	if cam != null:
		return to_local(cam.global_position)
	return Vector3(0, 1.6 * reach_k(), 0)


## The world's walls (host.blaster_collide): {} when none.
func _collide(p: Vector3, v: Vector3, r: float, prev: Vector3) -> Dictionary:
	if not _has("blaster_collide"):
		return {}
	var res: Variant
	if host.get_method_argument_count("blaster_collide") >= 4:
		res = host.blaster_collide(p, v, r, prev)
	else:
		res = host.blaster_collide(p, v, r)
	return res if res is Dictionary else {}


## How hard a collide result hit (its "hit": a speed, or true / false).
static func _hit_speed(res: Dictionary, v: Vector3) -> float:
	if res.is_empty():
		return 0.0
	var h: Variant = res.get("hit", false)
	if h is bool:
		return maxf(v.length(), 1e-3) if h else 0.0
	return float(h)


func _sfx(snd: String, k: float, p: Vector3) -> void:
	if _has("blaster_sfx"):
		host.blaster_sfx(snd, k, p)
	elif sound_on and audio != null and is_inside_tree():
		audio.ref_distance = reach_k()
		audio.sfx(snd, k, to_global(p))


func _buzz(hand: String, amp: float, ms: float) -> void:
	if _has("blaster_buzz"):
		host.blaster_buzz(hand, amp, ms)


## Challenge credit for the blaster: n targets hit by a `kind` shot.
func _credit(kind: String, n: int) -> void:
	if n > 0 and _has("blaster_credit"):
		host.blaster_credit(kind, n)


## A challenge's progress (AbodenShotCatalog.CHALLENGES says "add" or "best").
func _ch(id: String, value: int) -> void:
	if _has("blaster_challenge"):
		host.blaster_challenge(id, value)


## Moves a soft target toward `to` by `dist` game units (host.blaster_pull). False: no such call.
func _pull(t: Dictionary, to: Vector3, dist: float) -> bool:
	if not _has("blaster_pull") or t.get("kind", "") != "t":
		return false
	host.blaster_pull(t.get("src", {}), to, dist)
	return true


## The host's hostile projectiles (blaster_threats): [{ref | id, p, r?, metal?}], or [].
func threats() -> Array:
	if not _has("blaster_threats"):
		return []
	var out: Array = []
	for th: Variant in host.blaster_threats():
		if th is Dictionary and (th as Dictionary).has("p"):
			out.append(th)
	return out


## A hostile projectile stopped at `at` (the shield, the magnet): the host destroys it.
func _block(th: Dictionary, at: Vector3, kind: String) -> void:
	if _has("blaster_block"):
		host.blaster_block(th, at)
	_credit(kind, 1)
	shot_hit.emit(kind, th)


# --- the public API -------------------------------------------------------------------

## The style fire() uses: `style` if it is a catalog style, else the bolt.
func style_for() -> String:
	return style if SHOT_STYLE.has(style) and Catalog.has(style) else "bolt"


## Shots in flight (pellets, beans and bouncy balls included; beams are in `arcs`).
func shot_count() -> int:
	return shots.size()


func clear() -> void:
	clear_blast()


## Advances every shot, spark and arc by dt seconds (call it each frame, or auto_step).
func step(dt: float) -> void:
	step_blast(dt)


## Fires the current style from `origin` along `dir` (local, dir normalised) for `hand`
## ("left" / "right" / any id: each hand keeps its own cooldown). False while cooling down.
func fire(hand: String, origin: Vector3, dir: Vector3) -> bool:
	var kind := style_for()
	var P: Dictionary = SHOT_STYLE[kind]
	if clock - float(last_shot.get(hand, -10.0)) < P.cool:
		return false
	last_shot[hand] = clock
	fired += 1
	var hk := reach_k()
	var k := blast_k()
	var p := origin + dir * 0.08 * hk
	_hand_sign = -1.0 if hand == "left" else 1.0
	# A power-up (a triple shot) fans the shot out.
	var fan := 1
	var st := current_stage()
	if st and st.is_visible_in_tree() and st.has_method("shot_fan"):
		fan = clampi(int(st.shot_fan()), 1, 5)
	elif _has("shot_fan"):
		fan = clampi(int(host.shot_fan()), 1, 5)
	for j in fan:
		var d := dir.rotated(Vector3.UP, (j - (fan - 1) / 2.0) * FAN_STEP) if fan > 1 else dir
		match kind:
			"laser", "freeze":
				_laser(p, d, k, P, kind)
			"lightning":
				_lightning(p, d, k, P)
			"dates", "hose":
				# A little random spread on every date and every drop of the stream. The hose's
				# drops are set out along the stream as if let go one after another over its
				# `cool`, so a held trigger makes one steady stream.
				var n := int(P.get("pellets", 1))
				for c in n:
					var dd := cone_dir(d, float(P.cone) * sqrt(rnd()), rnd() * TAU)
					var o := _add_shot(kind, P, p, dd, k, j * 8 + c, hand)
					var ahead: float = float(P.cool) * c / n
					if not o.is_empty() and ahead > 0.0:
						o.v.y -= REAL_G * hk * float(P.grav) * ahead
						o.p += (dd * float(P.speed) * hk + Vector3.DOWN * REAL_G * hk * float(P.grav) * ahead * 0.5) * ahead
						o.t = ahead
			"shield":
				# One bubble a hand (a triple shot too): a new one takes the place of the last.
				if j == 0:
					for o: Dictionary in shots.filter(func(o: Dictionary) -> bool: return o.kind == "shield" and o.hand == hand):
						_drop_shot(o)
					_add_shot(kind, P, origin, dir, k, j, hand)
			"confetti":
				# The cannon: one pellet down the middle, the others in a ring around it.
				var phase := rnd() * TAU
				for c in int(P.pellets):
					var cd := d if c == 0 else cone_dir(d, float(P.cone) * (0.65 + 0.35 * rnd()), phase + (c - 1) * TAU / (int(P.pellets) - 1))
					_add_shot(kind, P, p, cd, k, j * 8 + c, hand)
			_:
				_add_shot(kind, P, p, d, k, j, hand)
	# Muzzle flash (not for a bubble or a shield), at the hand.
	if not kind in NO_MUZZLE:
		_spark(p, Vector3.ZERO, 0.07, Color(String(MUZZLE.get(kind, "ffe9b0"))), (0.07 if kind == "bolt" else (0.03 if kind in ["dates", "hose"] else 0.05)) * hk, true)
	var info := Catalog.info(kind)
	if kind == "dallah":
		_dallah_sfx("fair_ding", float(P.sk), p)
	elif kind == "hose":
		_dallah_sfx("hose_hiss", float(P.sk), p, Catalog.HOSE_HISS_GAP)
	else:
		_sfx(String(info.get("sound", "pew")), float(P.sk), p)
	if kind == "confetti":
		_sfx("start_pop", 0.5, p)
	var amp := 0.3
	if kind in ["bubble", "dates", "hose"]:
		amp = 0.12
	elif kind in ["rocket", "lightning", "laser", "blackhole", "freeze"]:
		amp = 0.45
	_buzz(hand, amp, 22)
	shot_fired.emit(kind, hand)
	return true


## Fires the current style from `origin` at a point (local), for `hand`. The twelve styles of
## the playful pack just aim their direction at it (no lead, no arc correction); the point is
## kept on every shot it makes as s["aim"], for weapons that fly to a point (a lofted missile,
## a cruise missile's last waypoint, artillery, a called strike). False while cooling down.
func fire_at(origin: Vector3, target_point: Vector3, hand := "right") -> bool:
	var d := target_point - origin
	if d.length_squared() < 1e-10:
		d = Vector3.FORWARD
	_aim = target_point
	var ok := fire(hand, origin, d.normalized())
	_aim = null
	return ok


## The dallah's sounds, kept soft and spaced: one `snd` at most every `gap` seconds (also the
## hose's hiss and the bomblets' pops).
func _dallah_sfx(snd: String, k: float, p: Vector3, gap := DALLAH_DING_GAP) -> void:
	var last := float(_sound_at.get(snd, -10.0))
	if clock - last < gap and clock >= last:
		return
	_sound_at[snd] = clock
	_sfx(snd, k, p)


## A direction `ang` radians off `d`, turned `az` around it.
static func cone_dir(d: Vector3, ang: float, az: float) -> Vector3:
	var u := d.cross(Vector3.UP) if absf(d.y) < 0.99 else d.cross(Vector3.RIGHT)
	u = u.normalized()
	var w := d.cross(u).normalized()
	return (d * cos(ang) + (u * cos(az) + w * sin(az)) * sin(ang)).normalized()


## A shot taken out of the air (the oldest bouncy ball when a new one comes): a little pop.
func _drop_shot(o: Dictionary) -> void:
	var at := _index_of(shots, o)
	if at < 0:
		return
	impact(o.p, Vector3.UP, o.color)
	if o.node:
		o.node.queue_free()
	shots.remove_at(at)


## One shot in flight (j: its place in a fan or a cannon's spray).
func _add_shot(kind: String, P: Dictionary, p: Vector3, dir: Vector3, k: float, j: int, hand := "") -> Dictionary:
	# Reuse the bounded flight budget instead of stalling a held trigger (a dallah's
	# beans only take free places).
	if kind == "bouncy":
		var mine := shots.filter(func(o: Dictionary) -> bool: return o.kind == "bouncy")
		if mine.size() >= BOUNCY_MAX:
			_drop_shot(mine[0])
	if shots.size() >= SHOTS_MAX:
		if kind == "bean" or kind == "hose":
			return {}
		var oldest: Dictionary = shots.pop_front()
		if oldest.node:
			oldest.node.queue_free()
	var node: Node3D = null
	var look := ""
	var color := Color.WHITE
	match kind:
		"mini":
			look = MINI_STYLES[(fired + j) % MINI_STYLES.size()]
			var hex: String = MINI_COLORS[_rng.randi() % MINI_COLORS.size()]
			color = Color(hex if hex != "" else String(STYLE_COLORS[look]))
		"bubble":
			look = "bubble"
			color = Color(BUBBLE_TINTS[_rng.randi() % BUBBLE_TINTS.size()])
		"confetti":
			color = Color(CONFETTI_COLS[(fired + j) % CONFETTI_COLS.size()])
		"bouncy":
			color = Color(BOUNCY_COLS[_rng.randi() % BOUNCY_COLS.size()])
		"bean":
			color = Color(BEAN_COLS[_rng.randi() % BEAN_COLS.size()])
		"hose":
			color = Color(HOSE_COLS[_rng.randi() % HOSE_COLS.size()])
		"bomblet":
			color = Color(CONFETTI_COLS[(fired + j) % CONFETTI_COLS.size()])
		_:
			node = _shot_node(kind, k)
			node.position = p
			if dir.length_squared() > 0.0 and kind in ["bolt", "rocket", "falcon", "dates"]:
				node.basis = Basis.looking_at(dir, Vector3.UP if absf(dir.y) < 0.999 else Vector3.RIGHT)
			add_child(node)
	var side := dir.cross(Vector3.UP)
	side = side.normalized() if side.length_squared() > 1e-6 else Vector3.RIGHT
	var speed: float = P.speed * reach_k()
	if kind == "rocket":
		speed *= 0.15  # it starts slow and speeds up
	elif kind == "falcon":
		speed *= 0.6  # it leaves the glove and beats up to speed
	var s := {"kind": kind, "node": node, "p": p, "v": dir * speed, "dir": dir, "t": 0.0, "r": P.r * k,
		"k": k, "style": look, "color": color, "spin": rnd() * TAU,
		"wob": rnd() * 6.0, "tap": 0.0,
		"o": p, "side": side * _hand_sign, "hand": hand, "ret": false, "caught": false, "hits": {}, "soft": {}, "pops": 0, "bounces": 0,
		"target": {}, "seek_t": 0.0, "size": 1.0, "axis": Vector3(rnd() - 0.5, rnd() - 0.5, rnd() - 0.5).normalized(),
		"hue": rnd(), "spray_t": 0.0, "n": Vector3.UP, "bank": 0.0, "pv": dir * speed, "aim": _aim,
		"parked": false, "life_end": -1.0, "hold": {}, "hold_t": 0.0, "dove": false, "tick": 0.0, "flash": 0.0}
	if kind == "mini":
		# Every little ball its own size and tumble.
		s.size = 0.8 + rnd() * 0.5
		s.wob = 6.0 + rnd() * 8.0
	elif kind == "hose":
		s.size = 0.7 + rnd() * 0.6
	elif kind == "shield" and node:
		# The bubble sits in front of the hand from the start.
		s.p = _shield_at(s, P)
		node.position = s.p
	shots.append(s)
	return s


## Material specs: [colour, alpha, kind] (flat, add, alpha, metal or lit).
const MATS := {
	"trail": ["ffe9a8", 0.95, "add"], "head": ["ffffff", 1.0, "flat"], "bolt_glow": ["ffb547", 0.55, "add"],
	"rocket": ["ffb347", 1.0, "flat"], "fw_glow": ["ff9a3c", 0.5, "add"], "flame": ["ffcf6a", 0.85, "add"],
	"rk_body": ["e8473c", 1.0, "lit"], "rk_nose": ["f4efe6", 1.0, "lit"], "rk_fin": ["3a6fd8", 1.0, "lit"],
	"glob": ["3fb4ff", 0.75, "alpha"], "glob_core": ["c9f1ff", 0.55, "add"],
	"brass": ["dcaa48", 1.0, "metal"], "brass_dark": ["9c6b22", 1.0, "metal"], "dallah_glow": ["ffd98a", 0.3, "add"],
	# v1.2: the falcon (brown back, cream breast, yellow beak, the leather hood and its plume) ...
	"fa_brown": ["7a4a2a", 1.0, "lit"], "fa_dark": ["4a2e1a", 1.0, "lit"], "fa_cream": ["efe6d2", 1.0, "lit"],
	"fa_beak": ["e0b84a", 1.0, "lit"], "fa_eye": ["111111", 1.0, "flat"], "fa_hood": ["8b5a2b", 1.0, "lit"], "fa_plume": ["c9302c", 1.0, "lit"],
	# ... the black hole, glossy dates, the bakhoor's coals, the cluster bomb, the magnet.
	"void": ["050208", 1.0, "flat"], "void_rim": ["8b5cf6", 0.9, "add"], "void_disk": ["c084fc", 0.45, "add"], "void_halo": ["6d28d9", 0.22, "add"],
	"date": ["5a2a12", 1.0, "gloss"], "date_amber": ["7b3d1a", 1.0, "gloss"], "date_cap": ["c9a36a", 1.0, "lit"],
	"gold": ["d4a640", 1.0, "metal"], "coal": ["2a1a12", 1.0, "lit"], "ember_glow": ["ff7a2e", 0.9, "add"],
	"bomb": ["6c3cff", 1.0, "gloss"], "bomb_dot": ["ffd23f", 1.0, "lit"], "fuse": ["c9b38a", 1.0, "lit"], "fuse_fire": ["ffd34d", 0.9, "add"],
	"mag_red": ["e53935", 1.0, "gloss"], "mag_tip": ["d8dde3", 1.0, "metal"],
}


func _mat(key: String) -> Material:
	if _shot_mats.has(key):
		return _shot_mats[key]
	var spec: Array = MATS.get(key, ["ffffff", 1.0, "flat"])
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(Color(String(spec[0])), float(spec[1]))
	match String(spec[2]):
		"flat":
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		"add":
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		"alpha":
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.roughness = 0.15
			m.rim_enabled = true
			m.rim = 0.6
		"metal":
			m.metallic = 0.75
			m.roughness = 0.3
		"gloss":
			m.roughness = 0.16
			m.metallic_specular = 0.8
			m.rim_enabled = true
			m.rim = 0.35
		_:
			m.roughness = 0.55
	_shot_mats[key] = m
	return m


static func _mesh_mi(mesh: Mesh, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func _sphere(r: float, segs := 10) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = segs
	s.rings = maxi(4, int(segs * 0.8))
	return s


static func _cyl(top: float, bottom: float, h: float, segs := 8) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = segs
	c.rings = 1
	return c


## The wooden boomerang's mesh (AbodenShotLooks).
static func boomerang_mesh() -> ArrayMesh:
	return Looks.boomerang_mesh()


## A shot drawn as its own little model (mini and bubble shots are drawn by shot_crowd,
## pellets, bouncy balls and beans with the sparks). Looks along -z.
func _shot_node(kind: String, k: float) -> Node3D:
	var root := Node3D.new()
	root.name = kind.capitalize()
	match kind:
		"bolt":
			# A hot white core in an amber glow, a long tapering trail behind.
			for t: Array in [[0.016, 0.52, "bolt_glow"], [0.006, 0.42, "trail"]]:
				var tr := _mesh_mi(_cyl(0.0015 * k, float(t[0]) * k, float(t[1]) * k, 8), _mat(String(t[2])))
				tr.rotation.x = PI / 2  # +y (the thin end) behind the head (the head looks along -z)
				tr.position.z = float(t[1]) * 0.5 * k
				root.add_child(tr)
			root.add_child(_mesh_mi(_sphere(0.03 * k), _mat("bolt_glow")))
			root.add_child(_mesh_mi(_sphere(0.013 * k), _mat("head")))
		"firework":
			root.add_child(_mesh_mi(_sphere(0.017 * k), _mat("rocket")))
			root.add_child(_mesh_mi(_sphere(0.04 * k), _mat("fw_glow")))
		"rocket":
			var body := _mesh_mi(_cyl(0.018 * k, 0.018 * k, 0.11 * k, 10), _mat("rk_body"))
			body.rotation.x = -PI / 2  # +y (the nose end) forward, -z
			root.add_child(body)
			var nose := _mesh_mi(_cyl(0.0, 0.018 * k, 0.045 * k, 10), _mat("rk_nose"))
			nose.rotation.x = -PI / 2
			nose.position.z = -0.0775 * k
			root.add_child(nose)
			for i in 3:
				var fin := _mesh_mi(BoxMesh.new(), _mat("rk_fin"))
				(fin.mesh as BoxMesh).size = Vector3(0.004, 0.03, 0.035) * k
				var a := i * TAU / 3.0
				fin.position = Vector3(cos(a) * 0.024 * k, sin(a) * 0.024 * k, 0.045 * k)
				fin.rotation.z = a - PI / 2
				root.add_child(fin)
			var flame := _mesh_mi(_sphere(0.022 * k, 8), _mat("flame"))
			flame.name = "Flame"
			flame.position.z = 0.07 * k
			root.add_child(flame)
		"boomerang":
			# A classic wooden boomerang (boomerang_mesh): it leans into its curve (Tilt) and
			# spins flat in its own plane (Spin).
			var tilt := Node3D.new()
			tilt.name = "Tilt"
			root.add_child(tilt)
			var spin := Node3D.new()
			spin.name = "Spin"
			tilt.add_child(spin)
			var mi := _mesh_mi(boomerang_mesh(), Looks.acc_material())
			mi.scale = Vector3.ONE * k
			spin.add_child(mi)
		"glob":
			var blob := _mesh_mi(_sphere(0.045 * k, 14), _mat("glob"))
			blob.name = "Blob"
			root.add_child(blob)
			var core := _mesh_mi(_sphere(0.026 * k, 10), _mat("glob_core"))
			core.position = Vector3(-0.012, 0.014, 0.0) * k
			root.add_child(core)
		"dallah":
			# The Arabic coffee pot: a round-bellied brass body, a waisted neck, a domed lid
			# with its finial, the long beaked spout and the handle at the back.
			var pot := Node3D.new()
			pot.name = "Spin"
			pot.scale = Vector3.ONE * 1.3
			root.add_child(pot)
			pot.add_child(_mesh_mi(_cyl(0.02 * k, 0.034 * k, 0.045 * k, 14), _mat("brass")))
			var base := _mesh_mi(_cyl(0.034 * k, 0.03 * k, 0.008 * k, 14), _mat("brass_dark"))
			base.position.y = -0.026 * k
			pot.add_child(base)
			var neck := _mesh_mi(_cyl(0.023 * k, 0.016 * k, 0.03 * k, 12), _mat("brass"))
			neck.position.y = 0.037 * k
			pot.add_child(neck)
			var lid := _mesh_mi(_cyl(0.004 * k, 0.024 * k, 0.018 * k, 12), _mat("brass_dark"))
			lid.position.y = 0.061 * k
			pot.add_child(lid)
			var fin := _mesh_mi(_sphere(0.007 * k, 8), _mat("brass"))
			fin.position.y = 0.074 * k
			pot.add_child(fin)
			var spout := _mesh_mi(_cyl(0.004 * k, 0.008 * k, 0.07 * k, 8), _mat("brass"))
			spout.position = Vector3(0.0, 0.03 * k, -0.04 * k)
			spout.rotation.x = -0.75
			pot.add_child(spout)
			var handle := _mesh_mi(TorusMesh.new(), _mat("brass_dark"))
			(handle.mesh as TorusMesh).inner_radius = 0.016 * k
			(handle.mesh as TorusMesh).outer_radius = 0.021 * k
			handle.rotation.z = PI / 2
			handle.position = Vector3(0.0, 0.012 * k, 0.03 * k)
			pot.add_child(handle)
			pot.add_child(_mesh_mi(_sphere(0.07 * k, 10), _mat("dallah_glow")))
		"falcon":
			_falcon_node(root, k)
		"blackhole":
			# A black core in a violet glow, a thin bright ring at its edge and a flat swirling disk.
			var hole := Node3D.new()
			hole.name = "Hole"
			root.add_child(hole)
			hole.add_child(_mesh_mi(_sphere(0.05 * k, 16), _mat("void")))
			hole.add_child(_mesh_mi(_sphere(0.09 * k, 12), _mat("void_halo")))
			var disk := Node3D.new()
			disk.name = "Disk"
			disk.rotation = Vector3(0.45, 0.0, 0.2)
			hole.add_child(disk)
			var rim := _mesh_mi(TorusMesh.new(), _mat("void_rim"))
			(rim.mesh as TorusMesh).inner_radius = 0.052 * k
			(rim.mesh as TorusMesh).outer_radius = 0.062 * k
			disk.add_child(rim)
			for i in 3:
				# Three offset arms of the swirl (flattened rings, a little apart).
				var arm := _mesh_mi(TorusMesh.new(), _mat("void_disk"))
				(arm.mesh as TorusMesh).inner_radius = (0.07 + 0.02 * i) * k
				(arm.mesh as TorusMesh).outer_radius = (0.082 + 0.024 * i) * k
				arm.scale = Vector3(1.0, 0.25, 1.0)
				arm.position = Vector3(0.006 * (i - 1), 0.0, 0.004 * i) * k
				disk.add_child(arm)
		"dates":
			# A glossy date: a long oval, its pale cap at the back.
			var date := _mesh_mi(_sphere(0.012 * k, 10), _mat("date" if rnd() < 0.6 else "date_amber"))
			date.name = "Date"
			date.scale = Vector3(1.0, 0.95, 1.75)
			root.add_child(date)
			var cap := _mesh_mi(_cyl(0.004 * k, 0.005 * k, 0.004 * k, 6), _mat("date_cap"))
			cap.rotation.x = PI / 2
			cap.position.z = 0.02 * k
			root.add_child(cap)
		"bakhoor":
			# The mabkhara: a square foot, a waisted square stem and a flared square bowl, dark wood
			# with a gold lattice and gold studs at the corners, glowing coals in the bowl.
			var burner := Node3D.new()
			burner.name = "Spin"
			root.add_child(burner)
			var wood := Looks.bakhoor_material()
			var foot := _mesh_mi(_cyl(0.026 * k, 0.03 * k, 0.012 * k, 4), wood)
			foot.position.y = -0.034 * k
			burner.add_child(foot)
			var stem := _mesh_mi(_cyl(0.016 * k, 0.022 * k, 0.026 * k, 4), wood)
			stem.position.y = -0.015 * k
			burner.add_child(stem)
			var bowl := _mesh_mi(_cyl(0.036 * k, 0.018 * k, 0.026 * k, 4), wood)
			bowl.position.y = 0.011 * k
			burner.add_child(bowl)
			for y: float in [-0.028, -0.002, 0.024]:
				var band := _mesh_mi(_cyl(0.0, 0.0, 0.0025 * k, 4), _mat("gold"))
				var rr := 0.031 if y < -0.02 else (0.019 if y < 0.0 else 0.0355)
				(band.mesh as CylinderMesh).top_radius = (rr + 0.0015) * k
				(band.mesh as CylinderMesh).bottom_radius = (rr + 0.0015) * k
				band.position.y = y * k
				burner.add_child(band)
			for i in 4:
				var a := PI / 4.0 + i * PI / 2.0
				for at: Array in [[0.03, -0.04], [0.036, 0.025]]:
					var stud := _mesh_mi(_sphere(0.003 * k, 6), _mat("gold"))
					stud.position = Vector3(cos(a) * float(at[0]), float(at[1]), sin(a) * float(at[0])) * k
					burner.add_child(stud)
			var coals := _mesh_mi(_cyl(0.026 * k, 0.026 * k, 0.004 * k, 4), _mat("coal"))
			coals.position.y = 0.024 * k
			burner.add_child(coals)
			var glow := _mesh_mi(_sphere(0.014 * k, 8), _mat("ember_glow"))
			glow.name = "Glow"
			glow.scale = Vector3(1.4, 0.45, 1.4)
			glow.position.y = 0.027 * k
			burner.add_child(glow)
		"lasso":
			# The rope's loop (the rope itself is drawn with the beams, _draw_ropes).
			var loop := _mesh_mi(TorusMesh.new(), Looks.shemagh_material())
			loop.name = "Loop"
			(loop.mesh as TorusMesh).inner_radius = 0.062 * k
			(loop.mesh as TorusMesh).outer_radius = 0.074 * k
			(loop.mesh as TorusMesh).rings = 32
			(loop.mesh as TorusMesh).ring_segments = 8
			root.add_child(loop)
			var knot := _mesh_mi(_sphere(0.012 * k, 8), Looks.shemagh_material())
			knot.position = Vector3(0.0, 0.0, 0.068 * k)
			knot.scale = Vector3(1.0, 1.0, 1.4)
			loop.add_child(knot)
		"cluster":
			# A round toy bomb: glossy violet with yellow dots, a fuse with a fizzing tip.
			var bomb := Node3D.new()
			bomb.name = "Spin"
			root.add_child(bomb)
			bomb.add_child(_mesh_mi(_sphere(0.04 * k, 14), _mat("bomb")))
			for i in 8:
				var dot := _mesh_mi(_sphere(0.008 * k, 6), _mat("bomb_dot"))
				var d := cone_dir(Vector3.UP, 0.7 + 0.9 * (i % 2), i * TAU / 8.0)
				dot.position = d * 0.037 * k
				dot.scale = Vector3(1.0, 0.45, 1.0)
				dot.basis = Basis.looking_at(d, Vector3.RIGHT if absf(d.y) > 0.9 else Vector3.UP).scaled(Vector3(1.0, 1.0, 0.35))
				bomb.add_child(dot)
			var neck := _mesh_mi(_cyl(0.012 * k, 0.014 * k, 0.012 * k, 8), _mat("bomb_dot"))
			neck.position.y = 0.042 * k
			bomb.add_child(neck)
			var fuse := _mesh_mi(_cyl(0.003 * k, 0.003 * k, 0.03 * k, 6), _mat("fuse"))
			fuse.position = Vector3(0.006, 0.06, 0.0) * k
			fuse.rotation.z = -0.4
			bomb.add_child(fuse)
			var fire := _mesh_mi(_sphere(0.008 * k, 8), _mat("fuse_fire"))
			fire.name = "Fire"
			fire.position = Vector3(0.012, 0.074, 0.0) * k
			bomb.add_child(fire)
		"magnet":
			# A horseshoe magnet: a red U (two arms and a bend of short blocks) with silver poles.
			var mag := Node3D.new()
			mag.name = "Spin"
			root.add_child(mag)
			var u := Node3D.new()
			u.rotation.x = -PI / 2  # the poles point forward (-z)
			mag.add_child(u)
			var w := 0.014
			for sx: float in [-1.0, 1.0]:
				var arm := _mesh_mi(_box(Vector3(w, 0.04, w) * k), _mat("mag_red"))
				arm.position = Vector3(sx * 0.024, 0.012, 0.0) * k
				u.add_child(arm)
				var tip := _mesh_mi(_box(Vector3(w + 0.001, 0.014, w + 0.001) * k), _mat("mag_tip"))
				tip.position = Vector3(sx * 0.024, 0.039, 0.0) * k
				u.add_child(tip)
			for i in 7:
				var a := PI + PI * (i + 0.5) / 7.0
				var blk := _mesh_mi(_box(Vector3(0.012, w, w) * k), _mat("mag_red"))
				blk.position = Vector3(cos(a) * 0.024, -0.008 + sin(a) * 0.024, 0.0) * k
				blk.rotation.z = a + PI / 2
				u.add_child(blk)
		"shield":
			var bub := _mesh_mi(_sphere(1.0, 24), Looks.shield_material())
			bub.name = "Bubble"
			bub.scale = Vector3.ONE * float(SHOT_STYLE.shield.r) * k
			root.add_child(bub)
	return root


## A low-poly slab: the convex outline `pts` ([x, z] in metres, x mirrored by `sx`) with
## `thick` metres of thickness, centred on y = 0, k times life size.
static func _slab(pts: Array, thick: float, k: float, sx := 1.0) -> ArrayMesh:
	var poly := PackedVector2Array()
	for q: Array in pts:
		poly.append(Vector2(float(q[0]) * sx, float(q[1])) * k)
	if sx < 0.0:
		poly.reverse()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h := thick * 0.5 * k
	var n := poly.size()
	for i in range(1, n - 1):
		# Top (seen from +y: counter-clockwise in x/z is clockwise from above) and bottom.
		for v: Vector2 in [poly[0], poly[i + 1], poly[i]]:
			st.add_vertex(Vector3(v.x, h, v.y))
		for v: Vector2 in [poly[0], poly[i], poly[i + 1]]:
			st.add_vertex(Vector3(v.x, -h, v.y))
	for i in n:
		var a := poly[i]
		var b := poly[(i + 1) % n]
		for v: Vector3 in [Vector3(a.x, h, a.y), Vector3(b.x, h, b.y), Vector3(b.x, -h, b.y), Vector3(a.x, h, a.y), Vector3(b.x, -h, b.y), Vector3(a.x, -h, a.y)]:
			st.add_vertex(v)
	st.generate_normals()
	return st.commit()


static func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


## The falcon (looks along -z): a brown back and cream breast, a dark head with a yellow beak, a
## fanned tail and two jointed wings (WingL / WingR, each with its Tip) that beat; a leather
## hood with a red plume over its head (Hood), which drops off once it is flying.
func _falcon_node(root: Node3D, k: float) -> void:
	var bird := Node3D.new()
	bird.name = "Bird"
	bird.scale = Vector3.ONE * 1.25
	root.add_child(bird)
	var body := _mesh_mi(_sphere(0.03 * k, 10), _mat("fa_brown"))
	body.scale = Vector3(0.85, 0.72, 1.7)
	bird.add_child(body)
	var breast := _mesh_mi(_sphere(0.026 * k, 10), _mat("fa_cream"))
	breast.scale = Vector3(0.82, 0.7, 1.35)
	breast.position = Vector3(0.0, -0.007, -0.016) * k
	bird.add_child(breast)
	var head := _mesh_mi(_sphere(0.017 * k, 10), _mat("fa_dark"))
	head.position = Vector3(0.0, 0.01, -0.058) * k
	bird.add_child(head)
	var cheek := _mesh_mi(_sphere(0.013 * k, 8), _mat("fa_cream"))
	cheek.position = Vector3(0.0, 0.003, -0.064) * k
	cheek.scale = Vector3(1.05, 0.8, 0.8)
	bird.add_child(cheek)
	for sx: float in [-1.0, 1.0]:
		var eye := _mesh_mi(_sphere(0.0035 * k, 6), _mat("fa_eye"))
		eye.position = Vector3(sx * 0.012, 0.014, -0.066) * k
		bird.add_child(eye)
	var beak := _mesh_mi(_cyl(0.0, 0.0055 * k, 0.016 * k, 6), _mat("fa_beak"))
	beak.rotation.x = -PI / 2 - 0.35
	beak.position = Vector3(0.0, 0.004, -0.079) * k
	bird.add_child(beak)
	# The tail: a fan, brown with a pale band at its end.
	bird.add_child(_mesh_mi(_slab([[-0.01, 0.045], [0.01, 0.045], [0.024, 0.1], [-0.024, 0.1]], 0.004, k), _mat("fa_brown")))
	var band := _mesh_mi(_slab([[-0.024, 0.098], [0.024, 0.098], [0.026, 0.108], [-0.026, 0.108]], 0.0045, k), _mat("fa_cream"))
	bird.add_child(band)
	for sx: float in [-1.0, 1.0]:
		var wing := Node3D.new()
		wing.name = "WingL" if sx < 0.0 else "WingR"
		wing.position = Vector3(sx * 0.016, 0.008, -0.012) * k
		bird.add_child(wing)
		# The arm (brown, cream beneath) and the hand (dark, pointed and swept back), one
		# low-poly slab each, joined at the wrist (Tip).
		var inner := _mesh_mi(_slab([[0.0, -0.022], [0.07, -0.016], [0.07, 0.024], [0.0, 0.03]], 0.005, k, sx), _mat("fa_brown"))
		wing.add_child(inner)
		var under := _mesh_mi(_slab([[0.004, -0.014], [0.066, -0.01], [0.066, 0.012], [0.004, 0.016]], 0.002, k, sx), _mat("fa_cream"))
		under.position.y = -0.0035 * k
		wing.add_child(under)
		var tip := Node3D.new()
		tip.name = "Tip"
		tip.position = Vector3(sx * 0.07, 0.0, 0.0) * k
		wing.add_child(tip)
		var outer := _mesh_mi(_slab([[0.0, -0.016], [0.05, -0.006], [0.085, 0.03], [0.04, 0.03], [0.0, 0.024]], 0.004, k, sx), _mat("fa_dark"))
		tip.add_child(outer)
	var hood := Node3D.new()
	hood.name = "Hood"
	hood.position = Vector3(0.0, 0.012, -0.058) * k
	bird.add_child(hood)
	var cap := _mesh_mi(_sphere(0.0195 * k, 10), _mat("fa_hood"))
	cap.scale = Vector3(1.0, 0.95, 1.1)
	hood.add_child(cap)
	var plume := _mesh_mi(_cyl(0.001 * k, 0.0035 * k, 0.014 * k, 6), _mat("fa_plume"))
	plume.position.y = 0.022 * k
	hood.add_child(plume)
	var knob := _mesh_mi(_sphere(0.003 * k, 6), _mat("gold"))
	knob.position.y = 0.017 * k
	hood.add_child(knob)


## The shots drawn by the crowd: tumbling little balls, each its own size and
## tumble, and iridescent soap bubbles that wobble as they drift.
func _draw_shots() -> void:
	var n := 0
	for s in shots:
		if s.style != "":
			n += 1
	if n == 0 and _crowd_drawn == 0:
		return
	shot_crowd.begin()
	for s in shots:
		if s.style == "":
			continue
		var p: Vector3 = s.p
		var spin: float = s.spin
		if s.kind == "mini":
			var tumble := Basis(s.axis as Vector3, spin) * Vector3.FORWARD
			var sq := sin(float(s.t) * float(s.wob)) * 0.08
			shot_crowd.add(s.style, p, s.r * float(s.size), p + tumble, Vector2(1.0 + sq, 1.0 - sq), s.color)
		else:
			var wob: float = s.wob
			var w := sin(wob * 2.3) * 0.08 + sin(wob * 3.7 + 1.3) * 0.04
			# The film's colours slide around as it turns.
			var base: Color = s.color
			var film := Color.from_hsv(fposmod(float(s.hue) + float(s.t) * 0.35 + sin(wob) * 0.08, 1.0), 0.3, 1.0)
			shot_crowd.add("bubble", p, s.r, p + Vector3(sin(spin), 0.0, cos(spin)), Vector2(1.0 + w, 1.0 - w), base.lerp(film, 0.6))
	shot_crowd.end()
	_crowd_drawn = n


## One spark. grow: it swells to (1 + grow) x its size by the end (smoke); curl: its way along
## the ground turns at this many radians a second (smoke curling as it rises).
func _spark(p: Vector3, v: Vector3, life: float, color: Color, size: float, flash := false, flake := false, grow := 0.0, curl := 0.0) -> void:
	if sparks.size() >= SPARKS_MAX:
		return
	sparks.append({"p": p, "v": v, "t": 0.0, "max": life, "flash": flash, "color": color, "size": size, "k": blast_k(),
		"flake": flake, "axis": Vector3(rnd() - 0.5, rnd() - 0.5, rnd() - 0.5).normalized() if flake else Vector3.UP, "rot": rnd() * TAU,
		"grow": grow, "curl": curl})


## A little spray of sparks where a shot lands, with a quick flash.
func impact(p: Vector3, n: Vector3, color := Color("ffd27a")) -> void:
	var k := blast_k()
	_spark(p, Vector3.ZERO, 0.08, Color("fffaf2"), 0.05 * k, true)
	for i in 8:
		var d := Vector3(rnd() - 0.5, rnd() - 0.5, rnd() - 0.5).normalized()
		d = (d + n * 1.2).normalized() * ((1.0 + rnd() * 1.5) * k)
		_spark(p, d, 0.25 + rnd() * 0.2, color if i % 2 else Color("fffaf2"), (0.008 + rnd() * 0.008) * k)


## A firework's bloom: a flash, a round shell of sparks in two colours and white glitter.
func bloom(p: Vector3) -> void:
	var k := blast_k()
	var c1 := Color(FIRE_COLS[_rng.randi() % (FIRE_COLS.size() - 1)])
	var c2 := Color(FIRE_COLS[_rng.randi() % FIRE_COLS.size()])
	_spark(p, Vector3.ZERO, 0.1, Color("fffaf2"), 0.07 * k, true)
	for i in 36:
		var d := Vector3(rnd() - 0.5, rnd() - 0.5, rnd() - 0.5).normalized() * ((2.2 + rnd() * 0.5) * k)
		_spark(p, d, 0.65 + rnd() * 0.3, c1 if i % 2 else c2, (0.011 + rnd() * 0.006) * k)
	for _i in 12:
		var d := Vector3(rnd() - 0.5, rnd() - 0.5, rnd() - 0.5).normalized() * ((0.6 + rnd() * 1.2) * k)
		_spark(p, d, 0.8 + rnd() * 0.4, Color("fffaf2"), 0.007 * k)
	_sfx("firework_burst", 1.0, p)


## A rocket's blast: a flash, fire and smoke.
func explosion(p: Vector3) -> void:
	var k := blast_k()
	_spark(p, Vector3.ZERO, 0.12, Color("fff4d6"), 0.09 * k, true)
	for i in 26:
		var d := Vector3(rnd() - 0.5, rnd() - 0.5, rnd() - 0.5).normalized() * ((1.0 + rnd() * 2.4) * k)
		_spark(p, d, 0.35 + rnd() * 0.35, Color("ff7a2e") if i % 3 else Color("ffd34d"), (0.016 + rnd() * 0.014) * k)
	for _i in 10:
		var d := Vector3(rnd() - 0.5, rnd() * 0.8, rnd() - 0.5) * 1.2 * k
		_spark(p, d, 0.7 + rnd() * 0.4, Color("8a8580"), (0.03 + rnd() * 0.02) * k, true)
	_sfx("boom", 1.0, p)


## The water shot's splash: blue drops every way.
func splat(p: Vector3, n: Vector3) -> void:
	var k := blast_k()
	for i in 16:
		var d := (Vector3(rnd() - 0.5, rnd() - 0.5, rnd() - 0.5).normalized() + n).normalized() * ((1.0 + rnd() * 2.0) * k)
		_spark(p, d, 0.4 + rnd() * 0.3, Color("3fb4ff") if i % 3 else Color("c9f1ff"), (0.012 + rnd() * 0.014) * k)
	_sfx("splash", 0.75, p)
	_sfx("squeak", 0.7, p)


## A pop above the player's head counts toward skyPop5.
func sky_pop(p: Vector3) -> void:
	if p.y > _eye().y + 0.25 * reach_k():
		_ch("skyPop5", 1)


## A soft target pops: a puff of sparks in its colour.
func burst(p: Vector3, color := Color("fffaf2"), by_player := true) -> void:
	if by_player:
		sky_pop(p)
	var k := blast_k()
	for i in (14 if by_player else 6):
		var a := rnd() * TAU
		var e := rnd() * PI - PI / 2
		var sp := (1.2 + rnd() * 1.8) * k
		_spark(p, Vector3(cos(a) * cos(e) * sp, sin(e) * sp + k, sin(a) * cos(e) * sp), 0.45 + rnd() * 0.3,
			color if i % 3 else Color("fffaf2"), (0.012 + rnd() * 0.012) * k)
	popped += 1
	if by_player or clock >= _next_ambient_pop:
		_sfx("start_pop", 1.0, p)
		_next_ambient_pop = clock + 0.12
	if by_player:
		_buzz("left", 0.35, 40)
		_ch("pop20", 1)


# --- what the homing and chaining shots go for -----------------------------------------

## Everything a rocket or a lightning arc can go for: [{kind, ref, p, r, src}] — the host's
## soft targets ("t": src is the host's Dictionary, ref its "ref" or "id") and the stage's
## hidden hit meshes ("s": the layers = 0 MeshInstance3Ds the blaster's ray finds).
func targets() -> Array:
	var out: Array = []
	if _has("blaster_targets"):
		for t: Variant in host.blaster_targets():
			if t is Dictionary and (t as Dictionary).has("p"):
				out.append({"kind": "t", "ref": _key(t), "p": t.p, "r": float(t.get("r", TARGET_R)), "src": t})
	var st := current_stage()
	if st and st.is_visible_in_tree() and st.has_method("shoot"):
		for mi in st.find_children("*", "MeshInstance3D", true, false):
			var m := mi as MeshInstance3D
			if m.layers == 0 and m.mesh != null and m.is_visible_in_tree():
				out.append({"kind": "s", "ref": m, "p": _proxy_center(m), "r": TARGET_R})
	return out


## A soft target's identity: its "ref", else its "id", else the Dictionary itself.
static func _key(t: Dictionary) -> Variant:
	if t.get("ref") != null:
		return t.ref
	if t.has("id"):
		return t.id
	return t


static func _same(a: Variant, b: Variant) -> bool:
	# typeof, not `is`: a host may have freed the object a shot remembers (a blocked threat).
	if typeof(a) == TYPE_OBJECT or typeof(b) == TYPE_OBJECT:
		return is_same(a, b)
	return typeof(a) == typeof(b) and a == b


## The host's soft target with this identity now, or {}.
func _soft_now(ref: Variant) -> Dictionary:
	if not _has("blaster_targets"):
		return {}
	for t: Variant in host.blaster_targets():
		if t is Dictionary and (t as Dictionary).has("p") and _same(_key(t), ref):
			return t
	return {}


## How close a shot must pass a target (beyond its own radius R).
func _target_r(t: Dictionary) -> float:
	return float(t.get("r", TARGET_R))


func _proxy_center(m: MeshInstance3D) -> Vector3:
	return global_transform.affine_inverse() * m.global_transform * m.mesh.get_aabb().get_center()


static func _index_of(list: Array, ref) -> int:
	for i in list.size():
		if is_same(list[i], ref):
			return i
	return -1


## Where a target is now, or null once it is gone.
func target_at(t: Dictionary) -> Variant:
	if t.is_empty():
		return null
	match String(t.kind):
		"t":
			var now := _soft_now(t.ref)
			return now.p if not now.is_empty() else null
		"s":
			var m = t.ref
			if is_instance_valid(m) and (m as MeshInstance3D).is_visible_in_tree():
				return _proxy_center(m)
	return null


## A soft target reached by a `kind` shot: the host says whether it counted (default yes);
## then it pops (unless it says "burst": false).
func _hit_soft(t: Dictionary, dir: Vector3, kind: String) -> bool:
	var src: Dictionary = t.get("src", {})
	var took := true
	if _has("blaster_hit"):
		took = bool(host.blaster_hit(src, dir if dir.length_squared() > 0.0 else Vector3.FORWARD))
	if not took:
		return false
	if bool(src.get("burst", true)):
		var c: Variant = src.get("color", "fffaf2")
		burst(t.p, c if c is Color else Color(str(c)))
	shot_hit.emit(kind, src)
	return true


## Hits a target: a soft one pops, a stage target takes the shot. True when it counted.
func hit_target(t: Dictionary, dir: Vector3, kind := "") -> bool:
	match String(t.kind):
		"t":
			var now := _soft_now(t.ref)
			if now.is_empty() and _has("blaster_targets"):
				return false
			return _hit_soft(t, dir, kind)
		"s":
			var m = t.ref
			var st := current_stage()
			if not is_instance_valid(m) or st == null or not st.has_method("shoot"):
				return false
			var at := _proxy_center(m)
			var took: bool = st.shoot(m, at, dir if dir.length_squared() > 0.0 else Vector3.FORWARD)
			impact(at, -dir, Color("ffd27a") if took else Color("fffaf2"))
			if took:
				shot_hit.emit(kind, m)
			return took
	return false


## Pops what is within RR of c (the soft targets and the stage's targets). Returns how many.
func pop_radius(c: Vector3, RR: float, kind := "") -> int:
	var n := 0
	for t in targets():
		var r: float = float(t.r) if t.kind == "t" else _proxy_radius(t.ref)
		if (t.p as Vector3).distance_to(c) < RR + r:
			var d: Vector3 = (t.p as Vector3) - c
			if hit_target(t, d.normalized() if d.length_squared() > 1e-8 else Vector3.FORWARD, kind):
				n += 1
	return n


func _proxy_radius(m: MeshInstance3D) -> float:
	var xf := global_transform.affine_inverse() * m.global_transform
	return m.mesh.get_aabb().size.length() * 0.35 * xf.basis.get_scale().x


## The nearest target ahead of a rocket (within `far`, in front of it), or {}. Each rocket picks
## its own: one another rocket in the air is already after is passed over while there are others.
## A falcon hunts the same way, passing over what another falcon is after.
func _seek(p: Vector3, fwd: Vector3, far: float, me := {}) -> Dictionary:
	var taken := []
	var kind := String(me.get("kind", "rocket"))
	for o: Dictionary in shots:
		if o.kind == kind and not is_same(o, me) and not (o.target as Dictionary).is_empty():
			taken.append(o.target.ref)
	var best := {}
	var best_score := INF
	var spare := {}
	var spare_score := INF
	for t in targets():
		var to: Vector3 = (t.p as Vector3) - p
		var d := to.length()
		if d < 1e-4 or d > far:
			continue
		var facing := fwd.dot(to / d)
		if facing < 0.3:
			continue
		var score := d * (1.6 - facing)
		if taken.any(func(r) -> bool: return _same(r, t.ref)):
			if score < spare_score:
				spare_score = score
				spare = t
			continue
		if score < best_score:
			best_score = score
			best = t
	return best if not best.is_empty() else spare


# --- the instant shots: laser and lightning ---------------------------------------------

## How far a beam from p along dir goes before the floor or a wall of the world.
func _beam_reach(p: Vector3, dir: Vector3, far: float, R: float) -> float:
	var end := far
	var fy := _floor_y()
	if dir.y < -1e-4 and p.y > fy:
		end = minf(end, (fy - p.y) / dir.y)
	if _has("blaster_collide"):
		var step_len := 0.5 * blast_k()
		var d := 0.0
		while d < end:
			var nd := minf(end, d + step_len)
			var rh := _collide(p + dir * nd, dir * 40.0 * blast_k(), R, p + dir * d)
			if _hit_speed(rh, dir) > 0.0:
				return maxf(0.0, ((rh.p as Vector3) - p).dot(dir))
			d = nd
	return end


## The laser: an instant beam that pops (or hits) up to `pierce` targets along the way,
## stopping at a wall; a glowing line that fades. The freeze ray is the same beam, short and
## icy, and freezes what it reaches (_frost).
func _laser(p: Vector3, dir: Vector3, k: float, P: Dictionary, kind := "laser") -> void:
	var R: float = P.r * k
	var end := _beam_reach(p, dir, P.range * reach_k(), R)
	var cur := 0.0
	var hits := 0
	var seen: Array = []
	var st := current_stage()
	var blocked := false
	var icy := kind == "freeze"
	var col := Color("9fe8ff") if icy else Color("ff3b6b")
	while hits < int(P.pierce):
		# The nearest soft target along the beam...
		var best := {}
		var best_d := end
		for t in targets():
			if t.kind == "s":
				continue
			var along := ((t.p as Vector3) - p).dot(dir)
			if along < cur or along > best_d:
				continue
			if (p + dir * along).distance_to(t.p) < _target_r(t) + R:
				best_d = along
				best = t
		# ... or the first thing of the stage before it.
		var sh := {}
		if st and st.is_visible_in_tree() and best_d > cur:
			sh = ray_stage(st, p + dir * cur, dir, best_d - cur, seen)
		if not sh.is_empty():
			var d := ((sh.point as Vector3) - p).dot(dir)
			seen.append(sh.node)
			var took: bool = st.has_method("shoot") and st.shoot(sh.node, sh.point, dir)
			impact(sh.point, sh.normal, col if took else Color("fffaf2"))
			if took:
				shot_hit.emit(kind, sh.node)
				if icy:
					_frost({"kind": "s", "ref": sh.node, "p": _proxy_center(sh.node), "r": TARGET_R}, P, false)
				hits += 1
				cur = d
				continue
			end = d
			blocked = true
			_sfx("thump", 0.25, sh.point)
			break
		if best.is_empty():
			break
		if icy:
			_frost(best, P, true, dir)
		else:
			hit_target(best, dir, "laser")
		hits += 1
		cur = best_d
	_credit(kind, hits)
	if hits >= int(P.pierce):
		end = cur  # the beam stops in the last one
	elif not blocked and end < P.range * reach_k() - 1e-3:
		impact(p + dir * end, -dir, col)
	_arc(p, p + dir * maxf(end, 0.05 * k), 1, 0.0, (0.016 if icy else 0.022) * k, col, P.life)
	if icy:
		# Frost glitters along the beam.
		var L := maxf(end, 0.05 * k)
		for i in 10:
			var q := p + dir * L * rnd()
			_spark(q, Vector3(rnd() - 0.5, rnd() - 0.2, rnd() - 0.5) * 0.3 * k, 0.35 + rnd() * 0.3,
				Color("e8fbff") if i % 2 else Color("9fe8ff"), (0.004 + rnd() * 0.004) * k, false, true)


## The freeze ray reached a target: a soft one is frozen for `frost` seconds by the host
## (blaster_freeze), or, with no such call, hit like any other shot; a stage's target has
## already taken it (stage.shoot). Either way it cracks with ice and wears a frost shell.
func _frost(t: Dictionary, P: Dictionary, soft: bool, dir := Vector3.FORWARD) -> void:
	var k := blast_k()
	var at: Vector3 = t.p
	if soft:
		if _has("blaster_freeze"):
			host.blaster_freeze(t.get("src", {}), float(P.frost))
			shot_hit.emit("freeze", t.get("src", {}))
		elif not hit_target(t, dir, "freeze"):
			return
	_sfx("ice_crack", 0.8, at)
	for i in 14:
		var d := Vector3(rnd() - 0.5, rnd() - 0.5, rnd() - 0.5).normalized() * ((0.6 + rnd() * 1.2) * k)
		_spark(at + d.normalized() * float(t.get("r", TARGET_R)) * 0.8, d, 0.5 + rnd() * 0.4,
			Color("e8fbff") if i % 3 else Color("7fd8ff"), (0.006 + rnd() * 0.006) * k, false, true)
	# The shell stays while it is frozen (a popped one is gone at once: target_at() says null).
	if auras.size() >= AURAS_MAX:
		auras.pop_front()
	auras.append({"target": t, "r": float(t.get("r", TARGET_R)), "t": 0.0, "max": float(P.frost)})


## Lightning: an arc to the target nearest the aim, then on to the nearest one within a
## hop of it, up to `chain` targets, along jagged flickering arcs.
func _lightning(p: Vector3, dir: Vector3, k: float, P: Dictionary) -> void:
	var col := Color("5aa8ff")
	var all := targets()
	var first := {}
	var best := INF
	var far: float = P.range * reach_k()
	for t in all:
		var to: Vector3 = (t.p as Vector3) - p
		var d := to.length()
		if d < 1e-4 or d > far:
			continue
		var ang := dir.angle_to(to)
		if ang > float(P.cone):
			continue
		var score := ang * 4.0 + d / far
		if score < best:
			best = score
			first = t
	if first.is_empty():
		# Nothing to go for: a crackle straight ahead, to whatever is there.
		var end := _beam_reach(p, dir, far * 0.5, P.r * k)
		var st := current_stage()
		if st and st.is_visible_in_tree():
			var sh := ray_stage(st, p, dir, end)
			if not sh.is_empty():
				end = ((sh.point as Vector3) - p).dot(dir)
				var took: bool = st.has_method("shoot") and st.shoot(sh.node, sh.point, dir)
				impact(sh.point, sh.normal, col if took else Color("cfe8ff"))
				if took:
					shot_hit.emit("lightning", sh.node)
		_arc(p, p + dir * end, maxi(4, int(end / (0.35 * k))), 0.1, 0.02 * k, col, P.life)
		return
	var from := p
	var cur := first
	var chain := 0
	var zapped := 0
	var done: Array = []
	while not cur.is_empty():
		var at: Vector3 = cur.p
		_arc(from, at, clampi(int(from.distance_to(at) / (0.3 * k)), 4, 12), 0.12, 0.016 * k, col, P.life)
		done.append(cur.ref)
		var d := (at - from).normalized() if at.distance_to(from) > 1e-5 else dir
		if hit_target(cur, d, "lightning"):
			zapped += 1
		_spark(at, Vector3.ZERO, 0.1, Color("e8f4ff"), 0.04 * k, true)
		chain += 1
		if chain > 1:
			_sfx("bricks_tink", 1.0, at)
		if chain >= int(P.chain):
			break
		from = at
		var nxt := {}
		var nd: float = P.hop * reach_k()
		for t in all:
			if done.any(func(x): return _same(x, t.ref)):
				continue
			if t.kind == "s" and not (t.ref as MeshInstance3D).is_visible_in_tree():
				continue
			if t.kind != "s" and target_at(t) == null:
				continue
			var dd := (t.p as Vector3).distance_to(from)
			if dd < nd:
				nd = dd
				nxt = t
		cur = nxt
	_ch("chain4", zapped)


func _arc(a: Vector3, b: Vector3, n: int, jit: float, w: float, color: Color, life: float) -> void:
	if arcs.size() >= ARCS_MAX:
		arcs.pop_front()
	arcs.append({"a": a, "b": b, "n": maxi(1, n), "jit": jit, "w": w, "color": color, "t": 0.0, "max": life,
		"k": blast_k(), "pts": PackedVector3Array(), "tick": -1})


func _arc_points(arc: Dictionary) -> PackedVector3Array:
	var a: Vector3 = arc.a
	var b: Vector3 = arc.b
	var n: int = arc.n
	var pts := PackedVector3Array()
	var d := b - a
	var L := d.length()
	var u := d.cross(Vector3.UP)
	if u.length_squared() < 1e-8:
		u = d.cross(Vector3.RIGHT)
	u = u.normalized()
	var w := d.cross(u).normalized()
	for i in n + 1:
		var f := i / float(n)
		var q := a + d * f
		if i > 0 and i < n and float(arc.jit) > 0.0:
			var amp: float = float(arc.jit) * L / sqrt(float(n)) * sin(PI * f)
			q += (u * (rnd() - 0.5) + w * (rnd() - 0.5)) * 2.0 * amp
		pts.append(q)
	return pts


## Draws the beams and arcs; returns how many beam segments they took.
func _draw_arcs(dt: float, k: float) -> int:
	var n := 0
	for i in range(arcs.size() - 1, -1, -1):
		var arc: Dictionary = arcs[i]
		arc.t += dt
		if arc.t >= arc.max:
			arcs.remove_at(i)
	for arc in arcs:
		if absf(float(arc.k) - k) > 1e-6:
			arc.w *= k / float(arc.k)
			arc.k = k
		# Lightning flickers: a new jag 30 times a second.
		var tick := int(float(arc.t) * 30.0)
		if tick != int(arc.tick) or (arc.pts as PackedVector3Array).is_empty():
			arc.tick = tick
			arc.pts = _arc_points(arc)
		var f: float = 1.0 - float(arc.t) / float(arc.max)
		var pts: PackedVector3Array = arc.pts
		for j in pts.size() - 1:
			for layer in 2:
				if n >= BEAM_SEGS_MAX:
					break
				var w: float = float(arc.w) * (1.0 if layer == 0 else 0.28) * (0.4 + 0.6 * f)
				# A coloured glow round a pale core of the same hue.
				var c: Color = arc.color if layer == 0 else (arc.color as Color).lerp(Color.WHITE, 0.55)
				_beam_mm.set_instance_transform(n, _seg_xf(pts[j], pts[j + 1], w))
				_beam_mm.set_instance_color(n, Color(c, (0.6 if layer == 0 else 1.0) * f))
				n += 1
	return n


static func _seg_xf(a: Vector3, b: Vector3, w: float) -> Transform3D:
	var d := b - a
	var L := d.length()
	if L < 1e-6:
		return Transform3D(Basis.from_scale(Vector3.ONE * w), a)
	var bz := Basis.looking_at(d / L, Vector3.UP if absf(d.y / L) < 0.999 else Vector3.RIGHT)
	return Transform3D(Basis(bz.x * w, bz.y * w, bz.z * L), (a + b) * 0.5)


# --- the shots in flight -----------------------------------------------------------------

## How a shot moves this step (before it meets anything).
func _move(s: Dictionary, P: Dictionary, dt: float, k: float) -> void:
	var rk := reach_k()
	var G := REAL_G * rk
	match String(s.kind):
		"rocket":
			s.seek_t -= dt
			var tp = target_at(s.target)
			if tp == null and s.seek_t <= 0.0:
				s.seek_t = 0.1
				var fwd0: Vector3 = (s.v as Vector3).normalized() if (s.v as Vector3).length_squared() > 1e-10 else s.dir
				s.target = _seek(s.p, fwd0, P.seek * rk, s)
				tp = target_at(s.target)
			var fwd: Vector3 = (s.v as Vector3).normalized() if (s.v as Vector3).length_squared() > 1e-10 else s.dir
			# It locks on after a moment and turns toward its target.
			if tp != null and s.t > 0.1:
				var want: Vector3 = ((tp as Vector3) - (s.p as Vector3)).normalized()
				var ang := fwd.angle_to(want)
				if ang > 1e-4:
					fwd = fwd.slerp(want, minf(1.0, float(P.turn) * dt / ang)).normalized()
			var sp: float = lerpf(0.15, 1.0, smoothstep(0.0, 0.5, float(s.t))) * P.speed * rk
			s.v = fwd * sp
			s.p += s.v * dt
		"boomerang":
			var T: float = P.life
			if not s.ret:
				var u := clampf(float(s.t) / T, 0.0, 1.0)
				var back: Vector3 = _hand_at(s) - (s.o as Vector3)
				var want: Vector3 = (s.o as Vector3) + (s.dir as Vector3) * (P.reach * rk * sin(PI * u)) \
					+ (s.side as Vector3) * (P.swing * rk * sin(TAU * u)) + Vector3.UP * (0.25 * k * sin(PI * u)) + back * u
				s.v = (want - (s.p as Vector3)) / dt if dt > 0.0 else Vector3.ZERO
				s.p = want
				if u >= 1.0:
					s.caught = true
			else:
				# Knocked back: straight home to the hand.
				var to: Vector3 = _hand_at(s) - (s.p as Vector3)
				if to.length() < float(s.r) * 3.0 or s.t > T + 2.0:
					s.caught = true
				s.v = to.normalized() * P.speed * rk
				s.p += s.v * minf(dt, to.length() / maxf(1e-6, P.speed * rk))
		"falcon":
			_falcon_move(s, P, dt)
		"lasso":
			_lasso_move(s, P, dt)
		"shield":
			var at := _shield_at(s, P)
			s.v = (at - (s.p as Vector3)) / dt if dt > 0.0 else Vector3.ZERO
			s.p = at
		"blackhole", "magnet":
			# Straight out, slowing to a stop at the end of its flight (then it parks).
			if not s.parked:
				var f := clampf(1.0 - float(s.t) / float(P.life), 0.0, 1.0)
				s.v = (s.dir as Vector3) * P.speed * rk * f
				s.p += s.v * dt
		_:
			if s.parked:
				return
			s.v.y -= G * P.grav * dt
			if s.kind == "bubble":
				s.wob += dt * 3.0
				s.v.x += sin(s.wob) * 0.25 * k * dt
				s.v.z += cos(s.wob * 0.8) * 0.25 * k * dt
			s.p += s.v * dt


## Where a boomerang comes back to: host.blaster_hand(hand), else where it left.
func _hand_at(s: Dictionary) -> Vector3:
	if s.hand != "" and _has("blaster_hand"):
		var at: Variant = host.blaster_hand(String(s.hand))
		if at is Vector3:
			return at
	return s.o


## Where a shield bubble is: `ahead` metres in front of its hand, the way it was fired.
func _shield_at(s: Dictionary, P: Dictionary) -> Vector3:
	return _hand_at(s) + (s.dir as Vector3) * float(P.ahead) * reach_k()


## The falcon: out from the glove, it climbs a little and looks for prey (the rocket's _seek,
## passing over what another falcon is after); once it has one it turns in, screeches and
## stoops on it within `dive` (faster, tighter), and goes straight at it at the end. Then (a
## hit, a miss, prey gone, nothing found in FALCON_PATIENCE) it flies back to the hand.
func _falcon_move(s: Dictionary, P: Dictionary, dt: float) -> void:
	var rk := reach_k()
	var v: Vector3 = s.v
	var fwd: Vector3 = v.normalized() if v.length_squared() > 1e-10 else s.dir
	var sp: float = P.speed * rk
	if s.t > float(P.life) * 0.75:
		s.ret = true
	if s.ret:
		var hand := _hand_at(s)
		var to: Vector3 = hand - (s.p as Vector3)
		var d := to.length()
		sp *= 1.1
		if d < maxf(sp * dt, float(s.r) * 2.0):
			s.p = hand
			s.caught = true
			return
		s.v = v.lerp(to / d * sp, 1.0 - exp(-5.0 * dt))
		s.p += (s.v as Vector3) * dt
		return
	s.seek_t -= dt
	var had := not (s.target as Dictionary).is_empty()
	var tp: Variant = target_at(s.target)
	if tp == null and had:
		# Its prey is gone (popped by something else): back to the glove.
		s.target = {}
		s.ret = true
		return
	if tp == null and s.seek_t <= 0.0:
		s.seek_t = 0.1
		s.target = _seek(s.p, fwd, P.seek * rk, s)
		tp = target_at(s.target)
	if tp == null:
		if s.t > Catalog.FALCON_PATIENCE:
			s.ret = true
		elif s.t < 0.5:
			fwd = fwd.slerp((fwd + Vector3.UP * 0.25).normalized(), minf(1.0, dt * 1.5)).normalized()
	elif s.t > 0.2:
		var to: Vector3 = (tp as Vector3) - (s.p as Vector3)
		var d := to.length()
		var want := to / maxf(d, 1e-6)
		if d < 0.6 * rk:
			fwd = want
		else:
			var turn: float = float(P.turn) * (2.5 if s.dove else 1.0)
			var ang := fwd.angle_to(want)
			if ang > 1e-4:
				fwd = fwd.slerp(want, minf(1.0, turn * dt / ang)).normalized()
		if not s.dove and d < float(P.dive) * rk:
			s.dove = true
			_sfx("screech", 0.8, s.p)
	sp *= lerpf(0.6, 1.0, smoothstep(0.0, 0.4, float(s.t))) * (1.6 if s.dove else 1.0)
	s.v = fwd * sp
	s.p += (s.v as Vector3) * dt


## The lasso: thrown in an arc; once it has caught something (_touch_soft, with the host's
## blaster_pull) its loop stays on it and pulls it toward the hand for `drag` seconds (or until it
## is there, or gone); then, or after `life` with nothing caught, it reels back to the hand.
func _lasso_move(s: Dictionary, P: Dictionary, dt: float) -> void:
	var rk := reach_k()
	var hand := _hand_at(s)
	if not (s.hold as Dictionary).is_empty():
		var tp: Variant = target_at(s.hold)
		s.hold_t += dt
		if tp == null or float(s.hold_t) > float(P.drag) or (tp as Vector3).distance_to(hand) < 0.35 * rk:
			s.hold = {}
			s.ret = true
		else:
			s.v = ((tp as Vector3) - (s.p as Vector3)) / dt if dt > 0.0 else Vector3.ZERO
			s.p = tp
			_pull(s.hold, hand, float(P.tug) * rk * dt)
			return
	if s.ret:
		var to: Vector3 = hand - (s.p as Vector3)
		var d := to.length()
		var sp: float = P.speed * rk * 1.4
		if d < maxf(sp * dt, float(s.r)):
			s.p = hand
			s.caught = true
			return
		s.v = to / d * sp
		s.p += (s.v as Vector3) * dt
		return
	s.v.y -= REAL_G * rk * float(P.grav) * dt
	s.p += (s.v as Vector3) * dt
	if s.t >= float(P.life):
		s.ret = true


## The trail a shot leaves.
func _trail(s: Dictionary, k: float, dt: float) -> void:
	var p: Vector3 = s.p
	var v: Vector3 = s.v
	match String(s.kind):
		"bolt":
			if rnd() < 0.5:
				_spark(p, -v * 0.02 + Vector3(rnd() - 0.5, rnd() - 0.5, rnd() - 0.5) * 0.2 * k, 0.16, Color("ffe9a8"), 0.006 * k, true)
		"firework":
			# Gold glitter and orange embers.
			for i in 2:
				var c := Color("ffd76a") if i == 0 else Color("ff8a3c")
				_spark(p, -v * 0.06 + Vector3(rnd() - 0.5, rnd() - 0.5, rnd() - 0.5) * 0.4 * k, 0.3 + rnd() * 0.2,
					c if rnd() < 0.85 else Color("fffaf2"), (0.005 + rnd() * 0.004) * k)
		"confetti":
			if rnd() < 0.7:
				_spark(p, -v * 0.03 + Vector3(rnd() - 0.5, rnd() * 0.3, rnd() - 0.5) * 0.4 * k, 0.6 + rnd() * 0.3,
					Color(CONFETTI_COLS[_rng.randi() % CONFETTI_COLS.size()]), (0.01 + rnd() * 0.006) * k, false, true)
		"rocket":
			_spark(p - v.normalized() * 0.07 * k, -v * 0.05, 0.12, Color("ffcf6a"), 0.02 * k, true)
			if rnd() < 0.7:
				_spark(p - v.normalized() * 0.08 * k, Vector3(rnd() - 0.5, rnd() * 0.5, rnd() - 0.5) * 0.25 * k, 0.6 + rnd() * 0.3,
					Color("bdb8b0"), (0.012 + rnd() * 0.01) * k, true)
		"glob":
			if rnd() < 0.25:
				_spark(p, v * 0.2, 0.4, Color("3fb4ff"), 0.008 * k)
		"boomerang":
			if rnd() < 0.35:
				_spark(p, Vector3.ZERO, 0.22, Color(1, 1, 1, 0.6), 0.008 * k, true)
		"dallah":
			# It sprays coffee beans as it spins, with a wisp of steam.
			s.spray_t -= dt
			if s.spray_t <= 0.0:
				s.spray_t = SHOT_STYLE.dallah.spray
				var d := cone_dir(((s.side as Vector3).rotated(Vector3.UP, float(s.spin)) * 0.6 + v.normalized()).normalized(), 0.5, rnd() * TAU)
				var b := _add_shot("bean", SHOT_STYLE.bean, p, d, k, 0)
				if not b.is_empty():
					b.v += v * 0.5
			if rnd() < 0.3:
				_spark(p + Vector3.UP * 0.06 * k, Vector3(0, 0.4, 0) * k, 0.5, Color(1, 1, 1, 0.5), 0.012 * k, true)
		"hose":
			if rnd() < 0.2:
				_spark(p, v * 0.1 + Vector3(rnd() - 0.5, rnd() - 0.5, rnd() - 0.5) * 0.2 * k, 0.25, Color(0.8, 0.93, 1.0, 0.5), 0.006 * k, true)
		"blackhole":
			if s.parked:
				_linger(s, SHOT_STYLE.blackhole, dt, k)
			elif rnd() < 0.6:
				var a := rnd() * TAU
				_spark(p + Vector3(cos(a), 0.0, sin(a)) * 0.07 * k, Vector3(-sin(a), 0.0, cos(a)) * 0.4 * k, 0.3,
					Color(VOID_COLS[_rng.randi() % VOID_COLS.size()]), 0.006 * k, true)
		"bakhoor":
			if s.parked:
				_linger(s, SHOT_STYLE.bakhoor, dt, k)
			elif rnd() < 0.5:
				_spark(p + Vector3.UP * 0.03 * k, Vector3(rnd() - 0.5, 1.0, rnd() - 0.5) * 0.2 * k, 0.8, Color(0.85, 0.83, 0.8, 0.35),
					0.016 * k, true, false, 1.5)
		"magnet":
			if s.parked:
				_linger(s, SHOT_STYLE.magnet, dt, k)
		"cluster":
			# The fuse fizzes.
			var nd := s.node as Node3D
			var spin := nd.get_node_or_null("Spin") as Node3D if nd else null
			var fire := spin.get_node_or_null("Fire") as Node3D if spin else null
			if fire and rnd() < 0.8:
				_spark(nd.transform * spin.transform * fire.position, Vector3(rnd() - 0.5, rnd() + 0.2, rnd() - 0.5) * 0.6 * k, 0.2,
					Color("ffd34d") if rnd() < 0.6 else Color("fff4d6"), 0.004 * k, true)
		"falcon":
			if s.dove and rnd() < 0.4:
				_spark(p, -v * 0.03, 0.18, Color(1, 1, 1, 0.45), 0.006 * k, true)
		"shield":
			_shield_step(s, SHOT_STYLE.shield, dt, k)


## A shot popped `n` soft targets along its way: does it stop?
func _on_pop(s: Dictionary, P: Dictionary, n: int) -> bool:
	match String(s.kind):
		"mini":
			s.v *= 0.6
			return false
		"bouncy":
			s.pops += n
			s.v *= 0.85
			_ch("bouncy3", int(s.pops))
			return s.pops >= int(P.pops)
		"boomerang":
			s.pops += n
			return false
		"dallah":
			return false
		"falcon":
			# Got it: back to the glove.
			s.ret = true
			s.target = {}
			return false
		"lasso":
			if (s.hold as Dictionary).is_empty():
				s.ret = true  # no blaster_pull: it was a hit; the rope comes back
			return false
		"blackhole", "magnet", "bakhoor":
			return false
	return true


## A shot meets something solid (took: a stage target took it): does it stop?
func _on_solid(s: Dictionary, P: Dictionary, point: Vector3, n: Vector3, took: bool) -> bool:
	var R: float = s.r
	match String(s.kind):
		"mini":
			if took:
				return true
			s.p = point + n * R
			var vn: float = (s.v as Vector3).dot(n)
			if vn < 0.0:
				s.v -= n * 1.5 * vn
			return false
		"bouncy":
			s.p = point + n * R
			var vn: float = (s.v as Vector3).dot(n)
			if vn < 0.0:
				s.v -= n * 1.8 * vn
			s.bounces += 1
			if took:
				s.pops += 1
				_ch("bouncy3", int(s.pops))
			_sfx("bricks_tink", clampf((s.v as Vector3).length() / (15.0 * float(s.k)), 0.0, 1.0), s.p)
			return s.bounces > int(P.bounces) or s.pops >= int(P.pops)
		"boomerang":
			if not took:
				s.ret = true
				s.p = point + n * R
			return false
		"falcon", "lasso":
			s.ret = true
			s.hold = {}
			s.p = point + n * R
			return false
		"blackhole", "magnet":
			s.p = point + n * R
			_park(s, P)
			return false
		"bakhoor":
			s.p = point + n * R
			if n.y > 0.5:
				_park(s, P)
			else:
				# Off a wall: it drops on down, its throw mostly spent.
				var vn: float = (s.v as Vector3).dot(n)
				if vn < 0.0:
					s.v = ((s.v as Vector3) - n * 2.0 * vn) * 0.3
			return false
	s.p = point
	s.n = n
	return true


## A boomerang's pose: it faces along its flight, leans into the curve it is turning (from its
## sideways acceleration; thrown on edge, it lies down flatter as it comes back) and spins
## flat in its own plane.
func _boomerang_pose(s: Dictionary, nd: Node3D, dt: float) -> void:
	var tilt := nd.get_node_or_null("Tilt") as Node3D
	var sp := nd.get_node_or_null("Tilt/Spin") as Node3D
	if tilt == null or sp == null:
		return
	var v: Vector3 = s.v
	var hv := Vector3(v.x, 0.0, v.z)
	if hv.length_squared() > 1e-10 and dt > 0.0:
		var f := hv.normalized()
		var right := f.cross(Vector3.UP)
		var lat := ((v - (s.pv as Vector3)) / dt).dot(right) / maxf(1e-3, float(s.k))
		var life := float(SHOT_STYLE.boomerang.life)
		var lean := lerpf(0.9, 0.25, clampf(float(s.t) / life, 0.0, 1.0))
		var want := clampf(-lat * 0.03, -lean, lean)
		s.bank = lerpf(float(s.bank), want, 1.0 - exp(-10.0 * dt))
		tilt.basis = Basis.looking_at(f, Vector3.UP) * Basis(Vector3.FORWARD, float(s.bank)) * Basis(Vector3.RIGHT, 0.1)
	s.pv = v
	sp.rotation = Vector3(0.0, float(s.spin), 0.0)


## A shot of PARKS stops where it is and stays `linger` seconds: the black hole opens, the
## bakhoor sets down (upright, on the floor or what it landed on) and smokes, the magnet hangs.
func _park(s: Dictionary, P: Dictionary) -> void:
	if s.parked:
		return
	s.parked = true
	s.v = Vector3.ZERO
	s.life_end = float(s.t) + float(P.linger)
	s.spray_t = 0.0
	s.tick = 0.0
	match String(s.kind):
		"bakhoor":
			_sfx("ember", 0.9, s.p)
			_sfx("thump", 0.25, s.p)
			impact(s.p, Vector3.UP, Color("ffb35c"))
		"blackhole":
			_spark(s.p, Vector3.ZERO, 0.15, Color("c4b5fd"), 0.08 * float(s.k), true)
		"magnet":
			_sfx("zing", 0.6, s.p)


## A parked shot's work each step. The black hole pulls the soft targets within `field` toward
## it (host.blaster_pull, faster nearer the core) in a violet swirl; the bakhoor's smoke rises
## and curls with embers, and slows what is in its cloud (host.blaster_slow); the magnet pulls
## metal soft targets ("metal": true) and the host's projectiles (blaster_threats; "metal":
## false spares one) toward it, stops those that reach it (blaster_block), and bends the kit's
## own metal-ish shots (MAGNET_PULLS) its way.
func _linger(s: Dictionary, P: Dictionary, dt: float, k: float) -> void:
	var rk := reach_k()
	var c: Vector3 = s.p
	match String(s.kind):
		"blackhole":
			var F: float = float(P.field) * rk
			for t in targets():
				if t.kind != "t":
					continue
				var d := (t.p as Vector3).distance_to(c)
				if d > F or d < 1e-4:
					continue
				_pull(t, c, float(P.tug) * rk * dt * (2.0 - d / F))
				if rnd() < 0.3:
					_spark(t.p, (c - (t.p as Vector3)).normalized() * 1.5 * k, 0.25, Color(VOID_COLS[0]), 0.006 * k, true)
			for i in 3:
				# The swirl: sparks spiralling in, in the disk's plane.
				var a := rnd() * TAU
				var rr := (0.15 + rnd() * 0.45) * float(P.field) * k
				var out := Vector3(cos(a), (rnd() - 0.5) * 0.15, sin(a))
				var tang := Vector3(-sin(a), 0.0, cos(a))
				_spark(c + out * rr, (tang * 1.6 - out * 1.1) * rr * 1.2, 0.45 + rnd() * 0.25,
					Color(VOID_COLS[_rng.randi() % VOID_COLS.size()]), (0.005 + rnd() * 0.006) * k, true)
		"bakhoor":
			s.spray_t -= dt
			var top := c + Vector3.UP * 0.03 * k
			if s.spray_t <= 0.0:
				s.spray_t = 0.06
				var a := rnd() * TAU
				var off := Vector3(cos(a), 0.0, sin(a)) * rnd() * 0.05 * k
				var drift := Vector3(cos(a), 0.0, sin(a)) * (0.1 + rnd() * 0.25) * float(P.cloud) * k
				var grey := 0.78 + rnd() * 0.14
				_spark(top + off, drift + Vector3.UP * (0.22 + rnd() * 0.2) * k, 1.8 + rnd() * 0.8,
					Color(grey, grey * 0.98, grey * 0.95, 0.28), (0.035 + rnd() * 0.03) * k, true, false, 2.2, (rnd() - 0.5) * 3.0)
			if rnd() < 0.3:
				_spark(top, Vector3(rnd() - 0.5, 1.2 + rnd(), rnd() - 0.5) * 0.35 * k, 0.5 + rnd() * 0.4,
					Color("ff8a3c") if rnd() < 0.6 else Color("ffc46b"), (0.003 + rnd() * 0.003) * k)
			s.tick -= dt
			if s.tick <= 0.0:
				s.tick = Catalog.BAKHOOR_TICK
				if _has("blaster_slow"):
					var mid := c + Vector3.UP * float(P.cloud) * 0.5 * rk
					for t in targets():
						if t.kind == "t" and (t.p as Vector3).distance_to(mid) < float(P.cloud) * rk + float(t.r):
							host.blaster_slow(t.src, float(P.slow), Catalog.BAKHOOR_HOLD)
		"magnet":
			var F: float = float(P.field) * rk
			var tug: float = float(P.tug) * rk
			for t in targets():
				if t.kind == "t" and bool((t.src as Dictionary).get("metal", false)):
					var d := (t.p as Vector3).distance_to(c)
					if d < F and d > 1e-4:
						_pull(t, c, tug * dt)
			for th: Dictionary in threats():
				if not bool(th.get("metal", true)):
					continue
				var tp: Vector3 = th.p
				var d := tp.distance_to(c)
				var key: Variant = _key(th)
				if d < float(s.r) + float(th.get("r", 0.02 * k)):
					if not _recent(s.soft, key, float(s.t)):
						s.soft[key] = s.t
						_block(th, tp, "magnet")
						_sfx("cans_clang", 0.5, tp)
						impact(tp, (tp - c).normalized(), Color("d8dde3"))
				elif d < F and _has("blaster_pull"):
					host.blaster_pull(th, c, tug * dt)
			for o: Dictionary in shots:
				if o.kind in Catalog.MAGNET_PULLS and not o.parked:
					var to: Vector3 = c - (o.p as Vector3)
					var d := to.length()
					if d < F and d > 1e-4:
						o.v += to / d * tug * Catalog.MAGNET_BEND * dt
			if rnd() < 0.5:
				# The field: red and silver motes that circle the poles.
				var a := rnd() * TAU
				var out := Vector3(cos(a), sin(a), 0.0).rotated(Vector3.UP, float(s.spin))
				_spark(c + out * 0.08 * k, out.cross(Vector3.UP).normalized() * 0.25 * k - out * 0.2 * k, 0.4,
					Color("ff6b6b") if rnd() < 0.5 else Color("e6eef5"), 0.004 * k, true)


## The shield each step: every projectile the host reports (blaster_threats) that reaches the
## bubble is stopped (blaster_block) with a ripple and a "bwong"; the bubble flashes.
func _shield_step(s: Dictionary, P: Dictionary, dt: float, k: float) -> void:
	var c: Vector3 = s.p
	var R: float = s.r
	for th: Dictionary in threats():
		var tp: Vector3 = th.p
		var key: Variant = _key(th)
		if tp.distance_to(c) < R + float(th.get("r", 0.02 * k)) and not _recent(s.soft, key, float(s.t)):
			s.soft[key] = s.t
			var n := (tp - c).normalized() if tp.distance_to(c) > 1e-5 else -(s.dir as Vector3)
			var at := c + n * R
			_block(th, at, "shield")
			s.flash = 1.0
			_sfx("shield_block", 0.9, at)
			_buzz(String(s.hand), 0.4, 30)
			for i in 12:
				# A ring of light running round the bubble from where it was struck.
				var a := i * TAU / 12.0
				var u := n.cross(Vector3.UP if absf(n.y) < 0.9 else Vector3.RIGHT).normalized()
				var w := n.cross(u)
				_spark(at, (u * cos(a) + w * sin(a)) * 0.9 * k, 0.3, Color("bff4ff") if i % 2 else Color("6fe0ff"), 0.008 * k, true)
	s.flash = maxf(0.0, float(s.flash) - dt * 3.0)
	var mi := (s.node as Node3D).get_node_or_null("Bubble") as MeshInstance3D if s.node else null
	if mi:
		var m := mi.material_override as ShaderMaterial
		var life: float = float(P.life)
		var t: float = s.t
		m.set_shader_parameter("flash", float(s.flash))
		m.set_shader_parameter("fade", clampf(t / 0.15, 0.0, 1.0) * clampf((life - t) / 0.3, 0.0, 1.0))
		# It wobbles a little as it opens and when struck.
		var wob := sin(t * 20.0) * (0.06 * exp(-t * 6.0) + 0.04 * float(s.flash))
		mi.scale = Vector3(1.0 + wob, 1.0 - wob, 1.0 + wob) * R / maxf(1e-6, (s.node as Node3D).scale.x)


## A shot reaches a soft target: most hit it (_hit_soft). With the host's blaster_pull, a lasso
## catches it instead (and holds on); with blaster_push (or blaster_pull) a hose drop pushes it on; a shield touches nothing; a
## parked bakhoor is only smoke.
func _touch_soft(s: Dictionary, t: Dictionary, dir: Vector3) -> bool:
	match String(s.kind):
		"shield":
			return false
		"bakhoor":
			if s.parked:
				return false
		"lasso":
			if not (s.hold as Dictionary).is_empty() or s.ret:
				return false
			if _has("blaster_pull"):
				s.hold = t
				s.hold_t = 0.0
				s.life_end = float(s.t) + float(SHOT_STYLE.lasso.drag) + 2.0
				_sfx("snap", 1.0, t.p)
				_buzz(String(s.hand), 0.4, 30)
				_spark(t.p, Vector3.ZERO, 0.08, Color("fffaf2"), 0.04 * float(s.k), true)
				shot_hit.emit("lasso", t.src)
				return true
		"hose":
			if _has("blaster_push") or _has("blaster_pull"):
				var d := dir if dir.length_squared() > 1e-8 else (s.dir as Vector3)
				if _has("blaster_push"):
					host.blaster_push(t.src, d * float(SHOT_STYLE.hose.push) * reach_k())
				else:
					_pull(t, (t.p as Vector3) + d * reach_k(), float(SHOT_STYLE.hose.shove) * reach_k())
				_droplets(s.p, -d, 4)
				_dallah_sfx("splash", 0.25, s.p, Catalog.HOSE_HISS_GAP)
				shot_hit.emit("hose", t.src)
				return true
	return _hit_soft(t, dir, String(s.kind))


## Dates break into crumbs where they hit: a few flat brown bits that tumble down.
func crumble(p: Vector3, n: Vector3) -> void:
	var k := blast_k()
	for i in 9:
		var d := (Vector3(rnd() - 0.5, rnd() - 0.2, rnd() - 0.5).normalized() + n * 0.8).normalized() * ((0.5 + rnd() * 1.0) * k)
		_spark(p, d, 0.5 + rnd() * 0.4, Color(CRUMB_COLS[_rng.randi() % CRUMB_COLS.size()]), (0.005 + rnd() * 0.005) * k, false, i % 3 != 0)


## A hose drop's little splash (no sound: the stream's hiss covers it).
func _droplets(p: Vector3, n: Vector3, count: int) -> void:
	var k := blast_k()
	for i in count:
		var d := (Vector3(rnd() - 0.5, rnd() - 0.5, rnd() - 0.5).normalized() + n).normalized() * ((0.4 + rnd() * 0.8) * k)
		_spark(p, d, 0.25 + rnd() * 0.15, Color(HOSE_COLS[i % HOSE_COLS.size()]), (0.004 + rnd() * 0.004) * k)


## The black hole closes: a dark flash, a ring of violet sparks thrown out and a deep "whoomp".
func implode(p: Vector3, burst_r: float) -> void:
	var k := blast_k()
	_spark(p, Vector3.ZERO, 0.18, Color("e9d5ff"), 0.1 * k, true)
	_spark(p, Vector3.ZERO, 0.3, Color(0.1, 0.0, 0.2, 0.8), 0.06 * k, true)
	for i in 30:
		var a := i * TAU / 30.0 + rnd() * 0.2
		var d := Vector3(cos(a), (rnd() - 0.5) * 0.3, sin(a)) * (burst_r / 0.35 + rnd()) * k
		_spark(p, d, 0.4 + rnd() * 0.25, Color(VOID_COLS[i % VOID_COLS.size()]), (0.008 + rnd() * 0.008) * k, true)
	_sfx("whoomp", 1.0, p)


## A bomblet goes off: a flash and a small bloom in its own colour.
func bomblet_pop(p: Vector3, color: Color) -> void:
	var k := blast_k()
	_spark(p, Vector3.ZERO, 0.08, Color("fffaf2"), 0.05 * k, true)
	for i in 12:
		var d := Vector3(rnd() - 0.5, rnd() - 0.3, rnd() - 0.5).normalized() * ((0.8 + rnd() * 1.0) * k)
		_spark(p, d, 0.3 + rnd() * 0.2, color if i % 3 else Color("fff2c2"), (0.008 + rnd() * 0.006) * k)
	_dallah_sfx("cluster_pop", float(SHOT_STYLE.bomblet.sk), p, Catalog.BOMBLET_POP_GAP)


## Ends a shot: a firework blooms, a rocket blows up, a glob splats, a dallah spills.
func _finish(s: Dictionary, P: Dictionary, k: float) -> void:
	match String(s.kind):
		"firework":
			_credit("firework", pop_radius(s.p, P.burst * k, "firework"))
			bloom(s.p)
		"rocket":
			_credit("rocket", pop_radius(s.p, P.burst * k, "rocket"))
			explosion(s.p)
		"glob":
			var n: Vector3 = s.n
			pop_radius(s.p, P.splat * k, "glob")
			splat(s.p, n)  # a burst of water drops, no puddle left behind (owner's call)
		"dallah":
			for i in 6:
				var d := cone_dir(Vector3.UP, 1.1, i * TAU / 6.0)
				_add_shot("bean", SHOT_STYLE.bean, s.p, d, k, i)
			impact(s.p, Vector3.UP, Color("dcaa48"))
			_dallah_sfx("fair_ding", DALLAH_SPILL_K, s.p)
		"boomerang":
			if s.caught:
				_sfx("thump", 0.25, s.p)
				_buzz(String(s.hand), 0.35, 30)
				# Back in the hand after hitting something: toward boomerang3.
				if int(s.pops) > 0 or not (s.hits as Dictionary).is_empty():
					_ch("boomerang3", 1)
		"falcon":
			if s.caught:
				_sfx("flap", 0.5, s.p)
				_buzz(String(s.hand), 0.35, 40)
		"lasso":
			if s.caught:
				_sfx("thump", 0.25, s.p)
				_buzz(String(s.hand), 0.25, 25)
		"blackhole":
			_credit("blackhole", pop_radius(s.p, P.burst * k, "blackhole"))
			implode(s.p, float(P.burst))
		"bakhoor":
			# The last of its smoke as it burns out.
			for i in 6:
				_spark(s.p + Vector3.UP * 0.04 * k, Vector3(rnd() - 0.5, 1.0, rnd() - 0.5) * 0.25 * k, 1.2, Color(0.85, 0.83, 0.8, 0.25),
					0.04 * k, true, false, 2.0, 1.0)
		"magnet":
			impact(s.p, Vector3.UP, Color("e6eef5"))
			_sfx("thump", 0.25, s.p)
		"dates":
			if float(s.t) <= float(P.life):
				crumble(s.p, s.n)
		"hose":
			if float(s.t) <= float(P.life):
				_droplets(s.p, s.n, 5)
		"cluster":
			# It bursts into its bomblets, thrown out and up every way round.
			_spark(s.p, Vector3.ZERO, 0.1, Color("fff2c2"), 0.06 * k, true)
			_sfx("start_pop", 0.8, s.p)
			for i in int(P.pellets):
				var d := cone_dir(Vector3.UP, 0.9 + 0.5 * rnd(), i * TAU / float(P.pellets) + rnd() * 0.4)
				var b := _add_shot("bomblet", SHOT_STYLE.bomblet, s.p, d, k, i)
				if not b.is_empty():
					b.v += (s.v as Vector3) * 0.35
		"bomblet":
			_credit("bomblet", pop_radius(s.p, P.burst * k, "bomblet"))
			bomblet_pop(s.p, s.color)
		"shield":
			_sfx("start_pop", 0.6, s.p)
			for i in 16:
				var d := Vector3(rnd() - 0.5, rnd() - 0.5, rnd() - 0.5).normalized()
				_spark((s.p as Vector3) + d * float(s.r), d * 0.4 * k, 0.35, Color("bff4ff"), 0.007 * k, true)


## The shots that do something when they end (_finish), whatever ended them.
const FINISHES := ["firework", "rocket", "glob", "dallah", "blackhole", "bakhoor", "magnet", "dates", "hose", "cluster", "bomblet", "shield"]


## How the v1.2 shots' models move as they fly: the falcon beats its wings (folds them to
## stoop, glides home) and drops its hood; the bakhoor tumbles, then stands and glows; the
## black hole's disk swirls and it swells, then shrinks just before it closes; a date tumbles
## along its flight; the lasso's loop spins open, then cinches round what it caught; the
## cluster bomb rolls; the magnet points its poles ahead, then hangs and turns.
func _pose(s: Dictionary, P: Dictionary, nd: Node3D, dt: float) -> void:
	var v: Vector3 = s.v
	var t: float = s.t
	var keep := nd.basis.get_scale()
	var up := Vector3.UP if absf(v.normalized().y) < 0.999 else Vector3.RIGHT
	match String(s.kind):
		"falcon":
			if v.length_squared() > 1e-10:
				nd.basis = Basis.looking_at(v.normalized(), up).scaled(keep)
			var amp := 0.0 if s.dove else (0.45 if s.ret else 0.75)
			var ph := t * Catalog.FALCON_FLAP * (0.75 if s.ret else 1.0)
			for side: String in ["L", "R"]:
				var w := nd.get_node_or_null("Bird/Wing" + side) as Node3D
				if w == null:
					continue
				var sx := -1.0 if side == "L" else 1.0
				var tip := w.get_node_or_null("Tip") as Node3D
				if s.dove:
					# Stooping: the wings half folded, swept back along the body.
					w.rotation = Vector3(0.0, sx * 0.9, sx * 0.25)
					if tip:
						tip.rotation = Vector3(0.0, sx * 0.6, 0.0)
				else:
					w.rotation = Vector3(0.0, sx * 0.1, sx * sin(ph) * amp)
					if tip:
						tip.rotation = Vector3(0.0, 0.0, sx * sin(ph - 0.7) * amp * 0.6)
			var hood := nd.get_node_or_null("Bird/Hood") as Node3D
			if hood and t > 0.12:
				_drop_prop(nd, hood, v * 0.3 + Vector3.UP * 1.2 * float(s.k))
		"bakhoor":
			var sp := nd.get_node_or_null("Spin") as Node3D
			if sp:
				sp.rotation = Vector3.ZERO if s.parked else Vector3(float(s.spin) * 3.0, 0.0, float(s.spin) * 2.0)
			var gl := nd.get_node_or_null("Spin/Glow") as Node3D
			if gl:
				gl.scale = Vector3(1.4, 0.45, 1.4) * (0.85 + 0.3 * rnd())
		"blackhole":
			var disk := nd.get_node_or_null("Hole/Disk") as Node3D
			if disk:
				disk.rotate_object_local(Vector3.UP, dt * 7.0)
			var hole := nd.get_node_or_null("Hole") as Node3D
			if hole and s.parked:
				var left := float(s.life_end) - t
				var grow := 1.0 + 0.6 * clampf((t - (float(s.life_end) - float(P.linger))) / 0.4, 0.0, 1.0)
				hole.scale = Vector3.ONE * grow * clampf(left / 0.25, 0.2, 1.0) * (1.0 + sin(t * 25.0) * 0.03)
		"dates":
			if v.length_squared() > 1e-10:
				nd.basis = (Basis.looking_at(v.normalized(), up) * Basis(Vector3.FORWARD, float(s.spin) * 6.0)).scaled(keep)
		"lasso":
			var loop := nd.get_node_or_null("Loop") as Node3D
			if loop:
				if not (s.hold as Dictionary).is_empty():
					var r := float((s.hold as Dictionary).get("r", TARGET_R)) * 1.08 / maxf(1e-6, 0.068 * float(s.k))
					loop.scale = loop.scale.lerp(Vector3(r, 1.0, r), 1.0 - exp(-12.0 * dt))
					loop.rotation = Vector3.ZERO
				else:
					loop.scale = loop.scale.lerp(Vector3.ONE * (0.6 if s.ret else 1.0), 1.0 - exp(-8.0 * dt))
					loop.rotation = Vector3(0.35, float(s.spin) * 8.0, 0.0)
		"cluster":
			var sp := nd.get_node_or_null("Spin") as Node3D
			if sp:
				sp.rotation = Vector3(float(s.spin) * 2.0, 0.0, float(s.spin) * 1.2)
			var fire := nd.get_node_or_null("Spin/Fire") as Node3D
			if fire:
				fire.scale = Vector3.ONE * (0.7 + rnd() * 0.7)
		"magnet":
			var sp := nd.get_node_or_null("Spin") as Node3D
			if s.parked:
				nd.position = (s.p as Vector3) + Vector3.UP * sin(t * 3.0) * 0.01 * float(s.k)
				if sp:
					sp.rotation = Vector3(0.0, float(s.spin) * 2.0, 0.0)
			elif (s.dir as Vector3).length_squared() > 0.0:
				nd.basis = Basis.looking_at(s.dir, Vector3.UP if absf((s.dir as Vector3).y) < 0.999 else Vector3.RIGHT).scaled(keep)


## A part comes off a shot's model (the falcon's hood) and falls on its own for a moment.
func _drop_prop(owner_node: Node3D, part: Node3D, v: Vector3) -> void:
	var xf := Transform3D()
	var n: Node = part
	while n != null and n != self:
		xf = (n as Node3D).transform * xf
		n = n.get_parent()
	part.get_parent().remove_child(part)
	if props.size() >= PROPS_MAX:
		var old: Dictionary = props.pop_front()
		(old.node as Node3D).queue_free()
	part.transform = xf
	add_child(part)
	props.append({"node": part, "p": xf.origin, "v": v, "t": 0.0, "max": 0.9,
		"axis": Vector3(rnd() - 0.5, rnd() - 0.5, rnd() - 0.5).normalized()})


## Skips what a shot hit less than 0.3 s ago (a boomerang hits a target once on the way out
## and once back; a sturdy soft target is not hit every frame).
static func _recent(hits: Dictionary, key: Variant, t: float) -> bool:
	for h: Variant in hits.keys():
		if _same(h, key) and t - float(hits[h]) < 0.3:
			return true
	return false


func step_blast(dt: float) -> void:
	clock += dt
	var k := blast_k()
	if shots.is_empty() and sparks.is_empty() and arcs.is_empty() and props.is_empty() and auras.is_empty():
		_spark_mm.visible_instance_count = 0
		_beam_mm.visible_instance_count = 0
		_draw_shots()
		return
	var hk := reach_k()
	var G := REAL_G * k
	var stage_now := current_stage()
	var i := shots.size() - 1
	while i >= 0:
		if i >= shots.size():
			i = shots.size() - 1
			continue
		var s: Dictionary = shots[i]
		var P: Dictionary = SHOT_STYLE[s.kind]
		# The world was zoomed since the last step: the shot keeps its size and speed in it.
		if absf(float(s.k) - k) > 1e-6:
			var ratio: float = k / float(s.k)
			s.v *= ratio
			s.r *= ratio
			s.k = k
			if s.node:
				(s.node as Node3D).scale *= ratio
		var R: float = s.r
		s.t += dt
		s.spin += dt * (9.0 if s.kind == "mini" else (BOOMERANG_SPIN if s.kind == "boomerang" else (14.0 if s.kind == "dallah" else 1.2)))
		s.flash = float(s.flash)  # (the shield's)
		var a: Vector3 = s.p
		_move(s, P, dt, k)
		var seg: Vector3 = s.p - a
		var len := seg.length()
		var dir_n := seg / len if len > 0.0 else seg
		var near_seg := func(p: Vector3, rr: float) -> bool:
			var t := clampf((p - a).dot(seg) / (len * len if len > 0.0 else 1.0), 0.0, 1.0)
			return (a + seg * t).distance_to(p) < rr + R
		var done: bool = s.caught
		var popped_n := 0
		# What meets the world: not a shield (it rides the hand), not a parked shot, not a
		# falcon or a lasso flying home (or a lasso holding on).
		var solid: bool = not (s.kind == "shield" or s.parked or (s.ret and s.kind in ["falcon", "lasso"])
			or not (s.hold as Dictionary).is_empty())
		# Soft targets it reaches pop (or, for some, are caught or pushed: _touch_soft).
		if _has("blaster_targets") and (solid or s.parked):
			for t in targets():
				if t.kind != "t" or _recent(s.soft, t.ref, float(s.t)):
					continue
				if near_seg.call(t.p, float(t.r)) and _touch_soft(s, t, dir_n if len > 0.0 else (s.dir as Vector3)):
					s.soft[t.ref] = s.t
					popped_n += 1
		# A rocket goes off right by its target.
		if s.kind == "rocket" and not done:
			var tp = target_at(s.target)
			if tp != null and (tp as Vector3).distance_to(s.p) < R + float(s.target.get("r", TARGET_R)) * 0.8:
				done = true
		if popped_n > 0:
			_credit(String(s.kind), popped_n)
		if popped_n > 0 and not done:
			done = _on_pop(s, P, popped_n)
		# The stage: the first visible thing along the way.
		if not done and solid and stage_now and stage_now.is_visible_in_tree() and len > 0.0:
			# A boomerang going through a target hits it once on the way out and once back.
			var skip: Array = []
			for node in (s.hits as Dictionary).keys():
				if is_instance_valid(node) and float(s.t) - float(s.hits[node]) < 0.3:
					skip.append(node)
			var hit := ray_stage(stage_now, a, dir_n, len + R, skip)
			if not hit.is_empty():
				var n: Vector3 = hit.normal
				var took: bool = stage_now.has_method("shoot") and stage_now.shoot(hit.node, hit.point, dir_n)
				impact(hit.point, n, Color("ffd27a") if took else Color("fffaf2"))
				if took:
					s.hits[hit.node] = s.t
					_credit(String(s.kind), 1)
					shot_hit.emit(String(s.kind), hit.node)
				elif s.kind == "bean":
					_dallah_sfx("thump", 0.25, hit.point, BEAN_THUMP_GAP)
				elif s.kind != "bouncy":
					_sfx("thump", 0.25, hit.point)
				done = _on_solid(s, P, hit.point, n, took)
		# The world's walls (host.blaster_collide: a room's walls and furniture, a level's geometry).
		if not done and solid and _has("blaster_collide"):
			var rh := _collide(s.p, s.v, R, a)
			var hs := _hit_speed(rh, s.v)
			if hs > 0.0:
				if s.kind == "mini" or s.kind == "bouncy":
					s.p = rh.get("p", s.p)
					s.v = (rh.get("v", s.v) as Vector3) * (1.25 if s.kind == "bouncy" else 1.0)
					if hs > 1.5 * hk and s.t - s.tap > 0.15:
						s.tap = s.t
						_sfx("bricks_tink" if s.kind == "bouncy" else "thump", 0.15 if s.kind == "mini" else 0.75, s.p)
						if s.kind == "bouncy":
							s.bounces += 1
							done = s.bounces > int(P.bounces)
				elif s.kind in ["boomerang", "falcon", "lasso"]:
					s.ret = true
				else:
					impact(s.p, -dir_n)
					var hp: Vector3 = rh.get("p", s.p)
					var wn: Vector3 = rh.get("n", (hp - s.p).normalized() if hp.distance_to(s.p) > 1e-6 else -dir_n)
					done = _on_solid(s, P, hp, wn, false)
		# No wall out there: a bouncy ball too far off turns back your way (when the host
		# asks; else it flies on to the horizon).
		if not done and s.kind == "bouncy" and _has("blaster_roam") and bool(host.blaster_roam()):
			var eye := _eye()
			var off := Vector2(s.p.x - eye.x, s.p.z - eye.z)
			var roam: float = BOUNCY_ROAM * hk
			if off.length() > roam and Vector2(s.v.x, s.v.z).dot(off) > 0.0:
				var nrm := off.normalized()
				var fv := Vector2(s.v.x, s.v.z)
				fv -= nrm * 2.0 * fv.dot(nrm)
				s.v.x = fv.x
				s.v.z = fv.y
		# The floor.
		var fy := _floor_y()
		if not done and solid and s.p.y < fy + R:
			match String(s.kind):
				"mini":
					s.p.y = fy + R
					if s.v.y < -0.8 * k:
						s.v.y *= -0.45
					else:
						s.v.y = 0.0
					var f := pow(0.55, dt)
					s.v.x *= f
					s.v.z *= f
				"bouncy":
					# It never settles: every bounce at least BOUNCY_HOP high, on along the floor.
					s.p.y = fy + R
					if s.v.y < 0.0:
						var up: float = maxf(-s.v.y * 0.8, BOUNCY_HOP * reach_k())
						_sfx("bricks_tink", clampf(-s.v.y / (8.0 * k), 0.0, 1.0), s.p)
						s.v.y = up
						s.bounces += 1
					var flat := Vector2(s.v.x, s.v.z)
					if flat.length() < BOUNCY_ROLL * reach_k():
						flat = (flat.normalized() if flat.length() > 1e-4 else Vector2(rnd() - 0.5, rnd() - 0.5).normalized()) * BOUNCY_ROLL * reach_k()
						s.v.x = flat.x
						s.v.z = flat.y
				"boomerang", "falcon", "lasso":
					s.p.y = fy + R
					s.ret = true
					s.hold = {}
				"blackhole", "magnet", "bakhoor":
					s.p.y = fy + R
					_park(s, P)
				_:
					s.p.y = fy
					s.n = Vector3.UP
					impact(s.p, Vector3.UP)
					done = true
		if not done:
			_trail(s, k, dt)
		if s.node:
			var nd: Node3D = s.node
			nd.position = s.p
			match String(s.kind):
				"rocket":
					var v: Vector3 = s.v
					if v.length_squared() > 1e-10:
						nd.basis = Basis.looking_at(v.normalized(), Vector3.UP if absf(v.normalized().y) < 0.999 else Vector3.RIGHT).scaled(nd.basis.get_scale())
					var fl := nd.get_node_or_null("Flame") as Node3D
					if fl:
						fl.scale = Vector3.ONE * (0.8 + rnd() * 0.5)
				"boomerang":
					_boomerang_pose(s, nd, dt)
				"dallah":
					var sp := nd.get_node_or_null("Spin") as Node3D
					if sp:
						sp.rotation = Vector3(float(s.spin) * 0.6, 0.4, float(s.spin) * 0.25)
				"glob":
					var bl := nd.get_node_or_null("Blob") as Node3D
					if bl:
						var w := sin(float(s.t) * 18.0) * 0.12
						bl.scale = Vector3(1.0 + w, 1.0 - w, 1.0 + w * 0.5)
				_:
					_pose(s, P, nd, dt)
		# A parked shot (or a lasso holding on) has its own end; the others their life (+2 s
		# to come home).
		var life: float = float(s.life_end) if float(s.life_end) >= 0.0 else float(P.life) + (2.0 if s.ret else 0.0)
		var expired: bool = s.t > life
		if expired and s.kind in PARKS and not s.parked:
			# Its flight is over: it parks where it is and stays.
			_park(s, P)
			expired = false
		if done or expired:
			if s.kind in FINISHES or s.caught:
				_finish(s, P, k)
			if s.kind == "bubble" and not done:
				_sfx("start_pop", 1.0, s.p)
			if s.node:
				s.node.queue_free()
			var at := _index_of(shots, s)
			if at >= 0:
				shots.remove_at(at)
		i -= 1
	_draw_shots()
	var n := 0
	for j in range(sparks.size() - 1, -1, -1):
		var s: Dictionary = sparks[j]
		if absf(float(s.k) - k) > 1e-6:
			var ratio: float = k / float(s.k)
			s.v *= ratio
			s.size *= ratio
			s.k = k
		s.t += dt
		if s.flake:
			# Confetti flutters down slowly.
			s.v.y -= G * 0.25 * dt
			s.v *= pow(0.25, dt)
		elif not s.flash:
			s.v.y -= G * 0.5 * dt
		if float(s.curl) != 0.0:
			s.v = (s.v as Vector3).rotated(Vector3.UP, float(s.curl) * dt)
		s.p += s.v * dt
		if s.t >= s.max:
			sparks.remove_at(j)
	for s in sparks:
		var b := Basis().scaled(Vector3.ONE * s.size * (1.0 + float(s.grow) * s.t / s.max))
		if s.flake:
			b = Basis(s.axis as Vector3, float(s.rot) + float(s.t) * 9.0) * Basis.from_scale(Vector3(s.size, s.size * 0.18, s.size * 0.7))
		_spark_mm.set_instance_transform(n, Transform3D(b, s.p))
		_spark_mm.set_instance_color(n, Color(s.color, (s.color as Color).a * (1.0 - s.t / s.max)))
		n += 1
	# The round shots, drawn with the sparks.
	for s in shots:
		if s.node != null or s.style != "" or n >= SPARKS_MAX + SHOTS_MAX:
			continue
		var c: Color = s.color
		var b := Basis().scaled(Vector3.ONE * float(s.r) * float(s.size))
		var v: Vector3 = s.v
		if s.kind == "hose" and v.length_squared() > 1e-8:
			# The stream's drops stretch out along their flight, so it reads as one jet.
			b = Basis.looking_at(v.normalized(), Vector3.UP if absf(v.normalized().y) < 0.999 else Vector3.RIGHT).scaled(Vector3(1.0, 1.0, 4.5) * float(s.r) * float(s.size))
		_spark_mm.set_instance_transform(n, Transform3D(b, s.p))
		_spark_mm.set_instance_color(n, c)
		n += 1
	# Frost shells over what the freeze ray froze, while it is frozen and still there.
	for j in range(auras.size() - 1, -1, -1):
		var au: Dictionary = auras[j]
		au.t += dt
		if au.t >= au.max or target_at(au.target) == null:
			auras.remove_at(j)
	for au: Dictionary in auras:
		var at: Variant = target_at(au.target)
		if n >= SPARKS_MAX + SHOTS_MAX + AURAS_MAX:
			break
		var f: float = clampf((float(au.max) - float(au.t)) / 0.4, 0.0, 1.0)
		_spark_mm.set_instance_transform(n, Transform3D(Basis().scaled(Vector3.ONE * float(au.r) * 1.12), at))
		_spark_mm.set_instance_color(n, Color(0.75, 0.93, 1.0, 0.38 * f))
		n += 1
		if rnd() < 0.25:
			var d := Vector3(rnd() - 0.5, rnd() - 0.5, rnd() - 0.5).normalized()
			_spark((at as Vector3) + d * float(au.r) * 1.1, Vector3.ZERO, 0.25, Color("f2fdff"), 0.006 * k, true)
	_spark_mm.visible_instance_count = n
	_step_props(dt, k)
	_beam_mm.visible_instance_count = _draw_ropes(_draw_arcs(dt, k), k)


## The bits that fell off shots fall, tumble, rest on the floor and are gone.
func _step_props(dt: float, k: float) -> void:
	var fy := _floor_y()
	for j in range(props.size() - 1, -1, -1):
		var pr: Dictionary = props[j]
		pr.t += dt
		var nd: Node3D = pr.node
		if pr.t >= pr.max or not is_instance_valid(nd):
			if is_instance_valid(nd):
				nd.queue_free()
			props.remove_at(j)
			continue
		pr.v.y -= REAL_G * k * dt
		pr.p += (pr.v as Vector3) * dt
		if pr.p.y < fy:
			pr.p.y = fy
			pr.v = Vector3.ZERO
		else:
			nd.basis = nd.basis.rotated(pr.axis, dt * 9.0)
		nd.position = pr.p


## Each lasso's rope, from its hand to its loop: a sagging line of short beam segments, the
## shemagh's red and white in turn, that pulls taut while it holds something. Returns the next
## free beam (after `n`).
func _draw_ropes(n: int, k: float) -> int:
	for s: Dictionary in shots:
		if s.kind != "lasso":
			continue
		var a := _hand_at(s)
		var b: Vector3 = s.p
		var L := a.distance_to(b)
		var taut := not (s.hold as Dictionary).is_empty()
		var sag := L * (0.03 if taut else 0.12)
		var prev := a
		for j in ROPE_SEGS:
			if n >= BEAM_SEGS_MAX:
				return n
			var f := (j + 1) / float(ROPE_SEGS)
			var q := a.lerp(b, f) + Vector3.DOWN * sag * 4.0 * f * (1.0 - f)
			_beam_mm.set_instance_transform(n, _seg_xf(prev, q, 0.007 * k))
			_beam_mm.set_instance_color(n, Color(SHEMAGH_COLS[j % 2]))
			n += 1
			prev = q
	return n


func clear_blast() -> void:
	for s in shots:
		if s.node:
			s.node.queue_free()
	shots.clear()
	sparks.clear()
	arcs.clear()
	auras.clear()
	for pr: Dictionary in props:
		if is_instance_valid(pr.node):
			(pr.node as Node3D).queue_free()
	props.clear()
	_spark_mm.visible_instance_count = 0
	_beam_mm.visible_instance_count = 0
	_draw_shots()


## Whether a mesh is a picture, not a thing (up to the stage): text (TextMesh, Label3D
## ancestors) and anything in the "blaster_ignore" group or with "blaster_ignore" meta.
static func _ignored(n: Node, stop: Node) -> bool:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh is TextMesh:
		return true
	while n != null and n != stop:
		if n is Label3D or n.is_in_group(&"blaster_ignore") or n.has_meta(&"blaster_ignore"):
			return true
		n = n.get_parent()
	return false


## The first solid stage mesh along a ray (local units): {node, point, normal} or {}.
## Floating texts and "blaster_ignore" meshes (guide lines, nets, decorations) don't stop a
## shot; nor do immediate meshes or the meshes in `exclude` (a beam
## already went through them).
func ray_stage(st: Node3D, from: Vector3, dir: Vector3, far: float, exclude: Array = []) -> Dictionary:
	var best := {}
	var best_d := far
	var to_root: Transform3D = global_transform.affine_inverse()
	for mi in st.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null or not m.is_visible_in_tree() or exclude.has(m):
			continue
		if m.mesh is ImmediateMesh or _ignored(m, st):
			continue
		# Ray into the mesh's space.
		var xf: Transform3D = to_root * m.global_transform
		var inv := xf.affine_inverse()
		var lo := inv * from
		var lend := inv * (from + dir * best_d)
		if not m.mesh.get_aabb().grow(0.001).intersects_segment(lo, lend):
			continue
		var tri: TriangleMesh = _tri_cache.get(m.mesh)
		if tri == null:
			tri = m.mesh.generate_triangle_mesh()
			_tri_cache[m.mesh] = tri
		if tri == null:
			continue
		var r: Dictionary = tri.intersect_segment(lo, lend)
		if r.is_empty():
			continue
		var wp: Vector3 = xf * (r.position as Vector3)
		var d := (wp - from).dot(dir)
		if d >= 0.0 and d < best_d:
			best_d = d
			var nrm: Vector3 = (xf.basis.inverse().transposed() * (r.normal as Vector3)).normalized()
			if nrm.dot(dir) > 0.0:
				nrm = -nrm
			best = {"node": m, "point": wp, "normal": nrm}
	return best
