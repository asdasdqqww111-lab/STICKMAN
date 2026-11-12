extends Node3D
## Monster with a real state machine: idle -> patrol -> chase -> attack -> return,
## plus hit reaction, death animation, leash and simulation LOD.

signal defeated(enemy: Node3D, archetype: String)
signal damaged(enemy: Node3D, amount: float)
signal attacked_player(enemy: Node3D, amount: float)
signal phase_changed(enemy: Node3D, phase: int)

const Math3D = preload("res://scripts/planet/sphere_math.gd")
const Terrain = preload("res://scripts/planet/terrain.gd")
const CharacterAnimator = preload("res://scripts/core/character_animator.gd")
const EnemyData = preload("res://scripts/data/enemy_data.gd")
const AssetCatalog = preload("res://scripts/core/asset_catalog.gd")

enum State { IDLE, PATROL, CHASE, ATTACK, RETURN, DEAD }

## Beyond this distance the AI updates at a fraction of the frame rate.
const LOD_FAR_DISTANCE := 45.0
const LOD_FREQUENCY := 0.2

var data: Resource
var instance_id := ""
var home_direction := Vector3(0, 0, 1)
var current_direction := Vector3(0, 0, 1)
var patrol_direction := Vector3(0, 0, 1)
var health := 40.0
var state: int = State.IDLE
var animator: Node
var model_root: Node3D
var player: Node3D
var player_state: RefCounted

var attack_timer := 0.0
var reaction_timer := 0.0
var lod_timer := 0.0
var slow_timer := 0.0
var facing := 0.0
var alive := true
var boss_phase := 0
var _rng := RandomNumberGenerator.new()

## Simulation snapshot for off-screen enemies (kept by WorldSimulation).
var simulation_tick := false


func configure(enemy_data: Resource, id: String, direction: Vector3) -> void:
	data = enemy_data
	instance_id = id
	home_direction = direction.normalized()
	current_direction = home_direction
	patrol_direction = home_direction
	health = data.max_health
	_rng.randomize()


func build_visual() -> void:
	model_root = Node3D.new()
	model_root.name = "Model"
	add_child(model_root)
	var path: String = data.model_path
	var scene: PackedScene = load(path) if path != "" and ResourceLoader.exists(path) else null
	if scene != null:
		var instance: Node3D = scene.instantiate()
		instance.rotation.y = PI
		instance.scale = Vector3.ONE * data.model_scale
		model_root.add_child(instance)
		animator = CharacterAnimator.new()
		add_child(animator)
		if not animator.setup(instance):
			animator = null
	else:
		var fallback := MeshInstance3D.new()
		var mesh := CapsuleMesh.new()
		mesh.radius = 0.5 * data.model_scale
		mesh.height = 1.2 * data.model_scale
		fallback.mesh = mesh
		fallback.position.y = 0.6 * data.model_scale
		model_root.add_child(fallback)
	_place()


func _place() -> void:
	global_position = Math3D.surface_point(current_direction, Terrain.elevation(current_direction))
	global_transform.basis = Math3D.frame_at(current_direction).rotated(current_direction, facing)


func bind_player(node: Node3D, state: RefCounted) -> void:
	player = node
	player_state = state


func distance_to_player() -> float:
	if player == null:
		return 1.0e9
	return Math3D.arc_distance(current_direction, player.current_direction)


func _physics_process(delta: float) -> void:
	if not alive or data == null or player == null:
		return
	var distance := distance_to_player()
	# Simulation LOD: far monsters tick less often but still move.
	if distance > LOD_FAR_DISTANCE:
		lod_timer += delta
		if lod_timer < LOD_FREQUENCY:
			return
		delta = lod_timer
		lod_timer = 0.0
	attack_timer = maxf(0.0, attack_timer - delta)
	reaction_timer = maxf(0.0, reaction_timer - delta)
	slow_timer = maxf(0.0, slow_timer - delta)
	if boss_phase == 2 and health > 0.0 and health / data.max_health < 0.35:
		_enter_phase(3)
	match state:
		State.IDLE:
			_tick_idle(delta, distance)
		State.PATROL:
			_tick_patrol(delta, distance)
		State.CHASE:
			_tick_chase(delta, distance)
		State.ATTACK:
			_tick_attack(delta, distance)
		State.RETURN:
			_tick_return(delta)
	_update_animator(delta, distance)


func _tick_idle(delta: float, distance: float) -> void:
	if _should_aggro(distance):
		state = State.CHASE
		return
	if data.ai == EnemyData.AI.PATROL and _rng.randf() < delta * 0.25:
		var tangent := Math3D.east(patrol_direction) * _rng.randf_range(-1, 1) + Math3D.north(patrol_direction) * _rng.randf_range(-1, 1)
		patrol_direction = (patrol_direction + tangent.normalized() * 0.01).normalized()
		state = State.PATROL


func _should_aggro(distance: float) -> bool:
	if data.ai == EnemyData.AI.PASSIVE:
		return false
	if player_state != null and not player_state.is_alive():
		return false
	if data.ai == EnemyData.AI.BOSS:
		return distance < data.aggro_radius
	return distance < data.aggro_radius


func _tick_patrol(delta: float, distance: float) -> void:
	if _should_aggro(distance):
		state = State.CHASE
		return
	var metres := data.move_speed * 0.45 * delta
	var to_target := (patrol_direction - current_direction * current_direction.dot(patrol_direction)).normalized()
	var angle := metres / Math3D.RADIUS
	current_direction = (current_direction * cos(angle) + to_target * sin(angle)).normalized()
	_face(to_target)
	_place()
	if Math3D.arc_distance(current_direction, home_direction) > data.leash_radius * 0.6:
		state = State.RETURN


func _tick_chase(delta: float, distance: float) -> void:
	if player_state != null and not player_state.is_alive():
		state = State.RETURN
		return
	if distance > data.leash_radius:
		state = State.RETURN
		return
	if distance <= data.attack_range:
		state = State.ATTACK
		return
	var speed := data.move_speed * (0.55 if slow_timer > 0.0 else 1.0)
	var metres := speed * delta
	var target_up: Vector3 = player.current_direction
	var to_target := (target_up - current_direction * current_direction.dot(target_up)).normalized()
	var angle := metres / Math3D.RADIUS
	current_direction = (current_direction * cos(angle) + to_target * sin(angle)).normalized()
	_face(to_target)
	_place()


func _tick_attack(delta: float, distance: float) -> void:
	if player_state != null and not player_state.is_alive():
		state = State.RETURN
		return
	var target_up: Vector3 = player.current_direction
	_face((target_up - current_direction * current_direction.dot(target_up)).normalized())
	if distance > data.attack_range * 1.35:
		state = State.CHASE
		return
	if attack_timer <= 0.0:
		attack_timer = data.attack_cooldown
		if animator != null:
			animator.play("attack_heavy" if data.is_boss() else "attack_light", 0.06, true)
		var amount: float = data.damage * _boss_damage_multiplier()
		emit_signal("attacked_player", self, amount)


func _boss_damage_multiplier() -> float:
	if not data.is_boss():
		return 1.0
	return [1.0, 1.15, 1.35, 1.6][clampi(boss_phase, 0, 3)]


func _tick_return(delta: float) -> void:
	var distance_home := Math3D.arc_distance(current_direction, home_direction)
	if distance_home < 0.8:
		state = State.IDLE
		current_direction = home_direction
		_place()
		if health < data.max_health:
			health = data.max_health
		return
	var metres := data.move_speed * 0.8 * delta
	var to_target := (home_direction - current_direction * current_direction.dot(home_direction)).normalized()
	var angle := metres / Math3D.RADIUS
	current_direction = (current_direction * cos(angle) + to_target * sin(angle)).normalized()
	_face(to_target)
	_place()


func _face(tangent: Vector3) -> void:
	if tangent.length_squared() < 0.0001:
		return
	var north := Math3D.north(current_direction)
	var east := Math3D.east(current_direction)
	facing = atan2(tangent.dot(east), tangent.dot(north))
	global_transform.basis = Math3D.frame_at(current_direction).rotated(current_direction, facing)


func _update_animator(_delta: float, distance: float) -> void:
	if animator == null:
		return
	if distance > LOD_FAR_DISTANCE:
		return
	if state == State.CHASE or state == State.PATROL or state == State.RETURN:
		animator.set_locomotion(1.0, state == State.CHASE)
	elif state == State.ATTACK:
		animator.set_locomotion(0.0, false)


func take_damage(amount: float, source: String = "melee") -> float:
	if not alive or amount <= 0.0:
		return 0.0
	var mitigated := maxf(1.0, amount - data.defence * 0.5)
	if source == "fire":
		mitigated *= 1.0 - data.resist_fire
	elif source == "ice":
		mitigated *= 1.0 - data.resist_ice
	elif source == "arcane":
		mitigated *= 1.0 - data.resist_arcane
	health -= mitigated
	emit_signal("damaged", self, mitigated)
	if health <= 0.0:
		_die()
		return mitigated
	reaction_timer = 0.35
	if animator != null:
		animator.play("hit", 0.04, true)
	if state == State.IDLE:
		state = State.CHASE
	if data.is_boss():
		_update_boss_phase()
	return mitigated


func apply_slow(seconds: float) -> void:
	slow_timer = maxf(slow_timer, seconds)


func _update_boss_phase() -> void:
	var ratio := health / data.max_health
	if boss_phase <= 1 and ratio < 0.7:
		_enter_phase(2)
	elif boss_phase <= 2 and ratio < 0.35:
		_enter_phase(3)


func _enter_phase(phase: int) -> void:
	if boss_phase == phase:
		return
	boss_phase = phase
	emit_signal("phase_changed", self, phase)
	if animator != null:
		animator.play("spell" if phase == 2 else "cheer", 0.1)


func _die() -> void:
	alive = false
	state = State.DEAD
	if animator != null:
		animator.die()
	emit_signal("defeated", self, data.id)
	var tween := create_tween()
	tween.tween_interval(1.6)
	tween.tween_callback(queue_free)


func health_ratio() -> float:
	if data == null:
		return 0.0
	return clampf(health / maxf(1.0, data.max_health), 0.0, 1.0)


func display_name() -> String:
	return data.display_name if data != null else "Monster"


## Melee hit test: is the player inside the enemy's attack cone?
func player_in_range(range_metres: float) -> bool:
	if player == null:
		return false
	if distance_to_player() > range_metres:
		return false
	var to_player: Vector3 = player.global_position - global_position
	return to_player.normalized().dot(forward_tangent()) > -0.25


func forward_tangent() -> Vector3:
	return (-global_transform.basis.z).normalized()
