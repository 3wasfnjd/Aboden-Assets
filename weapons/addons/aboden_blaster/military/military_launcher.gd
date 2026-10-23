class_name AbodenMilitaryLauncher
extends Node3D
## حزمة الأسلحة العسكرية — the military pack's launcher (AB-W-023 ... AB-W-040, the
## weapons of the battleship in «حرب البارجة»): the ballistic missile, the hypersonic glide
## missile, cruise and anti-ship missiles that follow the terrain, artillery, the MLRS
## salvo, the cluster missile that opens in the air, the jet-dropped bunker buster, the
## kamikaze drone and the drone swarm, the strike jet, glide-bomb jet, attack helicopter
## and recon drone that fly a sortie and land back, the anti-air missile that homes on an
## air target, the top-attack anti-tank missile, the torpedo and the nuclear test.
##
## Every position is in this node's local space, in table units (AbodenMilitaryCatalog:
## a miniature war table about 1 unit across). For another scale put the launcher under
## a scaled parent. Several shots fly at once (a pool of MAX_FLIGHTS nodes, nothing is
## allocated per shot). Effects (smoke, fire, splashes, the mushroom cloud) are drawn by
## the launcher's own AbodenMilitaryFx; damage to the world is the host's: it gets the
## impacted signal (and military_hit) with the point, the kind and the radii.
##
## Fire with fire(target, weapon_id); show the aim with aim(target); call step(dt) each
## frame (or leave auto_step on).
##
## The host is any Node passed to setup(host). Every call on it is optional:
##   military_surface(x, z) -> float      height a shot hits at (x, z): ground or water
##                                         surface; -INF where there is nothing (0.0)
##   military_ceiling(x, z) -> float      the highest a shot or smoke may go (open sky)
##   military_water_depth(x, z) -> float  water depth over the ground there (0: dry land)
##   military_launch_point(id) -> Vector3 where a weapon leaves from (the ship's launcher,
##                                         else `origin`)
##   military_roof(x, z) -> float         top of the standing buildings there, -INF where
##                                         none: low flyers climb over them (no buildings)
##   military_air_target(from, aim) -> Variant  what an anti-air missile fired at `aim` goes
##                                         for: a Node3D (followed; lost when freed, hidden
##                                         or out of the tree), a Vector3, or null (nothing
##                                         in the air: it does not fire). Without it, `aim`.
##   military_hit(point, info)            a shot went off (same as the impacted signal)
##   military_scan(point, radius)         the recon drone looks down (same as recon_scan)
##   military_shock(point, r_from, r_to, k)  the nuke's shock wave front moved (shock_wave)
##   military_sfx(name, k, pos)           a sound: launch, boom, thump (the kit's player)
##
## The host's air defence (an enemy SAM site, a CIWS) reads air_shots() and calls
## shoot_down(serial); an aircraft shot down is lost (sortie_lost) and a replacement comes
## aboard LOST_RELOAD s later.

const Catalog := preload("military_catalog.gd")
const Flight := preload("military_flight.gd")
const Fx := preload("military_fx.gd")
const Looks := preload("military_looks.gd")
const BlasterAudio := preload("../blaster_audio.gd")

const G := Catalog.G
const MAX_FLIGHTS := 24          # MLRS salvos and cluster bomblets fly together
const SHALLOW := 0.0015          # water shallower than this: a small shore splash
const SALVO_GAP := 0.09          # s between two rockets of a salvo (when the weapon gives none)
const PREVIEW_DOTS := 56
const SCAN_EVERY := 0.1          # s between two recon_scan reports of a recon drone
const LOST_RELOAD := 25.0        # s until an aircraft shot down is replaced

## A shot left its launcher (salvo rockets and bomblets included: `sub` true for those).
signal launched(id: String, from: Vector3, to: Vector3, sub: bool)
## A shot went off. info: {id, kind ("land" / "water" / "shallow" / "nuke" / "air"), blast_r,
## crater_r, crater_d, ejecta, nuke_r and wave_r (nuke only), armor_r (anti-armour shots:
## armour within it is knocked out), target (kind "air": what the anti-air missile hit)}.
## Craters and broken things are the host's.
signal impacted(point: Vector3, info: Dictionary)
## An aircraft (strike jet, bunker-buster jet, glide-bomb jet, helicopter, recon drone) is
## back on its deck (its weapon id).
signal sortie_landed(id: String)
## An aircraft was shot down (shoot_down): it does not come back; a replacement comes
## aboard LOST_RELOAD s later.
signal sortie_lost(id: String)
## A shot was destroyed in the air by the host (shoot_down) or an anti-air missile lost its
## target and self-destructed (`by_host` false).
signal shot_down(id: String, point: Vector3, by_host: bool)
## The recon drone looks down from `point` (in the air) over a horizontal `radius`, every
## SCAN_EVERY s while it circles: the host decides what it sees there.
signal recon_scan(point: Vector3, radius: float)
## The nuke's shock wave front moved out from r_from to r_to round `point` (k: 0 .. 1 of
## its run): flatten what is in that ring.
signal shock_wave(point: Vector3, r_from: float, r_to: float, k: float)

## The current weapon (used when fire() / aim() get no id).
@export var weapon := "ballistic"
## Run step(delta) from _physics_process. Leave it off when you call step() yourself.
@export var auto_step := true
## Ignore ammo and cooldowns (a sandbox, screenshots).
@export var unlimited := false
## The built-in player's switch (when the host has no military_sfx).
@export var sound_on := true
## Where shots leave from when there is no ship and no military_launch_point.
@export var origin := Vector3(0, 0.05, 0)
## Slow motion: step() runs this much game time per second while slow_motion is on.
@export var slow_factor := 0.2
var slow_motion := false

## An optional launch platform (AbodenMilitaryShip, or any node with
## launch_point(id) -> Vector3 in its parent's space).
var ship: Node3D
var host: Node
var fx: Fx
var audio: BlasterAudio

var flights: Array[Dictionary] = []   # {plan, t, w, slot, trail_acc, tgt, split, sub, serial}
var _pending: Array[Dictionary] = []  # salvo rockets still to go: {delay, origin, tgt, id}
var _pool: Array[Dictionary] = []     # {node, body, glow, glow_mat, id}
var _ammo := {}
var _reload := {}
var _cool := {}
var _out := {}                        # aircraft id -> how many are flying
var _lost: Array[Dictionary] = []     # aircraft shot down: {id, t} (s until the replacement)
var _waves: Array[Dictionary] = []    # nuke shock waves: {p, r0, r1, T, t, cur, dust}
var _serial := 0
var _rng := RandomNumberGenerator.new()
var preview_mm: MultiMesh
var marker: MeshInstance3D
var _mat_aim: StandardMaterial3D
var _mat_lock: StandardMaterial3D

var last_plan := {}
var last_impact := Vector3.INF
var last_impact_kind := ""
var impact_count := 0
var sim_time := 0.0

var flying: bool:
	get:
		return not flights.is_empty() or not _pending.is_empty()
## A nuke's shock wave is still running out.
var shocking: bool:
	get:
		return not _waves.is_empty()


func _init() -> void:
	fx = Fx.new()
	fx.name = "Fx"
	add_child(fx)
	audio = BlasterAudio.new()
	audio.name = "Audio"
	audio.ref_distance = 0.3
	add_child(audio)
	for k in MAX_FLIGHTS:
		_pool.append(_make_slot(k))
	_build_preview()
	_build_marker()
	refill()


func setup(h: Node) -> void:
	host = h
	fx.ceiling = Callable(self, "ceiling") if _has("military_ceiling") else Callable()


func _has(m: String) -> bool:
	return host != null and is_instance_valid(host) and host.has_method(m)


func _physics_process(delta: float) -> void:
	if auto_step:
		step(delta * (slow_factor if slow_motion else 1.0))


# --- the world, through the host ----------------------------------------------------

## The height a shot hits at (x, z); -INF where there is nothing.
func surface(x: float, z: float) -> float:
	return float(host.call("military_surface", x, z)) if _has("military_surface") else 0.0


## The highest a shot may fly at (x, z) (INF: open sky).
func ceiling(x: float, z: float) -> float:
	return float(host.call("military_ceiling", x, z)) if _has("military_ceiling") else INF


func water_depth(x: float, z: float) -> float:
	return float(host.call("military_water_depth", x, z)) if _has("military_water_depth") else 0.0


## Top of the buildings at (x, z) (-INF: none).
func roof(x: float, z: float) -> float:
	return float(host.call("military_roof", x, z)) if _has("military_roof") else -INF


func _ceiling_fn() -> Callable:
	return Callable(self, "ceiling") if _has("military_ceiling") else Callable()


func _roof_fn() -> Callable:
	return Callable(self, "roof") if _has("military_roof") else Callable()


func _water_fn() -> Callable:
	return Callable(self, "water_depth") if _has("military_water_depth") else Callable()


func _plan(w: Dictionary, o: Vector3, tgt: Vector3) -> Dictionary:
	return Flight.plan(w, o, tgt, surface, G, _ceiling_fn(), _roof_fn(), _water_fn())


## Where a weapon leaves from: the host's point, else the ship's launcher, else `origin`.
func launch_point(id := "") -> Vector3:
	var wid := id if id != "" else weapon
	if _has("military_launch_point"):
		return host.call("military_launch_point", wid)
	if ship != null and is_instance_valid(ship) and ship.has_method("launch_point"):
		if ship.get_parent() == self:
			return ship.launch_point(wid)
		if ship.is_inside_tree() and is_inside_tree():
			return to_local(ship.get_parent().to_global(ship.launch_point(wid)))
	return origin


func _sfx(snd: String, k: float, p: Vector3) -> void:
	if _has("military_sfx"):
		host.call("military_sfx", snd, k, p)
		return
	if not sound_on or not audio.is_inside_tree():
		return
	var gp := to_global(p)
	match snd:
		"launch":
			audio.sfx("whoosh", clampf(k, 0.2, 1.0), gp)
		"boom":
			audio.sfx("boom", k, gp)
		"thump":
			audio.sfx("splash", clampf(k, 0.25, 1.0), gp)


# --- ammo -------------------------------------------------------------------------

## Every weapon full and ready (every aircraft aboard).
func refill() -> void:
	for id: String in Catalog.ids():
		_ammo[id] = int(Catalog.WEAPONS[id].ammo)
		_reload[id] = 0.0
		_cool[id] = 0.0
	_out.clear()
	_lost.clear()
	_jets_changed()


func ammo(id: String) -> int:
	return int(_ammo.get(id, 0))


## Seconds until the weapon may fire again (0: ready).
func cooldown_left(id: String) -> float:
	return float(_cool.get(id, 0.0))


func can_fire(id := "") -> bool:
	var wid := id if id != "" else weapon
	if not Catalog.has(wid):
		return false
	return unlimited or (ammo(wid) > 0 and cooldown_left(wid) <= 0.0)


func _step_ammo(dt: float) -> void:
	for id: String in _cool:
		_cool[id] = maxf(0.0, float(_cool[id]) - dt)
		var w: Dictionary = Catalog.WEAPONS[id]
		var full := int(w.ammo)
		var rl := float(w.reload)
		if rl <= 0.0 or ammo(id) >= full:
			_reload[id] = 0.0
			continue
		_reload[id] = float(_reload[id]) + dt
		if float(_reload[id]) >= rl:
			_reload[id] = float(_reload[id]) - rl
			_ammo[id] = ammo(id) + 1


## One aircraft of `id` back aboard (landed, or the replacement of one shot down).
func _aboard(id: String) -> void:
	_ammo[id] = mini(ammo(id) + 1, int(Catalog.WEAPONS[id].ammo))
	_jets_changed()


func _step_lost(dt: float) -> void:
	var i := 0
	while i < _lost.size():
		_lost[i].t = float(_lost[i].t) - dt
		if float(_lost[i].t) <= 0.0:
			_aboard(String(_lost[i].id))
			_lost.remove_at(i)
			continue
		i += 1


func _jets_changed() -> void:
	if ship != null and is_instance_valid(ship) and ship.has_method("set_jets_aboard"):
		ship.set_jets_aboard(ammo("jet"))


# --- aiming -----------------------------------------------------------------------

func plan(tgt: Vector3, id := "", from := Vector3.INF) -> Dictionary:
	var w := Catalog.get_weapon(id if id != "" else weapon)
	var o := from if from != Vector3.INF else launch_point(w.id)
	return _plan(w, o, tgt)


## The trajectory preview (dots from the launcher to the target) and the target ring
## (its size = the blast). `locked` draws the ring red.
func aim(tgt: Vector3, id := "", locked := false, from := Vector3.INF) -> Dictionary:
	var pl := plan(tgt, id, from)
	var n := preview_mm.instance_count
	var T: float = pl.T
	var shown := 0
	for k in n:
		var t := T * float(k) / (n - 1)
		var p := Flight.position_at(pl, t)
		var s := surface(p.x, p.z)
		if t > 0.1 and s > -INF and p.y < s:
			break
		var sc := 1.0 if k % 2 == 0 else 0.6
		preview_mm.set_instance_transform(k, Transform3D(Basis().scaled(Vector3.ONE * sc), p))
		preview_mm.set_instance_color(k, Color(1.0, 0.62, 0.25, 0.9 * (1.0 - 0.6 * float(k) / n)))
		shown += 1
	preview_mm.visible_instance_count = shown
	var w := Catalog.get_weapon(id if id != "" else weapon)
	var r: float = float(w.nuke_r) * 0.5 if bool(w.get("nuke", false)) else Catalog.CRATER_R * maxf(float(w.blast), 0.3)
	if w.has("scan_r"):
		r = float(w.scan_r)
	marker.transform = Transform3D(Basis().scaled(Vector3(r, r, r)), tgt + Vector3(0, 0.0006, 0))
	marker.material_override = _mat_lock if locked else _mat_aim
	marker.visible = true
	return pl


func hide_preview() -> void:
	preview_mm.visible_instance_count = 0
	marker.visible = false


# --- firing -----------------------------------------------------------------------

## Fire weapon `id` (the current one if empty) at `tgt`. False if it is cooling down or
## out of ammo (see can_fire, ammo, cooldown_left), or the id is unknown. The anti-air
## missile goes for the host's military_air_target(from, tgt) (false if that is null),
## else for the point `tgt` itself.
func fire(tgt: Vector3, id := "", from := Vector3.INF) -> bool:
	var wid := id if id != "" else weapon
	if not can_fire(wid):
		return false
	var w := Catalog.get_weapon(wid)
	var o := from if from != Vector3.INF else launch_point(wid)
	var air: Variant = null
	if String(w.arc) == "intercept":
		air = host.call("military_air_target", o, tgt) if _has("military_air_target") else tgt
		if air == null or (typeof(air) == TYPE_OBJECT and not is_instance_valid(air)):
			return false
	if not unlimited:
		_ammo[wid] = ammo(wid) - 1
		_cool[wid] = float(w.cooldown)
		if String(w.arc) == "sortie":
			_out[wid] = int(_out.get(wid, 0)) + 1
			_jets_changed()
	# MLRS, the drone swarm: the rest of the salvo follows one every salvo_gap, scattered round the target
	var gap := float(w.get("salvo_gap", SALVO_GAP))
	for k in range(1, int(w.get("salvo", 1))):
		_pending.append({"delay": k * gap, "origin": o, "tgt": _scatter(tgt, float(w.spread)), "id": wid})
	var f := _launch(w, o, tgt)
	if air != null:
		f.air = air
	return true


## Fire the anti-air missile (or another `intercept` weapon) at an air target: a Node3D it
## follows, or a point. Same checks as fire().
func fire_at_air(target: Variant, id := "aa", from := Vector3.INF) -> bool:
	var wid := id
	if not can_fire(wid) or String(Catalog.WEAPONS[wid].arc) != "intercept" or target == null:
		return false
	var w := Catalog.get_weapon(wid)
	var o := from if from != Vector3.INF else launch_point(wid)
	var tp := _air_pos(target)
	if tp == Vector3.INF:
		return false
	if not unlimited:
		_ammo[wid] = ammo(wid) - 1
		_cool[wid] = float(w.cooldown)
	var f := _launch(w, o, tp)
	f.air = target
	return true


## Where an air target is now, in this node's space (INF when it is gone).
func _air_pos(target: Variant) -> Vector3:
	if typeof(target) == TYPE_VECTOR3:
		return target
	if typeof(target) == TYPE_OBJECT and is_instance_valid(target) and target is Node3D:
		var n: Node3D = target
		if not n.is_inside_tree() or not n.is_visible_in_tree():
			return Vector3.INF
		return to_local(n.global_position) if is_inside_tree() else n.position
	return Vector3.INF


## Everything in the air now, for the host's air defence: [{serial, id, position,
## velocity, sub, aircraft, intercept (the catalogue's hint)}]. Torpedoes are not listed.
func air_shots() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for f in flights:
		var w: Dictionary = f.w
		if String(w.arc) == "torpedo":
			continue
		out.append({"serial": f.serial, "id": String(w.id), "position": (f.slot.node as Node3D).position,
			"velocity": _vel(f), "sub": bool(f.sub), "aircraft": String(w.arc) == "sortie",
			"intercept": float(w.get("intercept", 0.0))})
	return out


## The host's air defence destroys a shot in the air: a burst there, no impact. An aircraft
## shot down is lost (sortie_lost; a replacement comes aboard LOST_RELOAD s later). False
## if there is no such shot.
func shoot_down(serial: int) -> bool:
	for i in flights.size():
		var f: Dictionary = flights[i]
		if int(f.serial) != serial:
			continue
		var w: Dictionary = f.w
		var p: Vector3 = (f.slot.node as Node3D).position
		_end_flight(i)
		fx.air_burst(p, 1.0 if String(w.arc) == "sortie" else 0.6)
		_sfx("boom", 0.3, p)
		if String(w.arc) == "sortie":
			var wid := String(w.id)
			if not unlimited and int(_out.get(wid, 0)) > 0:
				_out[wid] = int(_out[wid]) - 1
				_lost.append({"id": wid, "t": LOST_RELOAD})
			sortie_lost.emit(wid)
		shot_down.emit(String(w.id), p, true)
		return true
	return false


## A point within `r` of `tgt`, on the surface there.
func _scatter(tgt: Vector3, r: float) -> Vector3:
	var a := _rng.randf() * TAU
	var d := sqrt(_rng.randf()) * r
	var p := tgt + Vector3(cos(a) * d, 0.0, sin(a) * d)
	var su := surface(p.x, p.z)
	p.y = su if su > -INF else tgt.y
	return p


func set_seed(s: int) -> void:
	_rng.seed = s
	fx.rng.seed = s


func _launch(w: Dictionary, o: Vector3, tgt: Vector3, sub := false) -> Dictionary:
	var pl := _plan(w, o, tgt)
	if flights.size() >= MAX_FLIGHTS:
		_end_flight(0)
	var slot := _free_slot()
	var node: Node3D = slot.node
	if slot.id != w.id:
		(slot.body as MeshInstance3D).mesh = Looks.body(w)
		(slot.glow as Node3D).position = Vector3(-float(w.length) * 0.55, 0, 0)
		slot.id = w.id
	# the engine glow: not under water, not on a helicopter or the recon drone
	var engine := not sub and String(w.arc) != "torpedo" and not bool(w.get("heli", false)) and not w.has("orbit")
	(slot.glow as Node3D).visible = bool(w.get("glow", false)) or engine
	(slot.glow as Node3D).scale = Vector3.ONE
	(slot.glow_mat as StandardMaterial3D).albedo_color = Color(1.0, 0.75, 0.35)
	node.position = o
	node.visible = true
	_serial += 1
	var f := {"plan": pl, "t": 0.0, "w": w, "slot": slot, "trail_acc": 0.0, "tgt": tgt, "split": false, "sub": sub,
		"serial": _serial, "scan_acc": SCAN_EVERY}
	if String(w.arc) == "intercept":
		f.p = o
		f.v = Vector3(0, float(w.speed) * 0.6, 0)
		f.air = tgt
	flights.append(f)
	_orient(f)
	last_plan = pl
	if not sub:
		if String(w.arc) == "torpedo":
			fx.splash(o, 0.35)
		else:
			fx.muzzle(o, Flight.velocity_at(pl, 0.0).normalized())
		_sfx("launch", 0.6, o)
	launched.emit(String(w.id), o, tgt, sub)
	return f


func _free_slot() -> Dictionary:
	for s in _pool:
		var used := false
		for f in flights:
			if f.slot == s:
				used = true
				break
		if not used:
			return s
	return _pool[0]


func _end_flight(i: int) -> void:
	var f: Dictionary = flights[i]
	(f.slot.node as Node3D).visible = false
	flights.remove_at(i)


## Shots, salvos and smoke gone; ammo stays as it is.
func clear() -> void:
	_pending.clear()
	while not flights.is_empty():
		_end_flight(0)
	if not unlimited:
		for id: String in _out:
			_ammo[id] = mini(ammo(id) + int(_out[id]), int(Catalog.WEAPONS[id].ammo))
		for l in _lost:
			_ammo[l.id] = mini(ammo(l.id) + 1, int(Catalog.WEAPONS[l.id].ammo))
	_out.clear()
	_lost.clear()
	_waves.clear()
	_jets_changed()
	hide_preview()
	fx.clear()


# --- the simulation ---------------------------------------------------------------

## Advance everything by dt seconds of game time.
func step(dt: float) -> void:
	sim_time += dt
	_step_ammo(dt)
	_step_lost(dt)
	var k := 0
	while k < _pending.size():
		var q: Dictionary = _pending[k]
		q.delay -= dt
		if q.delay <= 0.0:
			_pending.remove_at(k)
			_launch(Catalog.get_weapon(q.id), q.origin, q.tgt, true)
			continue
		k += 1
	var steps := maxi(1, int(ceil(dt / (1.0 / 120.0))))
	for _i in steps:
		_step_flights(dt / steps)      # shells need the small step (exact impact points)
	_step_waves(dt)
	var ds := maxi(1, int(ceil(dt / 0.02)))
	for _j in ds:
		fx.step(dt / ds)


func _step_flights(dt: float) -> void:
	var i := 0
	while i < flights.size():
		var f: Dictionary = flights[i]
		if f.has("v"):
			if _step_intercept(i, f, dt):
				i += 1
			continue
		var pl: Dictionary = f.plan
		var t_prev: float = f.t
		var t: float = t_prev + dt
		f.t = t
		var p := Flight.position_at(pl, t)
		if pl.get("sortie", false):
			# an aircraft: bombs / rockets away over the target, then home to the deck
			var fw: Dictionary = f.w
			if not f.split and t >= float(pl.release_t):
				f.split = true
				var bw := Catalog.get_weapon(String(fw.get("bomb", "jetbomb")))
				for _b in int(fw.get("bombs", 0)):
					_launch(bw, p, _scatter(f.tgt, float(fw.spread)), true)
			if t >= float(pl.T):
				var jid: String = fw.id
				_end_flight(i)
				if not unlimited and int(_out.get(jid, 0)) > 0:
					_out[jid] = int(_out[jid]) - 1
					_aboard(jid)
				sortie_landed.emit(jid)
				continue
			(f.slot.node as Node3D).position = p
			_orient(f)
			_trail(f, p, dt)
			# recon: it looks down while it is out over the area
			if fw.has("scan_r") and t > float(pl.T) * 0.12 and t < float(pl.T) * 0.9:
				f.scan_acc = float(f.scan_acc) + dt
				if float(f.scan_acc) >= SCAN_EVERY:
					f.scan_acc = 0.0
					if _has("military_scan"):
						host.call("military_scan", p, float(fw.scan_r))
					recon_scan.emit(p, float(fw.scan_r))
			i += 1
			continue
		var s := surface(p.x, p.z)
		if String(pl.type) in ["cruise", "glide", "torpedo"] and t >= float(pl.T) and s > -INF:
			# the end of a planned path is its target: if the ground there was dug away (a
			# crater the host made) it still goes off there
			var w0: Dictionary = f.w
			var pts: PackedVector3Array = pl.pts
			var pe := pts[pts.size() - 1]
			_end_flight(i)
			_impact(Vector3(pe.x, minf(pe.y, s), pe.z), w0)
			continue
		if String(pl.type) != "torpedo" and t > 0.05 and s > -INF and p.y <= s + 1e-6:
			# bisect the surface crossing for the exact impact point
			var lo := t_prev
			var hi := t
			for _k in 24:
				var mid := (lo + hi) * 0.5
				var q := Flight.position_at(pl, mid)
				var sq := surface(q.x, q.z)
				if sq == -INF or q.y > sq:
					lo = mid
				else:
					hi = mid
			var w: Dictionary = f.w
			_end_flight(i)
			_impact(Flight.position_at(pl, hi), w)
			continue
		if (s == -INF and p.y < -0.02) or t > float(pl.T) + 3.0:
			_end_flight(i)   # missed everything: gone
			continue
		(f.slot.node as Node3D).position = p
		var nsplit := int((f.w as Dictionary).get("split", 0))
		if nsplit > 0 and not f.split and t >= float(pl.T) * Catalog.SPLIT_AT:
			# cluster missile: the case opens, the bomblets fall over the target area
			var aim_p: Vector3 = f.tgt
			var spread: float = f.w.spread
			_end_flight(i)
			fx.splash(p, 0.6)
			for _b in nsplit:
				_launch(Catalog.get_weapon("submunition"), p, _scatter(aim_p, spread), true)
			continue
		_orient(f)
		_trail(f, p, dt)
		i += 1


## The anti-air missile: steers onto its air target (a Node3D's position or a point) at
## `speed`, turning at `turn` /s, under the ceiling; bursts within kill_r of it (an
## impact of kind "air"), goes off on the ground if it meets it first, self-destructs
## after `life` s or when the target is gone. False when the flight ended.
func _step_intercept(i: int, f: Dictionary, dt: float) -> bool:
	var w: Dictionary = f.w
	f.t = float(f.t) + dt
	var p: Vector3 = f.p
	var tp := _air_pos(f.air)
	if tp == Vector3.INF or float(f.t) > float(w.get("life", 6.0)):
		_end_flight(i)
		fx.air_burst(p, float(w.blast))
		_sfx("boom", 0.2, p)
		shot_down.emit(String(w.id), p, false)
		return false
	var to := tp - p
	var v: Vector3 = f.v
	if to.length() > 1e-6:
		v = v.lerp(to.normalized() * float(w.speed), 1.0 - exp(-dt * float(w.get("turn", 6.0))))
	f.v = v
	p += v * dt
	p.y = minf(p.y, ceiling(p.x, p.z) - 0.003)
	f.p = p
	var s := surface(p.x, p.z)
	if float(f.t) > 0.05 and s > -INF and p.y <= s:
		_end_flight(i)
		_impact(Vector3(p.x, s, p.z), w)
		return false
	if (tp - p).length() < float(w.get("kill_r", 0.008)):
		_end_flight(i)
		_air_impact(p, w, f.air)
		return false
	(f.slot.node as Node3D).position = p
	_orient(f)
	_trail(f, p, dt)
	return true


func _vel(f: Dictionary) -> Vector3:
	if f.has("v"):
		return f.v
	return Flight.velocity_at(f.plan, f.t)


func _orient(f: Dictionary) -> void:
	var vel := _vel(f)
	if vel.length() > 1e-5:
		var up := Vector3.UP if absf(vel.normalized().y) < 0.99 else Vector3.RIGHT
		(f.slot.node as Node3D).basis = Basis.looking_at(vel.normalized(), up) * Basis(Vector3.UP, PI * 0.5)


func _trail(f: Dictionary, p: Vector3, dt: float) -> void:
	var w: Dictionary = f.w
	f.trail_acc += dt
	var reentry := false
	if bool(w.glow):
		var T: float = f.plan.T
		var vy: float = _vel(f).y
		var k := clampf((float(f.t) / T - 0.5) / 0.3, 0.0, 1.0) if vy < 0.0 else 0.0
		reentry = k > 0.05
		(f.slot.glow as Node3D).scale = Vector3.ONE * (1.0 + 1.6 * k)
		(f.slot.glow_mat as StandardMaterial3D).albedo_color = Color(1.0, 0.75, 0.35).lerp(Color(1.0, 0.95, 0.85), k)
	if f.trail_acc > float(w.trail):
		f.trail_acc = 0.0
		var tc: Color = w.trail_col
		if String(f.plan.type) == "torpedo":
			# its wake on the water surface above it
			var su := surface(p.x, p.z)
			fx.trail(Vector3(p.x, (su if su > -INF else p.y) + 0.0003, p.z), tc)
		elif reentry:
			fx.reentry(p)
		elif tc.a > 0.0:
			fx.trail(p, tc)


func _info(w: Dictionary) -> Dictionary:
	var b: float = w.blast
	var info := {"id": String(w.id), "blast_r": Catalog.BLAST_R * b, "crater_r": Catalog.CRATER_R * b,
		"crater_d": Catalog.CRATER_D * pow(b, 0.8) * float(w.get("crater_k", 1.0)), "ejecta": int(w.get("ejecta", 0))}
	if bool(w.get("anti_armor", false)):
		info.armor_r = Catalog.BLAST_R * b * float(w.get("armor_k", 2.6))
	return info


func _report(p: Vector3, info: Dictionary) -> void:
	last_impact = p
	last_impact_kind = info.kind
	impact_count += 1
	if _has("military_hit"):
		host.call("military_hit", p, info)
	impacted.emit(p, info)


## An anti-air missile met its air target: a burst in the air (kind "air").
func _air_impact(p: Vector3, w: Dictionary, target: Variant) -> void:
	var info := _info(w)
	info.kind = "air"
	info.crater_r = 0.0
	info.crater_d = 0.0
	info.ejecta = 0
	info.target = target
	fx.air_burst(p, 1.0)
	_sfx("boom", 0.4, p)
	_report(p, info)


func _impact(p: Vector3, w: Dictionary) -> void:
	var b: float = w.blast
	var info := _info(w)
	var depth := water_depth(p.x, p.z)
	if bool(w.get("nuke", false)):
		info.kind = "nuke"
		var r := float(w.nuke_r)
		info.nuke_r = r
		info.wave_r = r * float(w.get("wave_k", 1.0))
		# the mushroom cloud rises far higher in the open sky; a ceiling holds it in
		fx.nuke(p, r, float(w.get("cloud", 1.0)) if not _has("military_ceiling") else 1.0)
		_sfx("boom", 1.0, p)
		_sfx("thump", 1.0, p)
		if float(w.get("wave_k", 1.0)) > 1.0:
			_waves.append({"p": p, "r0": r, "r1": info.wave_r, "T": float(w.get("wave_t", 3.0)), "t": 0.0, "cur": r, "dust": 0.0})
	elif depth > SHALLOW:
		# deep enough: a water column, spray and ripples; no fire, no crater
		info.kind = "water"
		fx.water_splash(p, b)
		_sfx("thump", 0.5 + 0.35 * b, p)
	elif depth > 0.0:
		info.kind = "shallow"
		fx.water_splash(p, b * 0.45)
		_sfx("thump", 0.35 + 0.2 * b, p)
	else:
		info.kind = "land"
		fx.explosion(p, b)
		_sfx("boom", 0.6 + 0.3 * b, p)
	_report(p, info)


## The nuke's shock wave (wave_k > 1): its front runs from nuke_r out to nuke_r x wave_k in
## wave_t s, fast at first and slowing; each step reports the ring it swept (shock_wave,
## military_shock) and a front of low dust puffs runs over the ground with it.
func _step_waves(dt: float) -> void:
	var i := 0
	while i < _waves.size():
		var wv: Dictionary = _waves[i]
		wv.t = float(wv.t) + dt
		var r0: float = wv.r0
		var r1: float = wv.r1
		var k := clampf(float(wv.t) / float(wv.T), 0.0, 1.0)
		var cur := r0 + (r1 - r0) * (1.0 - pow(1.0 - k, 1.6))
		var p: Vector3 = wv.p
		if _has("military_shock"):
			host.call("military_shock", p, float(wv.cur), cur, k)
		shock_wave.emit(p, float(wv.cur), cur, k)
		wv.dust = float(wv.dust) + dt
		if float(wv.dust) > 0.12:
			wv.dust = 0.0
			for _q in 14:
				var a := _rng.randf() * TAU
				var d := Vector3(cos(a), 0.0, sin(a))
				var at := p + d * cur
				var su := surface(at.x, at.z)
				at.y = (su if su > -INF else p.y) + 0.004
				fx.puff(at, d * 0.03 + Vector3(0, 0.004, 0), 0.01, 0.03, _rng.randf_range(2.0, 3.0), Color(0.78, 0.70, 0.60, 0.6), 0, 0.002, 1.5)
		wv.cur = cur
		if k >= 1.0:
			_waves.remove_at(i)
			continue
		i += 1


# --- building ---------------------------------------------------------------------

func _make_slot(k: int) -> Dictionary:
	var n := Node3D.new()
	n.name = "Shot%d" % k
	n.visible = false
	add_child(n)
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(body)
	var glow := SphereMesh.new()
	glow.radius = 0.0009
	glow.height = 0.0018
	glow.radial_segments = 10
	glow.rings = 6
	var gm := StandardMaterial3D.new()
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.albedo_color = Color(1.0, 0.75, 0.35)
	glow.material = gm
	var gi := MeshInstance3D.new()
	gi.name = "Glow"
	gi.mesh = glow
	gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(gi)
	return {"node": n, "body": body, "glow": gi, "glow_mat": gm, "id": ""}


func _build_preview() -> void:
	var dot := SphereMesh.new()
	dot.radius = 0.0011
	dot.height = 0.0022
	dot.radial_segments = 8
	dot.rings = 4
	var dm := StandardMaterial3D.new()
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.vertex_color_use_as_albedo = true
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dot.material = dm
	preview_mm = MultiMesh.new()
	preview_mm.transform_format = MultiMesh.TRANSFORM_3D
	preview_mm.use_colors = true
	preview_mm.mesh = dot
	preview_mm.instance_count = PREVIEW_DOTS
	preview_mm.visible_instance_count = 0
	var pmi := MultiMeshInstance3D.new()
	pmi.name = "Preview"
	pmi.multimesh = preview_mm
	pmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pmi.custom_aabb = AABB(Vector3(-4, -1, -4), Vector3(8, 6, 8))
	add_child(pmi)


func _build_marker() -> void:
	# unit ring (r 0.85..1.0) + crosshair: one mesh, placed / scaled per target
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg := 40
	for i in seg:
		var a0 := TAU * i / seg
		var a1 := TAU * (i + 1) / seg
		var q := [Vector3(cos(a0) * 0.85, 0, sin(a0) * 0.85), Vector3(cos(a0), 0, sin(a0)), Vector3(cos(a1) * 0.85, 0, sin(a1) * 0.85), Vector3(cos(a1), 0, sin(a1))]
		for v in [q[0], q[2], q[1], q[1], q[2], q[3]]:
			st.add_vertex(v)
	for arm in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
		var a := Vector3(arm.x, 0, arm.y)
		var s := Vector3(-arm.y, 0, arm.x) * 0.05
		var p_in := a * 0.25
		var p_out := a * 1.25
		for v in [p_in - s, p_out - s, p_in + s, p_in + s, p_out - s, p_out + s]:
			st.add_vertex(v)
	marker = MeshInstance3D.new()
	marker.name = "TargetMarker"
	marker.mesh = st.commit()
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	marker.visible = false
	_mat_aim = _marker_mat(Color(1.0, 0.62, 0.2, 0.85))
	_mat_lock = _marker_mat(Color(1.0, 0.12, 0.08, 0.95))
	marker.material_override = _mat_aim
	add_child(marker)


static func _marker_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = true
	m.render_priority = 3
	m.albedo_color = c
	return m
