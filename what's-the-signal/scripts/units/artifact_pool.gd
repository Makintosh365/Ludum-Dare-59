class_name ArtifactPool
extends Resource

@export var artifacts: Array = []
@export var rarity_weights: Dictionary = {
	Artifact.Rarity.COMMON: 60.0,
	Artifact.Rarity.UNCOMMON: 25.0,
	Artifact.Rarity.RARE: 10.0,
	Artifact.Rarity.EPIC: 4.0,
	Artifact.Rarity.LEGENDARY: 1.0,
}


func pick_random(rng: RandomNumberGenerator = null) -> Artifact:
	var total := 0.0
	for a in artifacts:
		if a == null:
			continue
		total += weight_for(a)
	if total <= 0.0:
		return null
	var roll: float = (rng.randf() if rng != null else randf()) * total
	for a in artifacts:
		if a == null:
			continue
		var w := weight_for(a)
		if w <= 0.0:
			continue
		if roll < w:
			return a
		roll -= w
	return null


func weight_for(artifact: Artifact) -> float:
	if artifact == null:
		return 0.0
	return float(rarity_weights.get(artifact.rarity, 0.0))
