class_name EnemyTypeSpawnRule
extends Resource

# Path to a UnitLoadout .tres that defines the enemy's stats and map icon.
@export_file("*.tres") var enemy_type_path: String = "res://configs/enemies/enemy_1.tres"
@export var count: int = 1

# Distances are measured in walkable-path cells (BFS). Set max_* to -1 for no upper bound.
@export var min_distance_from_player: int = 0
@export var max_distance_from_player: int = -1

@export var min_distance_from_any_enemy: int = 0
@export var max_distance_from_any_enemy: int = -1

@export var min_distance_from_same_type: int = 0
@export var max_distance_from_same_type: int = -1
