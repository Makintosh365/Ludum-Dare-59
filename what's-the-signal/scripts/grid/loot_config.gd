class_name LootConfig
extends Resource

const TYPE_ARTIFACT := &"artifact"
const TYPE_WEAPON := &"weapon"

# Rarity -> multiplier applied to Artifact.value when computing inventory value.
@export var rarity_value_multipliers: Dictionary = {
	ArtifactVariant.Rarity.COMMON: 1.0,
	ArtifactVariant.Rarity.UNCOMMON: 1.5,
	ArtifactVariant.Rarity.RARE: 2.5,
	ArtifactVariant.Rarity.EPIC: 4.0,
	ArtifactVariant.Rarity.LEGENDARY: 7.0,
}

# Base weights for slot-type selection (stage 1). Keys: TYPE_ARTIFACT / TYPE_WEAPON.
@export var slot_type_base_weights: Dictionary = {
	TYPE_ARTIFACT: 70.0,
	TYPE_WEAPON: 30.0,
}
@export_range(0.0, 1.0, 0.01) var weapon_present_weight_multiplier: float = 0.2
@export_range(0.0, 1.0, 0.01) var artifact_present_weight_multiplier: float = 0.7

@export var artifact_pool: ArtifactPool
@export var weapon_pool: ArtifactPool

# Array of {"threshold": float, "weights": Dictionary[Rarity -> float]},
# sorted ascending by threshold. Curve picks the entry with the highest threshold
# still <= current inventory value.
@export var rarity_weight_breakpoints: Array = [
	{
		"threshold": 0.0,
		"weights": {
			ArtifactVariant.Rarity.COMMON: 70.0,
			ArtifactVariant.Rarity.UNCOMMON: 25.0,
			ArtifactVariant.Rarity.RARE: 4.0,
			ArtifactVariant.Rarity.EPIC: 1.0,
			ArtifactVariant.Rarity.LEGENDARY: 0.0,
		},
	},
	{
		"threshold": 25.0,
		"weights": {
			ArtifactVariant.Rarity.COMMON: 50.0,
			ArtifactVariant.Rarity.UNCOMMON: 30.0,
			ArtifactVariant.Rarity.RARE: 15.0,
			ArtifactVariant.Rarity.EPIC: 4.0,
			ArtifactVariant.Rarity.LEGENDARY: 1.0,
		},
	},
	{
		"threshold": 75.0,
		"weights": {
			ArtifactVariant.Rarity.COMMON: 25.0,
			ArtifactVariant.Rarity.UNCOMMON: 35.0,
			ArtifactVariant.Rarity.RARE: 25.0,
			ArtifactVariant.Rarity.EPIC: 12.0,
			ArtifactVariant.Rarity.LEGENDARY: 3.0,
		},
	},
	{
		"threshold": 200.0,
		"weights": {
			ArtifactVariant.Rarity.COMMON: 10.0,
			ArtifactVariant.Rarity.UNCOMMON: 25.0,
			ArtifactVariant.Rarity.RARE: 30.0,
			ArtifactVariant.Rarity.EPIC: 25.0,
			ArtifactVariant.Rarity.LEGENDARY: 10.0,
		},
	},
]

@export var slot_count_min: int = 3
@export var slot_count_max: int = 3

@export var coins_min: int = 3
@export var coins_max: int = 10

@export var skip_coins_min: int = 5
@export var skip_coins_max: int = 15

@export var battle_victory_coins: int = 10
@export var luck_value_bonus: float = 10.0


func rarity_value_multiplier(rarity: int) -> float:
	return float(rarity_value_multipliers.get(rarity, 1.0))


func rarity_weights_for_value(inventory_value: float) -> Dictionary:
	if rarity_weight_breakpoints.is_empty():
		return {}
	var chosen: Dictionary = rarity_weight_breakpoints[0].get("weights", {})
	for entry in rarity_weight_breakpoints:
		if entry == null:
			continue
		var threshold: float = float(entry.get("threshold", 0.0))
		if inventory_value >= threshold:
			chosen = entry.get("weights", chosen)
		else:
			break
	return chosen


func pool_for(slot_type: StringName) -> ArtifactPool:
	if slot_type == TYPE_WEAPON:
		return weapon_pool
	return artifact_pool
