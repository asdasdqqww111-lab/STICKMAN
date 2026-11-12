extends Node
## Resolves player attacks and enemy attacks against real hit detection.
##
## The player's light/heavy attack sweeps a cone in front of the character;
## spells use the spell's shape.  Damage numbers, hit flashes and audio are
## emitted from here so effects and rules never drift apart.

signal damage_number(world_position: Vector3, amount: float, is_crit: bool, is_player: bool)
signal hit_flash(enemy: Node3D)
signal player_hit

const Math3D = preload("res://scripts/planet/sphere_math.gd")
const SpellDB = preload("res://scripts/data/spell_database.gd")
const SpellData = preload("res://scripts/data/spell_data.gd")

const CRIT_CHANCE := 0.12
const CRIT_MULTIPLIER := 1.8
const HEAVY_MULTIPLIER := 1.75
const LIGHT_RANGE := 3.0
const HEAVY_RANGE := 3.6
const ARC_DOT := 0.10        # ~84 degree cone
const SPELL_ARC_DOT := -0.15

var player: Node3D
var player_state: RefCounted
var enemies: Array = []
var audio: Node
var _rng := RandomNumberGenerator.new()
var _last_hit_time := 0.0


func _init() -> void:
	_rng.randomize()


func bind(player_node: Node3D, state: RefCounted) -> void:
	player = player_node
	player_state = state


func register_enemy(enemy: Node) -> void:
	if enemy not in enemies:
		enemies.append(enemy)


func unregister_enemy(enemy: Node) -> void:
	enemies.erase(enemy)


func living_enemies() -> Array:
	var result := []
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.alive:
			result.append(enemy)
	return result


func nearest_enemy(max_distance: float) -> Node:
	if player == null:
		return null
	var best: Node = null
	var best_distance := max_distance
	for enemy in living_enemies():
		var distance: float = Math3D.arc_distance(player.current_direction, enemy.current_direction)
		if distance < best_distance:
			best = enemy
			best_distance = distance
	return best


## Light/heavy melee sweep.  Returns the number of enemies hit.
func resolve_melee(heavy: bool) -> int:
	if player == null or player_state == null:
		return 0
	var reach := HEAVY_RANGE if heavy else LIGHT_RANGE
	var forward: Vector3 = player.forward_tangent()
	var hits := 0
	for enemy in living_enemies():
		var distance: float = Math3D.arc_distance(player.current_direction, enemy.current_direction)
		if distance > reach + 0.6:
			continue
		var to_enemy: Vector3 = (enemy.global_position - player.global_position).normalized()
		if to_enemy.dot(forward) < ARC_DOT:
			continue
		var damage: float = player_state.attack_power() * (HEAVY_MULTIPLIER if heavy else 1.0)
		var crit := _rng.randf() < CRIT_CHANCE
		if crit:
			damage *= CRIT_MULTIPLIER
		var applied: float = enemy.take_damage(damage, "physical")
		player_state.register_damage(applied)
		emit_signal("damage_number", enemy.global_position + player.current_direction * 1.6, applied, crit, false)
		emit_signal("hit_flash", enemy)
		hits += 1
	if hits > 0:
		_last_hit_time = Time.get_ticks_msec() / 1000.0
		if audio != null:
			audio.play_attack()
	return hits


## Cast a spell.  Returns a result dictionary for the HUD.
func cast_spell(spell_id: String, now: float) -> Dictionary:
	if player == null or player_state == null:
		return {"ok": false, "message": "No caster."}
	if not player_state.knows_spell(spell_id):
		return {"ok": false, "message": "Spell not learned."}
	var spell: Resource = SpellDB.create(spell_id)
	if spell == null:
		return {"ok": false, "message": "Unknown spell."}
	if not player_state.spell_ready(spell_id, now):
		return {"ok": false, "message": "%s recharging." % spell.display_name}
	if not player_state.spend_mana(spell.mana_cost):
		return {"ok": false, "message": "Not enough mana."}
	player_state.start_spell_cooldown(spell_id, now)
	var hits := 0
	match spell.shape:
		SpellData.Shape.HEAL:
			var healed: float = player_state.heal(spell.heal_amount * player_state.spell_power())
			player.play_spell_animation()
			return {"ok": true, "message": "Mending Light: +%d HP" % int(healed), "hits": 0}
		SpellData.Shape.AURA:
			var forward_aura: Vector3 = player.forward_tangent()
			for enemy in living_enemies():
				var distance: float = Math3D.arc_distance(player.current_direction, enemy.current_direction)
				if distance <= spell.radius:
					hits += _apply_spell_damage(enemy, spell)
			player.play_spell_animation()
		SpellData.Shape.MELEE_ARC:
			var forward_arc: Vector3 = player.forward_tangent()
			for enemy in living_enemies():
				var distance: float = Math3D.arc_distance(player.current_direction, enemy.current_direction)
				if distance > spell.range_metres:
					continue
				var to_enemy: Vector3 = (enemy.global_position - player.global_position).normalized()
				if to_enemy.dot(forward_arc) < SPELL_ARC_DOT:
					continue
				hits += _apply_spell_damage(enemy, spell)
			player.play_spell_animation()
		_:
			var target := nearest_enemy(spell.range_metres)
			if target == null:
				return {"ok": false, "message": "No target in range.", "hits": 0}
			hits += _apply_spell_damage(target, spell)
			player.play_spell_animation()
	return {"ok": true, "message": "%s cast (%d hit%s)" % [spell.display_name, hits, "" if hits == 1 else "s"], "hits": hits}


func _apply_spell_damage(enemy: Node, spell: Resource) -> int:
	var element_name := "physical"
	match spell.element:
		SpellData.Element.FIRE: element_name = "fire"
		SpellData.Element.ICE: element_name = "ice"
		SpellData.Element.ARCANE: element_name = "arcane"
	var damage: float = spell.damage * player_state.spell_power()
	var applied: float = enemy.take_damage(damage, element_name)
	player_state.register_damage(applied)
	if spell.element == SpellData.Element.ICE:
		enemy.apply_slow(2.5)
	emit_signal("damage_number", enemy.global_position + player.current_direction * 1.6, applied, false, false)
	emit_signal("hit_flash", enemy)
	return 1


## Enemy -> player damage.
func receive_attack(enemy: Node, raw_amount: float) -> void:
	if player == null or player_state == null:
		return
	if player.invulnerable > 0.0:
		return
	if Math3D.arc_distance(player.current_direction, enemy.current_direction) > float(enemy.data.attack_range) + 1.2:
		return
	var applied: float = player_state.take_damage(raw_amount)
	player.on_hit()
	emit_signal("player_hit")
	emit_signal("damage_number", player.global_position + player.current_direction * 2.0, applied, false, true)
	if audio != null:
		audio.play_hit()


func in_combat() -> bool:
	if player == null:
		return false
	for enemy in living_enemies():
		if Math3D.arc_distance(player.current_direction, enemy.current_direction) < 16.0:
			return true
	return false
