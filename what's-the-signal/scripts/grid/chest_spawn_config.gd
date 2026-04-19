class_name ChestSpawnConfig
extends Resource

@export var chest_count: int = 3

# Distances are measured in walkable-path cells (BFS). Set max_* to -1 for no upper bound.
@export var min_distance_between_chests: int = 3
@export var min_distance_from_start: int = 4
@export var max_distance_from_start: int = -1

@export var closed_icon: Texture2D
@export var opened_icon: Texture2D
