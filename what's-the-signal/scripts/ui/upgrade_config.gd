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


func stat_cost(kind: int, current_level: int) -> int:
	var base: float = float(stat_base_cost.get(kind, 10))
	var level: int = maxi(0, current_level)
	return int(round(base * pow(stat_cost_multiplier, float(level))))


func stat_increment(kind: int) -> int:
	return int(stat_increments.get(kind, 1))


func weapon_upgrade_cost(current_rarity: int) -> int:
	if current_rarity < 0 or current_rarity >= weapon_rarity_costs.size():
		return -1
	return weapon_rarity_costs[current_rarity]
