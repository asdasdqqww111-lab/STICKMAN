extends Node3D
## Third-person player character on a spherical planet.
##
## Movement is analytic (no character body / navmesh): the character is always
## snapped to the terrain height along its direction vector, which keeps the
## planet collision exact at any scale and is cheap on mobile.

signal attacked(heavy: bool)
signal dodged
signal interacted
signal died

const Math3D = preload("res://scripts/planet/sphere_math.gd")
const Terrain = preload("res://scripts/planet/terrain.gd")
const CharacterAnimator = preload("res://scripts/core/character_animator.gd")
const AssetCatalog = preload("res://scripts/core/asset_catalog.gd")
const ItemDB = preload("res://scripts/data/item_database.gd")

const WALK_SPEED := 4.6
const RUN_SPEED := 8.2
const SPRINT_STAMINA_PER_SECOND := 18.0
const DODGE_DISTANCE := 4.5
const DODGE_STAMINA := 22.0
const JUMP_HEIGHT := 3.4
const GRAVITY := 18.0
const ATTACK_STAMINA := 12.0

var state: RefCounted
var animator: Node
var model_root: Node3D
var camera_rig: Node3D

## Movement input in the camera's tangent plane: x = strafe, y = forward.
var move_input := Vector2.ZERO
var look_input := Vector2.ZERO
var running := false

var velocity_height := 0.0
var airborne := false
var attack_cooldown := 0.0
var dodge_cooldown := 0.0
var invulnerable := 0.0
var facing := 0.0               # yaw around planet-up, radians
var current_direction := Vector3(0, 0, 1)
var heading_direction := Vector3(0, 0, 1)
var height_offset := 0.0
var footstep_timer := 0.0
var _weapon_node: Node3D
var _offhand_node: Node3D
var _model_scale := 1.0


func setup(player_state: RefCounted, body_path: String = AssetCatalog.PLAYER_BODY) -> void:
	state = player_state
	model_root = Node3D.new()
	model_root.name = "ModelRoot"
	add_child(model_root)
	var scene: PackedScene = load(body_path) if ResourceLoader.exists(body_path) else null
	if scene != null:
		var instance: Node3D = scene.instantiate()
		instance.rotation.y = PI
		model_root.add_child(instance)
		animator = (load("res://scripts/core/character_animator.gd") as GDScript).new()
		add_child(animator)
		if not animator.setup(instance):
			animator = null
	else:
		_build_placeholder()
	current_direction = state.direction.normalized()
	heading_direction = current_direction
	_snap_to_ground()
	refresh_equipment()


func _build_placeholder() -> void:
	# Only used when the vendor assets are missing (never in a shipped build).
	var body := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.34
	mesh.height = 1.5
	body.mesh = mesh
	body.position.y = 0.85
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("d9c08a")
	body.material_override = material
	model_root.add_child(body)


## Re-attach equipment visuals after changing weapons/armour.
func refresh_equipment() -> void:
	for node in [_weapon_node, _offhand_node]:
		if is_instance_valid(node):
			node.queue_free()
	_weapon_node = null
	_offhand_node = null
	if animator == null:
		return
	var weapon: Resource = state.weapon_item()
	if weapon != null and weapon.model_path != "":
		var scene: PackedScene = load(weapon.model_path) if ResourceLoader.exists(weapon.model_path) else null
		if scene != null:
			var instance: Node3D = scene.instantiate()
			_weapon_node = animator.attach_to_hand(instance, "hand.r", Vector3(0.0, 0.0, 0.0), Vector3(0.0, 0.0, 0.0), 1.0)
	var offhand: Resource = state.offhand_item()
	if offhand != null and offhand.model_path != "":
		var scene: PackedScene = load(offhand.model_path) if ResourceLoader.exists(offhand.model_path) else null
		if scene != null:
			var instance: Node3D = scene.instantiate()
			_offhand_node = animator.attach_to_hand(instance, "hand.l", Vector3(0.0, 0.0, 0.0), Vector3(0.0, 0.0, 0.0), 1.0)


func set_look_input(value: Vector2) -> void:
	look_input = value


func apply_look(delta: float) -> void:
	if look_input.length_squared() < 0.0001:
		return
	facing = wrapf(facing - look_input.x * delta * 3.0, -PI, PI)
	if camera_rig != null and camera_rig.has_method("orbit"):
		camera_rig.orbit(look_input.y * delta * 1.6)


func _process(delta: float) -> void:
	if state == null:
		return
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	dodge_cooldown = maxf(0.0, dodge_cooldown - delta)
	invulnerable = maxf(0.0, invulnerable - delta)
	apply_look(delta)
	if not state.is_alive():
		return
	if not airborne and not is_busy():
		_move(delta)
	_simulate_gravity(delta)
	_update_transform()
	_audio_steps(delta)
	if animator != null and not is_busy():
		var speed := move_input.length()
		animator.set_locomotion(speed, running)


func _move(delta: float) -> void:
	if move_input.length_squared() < 0.0001:
		running = false
		return
	var wants_run := running or move_input.length() > 0.95
	var speed := RUN_SPEED if wants_run else WALK_SPEED
	if wants_run:
		if not state.spend_stamina(SPRINT_STAMINA_PER_SECOND * delta):
			speed = WALK_SPEED
			running = false
	# Input is camera-relative: forward means "away from camera", i.e. along the
	# camera rig's projected forward tangent.
	var forward := Math3D.north(current_direction)
	var right := Math3D.east(current_direction)
	if camera_rig != null and camera_rig.has_method("tangent_forward"):
		forward = camera_rig.tangent_forward(current_direction)
		right = forward.cross(current_direction).normalized()
	var tangent := (forward * move_input.y + right * move_input.x)
	if tangent.length_squared() < 0.0001:
		return
	tangent = tangent.normalized()
	var metres := speed * delta
	var angle := metres / Math3D.RADIUS
	current_direction = (current_direction * cos(angle) + tangent * sin(angle)).normalized()
	heading_direction = current_direction
	# Face the movement direction (smoothly).
	var desired_yaw := _yaw_from_tangent(tangent, current_direction)
	facing = lerp_angle(facing, desired_yaw, clampf(delta * 10.0, 0.0, 1.0))
	_snap_to_ground()


## Yaw (in the local frame) for a tangent direction.
func _yaw_from_tangent(tangent: Vector3, up: Vector3) -> float:
	var north := Math3D.north(up)
	var east := Math3D.east(up)
	return atan2(tangent.dot(east), tangent.dot(north))


func _simulate_gravity(delta: float) -> void:
	var ground_height := Terrain.elevation(current_direction)
	if airborne:
		velocity_height -= GRAVITY * delta
		height_offset += velocity_height * delta
		if height_offset <= ground_height:
			height_offset = ground_height
			airborne = false
			velocity_height = 0.0
			if animator != null:
				animator.play("land")
	else:
		height_offset = ground_height


func _snap_to_ground() -> void:
	if not airborne:
		height_offset = Terrain.elevation(current_direction)


func _update_transform() -> void:
	var up := current_direction
	global_position = up * (Math3D.RADIUS + height_offset)
	var frame := Math3D.frame_at(up)
	global_transform.basis = frame.rotated(up, facing)
	state.direction = up
	state.yaw = facing


func _audio_steps(delta: float) -> void:
	if move_input.length_squared() < 0.01 or airborne:
		return
	footstep_timer -= delta
	if footstep_timer <= 0.0:
		footstep_timer = 0.32 if not running else 0.24
		var audio := get_tree().get_first_node_in_group("audio")
		if audio != null:
			audio.play_footstep()


func jump() -> bool:
	if airborne or is_busy():
		return false
	if not state.spend_stamina(10.0):
		return false
	airborne = true
	velocity_height = sqrt(2.0 * GRAVITY * JUMP_HEIGHT)
	if animator != null:
		animator.play("jump")
	return true


func dodge(direction: Vector2) -> bool:
	if dodge_cooldown > 0.0 or airborne or is_busy():
		return false
	if not state.spend_stamina(DODGE_STAMINA):
		return false
	dodge_cooldown = 0.65
	invulnerable = 0.35
	var tangent := Math3D.north(current_direction) * (direction.y if direction.length_squared() > 0.01 else 1.0)
	if direction.length_squared() > 0.01:
		tangent = (Math3D.east(current_direction) * direction.x + Math3D.north(current_direction) * direction.y).normalized()
	var angle := DODGE_DISTANCE / Math3D.RADIUS
	current_direction = (current_direction * cos(angle) + tangent.normalized() * sin(angle)).normalized()
	_snap_to_ground()
	if animator != null:
		animator.play("dodge")
	emit_signal("dodged")
	return true


func attack(heavy: bool = false) -> bool:
	if attack_cooldown > 0.0 or airborne or is_busy():
		return false
	var cost := ATTACK_STAMINA * (1.6 if heavy else 1.0)
	if not state.spend_stamina(cost):
		return false
	attack_cooldown = 0.72 if heavy else 0.42
	if animator != null:
		animator.play("attack_heavy" if heavy else "attack_light", 0.08, true)
	emit_signal("attacked", heavy)
	return true


func play_spell_animation() -> void:
	if animator != null and not animator.is_busy():
		animator.play("spell", 0.08, true)


func interact_animation() -> void:
	if animator != null and not animator.is_busy():
		animator.play("interact")


func is_busy() -> bool:
	return animator != null and animator.is_busy()


func on_hit() -> void:
	if animator != null:
		animator.play("hit", 0.05, true)


func on_death() -> void:
	if animator != null:
		animator.die()
	emit_signal("died")


func respawn(direction: Vector3) -> void:
	current_direction = direction.normalized()
	height_offset = Terrain.elevation(current_direction)
	airborne = false
	velocity_height = 0.0
	facing = 0.0
	if animator != null:
		animator.reset()
	_update_transform()


## World-space point at chest height, used as an attack origin.
func chest_point() -> Vector3:
	return global_position + current_direction * 1.05


## Forward tangent of the character (used for attack arcs and spell aiming).
func forward_tangent() -> Vector3:
	return (-global_transform.basis.z).normalized()


func hit_capsule_centres() -> Array[Vector3]:
	return [global_position + current_direction * 0.5, global_position + current_direction * 1.4]
