class_name UpgradeConfig
extends Resource

# Keys are UnitStats.Kind values (0=MAX_HEALTH, 1=DAMAGE, 2=DEFENSE, 4=LUCK).
@export var stat_base_cost: Dictionary = {
	0: 10,
	1: 10,
	2: 10,
	4: 10,
}

@export var stat_cost_multiplier: float = 2.0

@export var stat_increments: Dictionary = {
	0: 2,
	1: 1,
	2: 1,
	4: 1,
}

@export var weapon_rarity_costs: Array[int] = [15, 30, 60, 120]

@export var slot_unlock_costs: Array[int] = [120, 240]


func stat_cost(kind: int, current_level: int) -> int:
	var base: float = float(stat_base_cost.get(kind, 10))
	var level: int = maxi(0, current_level)
	return int(round(base * pow(stat_cost_multiplier, float(level))))


func stat_increment(kind: int) -> float:
	return float(stat_increments.get(kind, 1))


func weapon_upgrade_cost(current_rarity: int) -> int:
	if current_rarity < 0 or current_rarity >= weapon_rarity_costs.size():
		return -1
	return weapon_rarity_costs[current_rarity]


func slot_unlock_cost(slots_already_unlocked: int) -> int:
	if slots_already_unlocked < 0 or slots_already_unlocked >= slot_unlock_costs.size():
		return -1
	return slot_unlock_costs[slots_already_unlocked]


func max_slot_unlocks() -> int:
	return slot_unlock_costs.size()
