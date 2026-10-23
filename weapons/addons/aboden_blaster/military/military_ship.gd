class_name AbodenMilitaryShip
extends MeshInstance3D
## The launch ship of «حرب البارجة» (optional): a toy cruiser that carries a launcher for
## every military weapon (eight: vls, box, gun, pod, ramp, silo, deck, tube). Give it to
## AbodenMilitaryLauncher.ship and shots leave from their own launcher on board (it moves /
## turns / scales with the ship). The parked jets on the flight deck show how many strike
## jets are aboard.

const Looks := preload("military_looks.gd")

var parked: Array[MeshInstance3D] = []


func _init() -> void:
	name = "MilitaryShip"
	mesh = Looks.ship()
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var jm := Looks.parked_jet()
	for k in 2:
		var j := MeshInstance3D.new()
		j.name = "ParkedJet%d" % k
		j.mesh = jm
		j.position = Vector3(-0.066 + k * 0.009, Looks.SHIP_FB + 0.0035, (k - 0.5) * 0.011)
		j.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(j)
		parked.append(j)


## Show as many parked jets as are aboard.
func set_jets_aboard(n: int) -> void:
	for k in parked.size():
		parked[k].visible = k < n


## Launch point of a weapon in the parent's space (the launcher's parent, normally).
func launch_point(wid: String) -> Vector3:
	return transform * Looks.launcher_point(wid)
