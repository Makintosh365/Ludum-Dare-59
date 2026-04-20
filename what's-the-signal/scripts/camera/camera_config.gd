class_name CameraConfig
extends Resource

@export_range(0.1, 40.0, 0.1) var smooth_speed: float = 12.0
@export var target_offset: Vector2 = Vector2.ZERO
@export_range(0.0, 16.0, 0.1) var snap_distance: float = 0.5

@export var default_zoom: Vector2 = Vector2.ONE
@export var view_mode_zoom: Vector2 = Vector2(0.5, 0.5)
@export_range(0.0, 2.0, 0.01) var zoom_transition_time: float = 0.35
@export_range(0.0, 4000.0, 10.0) var view_pan_speed: float = 600.0

@export var intro_zoom: Vector2 = Vector2(0.35, 0.35)
@export_range(0.0, 5.0, 0.05) var intro_duration: float = 1.2
