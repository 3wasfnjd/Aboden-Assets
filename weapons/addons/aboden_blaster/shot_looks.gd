class_name AbodenShotLooks
extends RefCounted
## The shots' looks that need more than a primitive mesh: the little balls of the mini
## shot (bodies in five styles, the jelly's bandage, the fur ball's ribbon), the soap
## bubbles, and the wooden boomerang, with three.js's own geometry generators (so the shapes
## match the originals); and since v1.2 the bakhoor's gold-latticed wood, the lasso's shemagh
## and the shield's bubble, all drawn in code. Self-contained: only what the blaster uses is here.
##
## The jelly's light (light_dir, light_color, light_intensity) is a plain uniform of its
## material: set it from your sun if you like (body_material("jelly")).

## Each look's own colour (sRGB).
const LOOK_COLORS := {"jelly": "ff69b4", "fabric": "b36bff", "clay": "ff9b3d", "fur": "f1ebe1", "bubble": "cfe8ff"}
const STYLES := ["jelly", "fabric", "clay", "fur", "bubble"]
const BOW_AT := Vector3(-0.1, 0.86, 0.5)
const FUR_TEXTURE := "looks/fur.png"
## The canvas pattern that means "glows, unlit" in ACC_SHADER (the bandage's dots).
const PATTERN_UNLIT := 6

static var _cache := {}
## The addon's folder (AbodenBlaster sets it from its own script's path, so a copy under
## another folder still finds its files).
static var base_dir := "res://addons/aboden_blaster"

## Jelly: light refracted through the ball A soft sky is looked up
## along the path light takes through a sphere of index 1.35, a little apart per colour;
## Beer-Lambert absorption from the tint, a Fresnel reflection and the sun's highlight.
## The tint is the vertex/instance colour times `tint`.
const JELLY_SHADER := """
shader_type spatial;
render_mode unshaded, cull_back;
uniform vec3 light_dir = vec3(0.384, 0.808, 0.441);
uniform vec3 light_color = vec3(1.0, 0.945, 0.867);
uniform float light_intensity = 1.35;
uniform vec3 tint = vec3(1.0);
uniform float ior = 1.35;
uniform vec3 sky : source_color = vec3(0.8118, 0.8902, 1.0);
uniform vec3 ground : source_color = vec3(0.5412, 0.4902, 0.4235);
varying vec3 vW;
varying vec3 vN;
varying vec3 vC;
varying vec3 vTint;
void vertex() {
	vW = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vN = normalize(mat3(MODEL_MATRIX) * NORMAL);
	vC = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vTint = COLOR.rgb * tint;
}
vec3 world_col(vec3 d) { return mix(ground, sky, smoothstep(-0.25, 0.35, d.y)); }
vec3 through(vec3 p, vec3 v, vec3 nrm, float n, out float len) {
	vec3 t = refract(v, nrm, 1.0 / n);
	vec3 oc = p - vC;
	float b = dot(oc, t);
	len = max(0.0, -2.0 * b);
	vec3 q = p + t * len;
	vec3 nx = normalize(q - vC);
	vec3 o = refract(t, -nx, n);
	if (dot(o, o) < 0.01) o = reflect(t, -nx);
	return o;
}
void fragment() {
	vec3 N = normalize(vN);
	vec3 V = normalize(CAMERA_POSITION_WORLD - vW);
	vec3 I = -V;
	float R = max(length(vW - vC), 1e-4);
	float len;
	vec3 oR = through(vW, I, N, ior - 0.012, len);
	vec3 oG = through(vW, I, N, ior, len);
	vec3 oB = through(vW, I, N, ior + 0.014, len);
	vec3 seen = vec3(world_col(oR).r, world_col(oG).g, world_col(oB).b);
	vec3 absorption = vec3(0.08) + (vec3(1.0) - vTint) * 1.2;
	vec3 trans = seen * exp(-absorption * (len / (2.0 * R))) * mix(vec3(1.0), vTint * 2.4, 0.5) * 1.05;
	float f = 0.022 + (1.0 - 0.022) * pow(1.0 - max(dot(N, V), 0.0), 5.0);
	vec3 refl = world_col(reflect(I, N));
	vec3 L = normalize(light_dir);
	vec3 H = normalize(L + V);
	float nh = max(dot(N, H), 0.0);
	vec3 lc = light_color * min(1.4, 0.6 + light_intensity);
	vec3 spec = lc * (pow(nh, 260.0) * 2.2 + pow(nh, 40.0) * 0.12);
	float rim = pow(1.0 - max(dot(N, V), 0.0), 2.0) * max(dot(N, L) * 0.5 + 0.5, 0.0);
	ALBEDO = mix(trans, refl, f) + spec + vTint * rim * 0.35;
}
"""

## Bubble: a swirling soap film with white spots fixed to the body.
const BUBBLE_SHADER := """
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, blend_mix;
uniform vec3 tint = vec3(1.0);
varying vec3 vN;
varying vec3 vV;
varying vec3 vP;
varying vec3 vTint;
void vertex() {
	vec4 mv = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vN = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vV = normalize(-mv.xyz);
	vP = VERTEX;
	vTint = COLOR.rgb * tint;
}
float white_spot(vec3 p, vec3 at, float radius) { return 1.0 - smoothstep(radius - 0.018, radius + 0.018, distance(p, normalize(at))); }
void fragment() {
	vec3 n = normalize(vN);
	vec3 v = normalize(vV);
	float c = abs(dot(n, v));
	float f = 1.0 - c;
	vec3 p = normalize(vP);
	float th = 0.55 + 0.25 * sin(p.x * 5.0 + TIME * 0.7 + sin(p.y * 4.0 - TIME * 0.5) * 1.6) + 0.2 * sin(p.z * 7.0 - TIME * 0.4) - 0.25 * p.y;
	vec3 film = 0.5 + 0.5 * cos(6.2831 * (th * 2.2 / (0.4 + c) + vec3(0.0, 0.33, 0.67)));
	vec3 r = reflect(-v, n);
	float win = smoothstep(0.93, 0.97, dot(r, normalize(vec3(-0.45, 0.6, 0.65)))) + 0.6 * smoothstep(0.96, 0.985, dot(r, normalize(vec3(0.6, 0.3, 0.75))));
	float rim = pow(f, 1.8);
	vec3 col = mix(vTint, film, 0.32);
	float spots = max(white_spot(p, vec3(-0.38, 0.58, 0.72), 0.14), max(white_spot(p, vec3(-0.08, 0.77, 0.62), 0.08), white_spot(p, vec3(0.62, -0.38, 0.67), 0.065)));
	col = mix(col * (0.7 + rim * 0.3) + win * 0.7, vec3(1.0), spots);
	ALBEDO = col;
	ALPHA = min(1.0, 0.22 + rim * 0.65 + win * 0.65 + spots * 0.78);
}
"""

## Decorations (the boomerang's paint and wood, the ribbon, the bandage): vertex colour
## (linear) as albedo; UV2.x = roughness + 2 * pattern, UV2.y = metalness + 2 * round(10 *
## envMapIntensity). Pattern 6 glows unlit; the env term stands in for the reflected room.
const ACC_SHADER := """
shader_type spatial;
render_mode cull_disabled;
vec3 lin(vec3 c) { return mix(pow((c + vec3(0.055)) / 1.055, vec3(2.4)), c / 12.92, lessThan(c, vec3(0.04045))); }
vec3 room(float y) {
	float v = acos(clamp(y, -1.0, 1.0)) / PI;
	vec3 c = mix(vec3(1.0, 0.98, 0.941), vec3(0.914, 0.875, 0.812), smoothstep(0.0, 0.45, v));
	c = mix(c, vec3(0.616, 0.561, 0.486), smoothstep(0.45, 0.55, v));
	c = mix(c, vec3(0.298, 0.263, 0.220), smoothstep(0.55, 1.0, v));
	return lin(c);
}
void fragment() {
	float pk = floor(UV2.x * 0.5 + 0.001);
	float rough = clamp(UV2.x - 2.0 * pk, 0.0, 1.0);
	float eq = floor(UV2.y * 0.5 + 0.001);
	float metal = clamp(UV2.y - 2.0 * eq, 0.0, 1.0);
	float env = eq * 0.1;
	int k = int(pk + 0.5);
	vec3 col = COLOR.rgb;
	if (k == 6) {
		ALBEDO = vec3(0.0);
		EMISSION = col;
		SPECULAR = 0.0;
		ROUGHNESS = 1.0;
	} else {
		ALBEDO = col;
		ROUGHNESS = rough;
		METALLIC = metal;
		if (env > 0.0) {
			vec3 r = (INV_VIEW_MATRIX * vec4(reflect(-VIEW, NORMAL), 0.0)).xyz;
			float fv = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 5.0);
			vec3 f0 = mix(vec3(0.04), col, metal);
			EMISSION = room(r.y) * (f0 + (vec3(1.0) - f0) * fv) * env * (1.0 - rough * 0.6) * 0.6;
		}
	}
}
"""


static func _shader(key: String, code: String) -> Shader:
	if not _cache.has("shader_" + key):
		var sh := Shader.new()
		sh.code = code
		_cache["shader_" + key] = sh
	return _cache["shader_" + key]


## A body's material for crowds: the colour comes from each instance (white base).
## Bubbles draw after the rest (render_priority 3).
static func body_material(style: String) -> Material:
	if not style in STYLES:
		style = "jelly"
	var key := "body_" + style
	if _cache.has(key):
		return _cache[key]
	var m: Material
	match style:
		"jelly", "bubble":
			var sm := ShaderMaterial.new()
			sm.shader = _shader(style, JELLY_SHADER if style == "jelly" else BUBBLE_SHADER)
			sm.set_shader_parameter("tint", Color.WHITE)
			if style == "bubble":
				sm.render_priority = 3
			m = sm
		_:
			var s := StandardMaterial3D.new()
			s.albedo_color = Color.WHITE
			s.vertex_color_use_as_albedo = true
			match style:
				"fur":
					# The skin is the colour of the hair roots: the neutral coat keeps the hue.
					var path := base_dir.path_join(FUR_TEXTURE)
					if ResourceLoader.exists(path):
						s.albedo_texture = load(path)
					s.roughness = 0.95
				"fabric":
					s.roughness = 0.82
				_:
					s.roughness = 0.72
			m = s
	_cache[key] = m
	return m


## Decorations (ACC_SHADER), one material for all.
static func acc_material() -> ShaderMaterial:
	if not _cache.has("acc_mat"):
		var m := ShaderMaterial.new()
		m.shader = _shader("acc", ACC_SHADER)
		_cache["acc_mat"] = m
	return _cache["acc_mat"]


## The bakhoor burner's dark wood with a gold lattice (diamonds and dots) over its sides.
const BAKHOOR_SHADER := """
shader_type spatial;
uniform vec3 wood : source_color = vec3(0.23, 0.14, 0.086);
uniform vec3 gold : source_color = vec3(0.83, 0.65, 0.25);
void fragment() {
	vec2 g = UV * vec2(16.0, 3.0);
	float a = abs(fract(g.x + g.y) - 0.5);
	float b = abs(fract(g.x - g.y) - 0.5);
	float line = 1.0 - smoothstep(0.04, 0.09, min(a, b));
	vec2 c = fract(g + 0.5) - 0.5;
	float dot_ = 1.0 - smoothstep(0.07, 0.12, length(c));
	float m = max(line, dot_);
	float grain = 0.85 + 0.15 * sin(UV.y * 90.0 + sin(UV.x * 40.0) * 2.0);
	ALBEDO = mix(wood * grain, gold, m);
	METALLIC = m * 0.8;
	ROUGHNESS = mix(0.62, 0.28, m);
}
"""

## The shield: a pale cyan bubble, clear in the middle and bright at its rim, a faint grid of
## cells over it; `flash` (0..1) lights it up where something was stopped, `fade` fades it.
const SHIELD_SHADER := """
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never;
uniform vec4 tint : source_color = vec4(0.45, 0.88, 1.0, 1.0);
uniform float flash = 0.0;
uniform float fade = 1.0;
void fragment() {
	float fres = pow(1.0 - abs(dot(NORMAL, VIEW)), 2.2);
	vec2 g = UV * vec2(28.0, 14.0);
	vec2 f = abs(fract(vec2(g.x + 0.5 * floor(g.y), g.y)) - 0.5);
	float cell = smoothstep(0.40, 0.48, max(f.x, f.y));
	ALBEDO = mix(tint.rgb, vec3(1.0), 0.25 * fres + 0.5 * flash);
	ALPHA = clamp((0.03 + 0.6 * fres + 0.08 * cell + 0.3 * flash) * fade, 0.0, 1.0);
}
"""


## The bakhoor's wood (BAKHOOR_SHADER), one for all.
static func bakhoor_material() -> ShaderMaterial:
	if not _cache.has("bakhoor_mat"):
		var m := ShaderMaterial.new()
		m.shader = _shader("bakhoor", BAKHOOR_SHADER)
		_cache["bakhoor_mat"] = m
	return _cache["bakhoor_mat"]


## A shield bubble's material (SHIELD_SHADER): a new one per bubble (its flash and fade are its own).
static func shield_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _shader("shield", SHIELD_SHADER)
	m.render_priority = 4
	return m


## The shemagh's red-and-white check, drawn once into a small texture: a white cloth with red
## lines both ways, a red square where they cross and red dots between them.
static func shemagh_texture() -> ImageTexture:
	if _cache.has("shemagh_tex"):
		return _cache["shemagh_tex"]
	var n := 32
	var img := Image.create(n, n, false, Image.FORMAT_RGB8)
	var red := Color("c8102e")
	var white := Color("f4f1ea")
	for y in n:
		for x in n:
			var cx := x % 8
			var cy := y % 8
			var on := cx < 2 or cy < 2 or (cx == 5 and cy == 5)
			img.set_pixel(x, y, red if on else white)
	var tex := ImageTexture.create_from_image(img)
	_cache["shemagh_tex"] = tex
	return tex


## The lasso's cloth (shemagh_texture), one for all.
static func shemagh_material() -> StandardMaterial3D:
	if not _cache.has("shemagh_mat"):
		var m := StandardMaterial3D.new()
		m.albedo_texture = shemagh_texture()
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		m.uv1_scale = Vector3(8.0, 1.0, 1.0)
		m.roughness = 0.85
		_cache["shemagh_mat"] = m
	return _cache["shemagh_mat"]


# --- geometry (three.js generators, so the shapes match) -----------------------------------
## Generators return {v, n, uv, i}.

## three.js SphereGeometry.
static func sphere(r: float, ws: int, hs: int, phi0 := 0.0, phi_len := TAU, th0 := 0.0, th_len := PI) -> Dictionary:
	var pv := PackedVector3Array()
	var pn := PackedVector3Array()
	var puv := PackedVector2Array()
	var pi := PackedInt32Array()
	var th_end := minf(th0 + th_len, PI)
	for iy in hs + 1:
		var v := float(iy) / hs
		for ix in ws + 1:
			var u := float(ix) / ws
			var p := Vector3(-r * cos(phi0 + u * phi_len) * sin(th0 + v * th_len), r * cos(th0 + v * th_len), r * sin(phi0 + u * phi_len) * sin(th0 + v * th_len))
			pv.append(p)
			pn.append(p.normalized() if p.length_squared() > 0.0 else Vector3.UP)
			puv.append(Vector2(u, v))
	for iy in hs:
		for ix in ws:
			var a := iy * (ws + 1) + ix + 1
			var b := iy * (ws + 1) + ix
			var c := (iy + 1) * (ws + 1) + ix
			var d := (iy + 1) * (ws + 1) + ix + 1
			if iy != 0 or th0 > 0.0:
				pi.append_array([a, b, d])
			if iy != hs - 1 or th_end < PI:
				pi.append_array([b, c, d])
	return {"v": pv, "n": pn, "uv": puv, "i": pi}


## three.js BoxGeometry (one 0..1 UV square per face).
static func box(w: float, h: float, d: float) -> Dictionary:
	var pv := PackedVector3Array()
	var pn := PackedVector3Array()
	var puv := PackedVector2Array()
	var pi := PackedInt32Array()
	var e := Vector3(w, h, d) / 2.0
	for f in [[Vector3.RIGHT, Vector3.UP, Vector3.BACK], [Vector3.LEFT, Vector3.UP, Vector3.FORWARD],
			[Vector3.UP, Vector3.BACK, Vector3.RIGHT], [Vector3.DOWN, Vector3.FORWARD, Vector3.RIGHT],
			[Vector3.BACK, Vector3.UP, Vector3.LEFT], [Vector3.FORWARD, Vector3.UP, Vector3.RIGHT]]:
		var n: Vector3 = f[0]
		var a: Vector3 = f[1]
		var b: Vector3 = f[2]
		var base := pv.size()
		for c in [[-1, -1], [1, -1], [1, 1], [-1, 1]]:
			pv.append((n + a * float(c[0]) + b * float(c[1])) * e)
			pn.append(n)
			puv.append(Vector2((float(c[1]) + 1.0) * 0.5, (1.0 - float(c[0])) * 0.5))
		pi.append_array([base, base + 1, base + 2, base, base + 2, base + 3])
	return {"v": pv, "n": pn, "uv": puv, "i": pi}


## three.js CircleGeometry (facing +Z).
static func circle(r: float, segs: int) -> Dictionary:
	var pv := PackedVector3Array()
	var pn := PackedVector3Array()
	var puv := PackedVector2Array()
	var pi := PackedInt32Array()
	pv.append(Vector3.ZERO)
	pn.append(Vector3.BACK)
	puv.append(Vector2(0.5, 0.5))
	for s in segs + 1:
		var a := float(s) / segs * TAU
		pv.append(Vector3(cos(a) * r, sin(a) * r, 0))
		pn.append(Vector3.BACK)
		puv.append(Vector2(0.5, 0.5))
	for s in range(1, segs + 1):
		pi.append_array([0, s, s + 1])
	return {"v": pv, "n": pn, "uv": puv, "i": pi}


## three.js object matrix: position, Euler rotation (XYZ unless told), scale.
static func xf(pos: Vector3, rot := Vector3.ZERO, scl := Vector3.ONE, order := EULER_ORDER_XYZ) -> Transform3D:
	return Transform3D(Basis.from_euler(rot, order) * Basis.from_scale(scl), pos)


## Merge [geometry, transform, colour (sRGB; alpha kept), (surface)] parts into one mesh with
## vertex colours (linear). surface: [roughness, metalness, pattern, envMapIntensity]; when any
## part has one the mesh carries UV2 for ACC_SHADER (others get roughness 0.5). Triangles face
## the way their normals point (Godot: clockwise front).
static func merge(list: Array, with_uv := false) -> ArrayMesh:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var idx := PackedInt32Array()
	var surfaced := false
	for part: Array in list:
		if part.size() > 3:
			surfaced = true
	for part: Array in list:
		var g: Dictionary = part[0]
		var t: Transform3D = part[1]
		var col: Color = part[2]
		var s: Array = part[3] if part.size() > 3 else [0.5, 0.0, 0, 0.0]
		var s2 := Vector2(float(s[0]) + 2.0 * int(s[2]), float(s[1]) + 2.0 * roundf(float(s[3]) * 10.0))
		var lc := Color(col.srgb_to_linear(), col.a)
		var nb := t.basis.inverse().transposed()
		var base := v.size()
		var gv: PackedVector3Array = g.v
		var gn: PackedVector3Array = g.n
		var guv: PackedVector2Array = g.uv
		for k in gv.size():
			v.append(t * gv[k])
			n.append((nb * gn[k]).normalized())
			c.append(lc)
			uv.append(guv[k])
			uv2.append(s2)
		var gi: PackedInt32Array = g.i
		for k in range(0, gi.size(), 3):
			var a := base + gi[k]
			var b := base + gi[k + 1]
			var d := base + gi[k + 2]
			var face := (v[b] - v[a]).cross(v[d] - v[a])
			if face.dot(n[a] + n[b] + n[d]) > 0.0:
				idx.append_array([a, d, b])
			else:
				idx.append_array([a, b, d])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = n
	arr[Mesh.ARRAY_COLOR] = c
	if with_uv or surfaced:
		arr[Mesh.ARRAY_TEX_UV] = uv
	if surfaced:
		arr[Mesh.ARRAY_TEX_UV2] = uv2
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return mesh


static func _cached(key: String, build: Callable) -> ArrayMesh:
	if not _cache.has(key):
		_cache[key] = build.call()
	return _cache[key]


## A surface for merge(): roughness, metalness, pattern, envMapIntensity.
static func _s(rough := 0.5, metal := 0.0, pat := 0, env := 0.0) -> Array:
	return [rough, metal, pat, env]


## A body sphere (three SphereGeometry(r, segs, rings)) with UVs and white vertex colours.
static func body_mesh(r: float, segs := 32, rings := 20) -> ArrayMesh:
	return _cached("body_%f_%d_%d" % [r, segs, rings], func() -> ArrayMesh:
		return merge([[sphere(r, segs, rings), Transform3D.IDENTITY, Color.WHITE]], true))


## The fur ball's ribbon (two loops and a knot), unit radius.
static func bow_mesh() -> ArrayMesh:
	return _cached("bow_lite", func() -> ArrayMesh:
		var g := xf(BOW_AT.normalized() * 1.06, Vector3(-0.15, -0.1, 0.15))
		var red := _s(0.45, 0.0, 0, 0.5)
		var dark := _s(0.6)
		var list := []
		for s in [-1.0, 1.0]:
			list.append([sphere(0.17, 10, 8), g * xf(Vector3(s * 0.2, 0, 0), Vector3(0, 0, s * 0.35), Vector3(1.2, 0.9, 0.6)), Color("d8452f"), red])
		list.append([sphere(0.07, 8, 6), g, Color("b8432a"), dark])
		return merge(list))


## The jelly ball's plaster on its surface, tilted, unit radius.
static func bandage_mesh() -> ArrayMesh:
	return _cached("bandage", func() -> ArrayMesh:
		var n := Vector3(0.4, 0.62, 0.6).normalized()
		var g := Transform3D(Basis.looking_at(n, Vector3.UP, true) * Basis(Vector3.BACK, -0.55), n * 1.005)
		var list := [[box(0.66, 0.24, 0.03), g, Color("e8c29d"), _s(0.6, 0.0, 0, 0.4)], [box(0.22, 0.17, 0.04), g, Color("f4ddc3"), _s(0.95)]]
		for i in 6:
			var p := Vector3((i % 3 - 1) * 0.07 + (-0.23 if i < 3 else 0.23), (1 if i < 3 else -1) * 0.03, 0.016)
			list.append([circle(0.012, 8), g * xf(p), Color("c9a07c"), _s(1.0, 0.0, PATTERN_UNLIT)])
		return merge(list))


# --- the boomerang (world_balls.gd boomerang_mesh) ------------------------------------------

## The boomerang (units at k = 1, about 0.3 tip to tip, flat in XZ, spinning about its
## centre of mass at the origin): a smooth banana-curved V with a rounded elbow, arms
## tapering to round tips, an airfoil section (domed on top, flatter below) thinning toward
## the tips; natural wood painted with teal tips, red and yellow bands and white dots.
static func boomerang_mesh() -> ArrayMesh:
	return _cached("boomerang", _build_boomerang)


static func _build_boomerang() -> ArrayMesh:
	const L := 0.15  # half span
	const D := 0.1  # how far the arms sweep back
	const E := 0.32  # the elbow's roundness
	const W := 0.024  # half width at the elbow
	const T := 0.0058  # half thickness at the elbow
	var centre := func(u: float) -> Vector3:
		return Vector3(u * L, 0.0, D * (sqrt(u * u + E * E) - E) / (sqrt(1.0 + E * E) - E) + 0.012 * u * u * u * u)
	# The centre of mass (roughly: the centreline's mean), so it spins about the right spot.
	var com := Vector3.ZERO
	for k in 41:
		com += centre.call(-1.0 + 2.0 * k / 40.0)
	com /= 41.0
	var wood := Color("c8894c")
	var dark := Color("8a5428")
	var teal := Color("1fb5a6")
	var red := Color("e2483a")
	var yellow := Color("f6c445")
	var ws := [0.55, 0.0, 0, 0.35]
	var paint := [0.38, 0.0, 0, 0.45]
	# Bands along the span (|u| from the elbow out), mirrored on both arms.
	var bands: Array = [[0.0, 0.12, red], [0.12, 0.16, yellow], [0.16, 0.58, wood], [0.58, 0.62, dark], [0.62, 0.68, red],
		[0.68, 0.72, yellow], [0.72, 0.78, red], [0.78, 0.84, wood], [0.84, 1.0, teal]]
	var list := []
	for side: float in [-1.0, 1.0]:
		for b: Array in bands:
			var u0: float = b[0]
			var u1: float = b[1]
			var n := maxi(2, int(ceil((u1 - u0) * 48.0)))
			list.append([_boomerang_strip(centre, com, side, u0, u1, n, W, T), Transform3D.IDENTITY, b[2], ws if b[2] == wood or b[2] == dark else paint])
		# Painted dots down the middle of each arm, on the top face.
		for k in 6:
			var u := 0.24 + k * 0.058
			var c: Vector3 = (centre.call(u * side) as Vector3) - com
			var top := _boomerang_half_thick(u, T) * 0.92
			list.append([sphere(0.0042, 8, 4, 0.0, TAU, 0.0, PI / 2.0), xf(c + Vector3(0, top, 0), Vector3.ZERO, Vector3(1, 0.5, 1)),
				Color("fff6e0"), paint])
	return merge(list)


## The round end of an arm: 1 along it, falling to 0 at the very tip (|u| = 1).
static func _boomerang_tip(u: float) -> float:
	if u <= 0.89:
		return 1.0
	var q := (u - 0.89) / 0.11
	return sqrt(maxf(0.0, 1.0 - q * q))


static func _boomerang_width(u: float, W: float) -> float:
	return W * (1.0 - 0.3 * u) * _boomerang_tip(u)


static func _boomerang_half_thick(u: float, T: float) -> float:
	return T * (1.0 - 0.35 * u) * sqrt(_boomerang_tip(u))


## One stretch of an arm, |u| from u0 to u1 on `side`: rings of an airfoil section (domed
## on top, flatter underneath) around the centreline, normals from the surface.
static func _boomerang_strip(centre: Callable, com: Vector3, side: float, u0: float, u1: float, n: int, W: float, T: float) -> Dictionary:
	const M := 16
	var pv := PackedVector3Array()
	var pn := PackedVector3Array()
	var puv := PackedVector2Array()
	var pi := PackedInt32Array()
	var at := func(u: float, a: float) -> Vector3:
		var c: Vector3 = (centre.call(u * side) as Vector3) - com
		var d: Vector3 = (centre.call(minf(u + 0.01, 1.0) * side) as Vector3) - (centre.call(maxf(u - 0.01, 0.0) * side) as Vector3)
		if d.length_squared() < 1e-12:
			d = Vector3(side, 0, 0)
		var tw := d.normalized()
		var across := Vector3(tw.z, 0.0, -tw.x)
		var w := _boomerang_width(u, W)
		var th := _boomerang_half_thick(u, T)
		var sa := sin(a)
		return c + across * w * cos(a) + Vector3.UP * th * sa * (1.0 if sa > 0.0 else 0.6)
	for j in n + 1:
		var u := lerpf(u0, u1, float(j) / n)
		var c: Vector3 = (centre.call(u * side) as Vector3) - com
		for i in M + 1:
			var a := TAU * i / M
			var p: Vector3 = at.call(u, a)
			var du: Vector3 = (at.call(minf(u + 0.004, 1.0), a) as Vector3) - (at.call(maxf(u - 0.004, 0.0), a) as Vector3)
			var da: Vector3 = (at.call(u, a + 0.05) as Vector3) - (at.call(u, a - 0.05) as Vector3)
			var nrm := du.cross(da)
			if nrm.length_squared() < 1e-16 or u >= 0.999:
				nrm = p - c
			nrm = nrm.normalized()
			if nrm.dot(p - c) < 0.0:
				nrm = -nrm
			pv.append(p)
			pn.append(nrm)
			puv.append(Vector2(u, float(i) / M))
	var row := M + 1
	for j in n:
		for i in M:
			var q := j * row + i
			pi.append_array([q, q + 1, q + row + 1, q, q + row + 1, q + row])
	return {"v": pv, "n": pn, "uv": puv, "i": pi}
