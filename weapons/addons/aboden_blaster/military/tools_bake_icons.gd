extends SceneTree
## Bakes the military pack's icons (military/icons/<id>.svg, the source) to
## military/icons/<id>.png: 256 px RGBA, transparent around. With --docs=<dir> it also
## writes each on the dark rounded card of the kit's docs as mil_<id>.png.
##
##   godot --headless --path <project> -s res://addons/aboden_blaster/military/tools_bake_icons.gd [-- --docs=res://docs/icons]

const Catalog := preload("military_catalog.gd")
const KitBake := preload("../tools/bake_icons.gd")
const SIZE := 256


func _initialize() -> void:
	var dir: String = (get_script() as Script).resource_path.get_base_dir().path_join("icons")
	var docs := ""
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--docs="):
			docs = a.trim_prefix("--docs=")
	var err := OK
	for id: String in Catalog.ids():
		var img := icon(id)
		if img == null:
			err = FAILED
			continue
		err = maxi(err, img.save_png(ProjectSettings.globalize_path(dir.path_join(id + ".png"))))
		if docs != "":
			var abs_dir := ProjectSettings.globalize_path(docs) if docs.begins_with("res://") else docs
			DirAccess.make_dir_recursive_absolute(abs_dir)
			err = maxi(err, KitBake._card(img).save_png(abs_dir.path_join("mil_" + id + ".png")))
	print("bake military icons: %s -> %s %s" % [error_string(err), dir, docs])
	quit(0 if err == OK else 1)


## The icon rasterised from its SVG at `px` pixels (null if missing).
static func icon(id: String, px := SIZE) -> Image:
	var path := "res://addons/aboden_blaster/military/icons/%s.svg" % id
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var img := Image.new()
	if img.load_svg_from_string(f.get_as_text(), px / 256.0) != OK:
		return null
	img.convert(Image.FORMAT_RGBA8)
	return img
