extends Node3D
## Lightweight, pooled combat VFX: slash arcs, spell bolts, impact bursts and
## floating damage numbers.  Everything is primitive-mesh based so it survives
## the GL Compatibility renderer used on low-end Android devices.

const Math3D = preload("res://scripts/planet/sphere_math.gd")

const MAX_POOL := 24

var _pool: Array[MeshInstance3D] = []
var _labels_pool: Array[Label3D] = []
var _active_effects: Array[Dictionary] = []


func _ready() -> void:
	for i in range(MAX_POOL):
		var node := MeshInstance3D.new()
		node.visible = false
		var mesh := SphereMesh.new()
		mesh.radius = 0.5
		mesh.height = 1.0
		node.mesh = mesh
		add_child(node)
		_pool.append(node)
	for i in range(12):
		var label := Label3D.new()
		label.visible = false
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.font_size = 42
		label.outline_size = 12
		label.outline_modulate = Color(0, 0, 0, 0.85)
		label.pixel_size = 0.0042
		add_child(label)
		_labels_pool.append(label)


func _take_mesh(colour: Color, scale_value: float, unshaded: bool = true) -> MeshInstance3D:
	for node in _pool:
		if not node.visible:
			node.visible = true
			node.scale = Vector3.ONE * scale_value
			var material := StandardMaterial3D.new()
			material.albedo_color = colour
			material.emission_enabled = true
			material.emission = colour
			material.emission_energy_multiplier = 2.2
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			if unshaded:
				material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			node.material_override = material
			return node
	return null


func _release(node: MeshInstance3D) -> void:
	if node != null:
		node.visible = false


## A short arc swiped in front of the attacker.
func slash(origin: Vector3, forward: Vector3, up: Vector3, colour: Color = Color("ffe9b0")) -> void:
	var node := _take_mesh(colour, 1.0)
	if node == null:
		return
	node.position = origin + forward * 1.1
	node.look_at(node.position + forward, up)
	var tween := create_tween()
	tween.tween_property(node, "scale", Vector3(2.6, 0.16, 1.1), 0.12)
	tween.parallel().tween_property(node, "material_override:albedo_color:a", 0.0, 0.16)
	tween.tween_callback(_release.bind(node))


## Projectile-like bolt travelling from `from` to `to`.
func bolt(from: Vector3, to: Vector3, colour: Color) -> void:
	var node := _take_mesh(colour, 0.55)
	if node == null:
		return
	node.position = from
	var tween := create_tween()
	tween.tween_property(node, "position", to, 0.18)
	tween.parallel().tween_property(node, "scale", Vector3.ONE * 0.9, 0.18)
	tween.tween_callback(_release.bind(node))
	impact(to, colour, 1.4)


## Radial burst at an impact point.
func impact(at: Vector3, colour: Color, size: float = 1.0) -> void:
	var node := _take_mesh(colour, size * 0.4)
	if node == null:
		return
	node.position = at
	var tween := create_tween()
	tween.tween_property(node, "scale", Vector3.ONE * size * 1.9, 0.22)
	tween.parallel().tween_property(node, "material_override:albedo_color:a", 0.0, 0.24)
	tween.tween_callback(_release.bind(node))


func heal_burst(at: Vector3) -> void:
	impact(at, Color("a6ffbe"), 1.6)


## Floating combat text.
func damage_number(at: Vector3, amount: float, is_crit: bool, is_player: bool) -> void:
	for label in _labels_pool:
		if label.visible:
			continue
		label.visible = true
		label.text = ("%d!" % roundi(amount)) if is_crit else str(roundi(amount))
		label.modulate = Color("ff6b6b") if is_player else (Color("ffd166") if is_crit else Color("ffffff"))
		label.font_size = 52 if is_crit else 38
		label.global_position = at
		var tween := create_tween()
		tween.tween_property(label, "global_position", at + (at.normalized() * 1.4) if at.length() > 1.0 else at + Vector3.UP, 0.75)
		tween.parallel().tween_property(label, "modulate:a", 0.0, 0.75)
		tween.tween_callback(func() -> void: label.visible = false)
		return


## Boss phase telegraph (expanding ring).
func boss_phase_burst(at: Vector3, colour: Color = Color("ff5c2b")) -> void:
	var node := _take_mesh(colour, 1.0)
	if node == null:
		return
	node.position = at
	var tween := create_tween()
	tween.tween_property(node, "scale", Vector3(9.0, 0.25, 9.0), 0.7)
	tween.parallel().tween_property(node, "material_override:albedo_color:a", 0.0, 0.75)
	tween.tween_callback(_release.bind(node))
