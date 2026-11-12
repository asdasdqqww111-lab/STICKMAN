extends Node3D
const ASSETS = [preload("res://assets/gobkit/TreeMed001.glb"), preload("res://assets/gobkit/Rock001.glb"), preload("res://assets/gobkit/Bush001.glb"), preload("res://assets/city/casa_simples.glb")]
func _ready() -> void:
	for i in range(ASSETS.size()):
		var node: Node3D = ASSETS[i].instantiate(); add_child(node); node.position.x = (i - 1.5) * 3
	var light := DirectionalLight3D.new(); light.rotation_degrees = Vector3(-45, 30, 0); add_child(light)
	var camera := Camera3D.new(); add_child(camera); camera.position = Vector3(0, 5, 14); camera.look_at(Vector3(0, 1, 0)); camera.current = true
