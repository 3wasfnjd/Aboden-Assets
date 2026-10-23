class_name AbodenShotIcons
extends RefCounted
## The shot icons (IDS), as the original menu drew them: two-tone vector art, a light line layer (strokes
## and small solid details) over a soft tint layer (the shapes' fills), rasterised here with
## exact anti-aliasing (signed distances, no supersampling) on a 100-unit box centred on 0
## (y down, like a canvas).
##
## icons/<id>.png (baked by tools/bake_icons.gd): RGBA, the tint layer in TINT under the line
## layer in LINE, like a selected menu card. For other colours use
## textures(id) (the two white layers, alpha = coverage) and draw() them tinted.

const SPAN := 112.0  # design units across a cell (-56..56)
const LW := 6.2  # default line width (design units)
const SIZE := 256  # the baked icons' pixels
## The menu colours: line, tint (selected) and tint (at rest).
const LINE := Color(0.97, 0.965, 0.955)
const TINT := Color(1.0, 0.62, 0.36)
const TINT_REST := Color(0.42, 0.45, 0.56)
## The icon ids (AbodenShotCatalog SHOTS[id].icon).
const IDS := ["bolt", "mini", "bubble", "firework", "confetti", "bouncy", "laser", "boomerang", "glob", "rocket", "lightning", "dallah",
	"falcon", "freeze", "blackhole", "dates", "bakhoor", "lasso", "hose", "cluster", "magnet", "shield"]

static var _cache := {}  # [id, px] -> [line: Texture2D, tint: Texture2D]


## The two layers of an icon as textures (white; alpha = coverage), rasterised once per size.
static func textures(id: String, px := SIZE) -> Array:
	var key := "%s@%d" % [id, px]
	if _cache.has(key):
		return _cache[key]
	var pair: Array = []
	for img: Image in raster(shapes(id), px):
		img.generate_mipmaps()
		pair.append(ImageTexture.create_from_image(img))
	_cache[key] = pair
	return pair


## Draws icon `id` centred at `c`, `size` design units for the 100-unit box, lines in
## `line_col` over tints in `tint_col`.
static func draw(ci: CanvasItem, id: String, c: Vector2, size: float, line_col := LINE, tint_col := TINT) -> void:
	var pair := textures(id)
	if pair.size() < 2 or ci == null:
		return
	var s := size * SPAN / 100.0
	var r := Rect2(c - Vector2(s, s) / 2.0, Vector2(s, s))
	if tint_col.a > 0.0:
		ci.draw_texture_rect(pair[1], r, false, tint_col)
	ci.draw_texture_rect(pair[0], r, false, line_col)


## One RGBA image of an icon: the tint layer in `tint_col` under the line layer in `line_col`,
## on `back` (transparent by default).
static func image(id: String, px := SIZE, line_col := LINE, tint_col := TINT, back := Color(0, 0, 0, 0)) -> Image:
	var layers := raster(shapes(id), px)
	var img := Image.create(px, px, false, Image.FORMAT_RGBA8)
	for y in px:
		for x in px:
			var c := back
			for layer: Array in [[layers[1], tint_col], [layers[0], line_col]]:
				var a: float = (layer[0] as Image).get_pixel(x, y).a * (layer[1] as Color).a
				c = _over(Color(layer[1], a), c)
			img.set_pixel(x, y, c)
	return img


## Porter-Duff "over" (straight alpha).
static func _over(top: Color, under: Color) -> Color:
	var a := top.a + under.a * (1.0 - top.a)
	if a <= 0.0:
		return Color(0, 0, 0, 0)
	var rgb := (Vector3(top.r, top.g, top.b) * top.a + Vector3(under.r, under.g, under.b) * under.a * (1.0 - top.a)) / a
	return Color(rgb.x, rgb.y, rgb.z, a)


## Bakes every icon into `dir`/<id>.png (RGBA, SIZE px). Returns the first error.
static func bake(dir: String, px := SIZE, line_col := LINE, tint_col := TINT, back := Color(0, 0, 0, 0)) -> Error:
	var abs_dir := ProjectSettings.globalize_path(dir) if dir.begins_with("res://") else dir
	DirAccess.make_dir_recursive_absolute(abs_dir)
	for id: String in IDS:
		var err := image(id, px, line_col, tint_col, back).save_png(abs_dir.path_join(id + ".png"))
		if err != OK:
			return err
	return OK


# ---------------------------------------------------------------- rasteriser

## [line, tint] FORMAT_LA8 images (white, coverage in alpha) of `ops` at px x px.
static func raster(ops: Array, px: int) -> Array[Image]:
	var line := PackedFloat32Array()
	var tint := PackedFloat32Array()
	line.resize(px * px)
	tint.resize(px * px)
	var k := px / SPAN
	for op: Dictionary in ops:
		var src: PackedVector2Array = op.p
		var p := PackedVector2Array()
		p.resize(src.size())
		for i in src.size():
			p[i] = (src[i] + Vector2(SPAN, SPAN) / 2.0) * k
		var kind: String = op.k
		if kind == "s":
			_stroke(line, px, p, op.c, float(op.w) * k / 2.0)
		elif kind == "f":
			_fill(tint, tint, px, p, 0.0, false)
		elif kind == "S":
			_fill(line, line, px, p, 0.0, false)
		elif kind == "x":
			_fill(line, tint, px, p, float(op.g) * k, true)
	var out: Array[Image] = []
	for buf: PackedFloat32Array in [line, tint]:
		var data := PackedByteArray()
		data.resize(px * px * 2)
		for i in px * px:
			data[i * 2] = 255
			data[i * 2 + 1] = int(round(clampf(buf[i], 0.0, 1.0) * 255.0))
		out.append(Image.create_from_data(px, px, false, Image.FORMAT_LA8, data))
	return out


static func _seg_dist(q: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var l2 := ab.length_squared()
	var t := 0.0 if l2 < 1e-9 else clampf((q - a).dot(ab) / l2, 0.0, 1.0)
	return q.distance_to(a + ab * t)


## Round-capped, round-joined polyline of half width hw (pixels).
static func _stroke(buf: PackedFloat32Array, px: int, p: PackedVector2Array, closed: bool, hw: float) -> void:
	var n := p.size()
	var segs := n if closed else n - 1
	if n == 1:
		segs = 1
	for s in segs:
		var a := p[s]
		var b := p[(s + 1) % n]
		var x0 := maxi(0, int(floor(minf(a.x, b.x) - hw - 1.0)))
		var x1 := mini(px - 1, int(ceil(maxf(a.x, b.x) + hw + 1.0)))
		var y0 := maxi(0, int(floor(minf(a.y, b.y) - hw - 1.0)))
		var y1 := mini(px - 1, int(ceil(maxf(a.y, b.y) + hw + 1.0)))
		for y in range(y0, y1 + 1):
			for x in range(x0, x1 + 1):
				var cov := clampf(hw - _seg_dist(Vector2(x + 0.5, y + 0.5), a, b) + 0.5, 0.0, 1.0)
				var i := y * px + x
				if cov > buf[i]:
					buf[i] = cov


## A filled polygon (nonzero winding), grown by `grow` pixels. cut: clears both
## buffers under it instead of painting.
static func _fill(a_buf: PackedFloat32Array, b_buf: PackedFloat32Array, px: int, p: PackedVector2Array, grow: float, cut: bool) -> void:
	var n := p.size()
	if n < 3:
		return
	var lo := p[0]
	var hi := p[0]
	for v in p:
		lo = lo.min(v)
		hi = hi.max(v)
	var x0 := maxi(0, int(floor(lo.x - grow - 1.0)))
	var x1 := mini(px - 1, int(ceil(hi.x + grow + 1.0)))
	var y0 := maxi(0, int(floor(lo.y - grow - 1.0)))
	var y1 := mini(px - 1, int(ceil(hi.y + grow + 1.0)))
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var q := Vector2(x + 0.5, y + 0.5)
			var wn := 0
			var d := 1e9
			for e in n:
				var a := p[e]
				var b := p[(e + 1) % n]
				d = minf(d, _seg_dist(q, a, b))
				var cr := (b.x - a.x) * (q.y - a.y) - (q.x - a.x) * (b.y - a.y)
				if a.y <= q.y:
					if b.y > q.y and cr > 0.0:
						wn += 1
				elif b.y <= q.y and cr < 0.0:
					wn -= 1
			var sd := d if wn != 0 else -d
			var cov := clampf(sd + grow + 0.5, 0.0, 1.0)
			if cov <= 0.0:
				continue
			var i := y * px + x
			if cut:
				a_buf[i] *= 1.0 - cov
				b_buf[i] *= 1.0 - cov
			elif cov > a_buf[i]:
				a_buf[i] = cov


# ---------------------------------------------------------------- shape helpers

## Collects drawing ops; `xf` transforms every following shape (rotated groups).
class Pen:
	var ops: Array = []
	var w := 6.2  # LW
	var xf := Transform2D.IDENTITY

	## A line (closed: a loop).
	func s(p: PackedVector2Array, closed := false, width := -1.0) -> void:
		ops.append({"k": "s", "p": xf * p, "c": closed, "w": w if width < 0.0 else width})

	## A soft tint fill.
	func f(p: PackedVector2Array) -> void:
		ops.append({"k": "f", "p": xf * p})

	## A solid fill on the line layer (eyes, dots, small solid parts).
	func ink(p: PackedVector2Array) -> void:
		ops.append({"k": "S", "p": xf * p})

	## Clears both layers under a shape grown by `grow` units (a knock-out gap).
	func cut(p: PackedVector2Array, grow := 0.0) -> void:
		ops.append({"k": "x", "p": xf * p, "g": grow})

	## Tint fill and outline.
	func sf(p: PackedVector2Array, width := -1.0) -> void:
		f(p)
		s(p, true, width)


static func P(a: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for v: Array in a:
		out.append(Vector2(v[0], v[1]))
	return out


static func ell(cx: float, cy: float, rx: float, ry: float, n := 56) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n:
		var t := TAU * i / n
		out.append(Vector2(cx + cos(t) * rx, cy + sin(t) * ry))
	return out


## A canvas arc (y down): clockwise from a0 to a1 unless ccw.
static func arc(cx: float, cy: float, r: float, a0: float, a1: float, ccw := false) -> PackedVector2Array:
	var sweep := fposmod(a0 - a1, TAU) if ccw else fposmod(a1 - a0, TAU)
	if sweep < 1e-4:
		sweep = TAU
	var n := maxi(4, int(ceil(sweep / TAU * 64.0)))
	var out := PackedVector2Array()
	for i in n + 1:
		var t := a0 + (-sweep if ccw else sweep) * i / n
		out.append(Vector2(cx + cos(t) * r, cy + sin(t) * r))
	return out


static func rr(x: float, y: float, w: float, h: float, r: float) -> PackedVector2Array:
	r = minf(r, minf(w, h) / 2.0)
	var out := PackedVector2Array()
	var cs := [[x + w - r, y + r, -PI / 2.0], [x + w - r, y + h - r, 0.0], [x + r, y + h - r, PI / 2.0], [x + r, y + r, PI]]
	for c: Array in cs:
		for i in 9:
			var t: float = c[2] + PI / 2.0 * i / 8.0
			out.append(Vector2(c[0] + cos(t) * r, c[1] + sin(t) * r))
	return out


static func star(x: float, y: float, r: float, inner := 0.44) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in 10:
		var a := i * PI / 5.0 - PI / 2.0
		var s := r * inner if i % 2 == 1 else r
		out.append(Vector2(x + cos(a) * s, y + sin(a) * s))
	return out


## Appends a cubic Bezier from the last point of `p`.
static func bez(p: PackedVector2Array, c1: Vector2, c2: Vector2, e: Vector2, n := 20) -> PackedVector2Array:
	var a := p[p.size() - 1]
	for i in range(1, n + 1):
		var t := float(i) / n
		var u := 1.0 - t
		p.append(a * u * u * u + c1 * 3.0 * u * u * t + c2 * 3.0 * u * t * t + e * t * t * t)
	return p


# ---------------------------------------------------------------- the icons

static func shapes(id: String) -> Array:
	var d := Pen.new()
	match id:
		"bolt":
			d.sf(P([[8, -43], [-29, 5], [-3, 5], [-12, 44], [32, -12], [7, -12]]))
		"firework":
			d.xf = Transform2D(0.6, Vector2.ZERO)
			d.sf(rr(-14, -20, 28, 50, 4))
			d.ink(P([[-18, -20], [0, -42], [18, -20]]))
			d.s(P([[-14, 0], [14, 0]]), false, 4.0)
			d.s(P([[0, 30], [0, 46]]), false, 4.5)
			d.xf = Transform2D.IDENTITY
			d.ink(star(33, -32, 10, 0.45))
			d.s(P([[18, -44], [21, -40]]), false, 3.5)
			d.s(P([[44, -16], [40, -19]]), false, 3.5)
		"mini":
			# Mini balls: three little balls, each with a shine, and the hops of the first.
			var hop := P([[-46, 30]])
			bez(hop, Vector2(-40, -10), Vector2(-24, -10), Vector2(-16, 20))
			d.s(hop, false, 3.5)
			d.s(P([[-48, 42], [44, 42]]), false, 4.5)
			for c: Array in [[-10, 18, 13], [16, -6, 17], [34, 22, 11]]:
				var ball := ell(float(c[0]), float(c[1]), float(c[2]), float(c[2]))
				d.cut(ball, 3.0)
				d.sf(ball)
				d.s(arc(float(c[0]), float(c[1]), float(c[2]) * 0.62, PI * 1.08, PI * 1.4), false, 3.5)
		"bubble":
			# A soap bubble: a big round film with its shine and window glints, and a little one.
			d.sf(ell(0, 3, 36, 36))
			d.s(arc(0, 3, 26, PI * 1.08, PI * 1.38), false, 4.5)
			d.ink(ell(-15, -19, 7, 4, 20))
			d.ink(ell(18, 23, 3.4, 3.4, 16))
			d.s(ell(36, -32, 7, 7, 24), true, 4.0)
		"confetti":
			# The confetti cannon: a tilted barrel spraying slips and dots.
			d.xf = Transform2D(-0.65, Vector2(-20, 22))
			d.sf(rr(-22, -12, 40, 24, 6))
			d.s(P([[18, -15], [18, 15]]), false, 5.0)
			d.xf = Transform2D.IDENTITY
			d.s(P([[-42, 40], [-8, 40]]), false, 4.5)
			for c: Array in [[10, -22, 0.5], [30, -6, -0.6], [-2, -42, 1.1], [26, -38, 0.2], [44, 12, 0.9], [44, -26, -0.3]]:
				d.xf = Transform2D(float(c[2]), Vector2(float(c[0]), float(c[1])))
				d.sf(rr(-6, -3, 12, 6, 1.5), 3.5)
			d.xf = Transform2D.IDENTITY
			for c: Array in [[16, 10], [8, -36], [40, -46], [36, 30]]:
				d.ink(ell(float(c[0]), float(c[1]), 3.2, 3.2, 16))
		"bouncy":
			# The bouncy ball: a striped ball and the hops it took to get there.
			var hop := P([[-46, -32]])
			bez(hop, Vector2(-38, -32), Vector2(-22, -4), Vector2(-16, 36))
			d.s(hop, false, 3.5)
			var hop2 := P([[-16, 36]])
			bez(hop2, Vector2(-10, 10), Vector2(0, 0), Vector2(10, -2))
			d.s(hop2, false, 3.5)
			d.s(P([[-34, 44], [4, 44]]), false, 4.5)
			d.s(P([[-24, 32], [-29, 27]]), false, 3.5)
			d.s(P([[-8, 32], [-3, 27]]), false, 3.5)
			d.sf(ell(25, -12, 19, 19))
			d.s(arc(25, -12, 12, PI * 0.95, PI * 1.6), false, 4.5)
			d.s(P([[8, -4], [42, -20]]), false, 4.0)
		"laser":
			# The laser: an emitter, a straight beam through two ringed targets, a spark at its end.
			d.f(P([[-24, 15], [42, -37], [46, -29], [-20, 23]]))
			d.sf(rr(-48, 16, 28, 20, 6))
			d.s(P([[-22, 22], [42, -30]]), false, 6.5)
			d.s(ell(4, 1.5, 10, 10), true, 4.0)
			d.s(ell(24, -14.2, 10, 10), true, 4.0)
			d.ink(star(44, -32, 9, 0.4))
		"boomerang":
			# The boomerang: a V of two arms and the loop that brings it back.
			var arm := rr(0, -8, 46, 16, 8)
			d.xf = Transform2D(0.62, Vector2(-30, -2))
			d.sf(arm)
			d.xf = Transform2D(-0.62, Vector2(-30, 2))
			d.cut(arm, 3.0)
			d.sf(arm)
			d.xf = Transform2D.IDENTITY
			d.s(arc(8, 0, 40, -1.05, 1.35), false, 4.0)
			d.s(P([[23.6, 33.1], [16.8, 39.0], [25.4, 41.5]]), false, 4.0)
		"glob":
			# The water shot: a big drop (pointed top, round bottom) with a shine and two droplets.
			var drop := PackedVector2Array([Vector2(0, -44)])
			for k in 41:
				var a := -0.62 + (PI + 1.24) * k / 40.0
				drop.append(Vector2(cos(a) * 27.0, 12.0 + sin(a) * 27.0))
			d.cut(drop, 3.0)
			d.sf(drop)
			d.ink(P([[-12, 6], [-15, 16], [-10, 26]]))
			d.s(P([[-12, 6], [-15, 16], [-10, 26]]), false, 4.0)
			d.sf(ell(36, -26, 5, 6.5, 16), 3.5)
			d.sf(ell(-36, -14, 3.5, 4.5, 16), 3.5)
		"rocket":
			# The homing rocket: nose up and to the right, fins, a window and its flame.
			d.xf = Transform2D(PI / 4.0, Vector2(-2, 4))
			var flame := P([[-8, 22], [0, 46], [8, 22]])
			d.f(flame)
			d.s(flame, false, 4.0)
			for sx in [-1.0, 1.0]:
				var fin := P([[sx * 12, 2], [sx * 25, 18], [sx * 25, 27], [sx * 12, 20]])
				d.sf(fin, 4.5)
			var body := P([[0, -44]])
			bez(body, Vector2(10, -38), Vector2(13, -22), Vector2(13, -6))
			body.append(Vector2(13, 22))
			body.append(Vector2(-13, 22))
			body.append(Vector2(-13, -6))
			bez(body, Vector2(-13, -22), Vector2(-10, -38), Vector2(0, -44))
			d.cut(body, 3.0)
			d.sf(body)
			d.cut(ell(0, -12, 6, 6, 20), 0.0)
			d.s(ell(0, -12, 6, 6, 20), true, 4.0)
			d.xf = Transform2D.IDENTITY
			# The target it has locked on to.
			d.s(ell(36, -36, 9, 9, 28), true, 3.5)
			for c: Array in [[36, -50, 36, -44], [36, -28, 36, -22], [22, -36, 28, -36], [44, -36, 50, -36]]:
				d.s(P([[c[0], c[1]], [c[2], c[3]]]), false, 3.5)
		"lightning":
			# Chain lightning: a jagged arc leaping from one target to the next, and the next.
			d.s(P([[-36, -26], [-28, -14], [-34, -8], [-18, 2], [-22, 8], [-8, 14]]), false, 4.5)
			d.s(P([[6, 12], [12, 2], [8, -4], [22, -10], [18, -16], [28, -24]]), false, 4.5)
			d.s(P([[34, -16], [38, -2], [32, 4], [40, 18], [36, 24]]), false, 4.5)
			for c: Array in [[-38, -34, 11], [0, 20, 12], [36, -30, 10], [34, 36, 9]]:
				var t := ell(float(c[0]), float(c[1]), float(c[2]), float(c[2]), 36)
				d.cut(t, 3.0)
				d.sf(t)
				d.ink(ell(float(c[0]), float(c[1]), float(c[2]) * 0.32, float(c[2]) * 0.32, 16))
			d.ink(star(-50, -14, 5, 0.4))
		"dallah":
			# The dallah: the Arabic coffee pot (round belly, waist, flared top, domed lid and
			# finial, the long beaked spout and the handle) and two coffee beans.
			var spout := P([[-14, 26]])
			bez(spout, Vector2(-32, 22), Vector2(-38, 0), Vector2(-48, -22))
			spout.append(Vector2(-38, -22))
			bez(spout, Vector2(-30, -4), Vector2(-24, 12), Vector2(-10, 12))
			d.sf(spout, 4.5)
			var handle := P([[14, -6]])
			bez(handle, Vector2(36, -8), Vector2(38, 22), Vector2(18, 28))
			d.s(handle, false, 5.0)
			var pot := P([[-20, 38], [20, 38]])
			bez(pot, Vector2(28, 28), Vector2(14, 14), Vector2(9, 4))
			bez(pot, Vector2(6, -2), Vector2(16, -6), Vector2(17, -12))
			pot.append(Vector2(-17, -12))
			bez(pot, Vector2(-16, -6), Vector2(-6, -2), Vector2(-9, 4))
			bez(pot, Vector2(-14, 14), Vector2(-28, 28), Vector2(-20, 38))
			d.cut(pot, 3.0)
			d.sf(pot)
			d.s(P([[-14, 24], [14, 24]]), false, 3.5)
			var lid := arc(0, -13, 13, PI, TAU)
			d.sf(lid, 4.5)
			d.s(P([[0, -26], [0, -33]]), false, 4.5)
			d.ink(ell(0, -37, 4, 4, 16))
			for c: Array in [[34, -36, 0.5], [46, -20, -0.4]]:
				d.xf = Transform2D(float(c[2]), Vector2(float(c[0]), float(c[1])))
				d.sf(ell(0, 0, 7, 4.5, 20), 3.5)
				d.s(P([[-4, 0], [4, 0]]), false, 2.5)
			d.xf = Transform2D.IDENTITY
		"falcon":
			# The falcon, wings spread over its fanned tail, its hooded head and hooked beak.
			for sx: float in [-1.0, 1.0]:
				var wing := PackedVector2Array()
				for v: Array in [[6, -4], [24, -22], [50, -28], [42, -16], [50, -10], [36, -5], [44, 2], [26, 4], [8, 10]]:
					wing.append(Vector2(sx * float(v[0]), float(v[1])))
				d.sf(wing, 4.5)
			var tail := P([[-7, 18], [7, 18], [13, 42], [0, 38], [-13, 42]])
			d.sf(tail, 4.5)
			var body := ell(0, 4, 10, 20, 40)
			d.cut(body, 3.0)
			d.sf(body)
			var head := ell(0, -18, 9, 9, 32)
			d.cut(head, 3.0)
			d.sf(head)
			d.ink(P([[-4, -12], [4, -12], [0, -4]]))
			d.cut(ell(-4, -19, 1.8, 1.8, 12))
			d.cut(ell(4, -19, 1.8, 1.8, 12))
			d.s(P([[0, -27], [0, -33]]), false, 3.5)
		"freeze":
			# The freeze ray: an emitter, an icy beam and the snowflake it makes.
			d.f(P([[-24, 15], [10, -12], [14, -4], [-20, 23]]))
			d.sf(rr(-48, 16, 28, 20, 6))
			d.s(P([[-22, 22], [10, -6]]), false, 6.5)
			for i in 6:
				var a := i * PI / 3.0 - PI / 2.0
				var c := Vector2(26, -22)
				var e := c + Vector2(cos(a), sin(a)) * 24.0
				d.s(PackedVector2Array([c, e]), false, 4.5)
				var m := c + Vector2(cos(a), sin(a)) * 14.0
				for b: float in [-0.75, 0.75]:
					d.s(PackedVector2Array([m, m + Vector2(cos(a + b), sin(a + b)) * 8.0]), false, 3.5)
			var hex := PackedVector2Array()
			for i in 6:
				hex.append(Vector2(26, -22) + Vector2(cos(i * PI / 3.0), sin(i * PI / 3.0)) * 6.0)
			d.cut(hex, 2.0)
			d.sf(hex, 3.5)
		"blackhole":
			# The black hole: a dark core in a tilted swirling disk, and what it is pulling in.
			d.xf = Transform2D(-0.3, Vector2(0, 2))
			d.sf(ell(0, 0, 46, 15))
			d.s(arc(0, 0, 30, PI * 0.05, PI * 0.75), false, 3.5)
			d.s(arc(0, 0, 30, PI * 1.05, PI * 1.75), false, 3.5)
			d.xf = Transform2D.IDENTITY
			# The core is a hole: nothing drawn inside its bright edge.
			d.cut(ell(0, 2, 16, 16, 40), 3.0)
			d.s(ell(0, 2, 14, 14, 40), true, 4.5)
			for c: Array in [[-40, -34, 4.0], [38, 34, 3.4], [36, -40, 3.0]]:
				var at := Vector2(float(c[0]), float(c[1]))
				d.ink(ell(at.x, at.y, float(c[2]), float(c[2]), 16))
				var to := at.lerp(Vector2(0, 2), 0.3)
				d.s(PackedVector2Array([at.lerp(Vector2(0, 2), 0.12), to]), false, 3.0)
		"dates":
			# The date blaster: three glossy dates flying, with speed lines behind.
			for c: Array in [[-24, 24, 0.9], [4, 0, 0.8], [30, -26, 0.7]]:
				d.xf = Transform2D(-0.7, Vector2(float(c[0]), float(c[1]))).scaled_local(Vector2.ONE * float(c[2]))
				var date := ell(0, 0, 16, 10, 40)
				d.cut(date, 3.0)
				d.sf(date)
				d.s(arc(0, -1, 9, PI * 1.15, PI * 1.55), false, 3.5)
				d.ink(rr(-20, -3, 5, 6, 2))
			d.xf = Transform2D.IDENTITY
			for c: Array in [[-50, 22, -40, 30], [-28, -2, -18, 6], [-2, -26, 8, -18]]:
				d.s(P([[c[0], c[1]], [c[2], c[3]]]), false, 3.5)
		"bakhoor":
			# The mabkhara: a foot, a waisted stem and a flared bowl with gold diamonds, smoke curling up.
			d.sf(rr(-22, 34, 44, 10, 2))
			d.sf(P([[-9, 34], [9, 34], [6, 20], [-6, 20]]))
			var bowl := P([[-7, 20], [7, 20], [26, 0], [-26, 0]])
			d.cut(bowl, 3.0)
			d.sf(bowl)
			d.s(P([[-29, -1], [29, -1]]), false, 5.0)
			for x: float in [-11.0, 0.0, 11.0]:
				d.ink(P([[x, 4], [x + 3.5, 8.5], [x, 13], [x - 3.5, 8.5]]))
			var smoke := P([[-2, -6]])
			bez(smoke, Vector2(-14, -16), Vector2(8, -26), Vector2(-6, -36))
			bez(smoke, Vector2(-16, -42), Vector2(-4, -50), Vector2(-14, -52))
			d.s(smoke, false, 4.5)
			var smoke2 := P([[8, -6]])
			bez(smoke2, Vector2(20, -14), Vector2(4, -24), Vector2(18, -32))
			bez(smoke2, Vector2(28, -38), Vector2(20, -46), Vector2(30, -48))
			d.s(smoke2, false, 3.5)
			d.ink(ell(-18, -14, 2.5, 2.5, 12))
			d.ink(ell(24, -20, 2.0, 2.0, 12))
		"lasso":
			# The shemagh lasso: an open loop with the cloth's checks, its rope trailing to the knot.
			var rope := P([[-6, -2]])
			bez(rope, Vector2(-20, 10), Vector2(-14, 26), Vector2(-30, 34))
			bez(rope, Vector2(-40, 40), Vector2(-46, 44), Vector2(-50, 50))
			d.s(rope, false, 5.0)
			var outer := ell(14, -18, 32, 18, 56)
			var inner := ell(14, -18, 22, 10, 48)
			d.f(outer)
			d.cut(inner, 0.0)
			d.s(outer, true, 4.5)
			d.s(inner, true, 4.0)
			for i in 10:
				var a := i * TAU / 10.0 + 0.2
				var q := Vector2(14 + cos(a) * 27.0, -18 + sin(a) * 14.0)
				d.ink(rr(q.x - 2.5, q.y - 2.5, 5, 5, 0.5))
			d.ink(ell(-6, -2, 6, 5, 20))
		"hose":
			# The water hose: a nozzle, an arcing stream and its drops.
			d.xf = Transform2D(-0.55, Vector2(-30, 28))
			d.sf(rr(-18, -8, 34, 16, 5))
			d.s(P([[-6, 8], [-10, 20]]), false, 5.0)
			d.xf = Transform2D.IDENTITY
			var hose_tail := P([[-44, 36]])
			bez(hose_tail, Vector2(-52, 44), Vector2(-40, 52), Vector2(-30, 48))
			d.s(hose_tail, false, 4.5)
			var stream := P([[-14, 16]])
			bez(stream, Vector2(0, -22), Vector2(28, -34), Vector2(42, -8))
			var band := stream.duplicate()
			var back := P([[42, -2]])
			bez(back, Vector2(28, -26), Vector2(2, -14), Vector2(-12, 22))
			band.append_array(back)
			d.f(band)
			d.s(stream, false, 4.5)
			for c: Array in [[42, 10, 4.5], [34, 24, 3.6], [48, 26, 3.0]]:
				d.sf(ell(float(c[0]), float(c[1]), float(c[2]), float(c[2]) * 1.3, 16), 3.0)
		"cluster":
			# The cluster bomb: a round bomb with a fizzing fuse, its little bombs flying off.
			var bomb := ell(-12, 10, 26, 26, 48)
			d.cut(bomb, 3.0)
			d.sf(bomb)
			d.s(arc(-12, 10, 17, PI * 1.08, PI * 1.42), false, 4.0)
			d.sf(rr(-20, -22, 16, 8, 2), 4.0)
			var fuse := P([[-12, -22]])
			bez(fuse, Vector2(-12, -32), Vector2(-4, -36), Vector2(0, -42))
			d.s(fuse, false, 3.5)
			d.ink(star(2, -46, 8, 0.4))
			for c: Array in [[32, -30, 8.0], [42, 2, 7.0], [30, 32, 7.5]]:
				var b := ell(float(c[0]), float(c[1]), float(c[2]), float(c[2]), 24)
				d.cut(b, 2.5)
				d.sf(b, 4.0)
				var from := Vector2(float(c[0]), float(c[1])).lerp(Vector2(-12, 10), 0.35)
				d.s(PackedVector2Array([from, from.lerp(Vector2(-12, 10), 0.25)]), false, 3.0)
		"magnet":
			# The horseshoe magnet: a U with silver poles and the field drawing things in.
			var u := P([[-34, -22], [-34, 10]])
			u.append_array(arc(0, 10, 34, PI, 0.0, true))
			u.append(Vector2(34, -22))
			u.append(Vector2(16, -22))
			u.append(Vector2(16, 10))
			u.append_array(arc(0, 10, 16, 0.0, PI))
			u.append(Vector2(-16, -22))
			d.sf(u)
			d.ink(P([[-34, -22], [-16, -22], [-16, -10], [-34, -10]]))
			d.ink(P([[16, -22], [34, -22], [34, -10], [16, -10]]))
			d.s(arc(0, -24, 18, PI * 1.15, PI * 1.85), false, 3.5)
			d.s(arc(0, -24, 30, PI * 1.2, PI * 1.8), false, 3.0)
			d.ink(ell(0, -48, 3.5, 3.5, 16))
			d.ink(ell(-16, -44, 2.6, 2.6, 12))
		"shield":
			# The shield bubble: a round film with a grid of cells and a shine, a shot glancing off.
			var bub := ell(8, 6, 38, 38, 64)
			d.sf(bub)
			d.s(arc(8, 6, 28, PI * 1.38, PI * 1.62), false, 4.5)
			for c: Array in [[16, 12], [28, 5], [28, 19], [16, 26], [4, 19], [4, 5], [16, -2]]:
				var hx := PackedVector2Array()
				for i in 6:
					hx.append(Vector2(float(c[0]), float(c[1])) + Vector2(cos(i * PI / 3.0 + PI / 6.0), sin(i * PI / 3.0 + PI / 6.0)) * 7.0)
				d.s(hx, true, 2.5)
			d.s(P([[-44, -46], [-20, -21], [-48, -4]]), false, 3.5)
			d.ink(ell(-44, -46, 4, 4, 16))
			d.ink(star(-20, -21, 8, 0.4))
		_:
			d.sf(star(0, 0, 36, 0.46))
	return d.ops
