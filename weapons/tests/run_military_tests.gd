extends SceneTree
## The military pack's checks (AB-W-023 ... AB-W-040), through the host interface, on a
## small test table: dry land with a hill, a sea strip, a glass-dome ceiling and (for one
## check) a tower block.
## Every weapon lands where it was aimed, the MLRS fires its salvo of 8 and the drone swarm
## its 6, the cluster missile opens into 10 bomblets, every aircraft (strike jet, bunker
## buster, glide bombs, helicopter) releases its load and lands back aboard, the recon
## drone reports what it overflies and lands, the anti-air missile homes on a moving air
## target (or flies to a point, or does not fire with nothing in the air), the torpedo
## runs under the water and stops at the shore, the hypersonic missile glides and weaves,
## the nuke reports its radius and runs its shock wave, the host's air defence shoots
## shots and aircraft down, low flyers climb over a building, a shot into the sea
## splashes, arcs, aircraft and smoke stay under the ceiling, ammo / cooldown / reload
## hold, the ship's launchers are used, and with no host at all everything still runs.
##
##   godot --headless --path blaster-kit -s res://tests/run_military_tests.gd
## Prints PASS / FAIL per check, exits 1 if any failed.

const Catalog := preload("res://addons/aboden_blaster/military/military_catalog.gd")
const Launcher := preload("res://addons/aboden_blaster/military/military_launcher.gd")
const Flight := preload("res://addons/aboden_blaster/military/military_flight.gd")
const Ship := preload("res://addons/aboden_blaster/military/military_ship.gd")
const ShotCatalog := preload("res://addons/aboden_blaster/shot_catalog.gd")

const DT := 1.0 / 72.0
## The real-world example of each weapon, as the game's web HUD shows it.
const REAL := {"ballistic": "Iskander", "cruise": "Tomahawk", "hypersonic": "Kinzhal",
	"artillery": "M777", "mlrs": "HIMARS", "cluster": "ATACMS", "bunker": "GBU-57",
	"glide": "GBU-39", "jet": "F-15E", "heli": "AH-64 Apache", "drone": "Shahed-136",
	"swarm": "Lancet", "atgm": "Javelin", "antiship": "Harpoon", "torpedo": "Mk 48",
	"aa": "Patriot", "nuke": "B61", "recon": "ScanEagle"}
const LAND := Vector3(0.12, 0.0, 0.10)    # a flat point on land (y filled from the table)
const SEA := Vector3(-0.30, 0.0, 0.12)

var passed := 0
var failed := 0
var _started := false


## The test table: land for x > -0.2 (ground 0.02, a hill at (0.25, 0, -0.1)), sea
## (surface 0, depth 0.01) for x <= -0.2, nothing beyond 0.6; a dome R 0.55, K 0.6.
class Table:
	extends Node3D
	const R := 0.55
	const K := 0.6
	var hits: Array = []
	var sounds: Array = []
	var scans: Array = []
	var shocks: Array = []
	var towers: Array = []          # [Vector2 centre, half size, top]
	var air_mode := "aim"           # military_air_target: "aim" (the point), "node", "none"
	var air_node: Node3D
	func ground(x: float, z: float) -> float:
		if x <= -0.2:
			return -0.01
		return 0.02 + 0.05 * exp(-((x - 0.25) * (x - 0.25) + (z + 0.1) * (z + 0.1)) / 0.004)
	func military_surface(x: float, z: float) -> float:
		if absf(x) > 0.6 or absf(z) > 0.6:
			return -INF
		return maxf(ground(x, z), 0.0)
	func military_water_depth(x: float, z: float) -> float:
		return maxf(0.0, -ground(x, z))
	func military_ceiling(x: float, z: float) -> float:
		var r2 := x * x + z * z
		return 0.0 if r2 >= R * R else K * sqrt(R * R - r2)
	func military_hit(p: Vector3, info: Dictionary) -> void:
		hits.append([p, info])
	func military_sfx(snd: String, k: float, pos: Vector3) -> void:
		sounds.append([snd, k, pos])
	func military_roof(x: float, z: float) -> float:
		for t in towers:
			var c: Vector2 = t[0]
			if absf(x - c.x) < float(t[1]) and absf(z - c.y) < float(t[1]):
				return float(t[2])
		return -INF
	func military_air_target(_from: Vector3, aim: Vector3) -> Variant:
		match air_mode:
			"node":
				return air_node
			"none":
				return null
		return aim
	func military_scan(p: Vector3, r: float) -> void:
		scans.append([p, r])
	func military_shock(p: Vector3, r0: float, r1: float, k: float) -> void:
		shocks.append([p, r0, r1, k])


func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run_all()
	return false


func _run_all() -> void:
	var table := Table.new()
	root.add_child(table)
	var ml: Launcher = Launcher.new()
	ml.auto_step = false
	table.add_child(ml)
	ml.setup(table)
	ml.set_seed(11)
	var ship: Ship = Ship.new()
	ship.position = Vector3(-0.24, 0.0, -0.12)
	ml.add_child(ship)
	ml.ship = ship
	var rig := {"table": table, "ml": ml, "ship": ship}
	_catalog()
	_each_weapon(rig)
	_salvo(rig)
	_swarm(rig)
	_cluster(rig)
	_jet(rig)
	for id in ["bunker", "glide", "heli"]:
		_sortie(rig, id)
	_recon(rig)
	_aa(rig)
	_torpedo(rig)
	_glide_path(rig)
	_roofs(rig)
	_shoot_down(rig)
	_nuke(rig)
	_water(rig)
	_ceiling(rig)
	_ammo(rig)
	_ship(rig)
	_no_host()
	table.free()
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


func _on(rig: Dictionary, p: Vector3) -> Vector3:
	return Vector3(p.x, (rig.table as Table).military_surface(p.x, p.z), p.z)


func _reset(rig: Dictionary) -> void:
	var ml: Launcher = rig.ml
	ml.clear()
	ml.refill()
	var t: Table = rig.table
	t.hits.clear()
	t.sounds.clear()
	t.scans.clear()
	t.shocks.clear()
	t.towers.clear()
	t.air_mode = "aim"


func _run(ml: Launcher, seconds: float, until := Callable()) -> void:
	for i in int(seconds / DT):
		ml.step(DT)
		if until.is_valid() and until.call():
			return


func _catalog() -> void:
	var codes := {}
	var bad: Array = []
	var k := 23
	for id: String in Catalog.ids():
		var w := Catalog.get_weapon(id)
		var want := "AB-W-%03d" % k
		k += 1
		if str(w.code) != want or codes.has(w.code) or ShotCatalog.by_code(str(w.code)) != "" or ShotCatalog.RESERVED.has(w.code):
			bad.append(id)
		codes[w.code] = id
		for key in ["ar", "en", "ar_desc", "en_desc", "arc", "blast", "cooldown", "ammo", "reload", "trail", "length", "radius", "col", "launcher", "delivery", "trajectory", "hit", "role", "tier",
				"example", "ar_short", "intercept", "version"]:
			if not w.has(key):
				bad.append("%s.%s" % [id, key])
		for axis in ["delivery", "trajectory", "hit", "role"]:
			if not ShotCatalog.AXES[axis].has(w[axis]):
				bad.append("%s.%s=%s" % [id, axis, w[axis]])
		if Catalog.by_code(str(w.code)) != id:
			bad.append("by_code " + id)
		if w.has("bomb") and not Catalog.SUB.has(str(w.bomb)):
			bad.append("%s.bomb" % id)
		if str(w.example) != str(REAL.get(id, "")):
			bad.append("%s.example" % id)
	var game := Catalog.GAME_ORDER.duplicate()
	game.sort()
	var ours := Catalog.ids().duplicate()
	ours.sort()
	check(bad.is_empty() and Catalog.ids().size() == 18 and ShotCatalog.next_code() == "AB-W-041" and ShotCatalog.PACKS.has("military") and game == ours,
		"military catalog: 18 weapons AB-W-023..040 in order, unique, no clash with the playful pack or its reserved codes, every field and axis valid, a real-world example each, the game's 18 %s" % [bad])


## Every single-shot weapon (not the salvo / cluster / jet, checked on their own) lands
## within 2 cm of the target and goes off on land.
func _each_weapon(rig: Dictionary) -> void:
	var ml: Launcher = rig.ml
	var table: Table = rig.table
	for id in ["ballistic", "cruise", "artillery", "hypersonic", "drone", "antiship", "atgm"]:
		_reset(rig)
		var tgt := _on(rig, LAND)
		var fired := ml.fire(tgt, id)
		_run(ml, 12.0, func() -> bool: return not table.hits.is_empty())
		var ok := fired and table.hits.size() == 1
		var d := INF
		var kind := ""
		if ok:
			d = (table.hits[0][0] as Vector3).distance_to(tgt)
			kind = str(table.hits[0][1].kind)
		var snd := table.sounds.map(func(s: Array) -> String: return s[0])
		var info: Dictionary = table.hits[0][1] if ok else {}
		var armor: bool = not Catalog.WEAPONS[id].has("anti_armor") or is_equal_approx(float(info.get("armor_r", 0.0)), float(info.blast_r) * 2.6)
		check(ok and d < 0.02 and kind == "land" and snd.has("launch") and snd.has("boom") and armor and is_equal_approx(float(info.blast_r), Catalog.BLAST_R * float(Catalog.WEAPONS[id].blast)),
			"%s (%s) lands %.1f mm from the target, on land, blast_r %.1f mm%s, with launch and boom sounds" % [id, Catalog.get_weapon(id).code, d * 1000.0,
			float(info.get("blast_r", 0.0)) * 1000.0, (", armour within %.1f mm" % (float(info.armor_r) * 1000.0)) if info.has("armor_r") else ""])


func _salvo(rig: Dictionary) -> void:
	var ml: Launcher = rig.ml
	var table: Table = rig.table
	_reset(rig)
	var tgt := _on(rig, LAND)
	var launches := [0]
	var count := func(_id: String, _f: Vector3, _t: Vector3, _s: bool) -> void: launches[0] += 1
	ml.launched.connect(count)
	ml.fire(tgt, "mlrs")
	_run(ml, 6.0, func() -> bool: return table.hits.size() >= 8 and not ml.flying)
	ml.launched.disconnect(count)
	var far := 0.0
	for h in table.hits:
		far = maxf(far, Vector2((h[0] as Vector3).x - tgt.x, (h[0] as Vector3).z - tgt.z).length())
	check(launches[0] == 8 and table.hits.size() == 8 and far <= float(Catalog.WEAPONS.mlrs.spread) + 0.01,
		"mlrs: a salvo of %d rockets, %d impacts, all within %.0f mm of the target" % [launches[0], table.hits.size(), far * 1000.0])



## The drone swarm: 6 small drones, one every salvo_gap (0.22 s), spread over the target.
func _swarm(rig: Dictionary) -> void:
	var ml: Launcher = rig.ml
	var table: Table = rig.table
	_reset(rig)
	var tgt := _on(rig, LAND)
	var times := []
	var rec := func(id: String, _f: Vector3, _t: Vector3, _s: bool) -> void:
		if id == "swarm":
			times.append(ml.sim_time)
	ml.launched.connect(rec)
	ml.fire(tgt, "swarm")
	_run(ml, 14.0, func() -> bool: return table.hits.size() >= 6 and not ml.flying)
	ml.launched.disconnect(rec)
	var far := 0.0
	for h in table.hits:
		far = maxf(far, Vector2((h[0] as Vector3).x - tgt.x, (h[0] as Vector3).z - tgt.z).length())
	var gap: float = (times[1] - times[0]) if times.size() > 1 else 0.0
	check(times.size() == 6 and table.hits.size() == 6 and absf(gap - 0.22) < 0.02 and far <= float(Catalog.WEAPONS.swarm.spread) + 0.01
		and table.hits.all(func(h: Array) -> bool: return h[1].id == "swarm" and h[1].kind == "land"),
		"swarm: %d drones %.2f s apart, %d impacts, all within %.0f mm of the target" % [times.size(), gap, table.hits.size(), far * 1000.0])


## Any aircraft (bunker buster, glide bombs, helicopter): takes off, releases its load of
## `bomb` over the target, stays under the ceiling, lands back and is aboard again.
func _sortie(rig: Dictionary, id: String) -> void:
	var ml: Launcher = rig.ml
	var table: Table = rig.table
	_reset(rig)
	var w := Catalog.get_weapon(id)
	var tgt := _on(rig, LAND)
	var landed := []
	var on_land := func(i: String) -> void: landed.append(i)
	ml.sortie_landed.connect(on_land)
	var rel := []
	var on_launch := func(i: String, f: Vector3, _t: Vector3, sub: bool) -> void:
		if sub:
			rel.append(f)
	ml.launched.connect(on_launch)
	var full := ml.ammo(id)
	ml.fire(tgt, id)
	var out := ml.ammo(id)
	var under := true
	for i in int(60.0 / DT):
		ml.step(DT)
		for f in ml.flights:
			var p: Vector3 = (f.slot.node as Node3D).position
			if p.y > table.military_ceiling(p.x, p.z):
				under = false
		if not landed.is_empty() and not ml.flying:
			break
	ml.sortie_landed.disconnect(on_land)
	ml.launched.disconnect(on_launch)
	var bombs := table.hits.filter(func(h: Array) -> bool: return h[1].id == str(w.bomb))
	var far := 0.0
	for h in bombs:
		far = maxf(far, Vector2((h[0] as Vector3).x - tgt.x, (h[0] as Vector3).z - tgt.z).length())
	var lead := 0.0
	for r in rel:
		lead = maxf(lead, Vector2((r as Vector3).x - tgt.x, (r as Vector3).z - tgt.z).length())
	var extra := true
	if id == "bunker":
		extra = bombs.size() == 1 and float(bombs[0][1].crater_d) > Catalog.CRATER_D * 2.0
	elif id == "glide":
		extra = lead > 0.12
	elif id == "heli":
		extra = bombs.all(func(h: Array) -> bool: return h[1].has("armor_r"))
	check(bombs.size() == int(w.bombs) and far < float(w.spread) + 0.02 and landed == [id] and out == full - 1 and ml.ammo(id) == full and under and extra,
		"%s (%s): takes off, releases %d x %s %.0f mm out, all within %.0f mm of the target, stays under the ceiling, lands back (%d of %d aboard)" % [
		id, w.code, bombs.size(), w.bomb, lead * 1000.0, far * 1000.0, ml.ammo(id), full])


## The recon drone: circles the area, reports what it overflies (recon_scan, military_scan:
## the drone's position and its scan radius), goes off nowhere, lands back.
func _recon(rig: Dictionary) -> void:
	var ml: Launcher = rig.ml
	var table: Table = rig.table
	_reset(rig)
	var tgt := _on(rig, LAND)
	var sigs := []
	var on_scan := func(p: Vector3, r: float) -> void: sigs.append([p, r])
	ml.recon_scan.connect(on_scan)
	var landed := []
	var on_land := func(i: String) -> void: landed.append(i)
	ml.sortie_landed.connect(on_land)
	ml.fire(tgt, "recon")
	var out := ml.ammo("recon")
	_run(ml, 80.0, func() -> bool: return not landed.is_empty() and not ml.flying)
	ml.recon_scan.disconnect(on_scan)
	ml.sortie_landed.disconnect(on_land)
	var near := 0
	for sc in sigs:
		var p: Vector3 = sc[0]
		if Vector2(p.x - tgt.x, p.z - tgt.z).length() < float(Catalog.WEAPONS.recon.orbit) + 0.01:
			near += 1
	check(sigs.size() > 40 and near > sigs.size() / 2 and table.scans.size() == sigs.size() and is_equal_approx(float(sigs[0][1]), 0.075)
		and table.hits.is_empty() and landed == ["recon"] and out == 0 and ml.ammo("recon") == 1,
		"recon: %d scans of radius %.3f (%d on its circles round the target), the host told each, no blast, lands back" % [sigs.size(), float(sigs[0][1]) if not sigs.is_empty() else 0.0, near])


## The anti-air missile: homes on a moving air target the host names and bursts on it
## (kind "air", info.target); with nothing in the air it does not fire; a target that is
## gone makes it self-destruct.
func _aa(rig: Dictionary) -> void:
	var ml: Launcher = rig.ml
	var table: Table = rig.table
	_reset(rig)
	var plane := Node3D.new()
	table.add_child(plane)
	plane.position = Vector3(-0.05, 0.15, 0.05)
	table.air_node = plane
	# the host hands back a point in the air: it flies there and bursts
	var sky := Vector3(0.0, 0.12, 0.0)
	ml.fire(sky, "aa")
	_run(ml, 4.0, func() -> bool: return not table.hits.is_empty())
	var point_ok: bool = table.hits.size() == 1 and str(table.hits[0][1].kind) == "air" and (table.hits[0][0] as Vector3).distance_to(sky) < 0.01
	_reset(rig)
	table.air_node = plane
	table.air_mode = "none"
	var full := ml.ammo("aa")
	var none := not ml.fire(_on(rig, LAND), "aa") and ml.ammo("aa") == full
	table.air_mode = "node"
	var fired := ml.fire(_on(rig, LAND), "aa")
	var t := 0.0
	for i in int(6.0 / DT):
		plane.position += Vector3(0.1, 0.0, 0.0) * DT
		ml.step(DT)
		t += DT
		if not table.hits.is_empty():
			break
	var info: Dictionary = table.hits[0][1] if not table.hits.is_empty() else {}
	var d: float = (table.hits[0][0] as Vector3).distance_to(plane.position) if not table.hits.is_empty() else INF
	var hit_ok: bool = fired and info.get("kind", "") == "air" and info.get("target") == plane and d < 0.012
	# a target that disappears: the missile self-destructs, no impact
	_reset(rig)
	table.air_mode = "node"
	var lost := []
	var on_lost := func(id: String, _p: Vector3, by_host: bool) -> void: lost.append([id, by_host])
	ml.shot_down.connect(on_lost)
	ml.fire(_on(rig, LAND), "aa")
	_run(ml, 0.2)
	plane.free()
	_run(ml, 2.0, func() -> bool: return not ml.flying)
	ml.shot_down.disconnect(on_lost)
	var gone_ok := lost == [["aa", false]] and table.hits.is_empty() and not ml.flying
	check(point_ok and none and hit_ok and gone_ok,
		"aa: a point in the air -> bursts there; no air target -> does not fire; homes on a moving target and bursts %.1f mm from it after %.2f s (kind air, the target in info); target gone -> self-destructs" % [d * 1000.0, t])


## The torpedo: runs under the water surface to a point at sea (a water burst there), and
## stops and goes off at the shore when the target is on land.
func _torpedo(rig: Dictionary) -> void:
	var ml: Launcher = rig.ml
	var table: Table = rig.table
	_reset(rig)
	var sea_t := _on(rig, SEA)
	var pl := ml.plan(sea_t, "torpedo")
	var under := true
	var pts: PackedVector3Array = pl.pts
	for k in range(3, pts.size() - 1):
		if pts[k].y >= table.military_surface(pts[k].x, pts[k].z):
			under = false
	ml.fire(sea_t, "torpedo")
	_run(ml, 12.0, func() -> bool: return not table.hits.is_empty())
	var sea_ok := table.hits.size() == 1 and str(table.hits[0][1].kind) == "water" and (table.hits[0][0] as Vector3).distance_to(sea_t) < 0.003
	var t_sea := ml.sim_time
	_reset(rig)
	ml.fire(_on(rig, LAND), "torpedo")
	_run(ml, 12.0, func() -> bool: return not table.hits.is_empty())
	var shore: Vector3 = table.hits[0][0] if not table.hits.is_empty() else Vector3.INF
	check(under and sea_ok and pl.type == "torpedo" and shore.x > -0.21 and shore.x < -0.19,
		"torpedo: runs under the surface (%d points) to the target at sea, a water burst there; aimed at land it stops at the shore (x %.3f)" % [pts.size(), shore.x])


## The hypersonic glide missile: boosts up, glides weaving side to side, dives onto the
## target; stays under the ceiling.
func _glide_path(rig: Dictionary) -> void:
	var ml: Launcher = rig.ml
	var table: Table = rig.table
	var tgt := _on(rig, LAND)
	var o := ml.launch_point("hypersonic")
	var pl := ml.plan(tgt, "hypersonic")
	var dir := Vector2(tgt.x - o.x, tgt.z - o.z).normalized()
	var side := Vector2(-dir.y, dir.x)
	var off_l := 0.0
	var off_r := 0.0
	var under := true
	for k in 100:
		var q := Flight.position_at(pl, float(pl.T) * k / 99.0)
		var lat := Vector2(q.x - o.x, q.z - o.z).dot(side)
		off_l = minf(off_l, lat)
		off_r = maxf(off_r, lat)
		if q.y > table.military_ceiling(q.x, q.z):
			under = false
	var vend := Flight.velocity_at(pl, float(pl.T) - 0.02)
	check(pl.type == "glide" and off_l < -0.005 and off_r > 0.005 and under and vend.y < -0.5 * Vector2(vend.x, vend.z).length()
		and float(pl.T) >= 1.1 and float(pl.T) <= 2.2,
		"hypersonic: a glide that weaves %.0f / %.0f mm to each side, under the ceiling, a steep terminal dive, %.2f s" % [off_l * 1000.0, off_r * 1000.0, float(pl.T)])


## Low flyers climb over a building in their way (military_roof) and still hit the target behind it.
func _roofs(rig: Dictionary) -> void:
	var ml: Launcher = rig.ml
	var table: Table = rig.table
	_reset(rig)
	var tgt := _on(rig, LAND)
	var o := ml.launch_point("cruise")
	var mid := Vector2(o.x, o.z).lerp(Vector2(tgt.x, tgt.z), 0.75)
	table.towers.append([mid, 0.008, 0.02 + 0.03])
	var pl := ml.plan(tgt, "cruise")
	var clear := true
	var pts: PackedVector3Array = pl.pts
	for q in pts:
		var r := table.military_roof(q.x, q.z)
		if r > -INF and q.y < r:
			clear = false
	ml.fire(tgt, "cruise")
	_run(ml, 8.0, func() -> bool: return not table.hits.is_empty())
	var d: float = (table.hits[0][0] as Vector3).distance_to(tgt) if not table.hits.is_empty() else INF
	check(clear and not pl.crash and d < 0.003,
		"roofs: a cruise missile climbs over a 30 mm tower block in its way and hits the target behind it (%.1f mm)" % (d * 1000.0))


## The host's air defence: air_shots() lists what is up, shoot_down() destroys it: a
## cruise missile goes without an impact; a strike jet is lost (sortie_lost) and its
## replacement comes aboard LOST_RELOAD s later.
func _shoot_down(rig: Dictionary) -> void:
	var ml: Launcher = rig.ml
	var table: Table = rig.table
	_reset(rig)
	var downs := []
	var on_down := func(id: String, _p: Vector3, by_host: bool) -> void: downs.append([id, by_host])
	ml.shot_down.connect(on_down)
	var lost := []
	var on_lost := func(id: String) -> void: lost.append(id)
	ml.sortie_lost.connect(on_lost)
	ml.fire(_on(rig, LAND), "cruise")
	ml.fire(_on(rig, LAND), "jet")
	_run(ml, 0.5)
	var up := ml.air_shots()
	var cm: Array = up.filter(func(a: Dictionary) -> bool: return a.id == "cruise")
	var jt: Array = up.filter(func(a: Dictionary) -> bool: return a.id == "jet")
	var listed: bool = cm.size() == 1 and jt.size() == 1 and jt[0].aircraft and not cm[0].aircraft and is_equal_approx(float(cm[0].intercept), 0.6)
	var a := listed and ml.shoot_down(int(cm[0].serial)) and ml.shoot_down(int(jt[0].serial))
	var aboard := ml.ammo("jet")
	_run(ml, 5.0)
	var no_hit := table.hits.is_empty()
	_run(ml, Launcher.LOST_RELOAD)
	ml.shot_down.disconnect(on_down)
	ml.sortie_lost.disconnect(on_lost)
	check(a and downs == [["cruise", true], ["jet", true]] and lost == ["jet"] and no_hit and aboard == 1 and ml.ammo("jet") == 2 and not ml.shoot_down(12345),
		"air defence: air_shots lists the cruise missile and the jet, shoot_down destroys both (no impact), the jet is lost and replaced after %.0f s" % Launcher.LOST_RELOAD)

func _cluster(rig: Dictionary) -> void:
	var ml: Launcher = rig.ml
	var table: Table = rig.table
	_reset(rig)
	var tgt := _on(rig, LAND)
	ml.fire(tgt, "cluster")
	_run(ml, 8.0, func() -> bool: return table.hits.size() >= 10 and not ml.flying)
	var ids := {}
	var far := 0.0
	for h in table.hits:
		ids[h[1].id] = true
		far = maxf(far, Vector2((h[0] as Vector3).x - tgt.x, (h[0] as Vector3).z - tgt.z).length())
	check(table.hits.size() == 10 and ids.keys() == ["submunition"] and far <= float(Catalog.WEAPONS.cluster.spread) + 0.01,
		"cluster: opens into %d bomblets, all within %.0f mm of the target" % [table.hits.size(), far * 1000.0])


func _jet(rig: Dictionary) -> void:
	var ml: Launcher = rig.ml
	var ship: Ship = rig.ship
	var table: Table = rig.table
	_reset(rig)
	var tgt := _on(rig, LAND)
	var landed := []
	var on_land := func(id: String) -> void: landed.append(id)
	ml.sortie_landed.connect(on_land)
	var full := ml.ammo("jet")
	ml.fire(tgt, "jet")
	var out := ml.ammo("jet")
	var parked_out := ship.parked.filter(func(j: MeshInstance3D) -> bool: return j.visible).size()
	var top := -INF
	var under := true
	for i in int(40.0 / DT):
		ml.step(DT)
		for f in ml.flights:
			if f.plan.get("sortie", false):
				var p: Vector3 = (f.slot.node as Node3D).position
				top = maxf(top, p.y)
				if p.y > table.military_ceiling(p.x, p.z):
					if under:
						print("  over: ", p, " ceil ", table.military_ceiling(p.x, p.z), " t ", f.t, " / ", f.plan.T)
					under = false
		if not landed.is_empty() and not ml.flying:
			break
	ml.sortie_landed.disconnect(on_land)
	var bombs := table.hits.filter(func(h: Array) -> bool: return h[1].id == "jetbomb")
	var far := 0.0
	for h in bombs:
		far = maxf(far, Vector2((h[0] as Vector3).x - tgt.x, (h[0] as Vector3).z - tgt.z).length())
	var parked_back := ship.parked.filter(func(j: MeshInstance3D) -> bool: return j.visible).size()
	check(bombs.size() == 4 and far < 0.05 and landed == ["jet"] and out == full - 1 and ml.ammo("jet") == full
		and parked_out == full - 1 and parked_back == full and under,
		"jet: takes off (%d of %d aboard), drops %d bombs within %.0f mm, stays under the ceiling, lands back (%d aboard)" % [out, full, bombs.size(), far * 1000.0, ml.ammo("jet")])


func _nuke(rig: Dictionary) -> void:
	var ml: Launcher = rig.ml
	var table: Table = rig.table
	_reset(rig)
	var tgt := _on(rig, LAND)
	var waves := []
	var on_wave := func(_p: Vector3, _a: float, b: float, k: float) -> void: waves.append([b, k])
	ml.shock_wave.connect(on_wave)
	ml.fire(tgt, "nuke")
	_run(ml, 8.0, func() -> bool: return not table.hits.is_empty())
	var info: Dictionary = table.hits[0][1] if not table.hits.is_empty() else {}
	_run(ml, 3.5)
	ml.shock_wave.disconnect(on_wave)
	var puffs := ml.fx.puffs.size()
	var grows := waves.size() > 10
	for k in range(1, waves.size()):
		if float(waves[k][0]) < float(waves[k - 1][0]):
			grows = false
	var last: float = waves[waves.size() - 1][0] if not waves.is_empty() else 0.0
	check(info.get("kind", "") == "nuke" and is_equal_approx(float(info.get("nuke_r", 0.0)), 0.16) and is_equal_approx(float(info.get("wave_r", 0.0)), 0.16 * 2.6)
		and puffs > 150 and ml.ammo("nuke") == 0 and not ml.can_fire("nuke") and grows and is_equal_approx(last, 0.416)
		and table.shocks.size() == waves.size() and not ml.shocking,
		"nuke: a nuclear test, radius %.2f, %d puffs after 3.5 s (flash, rising fireball, mushroom); shock wave out to %.3f in %d steps (host told each); one round only" % [float(info.get("nuke_r", 0.0)), puffs, last, waves.size()])


func _water(rig: Dictionary) -> void:
	var ml: Launcher = rig.ml
	var table: Table = rig.table
	_reset(rig)
	ml.fire(_on(rig, SEA), "artillery")
	_run(ml, 6.0, func() -> bool: return not table.hits.is_empty())
	var kind := str(table.hits[0][1].kind) if not table.hits.is_empty() else ""
	var snd := table.sounds.map(func(s: Array) -> String: return s[0])
	check(kind == "water" and snd.has("thump") and not snd.has("boom") and ml.fx.ripples.size() > 0,
		"a shot into the sea: water splash, ripples and a thump, no explosion (%s)" % kind)


## Lofted arcs that would rise through the dome are flattened under it; the smoke of a
## big blast spreads under it instead of rising through.
func _ceiling(rig: Dictionary) -> void:
	var ml: Launcher = rig.ml
	var table: Table = rig.table
	_reset(rig)
	var bad: Array = []
	var flat := Flight.plan(Catalog.get_weapon("nuke"), ml.launch_point("nuke"), _on(rig, LAND), ml.surface, Catalog.G)
	var pl := ml.plan(_on(rig, LAND), "nuke")
	var open_top := -INF
	for k in 64:
		open_top = maxf(open_top, Flight.position_at(flat, float(flat.T) * k / 63.0).y)
	for id in ["ballistic", "cluster", "hypersonic", "atgm", "nuke", "artillery", "mlrs", "recon", "glide", "heli", "bunker"]:
		var p := ml.plan(_on(rig, LAND), id)
		for k in 64:
			var q := Flight.position_at(p, float(p.T) * k / 63.0)
			if q.y > table.military_ceiling(q.x, q.z):
				bad.append(id)
				break
	ml.fire(_on(rig, Vector3(0.05, 0, 0.0)), "nuke")
	var through := 0
	for i in int(9.0 / DT):
		ml.step(DT)
		for q in ml.fx.puffs:
			var pp: Vector3 = q.p
			if pp.y > table.military_ceiling(pp.x, pp.z) + 0.001:
				through += 1
	check(bad.is_empty() and open_top > table.military_ceiling(0, 0) and float(pl.T) < float(flat.T) and through == 0,
		"under the ceiling: every arc stays under the dome (open sky top %.2f > %.2f, flight %.2f s -> %.2f s), no smoke through it %s" % [open_top, table.military_ceiling(0, 0), float(flat.T), float(pl.T), bad])


func _ammo(rig: Dictionary) -> void:
	var ml: Launcher = rig.ml
	_reset(rig)
	var tgt := _on(rig, LAND)
	var full := ml.ammo("hypersonic")
	var first := ml.fire(tgt, "hypersonic")
	var second := ml.fire(tgt, "hypersonic")
	var cd := ml.cooldown_left("hypersonic")
	_run(ml, float(Catalog.WEAPONS.hypersonic.cooldown) + 0.1)
	var third := ml.fire(tgt, "hypersonic")
	ml._cool["hypersonic"] = 0.0      # skip the second cooldown: empty before a round comes back
	ml.fire(tgt, "hypersonic")
	var empty := ml.ammo("hypersonic") == 0 and not ml.fire(tgt, "hypersonic")
	ml._reload["hypersonic"] = 0.0
	_run(ml, float(Catalog.WEAPONS.hypersonic.reload) + 0.1)
	var back := ml.ammo("hypersonic")
	ml.unlimited = true
	var free := ml.fire(tgt, "hypersonic") and ml.fire(tgt, "hypersonic")
	ml.unlimited = false
	check(first and not second and cd > 0.0 and third and empty and back == 1 and full == 3 and free and not ml.fire(tgt, "nothing"),
		"ammo: hypersonic has %d rounds, %.0f s cooldown, empty after 3, one back after %.0f s; unlimited ignores both; unknown ids don't fire" % [full, cd, float(Catalog.WEAPONS.hypersonic.reload)])


func _ship(rig: Dictionary) -> void:
	var ml: Launcher = rig.ml
	var ship: Ship = rig.ship
	_reset(rig)
	var pts := {}
	for id: String in Catalog.ids():
		pts[str(Catalog.WEAPONS[id].launcher)] = ml.launch_point(id)
	var on_ship := true
	for key: String in pts:
		var local: Vector3 = ship.transform.affine_inverse() * (pts[key] as Vector3)
		if absf(local.x) > 0.09 or absf(local.z) > 0.015 or local.y < 0.0 or local.y > 0.012:
			on_ship = false
	var origins := []
	var rec := func(_id: String, f: Vector3, _t: Vector3, sub: bool) -> void:
		if not sub:
			origins.append(f)
	ml.launched.connect(rec)
	ml.fire(_on(rig, LAND), "cruise")
	ml.fire(_on(rig, LAND), "artillery")
	ml.launched.disconnect(rec)
	_run(ml, 6.0, func() -> bool: return not ml.flying)
	check(pts.size() == 8 and on_ship and origins.size() == 2 and (origins[0] as Vector3).distance_to(origins[1]) > 0.05,
		"ship: 8 launchers on board (vls, box, gun, pod, ramp, silo, deck, tube); each weapon leaves from its own")


func _no_host() -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	var ml: Launcher = Launcher.new()
	ml.auto_step = false
	holder.add_child(ml)
	var hit := []
	var landed := []
	ml.impacted.connect(func(p: Vector3, info: Dictionary) -> void: hit.append([p, info]))
	ml.sortie_landed.connect(func(id: String) -> void: landed.append(id))
	var scans := [0]
	ml.recon_scan.connect(func(_p: Vector3, _r: float) -> void: scans[0] += 1)
	var ok := true
	var aim := Vector3(0.25, 0.0, 0.1)
	for id: String in Catalog.ids():
		ml.clear()
		hit.clear()
		landed.clear()
		var fired := ml.fire(aim, id)
		_run(ml, 60.0, func() -> bool: return (not hit.is_empty() or not landed.is_empty()) and not ml.flying)
		var good := fired and not hit.is_empty() and absf((hit[0][0] as Vector3).y) <= 1e-3
		if id == "recon":
			good = fired and hit.is_empty() and landed == ["recon"] and scans[0] > 10
		elif id == "aa":
			good = fired and not hit.is_empty() and (hit[0][0] as Vector3).distance_to(aim) < 0.01
		elif String(Catalog.WEAPONS[id].arc) == "sortie":
			good = good and landed == [id]
		if not good:
			ok = false
			print("  no host: ", id, " ", hit, " ", landed)
	holder.free()
	check(ok, "no host: every weapon still flies from `origin` and goes off on the flat ground (y = 0); aircraft land back, the recon drone scans, the anti-air missile bursts at the point")
