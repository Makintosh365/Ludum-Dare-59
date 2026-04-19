class_name StatBonusSpawnConfig
extends Resource

@export var bonus_count: int = 5

# Distances are measured in walkable-path cells (BFS). Set max_* to -1 for no upper bound.
@export var min_distance_between_bonuses: int = 3
@export var min_distance_from_start: int = 3
@export var max_distance_from_start: int = -1

@export var closed_icon: Texture2D
@export var opened_icon: Texture2D

@export var hp_bonus: int = 5
@export var damage_bonus: int = 1
@export var armor_bonus: int = 2
