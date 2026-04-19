class_name ViewModeMarker
extends Node2D

@export var target: Node2D
@export var radius: float = 18.0
@export var ring_thickness: float = 2.0
@export var color: Color = Color(1.0, 0.85, 0.2, 0.9)
@export var pulse_period: float = 1.2

var _elapsed: float = 0.0


func _ready() -> void:
	z_index = -1
	if target != null:
		global_position = target.global_position


func _process(delta: float) -> void:
	if target != null and is_instance_valid(target):
		global_position = target.global_position
	_elapsed += delta
	queue_redraw()


func _draw() -> void:
	var phase := 0.5 + 0.5 * sin(_elapsed * TAU / maxf(pulse_period, 0.001))
	var inner_alpha := clampf(0.15 + 0.25 * phase, 0.0, 1.0)
	var pulse_radius := radius * (1.0 + 0.08 * phase)

	var inner_color := Color(color.r, color.g, color.b, inner_alpha)
	draw_circle(Vector2.ZERO, pulse_radius * 0.85, inner_color)
	draw_arc(Vector2.ZERO, pulse_radius, 0.0, TAU, 32, color, ring_thickness)
