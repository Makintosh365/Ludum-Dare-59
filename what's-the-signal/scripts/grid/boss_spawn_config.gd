class_name BossSpawnConfig
extends Resource

# Distances are measured in walkable-path cells (BFS). Set max_* to -1 for no upper bound.
@export var min_distance_between_bosses: int = 5
@export var min_distance_from_start: int = 4
@export var max_distance_from_start: int = -1

# One entry per boss. Index 0 spawns closest to start (easiest); the last
# index spawns farthest (hardest). The number of bosses equals the array size.
@export var boss_loadout_paths: Array[String] = [
	"res://configs/enemies/boss_1.tres",
	"res://configs/enemies/boss_2.tres",
	"res://configs/enemies/boss_3.tres",
]


func get_boss_count() -> int:
	return boss_loadout_paths.size()
