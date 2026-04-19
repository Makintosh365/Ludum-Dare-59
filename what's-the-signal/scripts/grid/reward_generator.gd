class_name RewardGenerator

const _LOOT_CONFIG_PATH := "res://configs/default_loot.tres"

static var _loot_config_cache: LootConfig = null


static func generate(player: Player, rng: RandomNumberGenerator, slot_count_override: int = -1) -> Dictionary:
	var cfg := _load_loot_config()
	if cfg == null:
		push_warning("RewardGenerator: LootConfig missing at %s" % _LOOT_CONFIG_PATH)
		return {"type": "bundle", "coins": 0, "items": []}

	var inventory_value: float = 0.0
	var has_weapon := false
	var has_artifact := false
	if player != null and player.inventory != null:
		inventory_value = player.inventory.get_inventory_value()
		for slot in player.inventory.get_slots():
			if slot.artifact == null:
				continue
			if slot.tag == LootConfig.TYPE_WEAPON:
				has_weapon = true
			elif slot.tag == Inventory.ANY_TAG:
				has_artifact = true

	var coins := _roll_coins(cfg, rng)
	var slot_count := _resolve_slot_count(cfg, rng, slot_count_override)
	var rarity_weights := cfg.rarity_weights_for_value(inventory_value)

	var items: Array = []
	for i in range(slot_count):
		var item := _generate_slot(cfg, rng, has_weapon, has_artifact, rarity_weights)
		if not item.is_empty():
			items.append(item)

	var seed_value: int = 0
	if rng != null:
		seed_value = int(rng.seed)

	return {
		"type": "bundle",
		"coins": coins,
		"items": items,
		"inventory_value": inventory_value,
		"seed": seed_value,
	}


static func apply_coins(player: Player, reward: Dictionary) -> void:
	if player == null or reward.is_empty():
		return
	var coins: int = int(reward.get("coins", 0))
	if coins > 0:
		player.add_coins(coins)


static func apply_item(player: Player, item: Dictionary, target_slot_index: int = -1) -> bool:
	if player == null or player.inventory == null or item.is_empty():
		return false
	var artifact: Artifact = item.get("artifact")
	if artifact == null:
		return false
	var rarity: int = int(item.get("rarity", -1))
	if target_slot_index >= 0:
		return player.inventory.replace_in_slot(artifact, target_slot_index, rarity)
	return player.inventory.place_auto(artifact, rarity) >= 0


static func _generate_slot(cfg: LootConfig, rng: RandomNumberGenerator, has_weapon: bool, has_artifact: bool, rarity_weights: Dictionary) -> Dictionary:
	var slot_type := _pick_slot_type(cfg, rng, has_weapon, has_artifact)
	if slot_type == &"":
		return {}
	var pool: ArtifactPool = cfg.pool_for(slot_type)
	if pool == null or pool.is_empty():
		var fallback: StringName = LootConfig.TYPE_ARTIFACT if slot_type == LootConfig.TYPE_WEAPON else LootConfig.TYPE_WEAPON
		pool = cfg.pool_for(fallback)
		if pool == null or pool.is_empty():
			push_warning("RewardGenerator: both pools empty, skipping slot")
			return {}
		slot_type = fallback
	var artifact := pool.pick_artifact(rng)
	if artifact == null:
		return {}
	var rarity := _pick_rarity(artifact, rarity_weights, rng)
	return {
		"artifact": artifact,
		"rarity": rarity,
		"display_name": artifact.display_name,
		"slot_tag": artifact.slot_tag,
		"slot_type": slot_type,
		"value": artifact.value * cfg.rarity_value_multiplier(rarity),
	}


static func _pick_slot_type(cfg: LootConfig, rng: RandomNumberGenerator, has_weapon: bool, has_artifact: bool) -> StringName:
	var weights: Dictionary = {}
	for key in cfg.slot_type_base_weights:
		var w: float = float(cfg.slot_type_base_weights[key])
		if key == LootConfig.TYPE_WEAPON and has_weapon:
			w *= cfg.weapon_present_weight_multiplier
		elif key == LootConfig.TYPE_ARTIFACT and has_artifact:
			w *= cfg.artifact_present_weight_multiplier
		weights[key] = w
	var picked = _weighted_pick_key(weights, rng)
	if picked == null:
		return &""
	return picked


static func _pick_rarity(artifact: Artifact, rarity_weights: Dictionary, rng: RandomNumberGenerator) -> int:
	var filtered: Dictionary = {}
	for key in rarity_weights:
		if artifact.has_rarity(int(key)):
			filtered[key] = float(rarity_weights[key])
	if filtered.is_empty():
		push_warning("RewardGenerator: no rarity overlap for %s, using first variant" % artifact.id)
		var first := artifact.first_variant()
		return int(first.rarity) if first != null else 0
	var picked = _weighted_pick_key(filtered, rng)
	if picked == null:
		var first := artifact.first_variant()
		return int(first.rarity) if first != null else 0
	return int(picked)


static func _weighted_pick_key(weights: Dictionary, rng: RandomNumberGenerator):
	var total := 0.0
	for key in weights:
		var w: float = float(weights[key])
		if w > 0.0:
			total += w
	if total <= 0.0:
		return null
	var roll: float = (rng.randf() if rng != null else randf()) * total
	for key in weights:
		var w: float = float(weights[key])
		if w <= 0.0:
			continue
		if roll < w:
			return key
		roll -= w
	return null


static func _roll_coins(cfg: LootConfig, rng: RandomNumberGenerator) -> int:
	var lo := cfg.coins_min
	var hi := maxi(lo, cfg.coins_max)
	if rng == null:
		return lo
	return rng.randi_range(lo, hi)


static func _resolve_slot_count(cfg: LootConfig, rng: RandomNumberGenerator, override: int) -> int:
	if override >= 0:
		return maxi(0, override)
	var lo: int = maxi(0, cfg.slot_count_min)
	var hi: int = maxi(lo, cfg.slot_count_max)
	if lo == hi or rng == null:
		return lo
	return rng.randi_range(lo, hi)


static func _load_loot_config() -> LootConfig:
	if _loot_config_cache != null:
		return _loot_config_cache
	if not ResourceLoader.exists(_LOOT_CONFIG_PATH):
		return null
	_loot_config_cache = load(_LOOT_CONFIG_PATH) as LootConfig
	return _loot_config_cache
