class_name ArtifactVariant
extends Resource

enum Rarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }

@export var rarity: Rarity = Rarity.COMMON
@export var icon: Texture2D
@export var modifiers: Array[StatModifier] = []
@export var abilities: Array[Ability] = []
