extends Node
## Drives a KayKit character model from gameplay states.
##
## The KayKit packs ship ~76-95 clips per character.  Instead of hard-coding one
## name, the animator resolves a *list* of candidates (see AssetCatalog.ANIM) so
## skeleton and adventurer packs share the same state machine.
##
## Signals:
##   action_finished(action) - emitted when a one-shot clip (attack/death/...) ends

signal action_finished(action: String)

const AssetCatalog = preload("res://scripts/core/asset_catalog.gd")

## One-shot states that lock movement until the clip finishes.
const ONESHOT := ["attack_light", "attack_heavy", "spell", "dodge", "hit", "death", "interact", "spawn"]

var model: Node3D
var player: AnimationPlayer
var library: AnimationLibrary
var state := "idle"
var speed := 0.0
var alive := true
var time_scale := 1.0

var _resolved := {}
var _oneshot_active := ""
var _oneshot_timer := 0.0
var _rng := RandomNumberGenerator.new()


## Wire a model instance.  Returns false when the model has no AnimationPlayer,
## which lets the caller fall back to a primitive placeholder mesh.
func setup(instance: Node3D) -> bool:
	model = instance
	player = _find_animation_player(instance)
	if player == null:
		return false
	library = _collect_library(player)
	if library == null:
		return false
	for key in AssetCatalog.ANIM.keys():
		_resolved[key] = AssetCatalog.pick_clip(library, AssetCatalog.ANIM[key])
	player.animation_finished.connect(_on_animation_finished)
	if _resolved.get("idle", "") != "":
		_play_loop("idle")
	return true


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null


## glTF imports put clips either in the AnimationPlayer's own library or in an
## "animations" library; merge both into one lookup-friendly instance.
func _collect_library(animation_player: AnimationPlayer) -> AnimationLibrary:
	var merged := AnimationLibrary.new()
	var found_any := false
	var names := animation_player.get_animation_library_list()
	if names.is_empty():
		var own := animation_player.get_animation_list()
		if own.is_empty():
			return null
		for name in own:
			merged.add_animation(name, animation_player.get_animation(name))
		return merged
	for name in names:
		var source := animation_player.get_animation_library(name)
		for clip in source.get_animation_list():
			if merged.has_animation(clip):
				continue
			merged.add_animation(clip, source.get_animation(clip))
			found_any = true
	return merged if found_any else null


func has_clip(action: String) -> bool:
	return _resolved.get(action, "") != ""


func set_locomotion(input_strength: float, running: bool) -> void:
	speed = input_strength
	if not alive or _oneshot_active != "":
		return
	if input_strength < 0.05:
		_play_loop("idle")
	else:
		_play_loop("run" if running else "walk")


func play(action: String, blend: float = 0.12, randomise: bool = false) -> void:
	if not alive and action != "death":
		return
	var clip := _pick_resolved(action, randomise)
	if clip == "":
		return
	if not player.has_animation(clip):
		return
	var animation := player.get_animation(clip)
	animation.loop_mode = Animation.LOOP_NONE
	player.play(clip, blend, time_scale)
	if action in ONESHOT:
		_oneshot_active = action
		_oneshot_timer = 0.0


func _pick_resolved(action: String, randomise: bool) -> String:
	var candidates: Array = AssetCatalog.ANIM.get(action, [])
	var available: Array[String] = []
	for candidate in candidates:
		if player.has_animation(candidate):
			available.append(candidate)
	if available.is_empty():
		return ""
	if randomise and available.size() > 1:
		return available[_rng.randi_range(0, available.size() - 1)]
	return available[0]


func _play_loop(action: String) -> void:
	if state == action and player.is_playing():
		return
	var clip := _pick_resolved(action, false)
	if clip == "":
		return
	var animation := player.get_animation(clip)
	animation.loop_mode = Animation.LOOP_LINEAR
	player.play(clip, 0.18, time_scale)
	state = action


func _on_animation_finished(clip: String) -> void:
	if _oneshot_active == "":
		return
	var finished_action := _oneshot_active
	_oneshot_active = ""
	if finished_action == "death":
		return
	# Locomotion resumes on the next frame from the controller.
	state = ""
	emit_signal("action_finished", finished_action)
	if alive:
		_play_loop("idle")


func is_busy() -> bool:
	return _oneshot_active != ""


func die() -> void:
	alive = false
	play("death", 0.1)


func reset() -> void:
	alive = true
	_oneshot_active = ""
	state = ""
	_play_loop("idle")


## Attach a weapon/prop to a hand bone.  Returns the parented node (or null).
##
## Imported glTF characters keep their bones *inside* a Skeleton3D, so a bone is
## not a scene node that can be parented to.  We therefore attach through a
## BoneAttachment3D, which follows the bone's global transform every frame.
## A plain node search is kept as a fallback for non-skinned props.
func attach_to_hand(prop: Node3D, hand := "hand.r", offset := Vector3(0, 0, 0), rotation := Vector3.ZERO, scale_value := 1.0) -> Node3D:
	var skeleton := find_skeleton(model)
	if skeleton != null and skeleton.find_bone(hand) >= 0:
		var attachment := BoneAttachment3D.new()
		attachment.name = "WeaponSocket"
		skeleton.add_child(attachment)
		attachment.bone_name = hand
		attachment.position = offset
		attachment.rotation = rotation
		attachment.scale = Vector3.ONE * scale_value
		attachment.add_child(prop)
		return attachment
	var bone := find_bone_node(hand)
	if bone == null:
		return null
	var holder := Node3D.new()
	holder.name = "WeaponSocket"
	holder.position = offset
	holder.rotation = rotation
	holder.scale = Vector3.ONE * scale_value
	bone.add_child(holder)
	holder.add_child(prop)
	return holder


func find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	if node == null:
		return null
	for child in node.get_children():
		var found := find_skeleton(child)
		if found != null:
			return found
	return null


func find_bone_node(bone_name: String) -> Node3D:
	return _find_bone(model, bone_name)


func _find_bone(node: Node, bone_name: String) -> Node3D:
	if node is Node3D and node.name == bone_name:
		return node
	for child in node.get_children():
		var found := _find_bone(child, bone_name)
		if found != null:
			return found
	return null


## Approximate model height in metres, used to scale placeholders / UI markers.
func model_height() -> float:
	if model == null:
		return 1.8
	var aabb := AABB()
	var first := true
	for child in model.get_children():
		if child is MeshInstance3D:
			var box: AABB = (child as MeshInstance3D).get_aabb()
			if first:
				aabb = box
				first = false
			else:
				aabb = aabb.merge(box)
	return maxf(aabb.size.y, 0.5)
