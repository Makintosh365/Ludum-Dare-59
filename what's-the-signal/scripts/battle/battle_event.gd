class_name BattleEvent
extends RefCounted

enum Kind { ATTACK, DEATH, END }

var kind: Kind = Kind.ATTACK
var actor_index: int = -1
var target_index: int = -1
var raw_damage: int = 0
var damage_dealt: int = 0
var target_hp_after: int = 0
var time: float = 0.0
var winner_index: int = -1


func _init(p_kind: Kind = Kind.ATTACK) -> void:
	kind = p_kind


func describe() -> String:
	match kind:
		Kind.ATTACK:
			return "ATTACK actor=%d -> target=%d raw=%d dealt=%d hp_after=%d t=%.2f" % [actor_index, target_index, raw_damage, damage_dealt, target_hp_after, time]
		Kind.DEATH:
			return "DEATH target=%d by=%d t=%.2f" % [target_index, actor_index, time]
		Kind.END:
			return "END winner=%d t=%.2f" % [winner_index, time]
	return "UNKNOWN"
