extends SceneTree
## Bakes the shot icons (all of AbodenShotIcons.IDS) (AbodenShotIcons) to the addon's icons/<id>.png: 256 px RGBA,
## the tint layer in the game's accent under the line layer, transparent around. With
## --docs=<dir> it also writes each icon on a dark rounded card (the game's dark menu glass)
## for documents with a light background.
##
##   godot --headless --path <project> -s res://addons/aboden_blaster/tools/bake_icons.gd [-- --docs=res://docs/icons]

const Icons := preload("../shot_icons.gd")
const CARD := Color(0.08, 0.085, 0.11)


func _initialize() -> void:
	var dir: String = (get_script() as Script).resource_path.get_base_dir().get_base_dir().path_join("icons")
	var err := Icons.bake(dir)
	print("bake_icons: %s -> %s" % [error_string(err), dir])
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--docs="):
			var docs := a.trim_prefix("--docs=")
			var abs_dir := ProjectSettings.globalize_path(docs) if docs.begins_with("res://") else docs
			DirAccess.make_dir_recursive_absolute(abs_dir)
			for id: String in Icons.IDS:
				var img := _card(Icons.image(id, Icons.SIZE))
				err = img.save_png(abs_dir.path_join(id + ".png"))
			print("bake_icons: %s -> %s (cards)" % [error_string(err), docs])
	quit(0 if err == OK else 1)


## The icon on a dark rounded square (radius 18% of the side), anti-aliased corners.
static func _card(icon: Image) -> Image:
	var px := icon.get_width()
	var r := px * 0.18
	var out := Image.create(px, px, false, Image.FORMAT_RGBA8)
	for y in px:
		for x in px:
			var q := Vector2(x + 0.5, y + 0.5)
			var cx := clampf(q.x, r, px - r)
			var cy := clampf(q.y, r, px - r)
			var cover := clampf(r - q.distance_to(Vector2(cx, cy)) + 0.5, 0.0, 1.0)
			var c := icon.get_pixel(x, y)
			var mix := CARD.lerp(Color(c.r, c.g, c.b), c.a)
			out.set_pixel(x, y, Color(mix.r, mix.g, mix.b, cover))
	return out
