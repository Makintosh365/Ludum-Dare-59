class_name Artifact
extends Resource

enum Rarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }

@export var id: StringName
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var rarity: Rarity = Rarity.COMMON
@export var modifiers: Array = []
