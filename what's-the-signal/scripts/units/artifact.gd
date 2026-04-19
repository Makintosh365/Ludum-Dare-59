class_name Artifact
extends Resource

@export var id: StringName
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var slot_tag: StringName = &"any"
@export var rarity: ArtifactVariant.Rarity = ArtifactVariant.Rarity.COMMON
@export var value: float = 0.0
@export var variants: Array[ArtifactVariant] = []


func get_variant(r: int) -> ArtifactVariant:
	for v in variants:
		if v != null and v.rarity == r:
			return v
	return null


func first_variant() -> ArtifactVariant:
	for v in variants:
		if v != null:
			return v
	return null


func resolve_variant(r: int = -1) -> ArtifactVariant:
	var target := r if r >= 0 else int(rarity)
	var v := get_variant(target)
	if v != null:
		return v
	return first_variant()


func has_rarity(r: int) -> bool:
	return get_variant(r) != null
