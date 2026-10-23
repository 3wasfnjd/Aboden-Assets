class_name AbodenBlasterAudio
extends Node
## The blaster's own sound player, used when the host has no blaster_sfx(): the bundled
## files in sounds/ (rendered from the original game's Web Audio code; the v1.2 weapons' own
## synthesised the same way by tools/gen_sounds.py) on a pool of AudioStreamPlayer3D.
##
## Files carry the web SFX bus already, so they play at 0 dB; only the per-call gain law
## (e.g. thump's .05 + .28 * k) is applied, relative to the variant picked. Spatial sounds
## use the web panner's law: inverse distance from ref_distance, rolloff 1, no air filter.

## name -> {k: rendered values of the call's parameter (empty = none), n: random variants
## (0 = one file), law: [a, b] amplitude a + b * k (empty = level does not depend on k),
## cycle: variants in turn, gain: k is its level (1 = as rendered)}.
const SFX := {
	"thump": {"k": [0.25, 0.5, 0.75, 1.0], "n": 0, "law": [0.05, 0.28]},
	"squeak": {"k": [0.7, 1.0, 1.15, 1.35], "n": 0, "law": []},
	"pew": {"k": [], "n": 3, "law": []},
	"splash": {"k": [0.25, 0.5, 0.75, 1.0], "n": 3, "law": [0.06, 0.16]},
	"boom": {"k": [], "n": 3, "law": []},
	"whoosh": {"k": [0.2, 0.4, 0.6, 0.8, 1.0], "n": 0, "law": []},
	"swish": {"k": [], "n": 3, "law": []},
	"start_pop": {"k": [], "n": 0, "law": []},
	"firework_launch": {"k": [], "n": 3, "law": [], "cycle": true},
	"firework_burst": {"k": [], "n": 3, "law": [], "cycle": true},
	"cans_clang": {"k": [0.25, 0.5, 0.75, 1.0], "n": 3, "law": [0.02, 0.07]},
	"bricks_tink": {"k": [0.0, 0.25, 0.5, 0.75, 1.0], "n": 0, "law": []},
	"fair_ding": {"k": [], "n": 0, "law": [], "gain": true},
	# v1.2 (tools/gen_sounds.py): k is the level for all of them (1 = as rendered).
	"flap": {"k": [], "n": 3, "law": [], "gain": true},
	"screech": {"k": [], "n": 2, "law": [], "gain": true},
	"ice_zap": {"k": [], "n": 3, "law": [], "gain": true},
	"ice_crack": {"k": [], "n": 3, "law": [], "gain": true},
	"whoomp": {"k": [], "n": 2, "law": [], "gain": true},
	"put": {"k": [], "n": 3, "law": [], "gain": true},
	"ember": {"k": [], "n": 0, "law": [], "gain": true},
	"snap": {"k": [], "n": 3, "law": [], "gain": true},
	"hose_hiss": {"k": [], "n": 3, "law": [], "gain": true},
	"cluster_pop": {"k": [], "n": 3, "law": [], "gain": true},
	"zing": {"k": [], "n": 2, "law": [], "gain": true},
	"shield_up": {"k": [], "n": 0, "law": [], "gain": true},
	"shield_block": {"k": [], "n": 3, "law": [], "gain": true},
}

## Where the files are (AbodenBlaster sets it to its own folder's sounds/).
@export var dir := "res://addons/aboden_blaster/sounds/"
## The panner's refDistance (world scale; 1 at life size).
@export var ref_distance: float = 1.0
@export var pool_size: int = 16
@export var bus := &"Master"
@export var volume_db := 0.0

var _streams: Dictionary = {}
var _pool: Array[AudioStreamPlayer3D] = []
var _next := 0
var _cycle: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_ensure_players()


func _ensure_players() -> void:
	if not _pool.is_empty():
		return
	for i in pool_size:
		var p := AudioStreamPlayer3D.new()
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		p.unit_size = ref_distance
		p.max_db = 0.0
		p.max_distance = 0.0
		p.attenuation_filter_db = 0.0
		p.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
		p.bus = bus
		add_child(p)
		_pool.append(p)


## Lazily loaded stream for a file name (without extension).
func stream(file: String) -> AudioStream:
	if _streams.has(file):
		return _streams[file]
	var s: AudioStream = null
	for ext in [".wav", ".ogg"]:
		var path: String = dir + file + ext
		if ResourceLoader.exists(path):
			s = load(path) as AudioStream
			break
	_streams[file] = s
	return s


static func _tag(k: float) -> String:
	return "_k%02d" % int(round(k * 100.0))


## Every file this player uses (without extension), for checks.
static func all_files() -> PackedStringArray:
	var out := PackedStringArray()
	for snd: String in SFX:
		var e: Dictionary = SFX[snd]
		var ks: Array = e.k
		var n: int = e.n
		var tags: Array[String] = []
		if ks.is_empty():
			tags.append("")
		else:
			for k: float in ks:
				tags.append(_tag(k))
		for t in tags:
			if n == 0:
				out.append(snd + t)
			else:
				for i in n:
					out.append("%s%s_%d" % [snd, t, i + 1])
	return out


## The file and the volume (dB) for a call like the original name(k).
func pick(snd: String, k: float) -> Array:
	var e: Dictionary = SFX[snd]
	var ks: Array = e.k
	var file: String = snd
	var db := 0.0
	if not ks.is_empty():
		var best: float = ks[0]
		for v: float in ks:
			if absf(v - k) < absf(best - k):
				best = v
		file += _tag(best)
		var law: Array = e.law
		if not law.is_empty():
			var a: float = law[0]
			var b: float = law[1]
			db = linear_to_db(maxf(a + b * clampf(k, 0.0, 1.0), 1e-4) / (a + b * best))
	elif e.get("gain", false):
		# One render; k sets its level (1 = as rendered), for quieter uses of the same sound.
		db = linear_to_db(clampf(k, 0.05, 1.0))
	var n: int = e.n
	if n > 0:
		var i: int
		if e.get("cycle", false):
			i = int(_cycle.get(snd, 0)) % n
			_cycle[snd] = i + 1
		else:
			i = _rng.randi_range(0, n - 1)
		file += "_%d" % (i + 1)
	return [file, db]


## Plays a sound effect. k: the original call's parameter (intensity, pitch or power).
## pos: world space (global).
func sfx(snd: String, k: float = 0.5, pos: Vector3 = Vector3.ZERO) -> void:
	if not SFX.has(snd):
		push_warning("AbodenBlasterAudio: unknown sound " + snd)
		return
	var chosen: Array = pick(snd, k)
	var s := stream(chosen[0])
	if s == null or not is_inside_tree():
		return
	_ensure_players()
	var vol: float = chosen[1] + volume_db
	var p := _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stop()
	p.stream = s
	p.unit_size = ref_distance
	p.volume_db = vol
	p.max_db = maxf(0.0, vol)
	p.global_position = pos
	p.play()
