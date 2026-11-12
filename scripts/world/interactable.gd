extends Node3D
## Anything the player can target with the Interact button: shrines, chests,
## the guild registrar, the forge, the shop, the dungeon entrance.

signal activated(interactable: Node3D)

enum Kind { SHRINE, CHEST, NPC, FORGE, SHOP, DUNGEON, PROPERTY, QUEST_BOARD }

var kind: int = Kind.SHRINE
var id := ""
var label := "Interact"
var prompt := "Interact"
var used := false
var radius := 3.4

## Gameplay payload filled by the world builder.
var payload: Dictionary = {}

var marker: Node3D
var _bob_tween: Tween


func configure(node_kind: int, node_id: String, world_position: Vector3, node_basis: Basis, display: String) -> void:
	kind = node_kind
	id = node_id
	label = display
	position = world_position
	basis = node_basis
	name = "Interact_%s" % node_id


func build_marker(colour: Color, height: float = 2.2) -> void:
	if marker != null:
		return
	marker = Node3D.new()
	add_child(marker)
	var beam := MeshInstance3D.new()
	var beam_mesh := CylinderMesh.new()
	beam_mesh.top_radius = 0.06
	beam_mesh.bottom_radius = 0.26
	beam_mesh.height = height
	beam.mesh = beam_mesh
	beam.position.y = height * 0.5
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.emission_enabled = true
	material.emission = colour
	material.emission_energy_multiplier = 1.6
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color.a = 0.85
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam.material_override = material
	marker.add_child(beam)
	var halo := MeshInstance3D.new()
	var halo_mesh := TorusMesh.new()
	halo_mesh.inner_radius = 0.34
	halo_mesh.outer_radius = 0.46
	halo.mesh = halo_mesh
	halo.position.y = 0.12
	var halo_material := StandardMaterial3D.new()
	halo_material.albedo_color = colour
	halo_material.emission_enabled = true
	halo_material.emission = colour
	halo_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	halo.material_override = halo_material
	marker.add_child(halo)
	_bob_tween = create_tween()
	_bob_tween.set_loops()
	_bob_tween.tween_property(halo, "rotation:y", TAU, 3.0).from(0.0)
	_bob_tween.parallel().tween_property(marker, "position:y", 0.12, 1.4).set_trans(Tween.TRANS_SINE)
	_bob_tween.tween_property(marker, "position:y", 0.0, 1.4).set_trans(Tween.TRANS_SINE)


func set_used(value: bool) -> void:
	used = value
	if marker != null:
		marker.visible = not value


func distance_to_point(point: Vector3) -> float:
	return global_position.distance_to(point)


func activate() -> void:
	emit_signal("activated", self)
