extends SceneTree
## The kit's checks, through the host interface:
## every style fires with its sound, keeps its cooldown, pops a soft target and hits a stage
## target; the laser pierces, lightning chains, the rocket homes (two rockets and the triple
## shot pick different targets), the boomerang comes back (hitting on both ways), the confetti
## cannon fans out, the bouncy ball bounces, lives ten seconds and is capped, the water glob
## splats and pops what is near, the dallah sprays beans with soft, spaced dings; sizes
## scale; texts don't stop shots; with no host at all everything still runs.
## v1.2: the falcon hunts its own prey, drops its hood and comes back to the hand; the freeze
## ray freezes (blaster_freeze); the black hole parks, pulls (blaster_pull) and implodes; dates
## fire fastest, spread and crumble; the bakhoor smokes and slows (blaster_slow); the lasso
## catches and pulls; the hose pushes; the cluster bomb splits into bomblets; the magnet pulls
## metal, projectiles and the kit's shots and stops threats (blaster_threats / blaster_block); the
## shield rides the hand and stops threats. Without those calls each still works (PlayHost has
## them, FakeHost has not).
##
##   godot --headless --path blaster-kit -s res://tests/run_tests.gd
## Prints PASS / FAIL per check, exits 1 if any failed.

const Blaster := preload("res://addons/aboden_blaster/blaster.gd")
const Catalog := preload("res://addons/aboden_blaster/shot_catalog.gd")
const Icons := preload("res://addons/aboden_blaster/shot_icons.gd")
const Audio := preload("res://addons/aboden_blaster/blaster_audio.gd")
const Looks := preload("res://addons/aboden_blaster/shot_looks.gd")

const DT := 1.0 / 72.0
const O := Vector3(0, 1.0, 0)
const FWD := Vector3(0, 0, -1)
const BR := 0.24

var passed := 0
var failed := 0


## A soft target's identity (the host's own object for it).
class Mark:
	extends RefCounted
	var name := ""


## The host: soft targets (any things of the game), a stage, and the records of what
## the blaster asked for.
class FakeHost:
	extends Node3D
	var units := 1.0
	var stage: Node3D = null
	var soft: Array = []  # {ref, p, r}
	var popped_soft := 0
	var sturdy_soft := false
	var sounds: Array = []
	var credits: Array = []  # [kind, n]
	var progress: Array = []  # [id, value]
	var buzzes := 0
	var walls: Array = []  # z of walls facing +z (blaster_collide)
	func blaster_scale() -> float: return units
	func blaster_targets() -> Array: return soft
	func blaster_hit(t: Dictionary, _dir: Vector3) -> bool:
		var i := soft.find(t)
		if i < 0:
			return false
		popped_soft += 1
		if not sturdy_soft:
			soft.remove_at(i)
		return true
	func blaster_stage() -> Node3D: return stage
	func blaster_sfx(snd: String, k: float, pos: Vector3) -> void:
		sounds.append([snd, k, pos])
	func blaster_buzz(_hand: String, _amp: float, _ms: float) -> void:
		buzzes += 1
	func blaster_credit(kind: String, n: int) -> void:
		credits.append([kind, n])
	func blaster_challenge(id: String, value: int) -> void:
		progress.append([id, value])
	func blaster_eye() -> Vector3: return Vector3(0, 1.6, 0)
	func blaster_collide(p: Vector3, v: Vector3, r: float) -> Dictionary:
		for z: float in walls:
			if p.z < z + r and v.z < 0.0:
				return {"hit": -v.z, "p": Vector3(p.x, p.y, z + r), "v": Vector3(v.x, v.y, -v.z * 0.8), "n": Vector3.BACK}
		return {}
	func credited(kind: String) -> int:
		var n := 0
		for c: Array in credits:
			if c[0] == kind:
				n += int(c[1])
		return n
	func best(id: String) -> int:
		var v := 0
		for c: Array in progress:
			if c[0] == id:
				v = maxi(v, int(c[1]))
		return v
	func added(id: String) -> int:
		var n := 0
		for c: Array in progress:
			if c[0] == id:
				n += int(c[1])
		return n


## The host with the v1.2 calls: it freezes, slows and moves its soft targets as asked (and
## writes it all down), reports hostile projectiles, and destroys the ones it is told were stopped.
class PlayHost:
	extends FakeHost
	var frozen: Array = []  # [target, seconds]
	var slowed: Array = []  # [target, factor, seconds]
	var pulls: Array = []  # [target, to, strength, where it was]
	var hostile: Array = []  # {ref, p, r, metal?}
	var blocked: Array = []  # [threat, at]
	var hand: Variant = null
	func blaster_freeze(t: Dictionary, seconds: float) -> void:
		frozen.append([t, seconds])
	func blaster_slow(t: Dictionary, factor: float, seconds: float) -> void:
		slowed.append([t, factor, seconds])
	func blaster_pull(t: Dictionary, to: Vector3, strength: float) -> void:
		pulls.append([t, to, strength, t.p])
		t.p = (t.p as Vector3).move_toward(to, strength)
	func blaster_threats() -> Array: return hostile
	func blaster_block(th: Dictionary, at: Vector3) -> bool:
		blocked.append([th, at])
		hostile.erase(th)
		return true
	func blaster_hand(_h: String) -> Variant: return hand
	func pulled(t: Dictionary) -> Array:
		return pulls.filter(func(x: Array) -> bool: return is_same(x[0], t))


## The same with blaster_push (the hose prefers it to blaster_pull).
class PushHost:
	extends PlayHost
	var pushes: Array = []  # [target, velocity]
	func blaster_push(t: Dictionary, velocity: Vector3) -> void:
		pushes.append([t, velocity])


## A plain stage: hidden hit spheres (layers = 0) that take a
## shot, and walls that do not. sturdy: a target stays up when hit.
class TargetStage:
	extends Node3D
	var hits := 0
	var targets: Array = []
	var sturdy := false
	var fan := 1
	func shot_fan() -> int: return fan
	func add_target(p: Vector3, r: float) -> MeshInstance3D:
		var mi := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = r
		s.height = r * 2.0
		mi.mesh = s
		mi.layers = 0
		mi.position = p
		add_child(mi)
		targets.append(mi)
		return mi
	func add_wall(p: Vector3, size: Vector3) -> MeshInstance3D:
		var mi := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = size
		mi.mesh = b
		mi.position = p
		add_child(mi)
		return mi
	func shoot(obj: Node, _point: Vector3, _dir: Vector3) -> bool:
		if obj in targets and (obj as Node3D).visible:
			hits += 1
			if not sturdy:
				(obj as Node3D).visible = false
			return true
		return false


var _started := false


## The tree is only live once the main loop runs: the suite starts on the first frame.
func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run_all()
	return false


func _run_all() -> void:
	var root_node := Node3D.new()
	root.add_child(root_node)
	var host := FakeHost.new()
	root_node.add_child(host)
	var wb: Blaster = Blaster.new()
	host.add_child(wb)
	wb.setup(host)
	wb.set_seed(7)
	var rig := {"host": host, "wb": wb}
	_catalog()
	_each_style(rig)
	_laser(rig)
	_lightning(rig)
	_rocket(rig)
	_boomerang(rig)
	_spread(rig)
	_bouncy(rig)
	_glob(rig)
	_dallah(rig)
	var play := PlayHost.new()
	root_node.add_child(play)
	var pb: Blaster = Blaster.new()
	play.add_child(pb)
	pb.setup(play)
	pb.set_seed(5)
	var prig := {"host": play, "wb": pb}
	_falcon(rig, prig)
	_freeze(rig, prig)
	_blackhole(rig, prig)
	_dates(rig)
	_bakhoor(rig, prig)
	_lasso(rig, prig)
	_hose(prig)
	_cluster(rig)
	_magnet(prig)
	_shield(prig)
	play.free()
	_scale(rig)
	_through_text(rig)
	_walls(rig)
	_signals(rig)
	_no_host(root_node)
	host.free()
	root_node.free()
	print("")
	print("%s: %d passed, %d failed" % ["PASS" if failed == 0 else "FAIL", passed, failed])
	quit(1 if failed > 0 else 0)


func check(ok: bool, what: String) -> void:
	if ok:
		passed += 1
		print("PASS  ", what)
	else:
		failed += 1
		print("FAIL  ", what)


func _stage(rig: Dictionary) -> TargetStage:
	var host: FakeHost = rig.host
	if host.stage:
		host.stage.free()
	var st := TargetStage.new()
	host.add_child(st)
	host.stage = st
	return st


func _reset(rig: Dictionary) -> void:
	var wb: Blaster = rig.wb
	var host: FakeHost = rig.host
	host.soft.clear()
	host.sturdy_soft = false
	host.popped_soft = 0
	host.walls.clear()
	wb.clear()
	wb.last_shot = {"left": -10.0, "right": -10.0}
	host.sounds.clear()
	host.credits.clear()
	host.progress.clear()
	if host.stage:
		host.stage.free()
		host.stage = null
	if host is PlayHost:
		var ph := host as PlayHost
		ph.frozen.clear()
		ph.slowed.clear()
		ph.pulls.clear()
		ph.hostile.clear()
		ph.blocked.clear()
		ph.hand = null


## A soft target at p.
func _rest(rig: Dictionary, p: Vector3) -> Dictionary:
	var t := {"ref": Mark.new(), "p": p, "r": BR, "color": "ff69b4"}
	(rig.host as FakeHost).soft.append(t)
	return t


func _run(wb: Blaster, seconds: float, until := Callable()) -> void:
	for i in int(seconds / DT):
		wb.step(DT)
		if until.is_valid() and until.call():
			return


## Where a style's first target goes: straight ahead, or a boomerang's far point; for the
## lobbed v1.2 styles, where their arc is that far ahead.
func _ahead(id: String, d: float) -> Vector3:
	var muzzle := O + FWD * 0.08
	var P: Dictionary = Catalog.SHOT_STYLE[id]
	if id == "boomerang":
		return muzzle + FWD * float(P.reach) + Vector3.UP * 0.25
	if str(Catalog.info(id).version) == "1.2" and float(P.grav) > 0.0 and float(P.speed) > 0.0:
		var t := d / float(P.speed)
		return muzzle + FWD * d + Vector3.DOWN * 0.5 * 9.8 * float(P.grav) * t * t
	return muzzle + FWD * d


func _catalog() -> void:
	var bad: Array = []
	for id: String in Catalog.ids():
		var info := Catalog.info(id)
		if info.is_empty() or str(info.get("ar", "")) == "" or str(info.get("en", "")) == "" or str(info.get("ar_desc", "")) == "":
			bad.append(id)
		if not Icons.IDS.has(str(info.get("icon", ""))):
			bad.append(id + ":icon")
		if not FileAccess.file_exists("res://addons/aboden_blaster/icons/%s.png" % info.get("icon", "")):
			bad.append(id + ":icon.png")
		if not Catalog.SHOT_STYLE.has(id) or not Catalog.SHOT_UNLOCKS.has(id):
			bad.append(id + ":style")
		for snd: String in info.get("sounds", []):
			if not Audio.SFX.has(snd):
				bad.append(id + ":" + snd)
		if not Audio.SFX.has(str(info.get("sound", ""))):
			bad.append(id + ":sound")
		for tag: String in info.get("tags", []):
			if not Catalog.CATEGORIES.has(tag):
				bad.append(id + ":" + tag)
		var need := Catalog.need(id)
		if need != "" and not Catalog.CHALLENGES.has(need):
			bad.append(id + ":" + need)
	check(bad.is_empty() and Catalog.ids().size() == 22, "catalog: every style's names, icons, sounds, tags and unlocks agree (22) %s" % [bad])
	var codes: Array = []
	var axes_bad: Array = []
	for i in Catalog.ids().size():
		var id: String = Catalog.ids()[i]
		var info := Catalog.info(id)
		codes.append(str(info.get("code", "")))
		for axis: String in Catalog.AXES:
			if not (Catalog.AXES[axis] as Dictionary).has(str(info.get(axis, ""))):
				axes_bad.append(id + ":" + axis)
		if int(info.get("tier", -1)) < 0 or int(info.get("tier", -1)) >= Catalog.TIERS.size() or not Catalog.STATUS.has(str(info.get("status", ""))):
			axes_bad.append(id + ":tier/status")
		if codes[i] != Catalog.CODE_PREFIX + "%03d" % (i + 1) or Catalog.by_code(codes[i]) != id:
			axes_bad.append(id + ":code")
	check(axes_bad.is_empty() and Catalog.next_code() == "AB-W-041" and Catalog.RESERVED.is_empty(), "catalog: codes AB-W-001..022 in order, unique, none reserved any more, 023..040 military, next AB-W-041; every axis, tier and status valid %s" % [axes_bad])
	var missing: Array = []
	for f: String in Audio.all_files():
		if not FileAccess.file_exists("res://addons/aboden_blaster/sounds/%s.wav" % f):
			missing.append(f)
	check(missing.is_empty(), "sounds: every file the built-in player picks is bundled %s" % [missing])
	var free_ids: Array = []
	for id: String in Catalog.ids().slice(0, 12):
		if Catalog.available(id, {}):
			free_ids.append(id)
	var new_open := Catalog.ids().slice(12).all(func(id: String) -> bool: return Catalog.need(id) == "" and Catalog.available(id, {}))
	check(free_ids == ["bolt", "mini", "bubble", "firework"] and new_open, "catalog: the first four of the original twelve were open from the start, the ten of v1.2 have no unlock %s" % [free_ids])
	check(not Catalog.available("laser", {"skyPop5": 4}) and Catalog.available("laser", {"skyPop5": 5}) and Catalog.available("laser", {"shot:laser": 1})
		and Catalog.need_text("laser")[1] == "Pop 5 targets above your head", "catalog: the laser's unlock (pop 5 above your head) as data")
	check(str(Catalog.info("glob").en) == "Water" and str(Catalog.info("glob").ar) == "ماء", "catalog: the glob is the water shot (ماء)")
	var imgs := Icons.raster(Icons.shapes("rocket"), 64)
	var cover := 0
	for y in 64:
		for x in 64:
			if imgs[0].get_pixel(x, y).a > 0.5:
				cover += 1
	check(cover > 100, "icons: the rasteriser draws an icon (%d px of line)" % cover)
	check(Catalog.pack("playful") == Catalog.ids() and Catalog.PACKS.has("military") and Catalog.pack("military").is_empty()
		and Catalog.ids().all(func(id: String) -> bool: return str(Catalog.info(id).status) == "stable")
		and Catalog.ids().slice(0, 12).all(func(id: String) -> bool: return str(Catalog.info(id).version) == "1.0")
		and Catalog.ids().slice(12).all(func(id: String) -> bool: return str(Catalog.info(id).version) == "1.2"),
		"catalog: the 22 are the playful pack, all stable (001..012 v1.0, 013..022 v1.2); the military pack has its own catalogue")
	# Ids are per pack: the playful cluster bomb and the military cluster missile are two weapons.
	var Mil: GDScript = load("res://addons/aboden_blaster/military/military_catalog.gd")
	check(Catalog.info("cluster").code == "AB-W-020" and str(Mil.WEAPONS.cluster.code) == "AB-W-027" and Catalog.by_code("AB-W-027") == "",
		"catalog: the playful \"cluster\" (AB-W-020) and the military one (AB-W-027) are told apart by code")
	var cools: Array = Catalog.ids().map(func(id: String) -> float: return float(Catalog.SHOT_STYLE[id].cool))
	check(float(Catalog.SHOT_STYLE.dates.cool) == cools.min() and cools.count(cools.min()) == 1, "catalog: the date blaster fires fastest of all (cool %.2f s)" % float(Catalog.SHOT_STYLE.dates.cool))


## Each style: fires (with its sound), keeps its cooldown, pops a soft target ahead, hits a stage target.
func _each_style(rig: Dictionary) -> void:
	var wb: Blaster = rig.wb
	var host: FakeHost = rig.host
	var fire_bad: Array = []
	var cool_bad: Array = []
	var pop_bad: Array = []
	var hit_bad: Array = []
	# The shield does not hit: it stops the host's projectiles (_shield).
	var defends := ["shield"]
	for id: String in Catalog.ids():
		var P: Dictionary = Catalog.SHOT_STYLE[id]
		wb.style = id
		_reset(rig)
		var n0 := wb.fired
		wb.fire("right", O, FWD)
		var snd := str(Catalog.info(id).sound)
		var heard := false
		for s: Array in host.sounds:
			if s[0] == snd:
				heard = true
		if wb.fired != n0 + 1 or not heard or (wb.shots.is_empty() and wb.arcs.is_empty()):
			fire_bad.append(id)
		# Cooldown: not again at once, again once it has passed (the other hand is free).
		wb.fire("right", O, FWD)
		var held := wb.fired == n0 + 1
		wb.fire("left", O, FWD)
		var other := wb.fired == n0 + 2
		wb.clock += float(P.cool) + 0.001
		wb.fire("right", O, FWD)
		if not (held and other and wb.fired == n0 + 3):
			cool_bad.append(id)
		if id in defends:
			continue
		# Pops a soft target in front of it.
		_reset(rig)
		_rest(rig, _ahead(id, 2.0))
		var before := wb.popped
		wb.fire("right", O, FWD)
		_run(wb, 3.0, func(): return host.soft.is_empty())
		if not host.soft.is_empty() or wb.popped <= before:
			pop_bad.append(id)
		# Hits a target of the stage (stage.shoot).
		_reset(rig)
		var st := _stage(rig)
		st.add_target(_ahead(id, 1.5), 0.2)
		wb.fire("right", O, FWD)
		_run(wb, 3.0, func(): return st.hits > 0)
		if st.hits < 1:
			hit_bad.append(id)
	check(fire_bad.is_empty() and Catalog.ids().size() == 22, "shots: every style (22) fires with its sound %s" % [fire_bad])
	check(cool_bad.is_empty(), "shots: every style keeps its cooldown, per hand %s" % [cool_bad])
	check(pop_bad.is_empty(), "shots: every style pops a soft target (the shield only defends) %s" % [pop_bad])
	check(hit_bad.is_empty(), "shots: every style hits a stage target (the shield only defends) %s" % [hit_bad])
	_reset(rig)
	wb.style = "nonsense"
	check(wb.style_for() == "bolt", "shots: an unknown style fires the bolt")


func _laser(rig: Dictionary) -> void:
	var wb: Blaster = rig.wb
	var host: FakeHost = rig.host
	_reset(rig)
	wb.style = "laser"
	for d in [2.0, 3.0, 4.0, 5.0]:
		_rest(rig, O + FWD * d)
	wb.fire("right", O, FWD)
	check(host.soft.size() == 1 and (host.soft[0].p as Vector3).z < -4.9 and wb.arcs.size() == 1 and wb.shots.is_empty(),
		"laser: an instant beam pierces three targets and stops in the third (%d left)" % host.soft.size())
	check(host.credited("laser") == 3, "laser: its three hits are credited (%d)" % host.credited("laser"))
	var arc: Dictionary = wb.arcs[0]
	check(absf((arc.b as Vector3).z - (O.z - 4.0)) < 0.1, "laser: the beam ends at the last one it went through")
	_run(wb, 0.4)
	check(wb.arcs.is_empty(), "laser: the glowing line fades")
	# Through two of the stage's targets and a soft one; a wall stops it.
	_reset(rig)
	var st := _stage(rig)
	st.add_target(O + FWD * 2.0, 0.2)
	st.add_target(O + FWD * 3.0, 0.2)
	st.add_wall(O + FWD * 4.0, Vector3(2, 2, 0.2))
	_rest(rig, O + FWD * 3.5)
	_rest(rig, O + FWD * 5.0)
	wb.fire("right", O, FWD)
	check(st.hits == 2 and host.soft.size() == 1 and (host.soft[0].p as Vector3).z < -4.9, "laser: through two targets and a soft one, stopped by a wall")


func _lightning(rig: Dictionary) -> void:
	var wb: Blaster = rig.wb
	var host: FakeHost = rig.host
	_reset(rig)
	wb.style = "lightning"
	for x in [0.0, 1.5, 3.0, 4.5, 6.0]:
		_rest(rig, O + Vector3(x, 0, -4))
	wb.fire("right", O, FWD)
	check(host.soft.size() == 1 and absf((host.soft[0].p as Vector3).x - 6.0) < 0.01 and wb.arcs.size() == 4,
		"lightning: chains through four targets, one hop at a time (%d left, %d arcs)" % [host.soft.size(), wb.arcs.size()])
	check(host.best("chain4") == 4, "lightning: a chain of four is reported for chain4")
	var jag := false
	for arc: Dictionary in wb.arcs:
		if int(arc.n) >= 4 and float(arc.jit) > 0.0:
			jag = true
	check(jag, "lightning: along jagged arcs")
	_reset(rig)
	var st := _stage(rig)
	st.add_target(O + FWD * 5.0, 0.25)
	_rest(rig, O + Vector3(1.2, 0, -5))
	wb.fire("right", O, FWD)
	check(st.hits == 1 and host.soft.is_empty(), "lightning: from a stage target on to a soft one")


func _rocket(rig: Dictionary) -> void:
	var wb: Blaster = rig.wb
	var host: FakeHost = rig.host
	_reset(rig)
	wb.style = "rocket"
	_rest(rig, O + Vector3(2.0, 0, -5))
	wb.fire("right", O, FWD)
	var s: Dictionary = wb.shots[0]
	var slow: float = (s.v as Vector3).length()
	var side := 0.0
	for i in int(3.0 / DT):
		wb.step(DT)
		side = maxf(side, (s.p as Vector3).x)
		if host.soft.is_empty():
			break
	check(slow < 0.3 * float(Catalog.SHOT_STYLE.rocket.speed), "rocket: starts slow (%.1f)" % slow)
	check(host.soft.is_empty() and side > 1.0, "rocket: homes in on a target off to the side (%.2f)" % side)
	_reset(rig)
	var st := _stage(rig)
	st.add_target(O + FWD * 4.0, 0.2)
	_rest(rig, O + Vector3(0.5, 0, -4.0))
	wb.fire("right", O, FWD)
	_run(wb, 3.0, func(): return wb.shots.is_empty())
	check(st.hits == 1 and host.soft.is_empty(), "rocket: explodes with a radius")
	check(host.credited("rocket") >= 2, "rocket: what its blast hits is credited (%d)" % host.credited("rocket"))
	# Two rockets one after the other each go for their own target.
	_reset(rig)
	_rest(rig, O + Vector3(-1.5, 0, -5))
	_rest(rig, O + Vector3(1.5, 0, -5))
	wb.fire("right", O, FWD)
	wb.fire("left", O, FWD)
	var r1: Dictionary = wb.shots[0]
	var r2: Dictionary = wb.shots[1]
	for i in int(0.4 / DT):
		wb.step(DT)
	check(not (r1.target as Dictionary).is_empty() and not (r2.target as Dictionary).is_empty() and not is_same(r1.target.ref, r2.target.ref),
		"rocket: two in the air pick different targets")
	# The triple shot: its three rockets share out the targets too.
	_reset(rig)
	var fs := _stage(rig)
	fs.fan = 3
	for x: float in [-1.2, 0.0, 1.2]:
		fs.add_target(O + Vector3(x, 0, -5), 0.15)
	wb.fire("right", O, FWD)
	var rockets := wb.shots.filter(func(o: Dictionary) -> bool: return o.kind == "rocket").size()
	for i in int(0.4 / DT):
		wb.step(DT)
	var refs := []
	for o: Dictionary in wb.shots:
		if o.kind == "rocket" and not (o.target as Dictionary).is_empty() and not refs.any(func(r) -> bool: return is_same(r, o.target.ref)):
			refs.append(o.target.ref)
	check(rockets == 3 and refs.size() == 3, "rocket: the triple shot's three rockets go for three targets (%d)" % refs.size())


func _boomerang(rig: Dictionary) -> void:
	var wb: Blaster = rig.wb
	var host: FakeHost = rig.host
	_reset(rig)
	wb.style = "boomerang"
	wb.fire("right", O, FWD)
	var s: Dictionary = wb.shots[0]
	var far := 0.0
	var last := O
	var nd: Node3D = s.node
	var sp := nd.get_node_or_null("Tilt/Spin") as Node3D
	var mesh := Blaster.boomerang_mesh()
	var bb := mesh.get_aabb()
	check(sp != null and sp.get_child_count() == 1 and (sp.get_child(0) as MeshInstance3D).mesh == mesh
		and bb.size.x > 0.25 and bb.size.x < 0.36 and bb.size.y < 0.02 and bb.size.z > 0.06 and bb.size.z < bb.size.x * 0.6
		and absf(bb.get_center().x) < 0.01,
		"boomerang: a curved V, about 0.3 tip to tip and thin (%s)" % [bb])
	var spins: Array = []
	var banks: Array = []
	for i in int(4.0 / DT):
		wb.step(DT)
		if i % 6 == 0 and sp != null and is_instance_valid(sp):
			spins.append(sp.rotation.y)
			banks.append(absf(float(s.bank)))
		last = s.p
		far = maxf(far, (s.p as Vector3).distance_to(O))
		if wb.shots.is_empty():
			break
	check(far > 5.0 and s.caught and last.distance_to(s.o) < 0.3 and wb.shots.is_empty(),
		"boomerang: curves out (%.1f) and comes back to the hand (%.2f)" % [far, last.distance_to(s.o)])
	var turned := 0.0
	for i in range(1, spins.size()):
		turned += absf(angle_difference(float(spins[i - 1]), float(spins[i])))
	check(turned > 2.0 and banks.max() > 0.1, "boomerang: it spins (%.1f rad seen) and banks into its curve (%.2f)" % [turned, banks.max()])
	_reset(rig)
	var st := _stage(rig)
	st.sturdy = true
	st.add_target(O + FWD * 1.8, 1.0)
	wb.fire("right", O, FWD)
	_run(wb, 3.0, func(): return wb.shots.is_empty())
	check(st.hits >= 2, "boomerang: hits on both ways (%d)" % st.hits)
	check(host.added("boomerang3") == 1, "boomerang: caught after a hit, it reports boomerang3")
	_reset(rig)
	st = _stage(rig)
	st.add_wall(O + FWD * 3.0, Vector3(6, 4, 0.2))
	wb.fire("right", O, FWD)
	s = wb.shots[0]
	_run(wb, 0.5)
	var back: bool = s.ret
	_run(wb, 3.0, func(): return wb.shots.is_empty())
	check(back and s.caught and wb.shots.is_empty() and host.added("boomerang3") == 0, "boomerang: knocked back by a wall, it flies home (no hit, no credit)")


func _spread(rig: Dictionary) -> void:
	var wb: Blaster = rig.wb
	_reset(rig)
	wb.style = "confetti"
	wb.fire("right", O, FWD)
	var cone: float = Catalog.SHOT_STYLE.confetti.cone
	var angles: Array = []
	var dirs: Array = []
	for s: Dictionary in wb.shots:
		if s.kind == "confetti":
			angles.append(FWD.angle_to(s.dir))
			dirs.append(s.dir)
	var off := 0
	var inside := true
	for a: float in angles:
		if a > 0.05:
			off += 1
		if a > cone + 1e-3:
			inside = false
	var distinct := true
	for i in dirs.size():
		for j in range(i + 1, dirs.size()):
			if (dirs[i] as Vector3).angle_to(dirs[j]) < 0.02:
				distinct = false
	check(angles.size() == 5 and off == 4 and inside and distinct, "confetti: five pellets fan out in a cone %s" % [angles])
	_run(wb, 0.3)
	var flakes := 0
	for sp: Dictionary in wb.sparks:
		if sp.flake:
			flakes += 1
	check(flakes > 5, "confetti: with confetti trails (%d)" % flakes)


func _bouncy(rig: Dictionary) -> void:
	var wb: Blaster = rig.wb
	var host: FakeHost = rig.host
	_reset(rig)
	wb.style = "bouncy"
	wb.fire("right", O, Vector3(0, -0.6, -1).normalized())
	var s: Dictionary = wb.shots[0]
	var up := false
	for i in int(1.5 / DT):
		wb.step(DT)
		if int(s.bounces) >= 1 and (s.v as Vector3).y > 0.0:
			up = true
			break
	check(up and not wb.shots.is_empty(), "bouncy: bounces off the floor and carries on")
	_reset(rig)
	_rest(rig, O + FWD * 1.5)
	_rest(rig, O + FWD * 2.4 + Vector3.DOWN * 0.1)
	wb.fire("right", O, FWD)
	_run(wb, 2.0, func(): return host.soft.is_empty())
	check(host.soft.is_empty(), "bouncy: pops on through more than one")
	check(host.best("bouncy3") >= 2, "bouncy: the hits of one ball are reported for bouncy3 (%d)" % host.best("bouncy3"))
	_reset(rig)
	wb.fire("right", O, Vector3(0.3, -0.2, -1).normalized())
	var first: Dictionary = wb.shots[0]
	_run(wb, 6.0)
	var hops := false
	for i in int(2.0 / DT):
		wb.step(DT)
		hops = hops or (first.v as Vector3).y > 0.5
	check(wb.shots.has(first) and hops, "bouncy: still bouncing about after 6 s")
	_run(wb, 3.0)
	check(not wb.shots.has(first), "bouncy: gone after its ten seconds")
	_reset(rig)
	wb.fire("right", O, Vector3(0.3, -0.2, -1).normalized())
	first = wb.shots[0]
	for i in Blaster.BOUNCY_MAX + 3:
		wb.last_shot = {}
		wb.fire("right", O, Vector3(0, 0.2, -1).normalized())
	var n := wb.shots.filter(func(o: Dictionary) -> bool: return o.kind == "bouncy").size()
	check(n == Blaster.BOUNCY_MAX and not wb.shots.has(first), "bouncy: at most %d at once, the oldest makes way (%d)" % [Blaster.BOUNCY_MAX, n])


func _glob(rig: Dictionary) -> void:
	var wb: Blaster = rig.wb
	var host: FakeHost = rig.host
	_reset(rig)
	wb.style = "glob"
	var dir := Vector3(0, -0.5, -1).normalized()
	wb.fire("right", O, dir)
	var landed := {"p": O}
	_run(wb, 2.0, func():
		if wb.shots.is_empty():
			return true
		landed.p = wb.shots[0].p
		return false)
	var splashed := host.sounds.any(func(x: Array) -> bool: return x[0] == "splash")
	check(wb.shots.is_empty() and absf((landed.p as Vector3).y) < 0.3 and splashed, "water: the glob splashes on the floor")
	_reset(rig)
	wb.style = "glob"
	_rest(rig, Vector3((landed.p as Vector3).x + 0.1, BR, (landed.p as Vector3).z))
	wb.fire("right", O, dir)
	_run(wb, 2.0, func(): return wb.shots.is_empty())
	check(host.soft.is_empty(), "water: and the splash pops a target sitting there")
	_reset(rig)
	var st := _stage(rig)
	st.add_wall(O + FWD * 3.0, Vector3(3, 3, 0.2))
	_rest(rig, O + FWD * 2.8 + Vector3(0.45, -0.3, 0))
	wb.fire("right", O, FWD)
	_run(wb, 2.0, func(): return wb.shots.is_empty())
	check(host.soft.is_empty(), "water: the splash on a wall pops a target beside it")


func _dallah(rig: Dictionary) -> void:
	var wb: Blaster = rig.wb
	var host: FakeHost = rig.host
	_reset(rig)
	wb.style = "dallah"
	wb.fire("right", O + Vector3.UP, FWD)
	var beans := 0
	for i in int(0.4 / DT):
		wb.step(DT)
		for s: Dictionary in wb.shots:
			if s.kind == "bean":
				beans += 1
	check(beans > 0 and wb.shots.size() < Blaster.SHOTS_MAX, "dallah: the pot sprays coffee beans as it flies")
	_run(wb, 1.0, func(): return not wb.shots.any(func(o: Dictionary) -> bool: return o.kind == "dallah"))
	var spilled := wb.shots.filter(func(o: Dictionary) -> bool: return o.kind == "bean").size()
	check(spilled >= 1, "dallah: it spills its beans where it lands (%d)" % spilled)
	_reset(rig)
	var st := _stage(rig)
	st.sturdy = true
	st.add_wall(O + FWD * 2.5, Vector3(6, 4, 0.2))
	for i in int(2.0 / DT):
		for h: String in ["left", "right"]:
			wb.fire(h, O + Vector3.UP, FWD)
		wb.step(DT)
	var dings: Array = host.sounds.filter(func(x: Array) -> bool: return x[0] == "fair_ding")
	var thumps: Array = host.sounds.filter(func(x: Array) -> bool: return x[0] == "thump")
	var loud: Array = dings.filter(func(x: Array) -> bool: return float(x[1]) > 0.31)
	check(dings.size() > 0 and dings.size() <= int(2.0 / Blaster.DALLAH_DING_GAP) + 1 and loud.is_empty() and thumps.size() <= int(2.0 / Blaster.BEAN_THUMP_GAP) + 1,
		"dallah: its dings are soft and spaced (%d dings, %d thumps in 2 s, both hands)" % [dings.size(), thumps.size()])
	var ga: Audio = Audio.new()
	check(float(ga.pick("fair_ding", Blaster.DALLAH_FIRE_K)[1]) < -9.0 and is_zero_approx(float(ga.pick("fair_ding", 1.0)[1])),
		"dallah: its ding plays %.1f dB under the full bell" % float(ga.pick("fair_ding", Blaster.DALLAH_FIRE_K)[1]))
	ga.free()


func _heard(host: FakeHost, snd: String) -> int:
	return host.sounds.filter(func(x: Array) -> bool: return x[0] == snd).size()


func _of(wb: Blaster, kind: String) -> Array:
	return wb.shots.filter(func(o: Dictionary) -> bool: return o.kind == kind)


## The falcon: picks its own prey, drops its hood, stoops (with a screech) and comes back.
func _falcon(rig: Dictionary, prig: Dictionary) -> void:
	var wb: Blaster = prig.wb
	var host: PlayHost = prig.host
	_reset(prig)
	wb.style = "falcon"
	host.hand = O + Vector3(0.3, 0.0, 0.2)
	_rest(prig, O + Vector3(2.0, 0.5, -5))
	wb.fire("right", O, FWD)
	var s: Dictionary = wb.shots[0]
	var nd: Node3D = s.node
	var hooded := nd.get_node_or_null("Bird/Hood") != null
	var hood_off := false
	var dove := false
	var flap: Array = []
	for i in int(7.0 / DT):
		wb.step(DT)
		if is_instance_valid(nd) and nd.get_node_or_null("Bird/Hood") == null and not wb.props.is_empty():
			hood_off = true
		dove = dove or bool(s.dove)
		var w := nd.get_node_or_null("Bird/WingR") as Node3D if is_instance_valid(nd) else null
		if w and not s.dove:
			flap.append(w.rotation.z)
		if wb.shots.is_empty():
			break
	check(hooded and hood_off, "falcon: a hooded falcon, its hood drops off once it flies")
	check(flap.size() > 4 and float(flap.max()) - float(flap.min()) > 0.8, "falcon: it beats its wings (%.2f rad)" % (float(flap.max()) - float(flap.min()) if flap.size() > 0 else 0.0))
	check(host.soft.is_empty() and dove and _heard(host, "screech") == 1, "falcon: stoops on a target off to the side (with a screech) and takes it")
	check(s.caught and wb.shots.is_empty() and (s.p as Vector3).distance_to(host.hand) < 0.05 and _heard(host, "flap") == 2,
		"falcon: then flies back to the hand (blaster_hand) and is caught (%.2f)" % (s.p as Vector3).distance_to(host.hand))
	# Two falcons go for two targets.
	_reset(prig)
	_rest(prig, O + Vector3(-1.5, 0, -6))
	_rest(prig, O + Vector3(1.5, 0, -6))
	wb.fire("right", O, FWD)
	wb.fire("left", O, FWD)
	var f1: Dictionary = wb.shots[0]
	var f2: Dictionary = wb.shots[1]
	_run(wb, 0.4)
	check(not (f1.target as Dictionary).is_empty() and not (f2.target as Dictionary).is_empty() and not is_same(f1.target.ref, f2.target.ref),
		"falcon: two in the air hunt different targets")
	_run(wb, 7.0, func(): return wb.shots.is_empty())
	check(host.soft.is_empty() and wb.shots.is_empty(), "falcon: both take theirs and come home")
	# Nothing to hunt: home again soon, without a host's hand to where it left.
	var fb: Blaster = rig.wb
	_reset(rig)
	fb.style = "falcon"
	fb.fire("right", O, FWD)
	var lone: Dictionary = fb.shots[0]
	var far := 0.0
	for i in int(6.0 / DT):
		fb.step(DT)
		far = maxf(far, (lone.p as Vector3).distance_to(O))
		if fb.shots.is_empty():
			break
	check(lone.caught and far > 2.0 and far < 15.0 and (lone.p as Vector3).distance_to(lone.o) < 0.05, "falcon: with nothing to hunt it circles back to where it left (%.1f m out)" % far)


## The freeze ray: an icy beam; the host freezes what it reaches (blaster_freeze) for `frost` s.
func _freeze(rig: Dictionary, prig: Dictionary) -> void:
	var wb: Blaster = prig.wb
	var host: PlayHost = prig.host
	var P: Dictionary = Catalog.SHOT_STYLE.freeze
	_reset(prig)
	wb.style = "freeze"
	var t := _rest(prig, O + FWD * 4.0)
	_rest(prig, O + FWD * 6.0)
	wb.fire("right", O, FWD)
	check(host.frozen.size() == 1 and is_same(host.frozen[0][0], t) and float(host.frozen[0][1]) == float(P.frost) and host.popped_soft == 0 and host.soft.size() == 2,
		"freeze: the beam freezes the first target for %.0f s (blaster_freeze), instead of popping it" % float(P.frost))
	check(wb.arcs.size() == 1 and wb.shots.is_empty() and _heard(host, "ice_zap") == 1 and _heard(host, "ice_crack") == 1 and wb.auras.size() == 1,
		"freeze: an instant icy beam (ice_zap), the ice cracks (ice_crack) and a frost shell covers it")
	_run(wb, float(P.frost) - 0.5)
	var held := wb.auras.size() == 1
	_run(wb, 1.0)
	check(held and wb.auras.is_empty(), "freeze: the frost shell lasts while it is frozen")
	_reset(prig)
	_rest(prig, O + FWD * (float(P.range) + 2.0))
	wb.fire("right", O, FWD)
	check(host.frozen.is_empty(), "freeze: a short beam: nothing beyond %.0f m" % float(P.range))
	var st := _stage(prig)
	st.sturdy = true
	st.add_target(O + FWD * 3.0, 0.2)
	wb.clock += 1.0
	wb.fire("right", O, FWD)
	check(st.hits == 1 and wb.auras.size() == 1, "freeze: a stage target takes it (shoot) and frosts over")
	# No blaster_freeze: it is a hit like any other.
	var fb: Blaster = rig.wb
	_reset(rig)
	fb.style = "freeze"
	_rest(rig, O + FWD * 4.0)
	fb.fire("right", O, FWD)
	check((rig.host as FakeHost).soft.is_empty() and (rig.host as FakeHost).credited("freeze") == 1, "freeze: without blaster_freeze the beam hits (pops) the target")


## The black hole: flies, slows to a stop, pulls (blaster_pull) for `linger`, then implodes.
func _blackhole(rig: Dictionary, prig: Dictionary) -> void:
	var wb: Blaster = prig.wb
	var host: PlayHost = prig.host
	var P: Dictionary = Catalog.SHOT_STYLE.blackhole
	_reset(prig)
	wb.style = "blackhole"
	var stop := 0.08 + float(P.speed) * float(P.life) * 0.5
	var t := _rest(prig, O + FWD * stop + Vector3(1.5, 0.0, 0.0))
	t.r = 0.1
	wb.fire("right", O, FWD)
	var s: Dictionary = wb.shots[0]
	_run(wb, float(P.life) + 0.05)
	check(s.parked and absf((s.p as Vector3).distance_to(O) - stop) < 0.15, "blackhole: slows to a stop %.1f m out and stays (%.2f)" % [stop, (s.p as Vector3).distance_to(O)])
	var park: Vector3 = s.p
	_run(wb, 0.5)
	var pulled := host.pulled(t)
	check(not pulled.is_empty() and (pulled[0][1] as Vector3).distance_to(park) < 1e-4 and float(pulled[0][2]) > 0.0 and (t.p as Vector3).distance_to(park) < 1.4,
		"blackhole: pulls a target within its field toward it (blaster_pull, %d calls)" % pulled.size())
	_run(wb, 2.0, func(): return wb.shots.is_empty())
	check(wb.shots.is_empty() and host.soft.is_empty() and _heard(host, "whoomp") == 1, "blackhole: then implodes (whoomp) and pops what it pulled in")
	# No blaster_pull: the swirl is only the look, but it still implodes on what is near.
	var fb: Blaster = rig.wb
	var fh: FakeHost = rig.host
	_reset(rig)
	fb.style = "blackhole"
	var near := _rest(rig, O + FWD * stop + Vector3(0.7, 0.0, 0.0))
	var away := _rest(rig, O + FWD * stop + Vector3(-1.8, 0.0, 0.0))
	var p0: Vector3 = away.p
	fb.fire("right", O, FWD)
	_run(fb, 3.0, func(): return fb.shots.is_empty())
	check(fb.shots.is_empty() and not fh.soft.has(near) and fh.soft.has(away) and (away.p as Vector3) == p0 and fh.credited("blackhole") == 1,
		"blackhole: without blaster_pull its implosion pops what is within %.1f m, nothing else moves" % float(P.burst))


## Dates: the fastest weapon, a little spread, a soft "put" each, crumbs on a hit.
func _dates(rig: Dictionary) -> void:
	var wb: Blaster = rig.wb
	var host: FakeHost = rig.host
	var P: Dictionary = Catalog.SHOT_STYLE.dates
	_reset(rig)
	wb.style = "dates"
	var angles: Array = []
	for i in 12:
		wb.fire("right", O, FWD)
		wb.clock += float(P.cool) + 0.001
	for s: Dictionary in _of(wb, "dates"):
		angles.append(FWD.angle_to(s.dir))
	var date: Node3D = (wb.shots[0].node as Node3D).get_node_or_null("Date")
	check(angles.size() == 12 and float(angles.max()) <= float(P.cone) + 1e-4 and float(angles.max()) > 0.005 and _heard(host, "put") == 12,
		"dates: twelve in 1.2 s, each a little off the aim (up to %.3f rad), each with its soft put" % float(angles.max()))
	check(date != null and date.scale.z > date.scale.x * 1.4, "dates: each a long glossy date")
	_reset(rig)
	var st := _stage(rig)
	st.add_wall(O + FWD * 2.0, Vector3(3, 3, 0.2))
	wb.fire("right", O, FWD)
	_run(wb, 1.0, func(): return wb.shots.is_empty())
	var crumbs := 0
	for sp: Dictionary in wb.sparks:
		for c: String in Catalog.CRUMB_COLS:
			if (sp.color as Color).is_equal_approx(Color(c)):
				crumbs += 1
	check(wb.shots.is_empty() and crumbs >= 5 and _heard(host, "thump") == 1, "dates: one crumbles into bits on a wall (%d crumbs)" % crumbs)


## The bakhoor: lobbed, it lands, stands and smokes `linger` s, slowing what is in its cloud.
func _bakhoor(rig: Dictionary, prig: Dictionary) -> void:
	var wb: Blaster = prig.wb
	var host: PlayHost = prig.host
	var P: Dictionary = Catalog.SHOT_STYLE.bakhoor
	_reset(prig)
	wb.style = "bakhoor"
	wb.fire("right", O, FWD)
	var s: Dictionary = wb.shots[0]
	_run(wb, 1.5, func(): return s.parked)
	var land: Vector3 = s.p
	var sp := (s.node as Node3D).get_node_or_null("Spin") as Node3D
	check(s.parked and absf(land.y - float(P.r)) < 0.01 and land.z < -2.5 and sp != null and sp.rotation.is_zero_approx() and _heard(host, "ember") == 1,
		"bakhoor: lobbed %.1f m, it lands upright on the floor and glows (ember)" % -land.z)
	var inside := _rest(prig, land + Vector3(0.3, 0.4, 0.0))
	var outside := _rest(prig, land + Vector3(2.5, 0.4, 0.0))
	_run(wb, 2.0)
	var smoke := wb.sparks.filter(func(x: Dictionary) -> bool: return float(x.grow) > 0.0).size()
	var slow_in := host.slowed.filter(func(x: Array) -> bool: return is_same(x[0], inside))
	var slow_out := host.slowed.filter(func(x: Array) -> bool: return is_same(x[0], outside))
	check(smoke > 15 and wb.shots.has(s), "bakhoor: a lingering cloud of rising smoke (%d puffs)" % smoke)
	check(slow_in.size() >= 6 and float(slow_in[0][1]) == float(P.slow) and float(slow_in[0][2]) == Catalog.BAKHOOR_HOLD and slow_out.is_empty() and host.soft.size() == 2,
		"bakhoor: slows what is in the cloud (blaster_slow x%.1f, every %.2f s), not what is outside, and pops nothing" % [float(P.slow), Catalog.BAKHOOR_TICK])
	_run(wb, float(P.linger) - 1.5)
	check(not wb.shots.has(s), "bakhoor: gone after its %.0f s of smoke" % float(P.linger))
	# No blaster_slow: only the smoke.
	var fb: Blaster = rig.wb
	_reset(rig)
	fb.style = "bakhoor"
	fb.fire("right", O, FWD)
	var fs: Dictionary = fb.shots[0]
	_run(fb, 1.5, func(): return fs.parked)
	_rest(rig, (fs.p as Vector3) + Vector3(0.2, 0.3, 0.0))
	_run(fb, 1.0)
	check(fs.parked and (rig.host as FakeHost).soft.size() == 1 and fb.sparks.any(func(x: Dictionary) -> bool: return float(x.grow) > 0.0),
		"bakhoor: without blaster_slow the smoke is only the look")


## The lasso: catches a target and pulls it to the hand (blaster_pull), or comes back empty.
func _lasso(rig: Dictionary, prig: Dictionary) -> void:
	var wb: Blaster = prig.wb
	var host: PlayHost = prig.host
	_reset(prig)
	wb.style = "lasso"
	host.hand = O
	var t := _rest(prig, _ahead("lasso", 3.0))
	var d0 := (t.p as Vector3).distance_to(O)
	wb.fire("right", O, FWD)
	var s: Dictionary = wb.shots[0]
	_run(wb, 1.0, func(): return not (s.hold as Dictionary).is_empty())
	check(not (s.hold as Dictionary).is_empty() and _heard(host, "snap") == 1 and host.popped_soft == 0, "lasso: its loop catches the target (snap), no pop")
	var rope := 0
	for i in int(0.6 / DT):
		wb.step(DT)
		rope = maxi(rope, wb._beam_mm.visible_instance_count)
	var pulled := host.pulled(t)
	check(not pulled.is_empty() and (pulled[0][1] as Vector3).distance_to(O) < 1e-4 and (t.p as Vector3).distance_to(O) < d0 - 1.0 and rope >= Blaster.ROPE_SEGS,
		"lasso: and pulls it toward the hand along its red-and-white rope (%.1f -> %.1f m)" % [d0, (t.p as Vector3).distance_to(O)])
	_run(wb, 5.0, func(): return wb.shots.is_empty())
	check(wb.shots.is_empty() and s.caught and host.popped_soft == 0 and host.soft.size() == 1, "lasso: then lets go and reels back into the hand")
	_reset(prig)
	wb.fire("right", O, FWD)
	s = wb.shots[0]
	_run(wb, 4.0, func(): return wb.shots.is_empty())
	check(s.caught and wb.shots.is_empty() and _heard(host, "snap") == 0, "lasso: a miss comes back to the hand")
	# No blaster_pull: the catch is a hit.
	var fb: Blaster = rig.wb
	_reset(rig)
	fb.style = "lasso"
	_rest(rig, _ahead("lasso", 3.0))
	fb.fire("right", O, FWD)
	var fs: Dictionary = fb.shots[0]
	_run(fb, 4.0, func(): return fb.shots.is_empty())
	check((rig.host as FakeHost).soft.is_empty() and fs.caught, "lasso: without blaster_pull it pops what it reaches, and comes back")


## The hose: a held trigger is a stream that pushes a target away (blaster_pull to behind it).
func _hose(prig: Dictionary) -> void:
	var wb: Blaster = prig.wb
	var host: PlayHost = prig.host
	_reset(prig)
	wb.style = "hose"
	var t := _rest(prig, _ahead("hose", 1.5))
	var z0: float = (t.p as Vector3).z
	var most := 0
	for i in int(1.0 / DT):
		wb.fire("right", O, FWD)
		wb.step(DT)
		most = maxi(most, _of(wb, "hose").size())
	var pushes := host.pulled(t)
	var away := pushes.all(func(x: Array) -> bool: return ((x[1] as Vector3) - (x[3] as Vector3)).dot(FWD) > 0.5)
	check(pushes.size() > 10 and away and (t.p as Vector3).z < z0 - 0.15 and host.popped_soft == 0,
		"hose: the stream (%d drops in the air) pushes the target away (%.2f m), no pop" % [most, z0 - (t.p as Vector3).z])
	var hiss := _heard(host, "hose_hiss")
	check(hiss >= 4 and hiss <= int(1.0 / Catalog.HOSE_HISS_GAP) + 1, "hose: its hiss is spaced (%d in 1 s)" % hiss)
	# Both hands on a held hose never push other shots out of the air.
	_reset(prig)
	wb.style = "rocket"
	wb.fire("right", O, Vector3.UP)
	var rocket: Dictionary = wb.shots[0]
	wb.style = "hose"
	for i in int(1.0 / DT):
		wb.fire("left", O, FWD)
		wb.fire("right", O, FWD)
		wb.step(DT)
	check(wb.shots.has(rocket) and wb.shots.size() <= Blaster.SHOTS_MAX, "hose: its drops only take free places (%d shots)" % wb.shots.size())
	# A host with blaster_push gets a shove (a velocity away from you) instead.
	var ph := PushHost.new()
	host.get_parent().add_child(ph)
	var qb: Blaster = Blaster.new()
	ph.add_child(qb)
	qb.setup(ph)
	qb.style = "hose"
	var pt := {"ref": Mark.new(), "p": _ahead("hose", 1.5), "r": BR}
	ph.soft.append(pt)
	for i in int(0.5 / DT):
		qb.fire("right", O, FWD)
		qb.step(DT)
	var vs: Array = ph.pushes.filter(func(x: Array) -> bool: return is_same(x[0], pt))
	check(vs.size() > 5 and vs.all(func(x: Array) -> bool: return (x[1] as Vector3).dot(FWD) > 1.0 and absf((x[1] as Vector3).length() - float(Catalog.SHOT_STYLE.hose.push)) < 1e-3)
		and ph.pulls.is_empty() and ph.popped_soft == 0, "hose: with blaster_push each drop gives it a velocity away from you (%.1f m/s), no pull, no pop" % float(Catalog.SHOT_STYLE.hose.push))
	ph.free()


## The cluster bomb: bursts into its bomblets, which go off all around.
func _cluster(rig: Dictionary) -> void:
	var wb: Blaster = rig.wb
	var host: FakeHost = rig.host
	var P: Dictionary = Catalog.SHOT_STYLE.cluster
	_reset(rig)
	wb.style = "cluster"
	wb.fire("right", O + Vector3.UP, FWD)
	_run(wb, float(P.life) + 0.02)
	var bomblets := _of(wb, "bomblet").size()
	check(bomblets == int(P.pellets) and _of(wb, "cluster").is_empty() and _heard(host, "start_pop") == 1, "cluster: after its fuse it bursts into %d bomblets" % bomblets)
	_run(wb, 2.0, func(): return wb.shots.is_empty())
	var pops := _heard(host, "cluster_pop")
	check(wb.shots.is_empty() and pops >= 1 and pops <= bomblets, "cluster: each bomblet goes off where it lands (%d pops heard)" % pops)
	# Dropped on the floor among six targets: the bomblets pop some of them.
	_reset(rig)
	for i in 6:
		var a := i * TAU / 6.0
		var tt := _rest(rig, Vector3(cos(a) * 0.5, 0.1, sin(a) * 0.5))
		tt.r = 0.2
	wb.fire("right", Vector3(0, 0.5, 0), Vector3.DOWN)
	_run(wb, 3.0, func(): return wb.shots.is_empty())
	check(host.soft.size() < 6 and host.credited("bomblet") >= 1, "cluster: its bomblets' blasts pop targets around it (%d of 6)" % (6 - host.soft.size()))


## The magnet: hangs where its flight ends and pulls metal targets, the host's projectiles
## (stopping those that reach it) and the kit's metal-ish shots.
func _magnet(prig: Dictionary) -> void:
	var wb: Blaster = prig.wb
	var host: PlayHost = prig.host
	var P: Dictionary = Catalog.SHOT_STYLE.magnet
	_reset(prig)
	wb.style = "magnet"
	var park := O + FWD * (0.08 + float(P.speed) * float(P.life) * 0.5)
	var iron := _rest(prig, park + Vector3(1.5, 0.0, 0.0))
	iron.r = 0.1
	iron.metal = true
	var wood := _rest(prig, park + Vector3(-1.5, 0.0, 0.0))
	wood.r = 0.1
	var th := {"ref": Mark.new(), "p": park + Vector3(0.0, 1.2, 0.0), "r": 0.03}
	host.hostile.append(th)
	wb.fire("right", O, FWD)
	var s: Dictionary = wb.shots[0]
	_run(wb, float(P.life) + 0.05)
	check(s.parked and (s.p as Vector3).distance_to(park) < 0.15 and _heard(host, "zing") == 2, "magnet: it flies %.1f m and hangs there (zing)" % (s.p as Vector3).distance_to(O))
	wb.style = "mini"
	var from: Vector3 = (s.p as Vector3) + Vector3(-0.6, 0.0, 0.6)
	wb.fire("left", from - Vector3(0, 0, 0.08), Vector3(0, 0, 1))
	var ball: Dictionary = _of(wb, "mini")[0]
	_run(wb, 0.25)
	check((ball.p as Vector3).x > from.x + 0.02, "magnet: it bends the kit's own shots toward it (%.3f m)" % ((ball.p as Vector3).x - from.x))
	_run(wb, 1.2)
	check(not host.pulled(iron).is_empty() and host.pulled(wood).is_empty() and (host.popped_soft == 1 or (iron.p as Vector3).distance_to(park) < 1.0),
		"magnet: pulls the metal target in (blaster_pull), leaves the other")
	check(not host.pulled(th).is_empty() and host.blocked.size() == 1 and is_same(host.blocked[0][0], th) and host.hostile.is_empty(),
		"magnet: draws a hostile projectile in and stops it (blaster_threats, blaster_block)")
	_run(wb, float(P.linger), func(): return not wb.shots.has(s))
	check(not wb.shots.has(s), "magnet: gone after %.0f s" % float(P.linger))


## The shield: a bubble in front of the hand that rides it and stops the host's projectiles.
func _shield(prig: Dictionary) -> void:
	var wb: Blaster = prig.wb
	var host: PlayHost = prig.host
	var P: Dictionary = Catalog.SHOT_STYLE.shield
	_reset(prig)
	wb.style = "shield"
	host.hand = O
	wb.fire("right", O, FWD)
	var s: Dictionary = wb.shots[0]
	var bub := (s.node as Node3D).get_node_or_null("Bubble") as MeshInstance3D
	check(bub != null and (s.p as Vector3).distance_to(O + FWD * float(P.ahead)) < 1e-4 and _heard(host, "shield_up") == 1,
		"shield: a bubble opens %.2f m in front of the hand (shield_up)" % float(P.ahead))
	host.hand = O + Vector3(0.5, 0.0, 0.0)
	wb.step(DT)
	check((s.p as Vector3).distance_to(host.hand + FWD * float(P.ahead)) < 1e-4, "shield: it rides the hand (blaster_hand)")
	var inside := _rest(prig, s.p)
	var th := {"ref": Mark.new(), "p": (s.p as Vector3) + FWD * 3.0, "r": 0.03}
	var far_off := {"ref": Mark.new(), "p": (s.p as Vector3) + Vector3(3.0, 0.0, 0.0), "r": 0.03}
	host.hostile.append(th)
	host.hostile.append(far_off)
	var flashed := 0.0
	for i in int(1.0 / DT):
		th.p = (th.p as Vector3).move_toward(s.p, 6.0 * DT)
		wb.step(DT)
		flashed = maxf(flashed, float(s.flash))
		if not host.blocked.is_empty():
			break
	check(host.blocked.size() == 1 and is_same(host.blocked[0][0], th) and absf((host.blocked[0][1] as Vector3).distance_to(s.p) - float(P.r)) < 0.02
		and _heard(host, "shield_block") == 1 and flashed > 0.5 and host.hostile == [far_off],
		"shield: a projectile reaching it is stopped at its skin (blaster_block, shield_block), one out of reach is not")
	check(host.soft.has(inside) and host.popped_soft == 0, "shield: it pops nothing (a defence only)")
	wb.clock += float(P.cool) + 0.01
	wb.fire("right", O, FWD)
	wb.fire("left", O, FWD)
	check(_of(wb, "shield").size() == 2 and not wb.shots.has(s), "shield: one bubble a hand (a new one takes the last one's place)")
	_run(wb, float(P.life) + 0.2)
	check(_of(wb, "shield").is_empty() and _heard(host, "start_pop") >= 2, "shield: they pop after %.0f s" % float(P.life))
	# No host at all: it still opens in front of where it was fired.
	var nb: Blaster = Blaster.new()
	host.get_parent().add_child(nb)
	nb.style = "shield"
	nb.fire("right", O, FWD)
	var ns: Dictionary = nb.shots[0]
	nb.step(DT)
	check((ns.p as Vector3).distance_to(O + FWD * float(P.ahead)) < 1e-4 and (ns.node as Node3D).get_node_or_null("Bubble") != null and (ns.node as Node3D).is_inside_tree(),
		"shield: with no host it still opens and draws, where it was fired")
	nb.free()


## The shots grow and shrink with blaster_scale().
func _scale(rig: Dictionary) -> void:
	var wb: Blaster = rig.wb
	var host: FakeHost = rig.host
	_reset(rig)
	host.units = 8.0
	var bad: Array = []
	for id: String in ["bolt", "rocket", "boomerang", "glob", "confetti"]:
		wb.style = id
		wb.last_shot = {"left": -10.0, "right": -10.0}
		wb.clear()
		wb.fire("right", O * 8.0, FWD)
		var s: Dictionary = wb.shots[0]
		if absf(float(s.r) - float(Catalog.SHOT_STYLE[id].r) * 8.0) > 1e-4:
			bad.append(id)
		var want: float = float(Catalog.SHOT_STYLE[id].speed) * 8.0 * (0.15 if id == "rocket" else 1.0)
		if id != "boomerang" and absf((s.v as Vector3).length() - want) > 1e-3:
			bad.append(id + ":speed")
	wb.style = "laser"
	wb.clear()
	wb.last_shot = {"left": -10.0, "right": -10.0}
	wb.fire("right", O * 8.0, FWD)
	if wb.arcs.is_empty() or absf(float(wb.arcs[0].w) - 0.022 * 8.0) > 1e-4:
		bad.append("laser")
	check(bad.is_empty(), "shots: sizes and speeds scale with blaster_scale() %s" % [bad])
	host.units = 1.0
	wb.clear()


## Floating texts and ignored meshes in front of a wall: the ray goes through them to the wall.
func _through_text(rig: Dictionary) -> void:
	var wb: Blaster = rig.wb
	_reset(rig)
	var st := _stage(rig)
	st.add_wall(O + FWD * 3.0, Vector3(3, 3, 0.2))
	var text := MeshInstance3D.new()
	var tm := TextMesh.new()
	tm.text = "WAVE 1"
	tm.depth = 0.1
	tm.pixel_size = 0.05
	text.mesh = tm
	text.position = O + FWD * 1.5
	st.add_child(text)
	var deco := st.add_wall(O + FWD * 2.0, Vector3(2, 2, 0.05))
	deco.add_to_group(&"blaster_ignore")
	var hit := wb.ray_stage(st, O, FWD, 10.0)
	check(not hit.is_empty() and (hit.point as Vector3).distance_to(O) > 2.5,
		"shots: fly through texts and blaster_ignore meshes and hit what is behind them (%s)" % [hit.get("point", "none")])


## The host's walls (blaster_collide): a bolt stops at one, a bouncy ball bounces back, the
## laser's beam ends there.
func _walls(rig: Dictionary) -> void:
	var wb: Blaster = rig.wb
	var host: FakeHost = rig.host
	_reset(rig)
	host.walls = [-3.0]
	wb.style = "bolt"
	wb.fire("right", O, FWD)
	var s: Dictionary = wb.shots[0]
	_run(wb, 1.0, func(): return wb.shots.is_empty())
	check(wb.shots.is_empty() and (s.p as Vector3).z > -3.2, "walls: a bolt stops at the host's wall (z %.2f)" % (s.p as Vector3).z)
	_reset(rig)
	host.walls = [-3.0]
	wb.style = "bouncy"
	wb.fire("right", O, FWD)
	s = wb.shots[0]
	var turned := false
	for i in int(1.5 / DT):
		wb.step(DT)
		if (s.v as Vector3).z > 0.0:
			turned = true
			break
	check(turned and (s.p as Vector3).z > -3.2, "walls: a bouncy ball bounces back off it")
	_reset(rig)
	host.walls = [-3.0]
	wb.style = "laser"
	wb.fire("right", O, FWD)
	check(not wb.arcs.is_empty() and (wb.arcs[0].b as Vector3).z > -3.6, "walls: the laser's beam ends at it (z %.2f)" % (wb.arcs[0].b as Vector3).z)
	host.walls.clear()


func _signals(rig: Dictionary) -> void:
	var wb: Blaster = rig.wb
	_reset(rig)
	var got := {"fired": [], "hit": []}
	var on_fire := func(kind: String, hand: String) -> void: got.fired.append([kind, hand])
	var on_hit := func(kind: String, target: Variant) -> void: got.hit.append([kind, target])
	wb.shot_fired.connect(on_fire)
	wb.shot_hit.connect(on_hit)
	wb.style = "bolt"
	var t := _rest(rig, O + FWD * 2.0)
	wb.fire("left", O, FWD)
	_run(wb, 1.0, func(): return wb.shots.is_empty())
	wb.shot_fired.disconnect(on_fire)
	wb.shot_hit.disconnect(on_hit)
	check(got.fired.size() == 1 and got.fired[0] == ["bolt", "left"] and got.hit.size() == 1 and got.hit[0][0] == "bolt" and is_same(got.hit[0][1].ref, t.ref),
		"signals: shot_fired and shot_hit (with the host's own target)")
	_reset(rig)
	var st := _stage(rig)
	st.add_target(O + FWD * 2.0, 0.2)
	wb.style = "boomerang"
	var shot := wb.fire("right", O, FWD)
	var again := wb.fire("right", O, FWD)
	check(shot and not again and wb.shot_count() == 1, "api: fire() says whether it fired; shot_count() counts what flies")
	wb.clear()
	check(wb.shot_count() == 0 and wb.sparks.is_empty() and wb.arcs.is_empty(), "api: clear() empties the air")
	_reset(rig)
	wb.style = "bolt"
	var point := O + Vector3(2.0, 0.5, -6.0)
	var aimed := wb.fire_at(O, point, "left")
	var b: Dictionary = wb.shots[0]
	check(aimed and (b.dir as Vector3).angle_to(point - O) < 1e-4 and b.aim == point and b.hand == "left",
		"api: fire_at(origin, point) aims at the point and keeps it on the shot")
	_reset(rig)
	wb.style = "laser"
	_rest(rig, O + Vector3(1.0, 0.0, -3.0))
	wb.fire_at(O, O + Vector3(2.0, 0.0, -6.0))
	check((rig.host as FakeHost).soft.is_empty(), "api: fire_at works for the instant styles too (the laser hits what lies on the line)")


## No host at all: every style fires, flies against `stage` and the floor, and ends.
func _no_host(parent: Node) -> void:
	var wb: Blaster = Blaster.new()
	parent.add_child(wb)
	var st := TargetStage.new()
	parent.add_child(st)
	wb.stage = st
	st.sturdy = true
	st.add_target(O + FWD * 3.0, 0.3)
	var fired_all := true
	for id: String in Catalog.ids():
		wb.style = id
		wb.clock += 5.0
		if not wb.fire("right", O, Vector3(0.03, -0.02, -1).normalized()):
			fired_all = false
		for i in int(0.5 / DT):
			wb.step(DT)
	for i in int(12.0 / DT):
		wb.step(DT)
	check(fired_all and wb.shot_count() == 0 and st.hits >= 1, "no host: every style fires, hits the `stage` target and is gone in time (%d left, %d hits)" % [wb.shot_count(), st.hits])
	var playing := 0
	for p: Node in wb.audio.get_children():
		if p is AudioStreamPlayer3D and (p as AudioStreamPlayer3D).stream != null:
			playing += 1
	check(playing > 0, "no host: the built-in player plays the bundled sounds (%d players used)" % playing)
	wb.free()
	st.free()

