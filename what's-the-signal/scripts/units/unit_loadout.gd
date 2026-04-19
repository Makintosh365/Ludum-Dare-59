class_name UnitLoadout
extends Resource

@export var display_name: String = ""
@export_multiline var description: String = ""

@export var max_health: int = 10
@export var damage: int = 1
@export var defense: int = 0
@export var attack_speed: float = 1.0
@export var crit_chance: float = 0.0

@export var map_icon: Texture2D
@export var battle_icon: Texture2D

@export var inventory: InventoryConfig
