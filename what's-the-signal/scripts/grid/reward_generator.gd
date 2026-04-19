class_name RewardGenerator

const _POOL_PATH := "res://configs/item/artifact/default_pool.tres"
const _DEFAULT_SLOT_COUNT := 3

static var _pool_cache: ArtifactPool = null


static func generate(_player: Player, rng: RandomNumberGenerator, slot_count: int = _DEFAULT_SLOT_COUNT) -> Dictionary:
	var coins := 5
	if rng != null:
		coins = rng.randi_range(3, 10)

	var items: Array = []
	var count := maxi(1, slot_count)
	for i in range(count):
		var pick := _pick_item(rng)
		if pick.is_empty():
			continue
		var artifact: Artifact = pick["artifact"]
		var rarity: int = pick["rarity"]
		items.append({
			"artifact": artifact,
			"rarity": rarity,
			"display_name": artifact.display_name,
			"slot_tag": artifact.slot_tag,
		})

	return {
		"type": "bundle",
		"coins": coins,
		"items": items,
	}


static func apply(player: Player, reward: Dictionary) -> void:
	if player == null or reward.is_empty():
		return

	var coins: int = int(reward.get("coins", 0))
	if coins > 0:
		player.add_coins(coins)

	var items: Array = reward.get("items", [])
	if items.is_empty() or player.inventory == null:
		return

	for item in items:
		var artifact: Artifact = item.get("artifact")
		var rarity: int = int(item.get("rarity", -1))
		if artifact == null:
			continue
		var index := player.inventory.place_auto(artifact, rarity)
		item["placed"] = index >= 0
		if index < 0:
			print("RewardGenerator: could not place %s (slot_tag=%s) — inventory full or already held" % [artifact.display_name, artifact.slot_tag])


static func _pick_item(rng: RandomNumberGenerator) -> Dictionary:
	var pool := _load_pool()
	if pool == null:
		return {}
	return pool.pick_random(rng)


static func _load_pool() -> ArtifactPool:
	if _pool_cache != null:
		return _pool_cache
	if not ResourceLoader.exists(_POOL_PATH):
		push_warning("RewardGenerator: pool not found at %s" % _POOL_PATH)
		return null
	var pool := load(_POOL_PATH) as ArtifactPool
	_pool_cache = pool
	return pool
