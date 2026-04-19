class_name BattleResolver

const MAX_ITERATIONS := 10000


static func snapshot(unit: Unit) -> Dictionary:
	var snap := {
		"name": "",
		"display_name": "",
		"description": "",
		"max_hp": 0,
		"current_hp": 0,
		"damage": 0,
		"defense": 0,
		"attack_speed": 1.0,
		"icon": null,
		"color": Color.WHITE,
		"is_player": false,
		"final_hp": 0,
		"inventory": [],
		"abilities": {},
	}
	if unit == null:
		return snap
	snap["name"] = String(unit.name)
	if unit.stats != null:
		snap["max_hp"] = unit.stats.get_final_int(UnitStats.Kind.MAX_HEALTH)
		snap["current_hp"] = unit.stats.current_health
		snap["damage"] = unit.stats.get_final_int(UnitStats.Kind.DAMAGE)
		snap["defense"] = unit.stats.get_final_int(UnitStats.Kind.DEFENSE)
		snap["attack_speed"] = unit.stats.get_final(UnitStats.Kind.ATTACK_SPEED)
		snap["abilities"] = unit.stats.get_abilities_summary()
	var loadout: UnitLoadout = null
	if unit is Player:
		loadout = (unit as Player).loadout
		snap["color"] = (unit as Player).body_color
		snap["is_player"] = true
	elif unit is Enemy:
		loadout = (unit as Enemy).loadout
		snap["color"] = (unit as Enemy).body_color
	if loadout != null:
		snap["icon"] = loadout.battle_icon
		if loadout.display_name != "":
			snap["display_name"] = loadout.display_name
		snap["description"] = loadout.description
	if snap["display_name"] == "":
		snap["display_name"] = snap["name"]
	if unit.inventory != null:
		snap["inventory"] = _serialize_inventory(unit.inventory)
	snap["final_hp"] = snap["current_hp"]
	return snap


static func _serialize_inventory(inv: Inventory) -> Array:
	var out: Array = []
	if inv == null:
		return out
	for slot in inv.get_slots():
		var artifact: Artifact = slot.get("artifact")
		var rarity: int = slot.get("rarity", -1)
		var entry := {
			"tag": slot.get("tag"),
			"display_name": slot.get("display_name", ""),
			"artifact_name": "",
			"icon": null,
		}
		if artifact != null:
			if artifact.display_name != "":
				entry["artifact_name"] = artifact.display_name
			else:
				entry["artifact_name"] = String(artifact.id)
			var variant := artifact.resolve_variant(rarity)
			if variant != null:
				entry["icon"] = variant.icon
		out.append(entry)
	return out


static func resolve(unit_a: Unit, unit_b: Unit, seed_value: int = 0) -> BattleLog:
	var result := BattleLog.new()
	result.seed_value = seed_value
	result.unit_a_snapshot = snapshot(unit_a)
	result.unit_b_snapshot = snapshot(unit_b)

	var max_hp: Array = [
		int(result.unit_a_snapshot.get("max_hp", 0)),
		int(result.unit_b_snapshot.get("max_hp", 0)),
	]
	var hp: Array = [int(result.unit_a_snapshot.get("current_hp", 0)), int(result.unit_b_snapshot.get("current_hp", 0))]
	var dmg: Array = [int(result.unit_a_snapshot.get("damage", 0)), int(result.unit_b_snapshot.get("damage", 0))]
	var defense: Array = [int(result.unit_a_snapshot.get("defense", 0)), int(result.unit_b_snapshot.get("defense", 0))]
	var speeds: Array = [
		maxf(0.0001, float(result.unit_a_snapshot.get("attack_speed", 1.0))),
		maxf(0.0001, float(result.unit_b_snapshot.get("attack_speed", 1.0))),
	]
	var intervals: Array = [1.0 / speeds[0], 1.0 / speeds[1]]
	var next_time: Array = [intervals[0], intervals[1]]

	var abilities_a: Dictionary = result.unit_a_snapshot.get("abilities", {})
	var abilities_b: Dictionary = result.unit_b_snapshot.get("abilities", {})
	var abilities: Array = [abilities_a, abilities_b]

	var first_strike: Array = [
		_ability_value(abilities[0], Ability.Kind.FIRST_STRIKE),
		_ability_value(abilities[1], Ability.Kind.FIRST_STRIKE),
	]
	var lifesteal: Array = [
		_ability_value(abilities[0], Ability.Kind.LIFESTEAL),
		_ability_value(abilities[1], Ability.Kind.LIFESTEAL),
	]
	var thorns: Array = [
		_ability_value(abilities[0], Ability.Kind.THORNS),
		_ability_value(abilities[1], Ability.Kind.THORNS),
	]
	var crit_chance: Array = [
		_ability_value(abilities[0], Ability.Kind.CRIT_CHANCE),
		_ability_value(abilities[1], Ability.Kind.CRIT_CHANCE),
	]
	var regen: Array = [
		_ability_value(abilities[0], Ability.Kind.REGEN),
		_ability_value(abilities[1], Ability.Kind.REGEN),
	]
	var pierce: Array = [
		_ability_value(abilities[0], Ability.Kind.ARMOR_PIERCE),
		_ability_value(abilities[1], Ability.Kind.ARMOR_PIERCE),
	]
	var evasion: Array = [
		_ability_value(abilities[0], Ability.Kind.EVASION),
		_ability_value(abilities[1], Ability.Kind.EVASION),
	]
	var execute: Array = [
		_ability_value(abilities[0], Ability.Kind.EXECUTE),
		_ability_value(abilities[1], Ability.Kind.EXECUTE),
	]
	var berserk: Array = [
		_ability_value(abilities[0], Ability.Kind.BERSERK),
		_ability_value(abilities[1], Ability.Kind.BERSERK),
	]
	var shield_remaining: Array = [
		int(_ability_value(abilities[0], Ability.Kind.SHIELD)),
		int(_ability_value(abilities[1], Ability.Kind.SHIELD)),
	]
	var last_stand_available: Array = [
		_ability_value(abilities[0], Ability.Kind.LAST_STAND) > 0.0,
		_ability_value(abilities[1], Ability.Kind.LAST_STAND) > 0.0,
	]

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value

	var a_can_hurt_b: bool = (maxi(0, dmg[0] - _effective_defense(defense[1], pierce[0])) > 0 or lifesteal[0] > 0.0 or thorns[1] > 0.0) and hp[1] > 0
	var b_can_hurt_a: bool = (maxi(0, dmg[1] - _effective_defense(defense[0], pierce[1])) > 0 or lifesteal[1] > 0.0 or thorns[0] > 0.0) and hp[0] > 0

	if hp[0] <= 0 and hp[1] <= 0:
		_append_end(result, 0, 0.0)
		return result
	if hp[0] <= 0:
		_append_end(result, 1, 0.0)
		return result
	if hp[1] <= 0:
		_append_end(result, 0, 0.0)
		return result

	if not a_can_hurt_b and not b_can_hurt_a:
		var stalemate_winner: int = 0 if hp[0] >= hp[1] else 1
		_append_end(result, stalemate_winner, 0.0)
		return result

	var iterations := 0
	while hp[0] > 0 and hp[1] > 0 and iterations < MAX_ITERATIONS:
		iterations += 1
		var actor: int = 0
		if next_time[1] < next_time[0]:
			actor = 1
		elif next_time[1] == next_time[0]:
			if first_strike[0] > 0.0 and first_strike[1] <= 0.0:
				actor = 0
			elif first_strike[1] > 0.0 and first_strike[0] <= 0.0:
				actor = 1
			elif speeds[1] > speeds[0]:
				actor = 1
			else:
				actor = 0
		var target: int = 1 - actor
		var t: float = next_time[actor]

		var dodged := false
		if evasion[target] > 0.0 and rng.randf() * 100.0 < evasion[target]:
			dodged = true

		var raw: int = dmg[actor]
		var is_crit := false
		var crit_mult: int = 1
		if crit_chance[actor] > 0.0:
			var cc: float = crit_chance[actor]
			var tier: int = int(floor(cc / 100.0))
			var remainder: float = cc - float(tier) * 100.0
			if tier >= 1:
				is_crit = true
				crit_mult = tier + 1
				if remainder > 0.0 and rng.randf() * 100.0 < remainder:
					crit_mult += 1
			else:
				if rng.randf() * 100.0 < remainder:
					is_crit = true
					crit_mult = 2

		var effective_defense: int = _effective_defense(defense[target], pierce[actor])
		var base_damage: int = maxi(0, raw - effective_defense)
		if is_crit:
			base_damage *= crit_mult
		if execute[actor] > 0.0 and hp[target] * 4 < max_hp[target]:
			base_damage = int(floor(float(base_damage) * (1.0 + execute[actor] / 100.0)))
		if berserk[actor] > 0.0 and hp[actor] * 10 < max_hp[actor] * 3:
			base_damage = int(floor(float(base_damage) * (1.0 + berserk[actor] / 100.0)))

		var reduced: int = 0 if dodged else base_damage
		var shield_absorbed := 0
		if reduced > 0 and shield_remaining[target] > 0:
			shield_absorbed = mini(reduced, shield_remaining[target])
			shield_remaining[target] -= shield_absorbed
			reduced -= shield_absorbed

		var lethal_saved := false
		if reduced >= hp[target] and last_stand_available[target]:
			reduced = maxi(0, hp[target] - 1)
			last_stand_available[target] = false
			lethal_saved = true

		hp[target] = maxi(0, hp[target] - reduced)

		var atk := BattleEvent.new(BattleEvent.Kind.ATTACK)
		atk.actor_index = actor
		atk.target_index = target
		atk.raw_damage = raw
		atk.damage_dealt = reduced
		atk.target_hp_after = hp[target]
		atk.time = t
		if is_crit and not dodged:
			atk.crit_multiplier = crit_mult
		result.events.append(atk)

		if dodged:
			var ev_dodge := BattleEvent.new(BattleEvent.Kind.ABILITY)
			ev_dodge.ability_kind = Ability.Kind.EVASION
			ev_dodge.actor_index = target
			ev_dodge.target_index = actor
			ev_dodge.ability_value = evasion[target]
			ev_dodge.time = t
			result.events.append(ev_dodge)

		if is_crit and not dodged:
			var ev_crit := BattleEvent.new(BattleEvent.Kind.ABILITY)
			ev_crit.ability_kind = Ability.Kind.CRIT_CHANCE
			ev_crit.actor_index = actor
			ev_crit.target_index = target
			ev_crit.ability_value = float(base_damage)
			ev_crit.time = t
			result.events.append(ev_crit)

		if shield_absorbed > 0:
			var ev_shield := BattleEvent.new(BattleEvent.Kind.ABILITY)
			ev_shield.ability_kind = Ability.Kind.SHIELD
			ev_shield.actor_index = target
			ev_shield.target_index = actor
			ev_shield.ability_value = float(shield_absorbed)
			ev_shield.time = t
			result.events.append(ev_shield)

		if lethal_saved:
			var ev_last := BattleEvent.new(BattleEvent.Kind.ABILITY)
			ev_last.ability_kind = Ability.Kind.LAST_STAND
			ev_last.actor_index = target
			ev_last.target_index = actor
			ev_last.ability_value = 1.0
			ev_last.time = t
			result.events.append(ev_last)

		if reduced > 0 and lifesteal[actor] > 0.0:
			var heal_lifesteal: int = int(floor(float(reduced) * lifesteal[actor] / 100.0))
			if heal_lifesteal > 0:
				hp[actor] = mini(max_hp[actor], hp[actor] + heal_lifesteal)
				var ev_life := BattleEvent.new(BattleEvent.Kind.ABILITY)
				ev_life.ability_kind = Ability.Kind.LIFESTEAL
				ev_life.actor_index = actor
				ev_life.target_index = target
				ev_life.ability_value = float(heal_lifesteal)
				ev_life.actor_hp_after = hp[actor]
				ev_life.time = t
				result.events.append(ev_life)

		if reduced > 0 and thorns[target] > 0.0:
			var bounce: int = int(floor(float(reduced) * thorns[target] / 100.0))
			if bounce > 0:
				hp[actor] = maxi(0, hp[actor] - bounce)
				var ev_thorns := BattleEvent.new(BattleEvent.Kind.ABILITY)
				ev_thorns.ability_kind = Ability.Kind.THORNS
				ev_thorns.actor_index = target
				ev_thorns.target_index = actor
				ev_thorns.ability_value = float(bounce)
				ev_thorns.actor_hp_after = hp[actor]
				ev_thorns.time = t
				result.events.append(ev_thorns)

		if hp[target] <= 0:
			var death_target := BattleEvent.new(BattleEvent.Kind.DEATH)
			death_target.actor_index = actor
			death_target.target_index = target
			death_target.time = t
			result.events.append(death_target)
			result.winner_index = actor
			break

		if hp[actor] <= 0:
			var death_actor := BattleEvent.new(BattleEvent.Kind.DEATH)
			death_actor.actor_index = target
			death_actor.target_index = actor
			death_actor.time = t
			result.events.append(death_actor)
			result.winner_index = target
			break

		if regen[actor] > 0.0 and hp[actor] < max_hp[actor]:
			var heal_regen: int = int(floor(regen[actor]))
			if heal_regen > 0:
				hp[actor] = mini(max_hp[actor], hp[actor] + heal_regen)
				var ev_regen := BattleEvent.new(BattleEvent.Kind.ABILITY)
				ev_regen.ability_kind = Ability.Kind.REGEN
				ev_regen.actor_index = actor
				ev_regen.target_index = actor
				ev_regen.ability_value = float(heal_regen)
				ev_regen.actor_hp_after = hp[actor]
				ev_regen.time = t
				result.events.append(ev_regen)

		next_time[actor] += intervals[actor]

	if result.winner_index == -1:
		if hp[0] > hp[1]:
			result.winner_index = 0
		elif hp[1] > hp[0]:
			result.winner_index = 1
		else:
			result.winner_index = 0

	result.unit_a_snapshot["final_hp"] = hp[0]
	result.unit_b_snapshot["final_hp"] = hp[1]

	var end_time: float = 0.0
	if not result.events.is_empty():
		end_time = result.events[result.events.size() - 1].time
	_append_end(result, result.winner_index, end_time)
	return result


static func _append_end(result: BattleLog, winner_index: int, time_value: float) -> void:
	var end_event := BattleEvent.new(BattleEvent.Kind.END)
	end_event.winner_index = winner_index
	end_event.time = time_value
	result.events.append(end_event)
	result.winner_index = winner_index


static func _ability_value(summary: Dictionary, kind: int) -> float:
	return float(summary.get(kind, 0.0))


static func _effective_defense(def: int, pierce: float) -> int:
	if pierce <= 0.0:
		return def
	return maxi(0, def - int(pierce))
