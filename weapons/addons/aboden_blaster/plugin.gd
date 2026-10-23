@tool
extends EditorPlugin
## Shows the kit as an addon and adds AbodenBlaster to the Create Node dialog. Optional: the
## kit works without enabling the plugin (AbodenBlaster is a global class either way).


func _enter_tree() -> void:
	var dir: String = (get_script() as Script).resource_path.get_base_dir()
	add_custom_type("AbodenBlaster", "Node3D", load(dir.path_join("blaster.gd")), null)


func _exit_tree() -> void:
	remove_custom_type("AbodenBlaster")
