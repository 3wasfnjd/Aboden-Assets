extends Node3D
## The mini and bubble shots drawn in a few MultiMesh draws: ball bodies of every look (the
## jelly ball with its plaster, the fur ball with its ribbon). Positions and sizes in this node's units.
##
## begin(); add(style, pos, radius, toward, squash, color) per ball; end().

const Looks := preload("shot_looks.gd")

var max_n := 48
var parts := {}  # name -> {mm: MultiMesh, mi: MultiMeshInstance3D, n: int, cap: int}


func _init(max_count := 48) -> void:
	max_n = max_count
	for s in Looks.STYLES:
		_part("body_" + s, Looks.body_mesh(1.0, 16, 12), Looks.body_material(s), max_n, true, 3 if s == "bubble" else 0)
	_part("bow", Looks.bow_mesh(), Looks.acc_material(), max_n)
	_part("bandage", Looks.bandage_mesh(), Looks.acc_material(), max_n)


func _part(id: String, mesh: Mesh, mat: Material, cap: int, colors := false, priority := 0) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = colors
	mm.mesh = mesh
	mm.instance_count = cap
	mm.visible_instance_count = 0
	var mi := MultiMeshInstance3D.new()
	mi.name = id
	mi.multimesh = mm
	mi.material_override = mat
	mi.sorting_offset = float(priority)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.custom_aabb = AABB(Vector3(-500, -500, -500), Vector3(1000, 1000, 1000))
	add_child(mi)
	parts[id] = {"mm": mm, "mi": mi, "n": 0, "cap": cap}


func begin() -> void:
	for id in parts:
		parts[id].n = 0


func _put(id: String, m: Transform3D, color = null) -> void:
	var p: Dictionary = parts[id]
	var n: int = p.n
	if n >= int(p.cap):
		return
	var mm: MultiMesh = p.mm
	mm.set_instance_transform(n, m)
	if color != null:
		mm.set_instance_color(n, color)
	p.n = n + 1


## One ball: style, centre, radius, the point it faces (or null), squash (sx, sy), colour (sRGB).
func add(style: String, pos: Vector3, radius: float, toward, squash := Vector2.ONE, color := Color.WHITE) -> void:
	var body := "body_" + style
	if not parts.has(body):
		body = "body_jelly"
	if int(parts[body].n) >= max_n:
		return
	var m := place(pos, radius, toward, squash)
	_put(body, m, color.srgb_to_linear())
	if style == "jelly":
		_put("bandage", m)
	if style == "fur":
		_put("bow", m)


## A ball's instance transform: at pos, radius big, squashed (in world axes), its +Z (face)
## toward the point asked.
static func place(pos: Vector3, radius: float, toward, squash := Vector2.ONE) -> Transform3D:
	var r := Basis.IDENTITY
	if toward != null:
		var d: Vector3 = (toward as Vector3) - pos
		if d.length_squared() > 1e-12:
			var dn := d.normalized()
			r = Basis.looking_at(dn, Vector3.UP if absf(dn.y) < 0.9999 else Vector3.BACK, true)
	return Transform3D(Basis.from_scale(Vector3(radius * squash.x, radius * squash.y, radius * squash.x)) * r, pos)


func end() -> void:
	for id in parts:
		(parts[id].mm as MultiMesh).visible_instance_count = int(parts[id].n)


## Balls drawn (bodies of every style).
func count() -> int:
	var n := 0
	for s in Looks.STYLES:
		n += int(parts["body_" + s].n)
	return n
