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

	var hp: Array = [int(result.unit_a_snapshot.get("current_hp", 0)), int(result.unit_b_snapshot.get("current_hp", 0))]
	var dmg: Array = [int(result.unit_a_snapshot.get("damage", 0)), int(result.unit_b_snapshot.get("damage", 0))]
	var defense: Array = [int(result.unit_a_snapshot.get("defense", 0)), int(result.unit_b_snapshot.get("defense", 0))]
	var speeds: Array = [
		maxf(0.0001, float(result.unit_a_snapshot.get("attack_speed", 1.0))),
		maxf(0.0001, float(result.unit_b_snapshot.get("attack_speed", 1.0))),
	]
	var intervals: Array = [1.0 / speeds[0], 1.0 / speeds[1]]
	var next_time: Array = [intervals[0], intervals[1]]

	var a_can_hurt_b: bool = maxi(0, dmg[0] - defense[1]) > 0 and hp[1] > 0
	var b_can_hurt_a: bool = maxi(0, dmg[1] - defense[0]) > 0 and hp[0] > 0

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
		# Stalemate: neither can kill the other. Winner is whoever has more HP, tie -> A.
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
			# tie-break: faster unit goes first; then A (player) wins ties.
			if speeds[1] > speeds[0]:
				actor = 1
			else:
				actor = 0
		var target: int = 1 - actor
		var t: float = next_time[actor]
		var reduced: int = maxi(0, dmg[actor] - defense[target])
		hp[target] = maxi(0, hp[target] - reduced)

		var atk := BattleEvent.new(BattleEvent.Kind.ATTACK)
		atk.actor_index = actor
		atk.target_index = target
		atk.raw_damage = dmg[actor]
		atk.damage_dealt = reduced
		atk.target_hp_after = hp[target]
		atk.time = t
		result.events.append(atk)

		if hp[target] <= 0:
			var death := BattleEvent.new(BattleEvent.Kind.DEATH)
			death.actor_index = actor
			death.target_index = target
			death.time = t
			result.events.append(death)
			result.winner_index = actor
			break

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
