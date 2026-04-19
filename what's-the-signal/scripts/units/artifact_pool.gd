class_name ArtifactPool
extends Resource

@export var artifacts: Array = []
@export var rarity_weights: Dictionary = {
	ArtifactVariant.Rarity.COMMON: 60.0,
	ArtifactVariant.Rarity.UNCOMMON: 25.0,
	ArtifactVariant.Rarity.RARE: 10.0,
	ArtifactVariant.Rarity.EPIC: 4.0,
	ArtifactVariant.Rarity.LEGENDARY: 1.0,
}
# Per-item draw weight for stage 2 (keyed by Artifact.id). Missing entries default to 1.0.
@export var item_weights: Dictionary = {}


func pick_random(rng: RandomNumberGenerator = null) -> Dictionary:
	var total := 0.0
	for a in artifacts:
		if a == null:
			continue
		for v in a.variants:
			if v == null:
				continue
			total += weight_for(v)
	if total <= 0.0:
		return {}
	var roll: float = (rng.randf() if rng != null else randf()) * total
	for a in artifacts:
		if a == null:
			continue
		for v in a.variants:
			if v == null:
				continue
			var w := weight_for(v)
			if w <= 0.0:
				continue
			if roll < w:
				return {"artifact": a, "rarity": v.rarity}
			roll -= w
	return {}


func pick_artifact(rng: RandomNumberGenerator = null) -> Artifact:
	var total := 0.0
	for a in artifacts:
		if a == null:
			continue
		total += item_weight_for(a)
	if total <= 0.0:
		return null
	var roll: float = (rng.randf() if rng != null else randf()) * total
	for a in artifacts:
		if a == null:
			continue
		var w := item_weight_for(a)
		if w <= 0.0:
			continue
		if roll < w:
			return a
		roll -= w
	return null


func is_empty() -> bool:
	for a in artifacts:
		if a != null:
			return false
	return true


func weight_for(variant: ArtifactVariant) -> float:
	if variant == null:
		return 0.0
	return float(rarity_weights.get(variant.rarity, 0.0))


func item_weight_for(artifact: Artifact) -> float:
	if artifact == null:
		return 0.0
	return float(item_weights.get(artifact.id, 1.0))
