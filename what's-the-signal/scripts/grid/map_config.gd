class_name MapConfig
extends Resource

@export var min_path_length: int = 200
@export var max_path_length: int = 250
@export var max_generation_attempts: int = 10
@export var fallback_seeds: PackedInt64Array = PackedInt64Array()

@export_range(0.0, 1.0, 0.05) var turn_chance: float = 0.2
@export_range(0.0, 1.0, 0.05) var branch_chance: float = 0.25

@export var start_coords: Vector2i = Vector2i(-1, -1)

@export var terrain_kinds: PackedStringArray = PackedStringArray(["forest", "mountain"])
@export var terrain_weights: PackedFloat32Array = PackedFloat32Array([0.7, 0.3])

@export var max_path_neighbors: int = 3
@export var forbid_double_width: bool = true

@export var min_junctions: int = 0
@export var max_junctions: int = 0
@export var max_junction_neighbors: int = 4
