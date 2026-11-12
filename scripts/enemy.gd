extends Node3D
const Sphere = preload("res://scripts/sphere.gd")
var direction := Vector3.FORWARD
var spawn_direction := Vector3.FORWARD
var enemy_id := ""
var health := 30.0
var attack_timer := 0.0
var state := "idle"
var game: Node3D
var visual: MeshInstance3D

func initialize(id: String, dir: Vector3, owner_game: Node3D) -> void:
	enemy_id = id; direction = dir; spawn_direction = dir; game = owner_game

func _ready() -> void:
	visual = MeshInstance3D.new()
	var mesh := SphereMesh.new(); mesh.radius = 0.55; mesh.height = 0.75
	visual.mesh = mesh
	var mat := StandardMaterial3D.new(); mat.albedo_color = Color("75d5b0"); mat.roughness = 0.45
	visual.material_override = mat
	add_child(visual)
	_update_position()

func _physics_process(delta: float) -> void:
	if not is_instance_valid(game): return
	attack_timer = maxf(0.0, attack_timer - delta)
	var player_dir: Vector3 = game.state.direction
	var distance := direction.distance_to(player_dir) * Sphere.RADIUS
	var home_distance := direction.distance_to(spawn_direction) * Sphere.RADIUS
	if distance < 8.0 and home_distance < 20.0:
		state = "chase"
		if distance > 1.4:
			var tangent := (player_dir - direction * player_dir.dot(direction)).normalized()
			direction = (direction + tangent * delta * 1.8 / Sphere.RADIUS).normalized()
		elif attack_timer <= 0.0:
			state = "attack"; attack_timer = 1.4
			game.take_damage(7.0)
	elif home_distance > 0.2:
		state = "return"
		var tangent := (spawn_direction - direction * spawn_direction.dot(direction)).normalized()
		direction = (direction + tangent * delta / Sphere.RADIUS).normalized()
	else: state = "idle"
	_update_position()

func _update_position() -> void:
	position = direction * (Sphere.RADIUS + 0.4)
	var n: Vector3 = Sphere.north(direction)
	basis = Basis(n.cross(direction).normalized(), direction, -n).orthonormalized()

func hit(amount: float) -> void:
	health -= amount
	if health <= 0:
		game.enemy_defeated(self)
		queue_free()
