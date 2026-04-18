class_name GridCell
extends RefCounted

enum Visibility { HIDDEN, DIM, FULL }

var coords: Vector2i

var is_walkable: bool = true
var is_explored: bool = false
var has_been_seen: bool = false
var visibility: Visibility = Visibility.HIDDEN

var kind: String = CellKinds.WALKABLE

var distance_from_start: int = -1

var contents = null


func _init(p_coords: Vector2i) -> void:
	coords = p_coords
