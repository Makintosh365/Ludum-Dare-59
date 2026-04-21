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

var has_enemy: bool = false
var enemy_type: String = ""
var was_enemy_seen: bool = false

var has_boss: bool = false

var has_chest: bool = false
var chest_opened: bool = false
var chest: Object = null
var was_chest_seen: bool = false

var has_stat_bonus: bool = false
var stat_bonus_opened: bool = false
var stat_bonus: Object = null
var was_stat_bonus_seen: bool = false


func _init(p_coords: Vector2i) -> void:
	coords = p_coords
