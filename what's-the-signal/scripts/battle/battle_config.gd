class_name BattleConfig
extends Resource

@export var playback_speeds: Array[float] = [1.0, 2.0, 4.0]
@export_range(0, 32, 1) var default_speed_index: int = 0
@export_range(0.05, 5.0, 0.01) var event_duration: float = 0.55
@export_range(0.0, 5.0, 0.01) var end_hold_duration: float = 0.8
@export var damage_number_color: Color = Color(1.0, 1.0, 1.0)
@export var crit_color_tier_2: Color = Color(1.0, 0.6, 0.0)
@export var crit_color_tier_3: Color = Color(1.0, 0.3, 0.0)
@export var crit_color_tier_4_plus: Color = Color(1.0, 0.1, 0.1)
@export_range(0.0, 128.0, 0.5) var damage_number_rise: float = 42.0
@export_range(0.05, 3.0, 0.01) var damage_number_lifetime: float = 0.75
@export_range(16, 512, 1) var unit_icon_size: int = 128
@export var player_fallback_color: Color = Color(0.3, 0.7, 1.0)
@export var enemy_fallback_color: Color = Color(1.0, 0.3, 0.3)

@export_group("Stat Colors")
@export var hp_color: Color = Color(0.55, 0.85, 0.35)
@export var damage_color: Color = Color(0.95, 0.35, 0.35)
@export var defense_color: Color = Color(0.45, 0.65, 0.95)
@export var speed_color: Color = Color(0.95, 0.8, 0.3)

@export_group("Stat Icons")
@export var hp_icon: Texture2D
@export var damage_icon: Texture2D
@export var defense_icon: Texture2D
@export var speed_icon: Texture2D

@export_group("Control Bar")
@export var controls_active_color: Color = Color(1, 1, 1, 1)
@export var controls_idle_color: Color = Color(0.45, 0.45, 0.45, 1)


func get_speed(index: int) -> float:
	if playback_speeds.is_empty():
		return 1.0
	var clamped: int = clampi(index, 0, playback_speeds.size() - 1)
	var value: float = playback_speeds[clamped]
	if value <= 0.0:
		return 1.0
	return value


func get_default_speed_index() -> int:
	if playback_speeds.is_empty():
		return 0
	return clampi(default_speed_index, 0, playback_speeds.size() - 1)
