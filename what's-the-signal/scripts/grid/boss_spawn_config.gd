class_name BossSpawnConfig
extends Resource

@export var boss_count: int = 3

# Distances are measured in walkable-path cells (BFS). Set max_* to -1 for no upper bound.
@export var min_distance_between_bosses: int = 5
@export var min_distance_from_start: int = 4
@export var max_distance_from_start: int = -1

@export_file("*.tres") var boss_loadout_path: String = "res://configs/enemies/boss.tres"
