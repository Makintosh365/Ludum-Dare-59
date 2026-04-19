class_name BattleLog
extends RefCounted

var events: Array[BattleEvent] = []
var unit_a_snapshot: Dictionary = {}
var unit_b_snapshot: Dictionary = {}
var winner_index: int = -1
var seed_value: int = 0


func event_count() -> int:
	return events.size()


func get_event(index: int) -> BattleEvent:
	if index < 0 or index >= events.size():
		return null
	return events[index]
