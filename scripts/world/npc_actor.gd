extends Node3D
## A living villager: walks a daily schedule on the sphere surface, greets the
## player and can hand out information.  Uses the same spherical frame maths as
## the player so villagers never float off the planet.

signal interacted(npc: Node3D)

const Math3D = preload("res://scripts/planet/sphere_math.gd")
const Terrain = preload("res://scripts/planet/terrain.gd")
const CharacterAnimator = preload("res://scripts/core/character_animator.gd")
const AssetCatalog = preload("res://scripts/core/asset_catalog.gd")

var npc_id := ""
var display_name := "Villager"
var role := "farmer"
var model_scale := 0.85
var animator: Node

## Schedule: array of {from: float(hour), to: float(hour), anchor: Vector3, label: String}
var schedule: Array[Dictionary] = []
var home_direction := Vector3.ZERO
var current_direction := Vector3.ZERO
var target_direction := Vector3.ZERO
var walk_speed := 1.35
var moving := false

var _body: Node3D
var _idle_offset := 0.0
var _rng := RandomNumberGenerator.new()


func configure(id: String, name_text: String, role_text: String, home: Vector3, schedule_rows: Array[Dictionary]) -> void:
	npc_id = id
	display_name = name_text
	role = role_text
	home_direction = home.normalized()
	current_direction = home_direction
	target_direction = home_direction
	schedule = schedule_rows
	_idle_offset = _rng.randf() * TAU
	name = "NPC_" + id


func build_visual(model_path: String = "") -> void:
	var path := model_path if model_path != "" else AssetCatalog.NPC_VILLAGER
	_body = Node3D.new()
	add_child(_body)
	var scene: PackedScene = load(path) if ResourceLoader.exists(path) else null
	if scene != null:
		var instance: Node3D = scene.instantiate()
		instance.scale = Vector3.ONE * model_scale
		instance.rotation.y = PI   # KayKit models face -Z; turn them to +Z.
		_body.add_child(instance)
		animator = CharacterAnimator.new()
		add_child(animator)
		if not animator.setup(instance):
			animator = null
	else:
		var fallback := MeshInstance3D.new()
		var mesh := CapsuleMesh.new()
		mesh.radius = 0.3
		mesh.height = 1.5
		fallback.mesh = mesh
		_body.add_child(fallback)
	_place()


func _place() -> void:
	var ground := Terrain.ground_point(current_direction)
	global_position = ground
	var frame := Math3D.frame_at(current_direction)
	global_transform.basis = frame


func _process(delta: float) -> void:
	if schedule.is_empty():
		return
	var clock: Node = get_tree().get_first_node_in_group("world_clock")
	var hour := 8.0
	if clock != null:
		hour = float(clock.time_of_day) * 24.0
	var target := _target_for_hour(hour)
	if target == Vector3.ZERO:
		return
	target_direction = target
	var distance := Math3D.arc_distance(current_direction, target_direction)
	moving = distance > 0.6
	if moving:
		var step := walk_speed * delta
		var to_target := (target_direction - current_direction * current_direction.dot(target_direction)).normalized()
		var angle := step / Math3D.RADIUS
		current_direction = (current_direction * cos(angle) + to_target * sin(angle)).normalized()
		_place()
		var facing := current_direction.cross(to_target).normalized()
		if facing.length_squared() > 0.01:
			look_at(global_position + to_target, current_direction)
	if animator != null:
		animator.set_locomotion(1.0 if moving else 0.0, false)


func _target_for_hour(hour: float) -> Vector3:
	for row in schedule:
		var from_hour: float = row.get("from", 0.0)
		var to_hour: float = row.get("to", 24.0)
		if hour >= from_hour and hour < to_hour:
			var anchor: Vector3 = row.get("anchor", home_direction)
			return anchor.normalized()
	return home_direction


func interact() -> void:
	emit_signal("interacted", self)
	if animator != null:
		animator.play("interact")


func greeting(clock_hour: float) -> String:
	if clock_hour < 6.0:
		return "%s: You're up late, adventurer. Mind the barrow." % display_name
	if clock_hour < 12.0:
		return "%s: Morning! The guild hall is just down the path." % display_name
	if clock_hour < 18.0:
		return "%s: Fine weather for a hunt. Watch the northern ridge." % display_name
	return "%s: Evenin'. Best get indoors before the wolves wake." % display_name
