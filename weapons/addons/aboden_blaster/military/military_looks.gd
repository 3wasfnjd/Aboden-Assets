class_name AbodenMilitaryLooks
extends RefCounted
## Meshes of the military pack (code only, no art files): each weapon's body (a cylinder
## along +X with a nose cone; wings for cruise missiles, drones and aircraft; the jets'
## fin, tailplane and canopy; the attack helicopter's own body with its rotor and rocket
## pods) and the launch ship of «حرب البارجة», a toy cruiser that carries every launcher.
## All in table units (AbodenMilitaryCatalog).

const MB := preload("military_mesh.gd")
const Catalog := preload("military_catalog.gd")

static var _bodies := {}
static var _mat: StandardMaterial3D


static func material() -> StandardMaterial3D:
	if _mat == null:
		_mat = MB.vc_material(0.5)
	return _mat


## The flying body of a weapon (or of "submunition" / "jetbomb"), cached per id.
static func body(w: Dictionary) -> ArrayMesh:
	var id: String = w.id
	if _bodies.has(id):
		return _bodies[id]
	var L: float = w.length
	var r: float = w.radius
	var col: Color = w.col
	if bool(w.get("heli", false)):
		_bodies[id] = _heli(L, r, col)
		return _bodies[id]
	var mb := MB.new()
	mb.xform = Transform3D(Basis(Vector3(0, 0, 1), -PI * 0.5), Vector3(-L * 0.5, 0, 0))
	mb.cylinder(Vector3.ZERO, r, r, L * 0.7, 8, col)
	mb.cylinder(Vector3(0, L * 0.7, 0), r, 0.0, L * 0.3, 8, col.lightened(0.2))
	var jetlike := bool(w.get("aircraft", false))
	if bool(w.get("wings", false)):
		var span := 1.5 if id in ["drone", "swarm"] else (1.9 if w.has("orbit") else (0.75 if jetlike else 0.9))
		mb.box(Vector3(0, L * 0.45, 0), Vector3(L * span, L * 0.12, r * 0.4), col)
	if jetlike and not w.has("orbit"):
		mb.box(Vector3(0, L * 0.08, r * 1.3), Vector3(L * 0.05, L * 0.18, r * 1.8), col.darkened(0.15))   # tail fin
		mb.box(Vector3(0, L * 0.06, 0), Vector3(L * 0.36, L * 0.08, r * 0.3), col)                       # tailplane
		mb.box(Vector3(0, L * 0.72, r * 0.8), Vector3(r * 0.9, L * 0.12, r * 0.6), Color(0.25, 0.35, 0.45))   # canopy
	_bodies[id] = mb.commit(null, material())
	return _bodies[id]


## The attack helicopter (nose along +X): a slim body with the cockpit forward, a tail
## boom and fin, stub wings with rocket pods, and a two-blade rotor (crossed thin boards).
static func _heli(L: float, r: float, col: Color) -> ArrayMesh:
	var mb := MB.new()
	mb.box(Vector3(L * 0.1, 0, 0), Vector3(L * 0.5, r * 1.6, r * 1.3), col)
	mb.box(Vector3(L * 0.33, r * 0.3, 0), Vector3(L * 0.16, r * 1.2, r * 1.0), Color(0.22, 0.30, 0.36))
	mb.box(Vector3(-L * 0.3, r * 0.2, 0), Vector3(L * 0.45, r * 0.5, r * 0.45), col)
	mb.box(Vector3(-L * 0.52, r * 0.9, 0), Vector3(L * 0.08, r * 1.6, r * 0.2), col.darkened(0.15))
	mb.box(Vector3(L * 0.08, -r * 0.2, 0), Vector3(L * 0.12, r * 0.25, L * 0.4), col.darkened(0.1))
	for sd in [-1.0, 1.0]:
		mb.box(Vector3(L * 0.08, -r * 0.5, sd * L * 0.18), Vector3(L * 0.16, r * 0.5, r * 0.5), Color(0.25, 0.27, 0.24))
	mb.box(Vector3(L * 0.1, r * 1.3, 0), Vector3(r * 0.5, r * 0.6, r * 0.5), Color(0.2, 0.2, 0.2))
	mb.box(Vector3(L * 0.1, r * 1.65, 0), Vector3(L * 1.15, r * 0.08, r * 0.35), Color(0.15, 0.15, 0.15))
	mb.box(Vector3(L * 0.1, r * 1.65, 0), Vector3(r * 0.35, r * 0.08, L * 1.15), Color(0.15, 0.15, 0.15))
	return mb.commit(null, material())


# --- the launch ship ------------------------------------------------------------------

## Ship size: length, beam, deck height above the water.
const SHIP_L := 0.17
const SHIP_B := 0.028
const SHIP_FB := 0.004
## Launcher points, ship-local (bow along +X, waterline y = 0).
const LAUNCHERS := {
	"vls": Vector3(0.040, SHIP_FB + 0.0035, 0.0),
	"box": Vector3(-0.004, SHIP_FB + 0.006, 0.0),
	"gun": Vector3(0.082, SHIP_FB + 0.0045, 0.0),
	"pod": Vector3(-0.040, SHIP_FB + 0.0065, 0.0),
	"ramp": Vector3(-0.080, SHIP_FB + 0.0025, 0.0),
	"silo": Vector3(0.016, SHIP_FB + 0.0012, 0.0),
	"deck": Vector3(-0.062, SHIP_FB + 0.0028, 0.0),
	"tube": Vector3(0.020, SHIP_FB - 0.002, SHIP_B * 0.52),
}
const HULL := Color(0.52, 0.57, 0.63)
const DECK := Color(0.40, 0.44, 0.48)
const DARK := Color(0.18, 0.20, 0.23)
const SUPER := Color(0.66, 0.70, 0.75)
const RED := Color(0.85, 0.18, 0.15)
const BOOT := Color(0.92, 0.25, 0.20)


## Ship-local launch point of a weapon.
static func launcher_point(wid: String) -> Vector3:
	var key := str(Catalog.get_weapon(wid).get("launcher", "vls"))
	return LAUNCHERS.get(key, LAUNCHERS.vls)


static func _hull(mb: MB, L: float, B: float, fb: float, col: Color, deck: Color) -> void:
	var hull := [Vector2(-L * 0.5, -B * 0.45), Vector2(L * 0.25, -B * 0.5), Vector2(L * 0.5, 0), Vector2(L * 0.25, B * 0.5), Vector2(-L * 0.5, B * 0.45)]
	var draft := fb * 0.8
	for k in hull.size():
		var a: Vector2 = hull[k]
		var b: Vector2 = hull[(k + 1) % hull.size()]
		var outd := Vector3((a.x + b.x) * 0.5, 0, (a.y + b.y) * 0.5)
		var A := Vector3(a.x, fb, a.y)
		var Bv := Vector3(b.x, fb, b.y)
		var Aw := Vector3(a.x * 0.97, -draft, a.y * 0.75)
		var Bw := Vector3(b.x * 0.97, -draft, b.y * 0.75)
		mb.tri_out(A, Bv, Bw, col, outd)
		mb.tri_out(A, Bw, Aw, col, outd)
		# red boot top at the waterline
		mb.tri_out(Vector3(a.x * 1.002, 0.0003, a.y * 1.002), Vector3(b.x * 1.002, 0.0003, b.y * 1.002), Vector3(b.x * 0.99, -0.0004, b.y * 0.93), BOOT.darkened(0.15), outd)
		mb.tri_out(Vector3(a.x * 1.002, 0.0003, a.y * 1.002), Vector3(b.x * 0.99, -0.0004, b.y * 0.93), Vector3(a.x * 0.99, -0.0004, a.y * 0.93), BOOT.darkened(0.15), outd)
	for k in range(1, hull.size() - 1):
		var a2: Vector2 = hull[0]
		var b2: Vector2 = hull[k]
		var c2: Vector2 = hull[k + 1]
		mb.tri_out(Vector3(a2.x, fb, a2.y), Vector3(b2.x, fb, b2.y), Vector3(c2.x, fb, c2.y), deck, Vector3.UP)


## The toy cruiser: vertical launch cells, the red nuclear silo hatch, angled box
## launchers, the bow gun, the aft rocket pod, the stern drone ramp, the flight deck with
## a helicopter circle, and the torpedo tubes on the starboard side.
static func ship() -> ArrayMesh:
	var FB := SHIP_FB
	var B := SHIP_B
	var mb := MB.new()
	_hull(mb, SHIP_L, B, FB, HULL, DECK)
	# superstructure: bridge block, funnel, mast with radar panels
	mb.box(Vector3(-0.012, FB + 0.0045, 0), Vector3(0.034, 0.009, B * 0.62), SUPER)
	mb.box(Vector3(-0.006, FB + 0.0105, 0), Vector3(0.016, 0.004, B * 0.5), SUPER.lightened(0.08))
	mb.box(Vector3(0.0, FB + 0.0105, 0), Vector3(0.004, 0.0022, B * 0.48), Color(0.25, 0.40, 0.55))
	mb.cylinder(Vector3(-0.004, FB + 0.0125, 0), 0.0009, 0.0004, 0.016, 6, DARK)
	mb.box(Vector3(-0.004, FB + 0.024, 0), Vector3(0.0008, 0.0035, 0.008), DARK)
	mb.box(Vector3(-0.024, FB + 0.011, 0), Vector3(0.008, 0.007, 0.007), DARK.lightened(0.15))
	# bow gun turret + barrel
	mb.cylinder(Vector3(0.068, FB, 0), 0.0045, 0.004, 0.0035, 12, SUPER)
	mb.box(Vector3(0.076, FB + 0.0025, 0), Vector3(0.012, 0.0009, 0.0009), DARK)
	# forward vertical launch cells (4 x 6 hatches)
	mb.box(Vector3(0.040, FB + 0.0012, 0), Vector3(0.018, 0.0024, B * 0.5), DECK.darkened(0.1))
	for i in 4:
		for j in 6:
			mb.box(Vector3(0.033 + i * 0.0045, FB + 0.0025, (j - 2.5) * 0.0022), Vector3(0.0036, 0.0002, 0.0018), DARK)
	# nuclear silo hatch (red)
	mb.cylinder(Vector3(0.016, FB, 0), 0.004, 0.004, 0.0012, 14, RED, true, RED.darkened(0.2))
	mb.cylinder(Vector3(0.016, FB + 0.0012, 0), 0.0012, 0.0012, 0.0002, 10, Color(1.0, 0.85, 0.2))
	# angled box launchers (cruise / anti-ship), both sides
	for side in [-1.0, 1.0]:
		var saved := mb.xform
		mb.xform = saved * Transform3D(Basis(Vector3(0, 0, 1), deg_to_rad(30.0)), Vector3(-0.004, FB + 0.003, side * B * 0.3))
		for k in 2:
			mb.box(Vector3(0, 0, (k - 0.5) * 0.0032), Vector3(0.014, 0.0028, 0.003), Color(0.46, 0.50, 0.44))
		mb.xform = saved
	# aft rocket pod (MLRS) on a turntable
	mb.cylinder(Vector3(-0.040, FB, 0), 0.0035, 0.0035, 0.0018, 10, SUPER)
	var saved2 := mb.xform
	mb.xform = saved2 * Transform3D(Basis(Vector3(0, 0, 1), deg_to_rad(40.0)), Vector3(-0.040, FB + 0.0045, 0))
	mb.box(Vector3.ZERO, Vector3(0.012, 0.005, 0.007), Color(0.46, 0.50, 0.38))
	for i in 3:
		for j in 3:
			mb.box(Vector3(0.0061, (i - 1) * 0.0015, (j - 1) * 0.002), Vector3(0.0002, 0.0011, 0.0011), DARK)
	mb.xform = saved2
	# stern drone ramp + two parked drones
	mb.box(Vector3(-0.074, FB + 0.0012, 0), Vector3(0.018, 0.0016, B * 0.55), DECK.lightened(0.1))
	for side in [-1.0, 1.0]:
		mb.box(Vector3(-0.082, FB + 0.0024, side * 0.006), Vector3(0.004, 0.0006, 0.0010), Color(0.86, 0.86, 0.82))
		mb.box(Vector3(-0.082, FB + 0.0026, side * 0.006), Vector3(0.0012, 0.0004, 0.006), Color(0.86, 0.86, 0.82))
	# flight deck markings for the strike jets
	mb.box(Vector3(-0.062, FB + 0.0025, 0), Vector3(0.028, 0.0002, B * 0.62), Color(0.30, 0.33, 0.36))
	mb.box(Vector3(-0.062, FB + 0.0027, 0), Vector3(0.026, 0.0001, 0.0006), Color(0.95, 0.85, 0.30))
	mb.box(Vector3(0.05, FB - 0.0018, B * 0.5 + 0.0002), Vector3(0.012, 0.0022, 0.0002), Color(0.95, 0.95, 0.93))
	# helicopter landing circle (aft of the jets' deck markings)
	for k in 16:
		var a := TAU * k / 16.0
		mb.box(Vector3(-0.049 + cos(a) * 0.0045, FB + 0.0028, sin(a) * 0.0045), Vector3(0.0018, 0.0001, 0.0005), Color(0.95, 0.95, 0.93))
	# torpedo tubes on the starboard side, just above the waterline (the torpedo's launcher)
	var tube: Vector3 = LAUNCHERS.tube
	for k in 2:
		var tsaved := mb.xform
		mb.xform = tsaved * Transform3D(Basis(Vector3(0, 0, 1), -PI * 0.5), Vector3(tube.x - 0.006, tube.y + k * 0.0012, B * 0.5))
		mb.cylinder(Vector3.ZERO, 0.0005, 0.0005, 0.012, 8, DARK.lightened(0.1), true, DARK)
		mb.xform = tsaved
	return mb.commit(null, MB.vc_material(0.6))


## A parked strike jet (on the flight deck; nose along +X).
static func parked_jet() -> ArrayMesh:
	var w := Catalog.get_weapon("jet")
	var Lj: float = w.length
	var rj: float = w.radius
	var col: Color = w.col
	var jm := MB.new()
	jm.box(Vector3.ZERO, Vector3(Lj, rj * 1.6, rj * 1.6), col)
	jm.box(Vector3(-Lj * 0.05, 0, 0), Vector3(Lj * 0.12, rj * 0.4, Lj * 0.75), col)
	jm.box(Vector3(-Lj * 0.42, rj * 1.2, 0), Vector3(Lj * 0.15, rj * 1.8, rj * 0.4), col.darkened(0.15))
	jm.box(Vector3(Lj * 0.25, rj * 0.9, 0), Vector3(Lj * 0.15, rj * 0.6, rj * 0.9), Color(0.25, 0.35, 0.45))
	return jm.commit(null, material())
