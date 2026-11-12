extends Node3D
## Harvestable world node (herbs, ore, wood).  Nodes are persistent: once
## gathered their id is stored in PlayerState.gathered and they regrow after a
## world-clock delay recorded in `respawn_at` (handled by WorldSimulation).

signal harvested(node_id: String, item_id: String, amount: int)

const ItemDB = preload("res://scripts/data/item_database.gd")

var node_id := ""
var item_id := "purple_herb"
var amount := 1
var display_name := "Herb"
var respawn_seconds := 240.0
var gathered_at := -1.0
var visual: Node3D
var glow: MeshInstance3D


func configure(id: String, item: String, count: int, world_position: Vector3, basis_orientation: Basis, label: String = "") -> void:
	node_id = id
	item_id = item
	amount = count
	display_name = label if label != "" else ItemDB.display_name(item)
	position = world_position
	basis = basis_orientation
	name = "Resource_" + id


func is_ready() -> bool:
	return visible


func harvest() -> Dictionary:
	if not visible:
		return {}
	visible = false
	gathered_at = Time.get_ticks_msec() / 1000.0
	emit_signal("harvested", node_id, item_id, amount)
	return {"item_id": item_id, "amount": amount, "name": display_name}


func regrow() -> void:
	visible = true
	gathered_at = -1.0


func set_gathered(persisted: bool) -> void:
	visible = not persisted


func build_visual(colour: Color, height: float = 0.7) -> void:
	if visual != null:
		return
	visual = Node3D.new()
	add_child(visual)
	var stem := MeshInstance3D.new()
	var stem_mesh := CylinderMesh.new()
	stem_mesh.top_radius = 0.03
	stem_mesh.bottom_radius = 0.05
	stem_mesh.height = height * 0.6
	stem.mesh = stem_mesh
	stem.position.y = height * 0.3
	var stem_material := StandardMaterial3D.new()
	stem_material.albedo_color = Color("37623a")
	stem.material_override = stem_material
	visual.add_child(stem)
	var bloom := MeshInstance3D.new()
	var bloom_mesh := SphereMesh.new()
	bloom_mesh.radius = height * 0.26
	bloom_mesh.height = height * 0.4
	bloom.mesh = bloom_mesh
	bloom.position.y = height * 0.68
	var bloom_material := StandardMaterial3D.new()
	bloom_material.albedo_color = colour
	bloom_material.emission_enabled = true
	bloom_material.emission = colour.darkened(0.45)
	bloom_material.emission_energy_multiplier = 0.7
	bloom.material_override = bloom_material
	visual.add_child(bloom)
	glow = bloom
	# Slow bob so nodes read as interactive on a small phone screen.
	var tween := create_tween()
	tween.set_loops()
	tween.tween_property(bloom, "position:y", height * 0.74, 1.1).set_trans(Tween.TRANS_SINE)
	tween.tween_property(bloom, "position:y", height * 0.62, 1.1).set_trans(Tween.TRANS_SINE)
