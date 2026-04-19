class_name FollowCamera
extends Camera2D

signal view_mode_changed(active: bool)

enum Mode { FOLLOW, VIEW }

@export var config: CameraConfig

const _DEFAULT_CAMERA_CONFIG_PATH := "res://configs/default_camera.tres"

var _target: Node2D = null
var _desired_position: Vector2 = Vector2.ZERO
var _has_target: bool = false
var _mode: int = Mode.FOLLOW
var _saved_target: Node2D = null
var _pan_input: Vector2 = Vector2.ZERO
var _zoom_tween: Tween = null


func _ready() -> void:
	make_current()
	var cfg := _ensure_config()
	zoom = cfg.default_zoom


func _exit_tree() -> void:
	if _target is Player:
		var prev := _target as Player
		if prev.moved.is_connected(_on_player_moved):
			prev.moved.disconnect(_on_player_moved)


func set_target(target: Node2D, snap: bool = true) -> void:
	if _target is Player:
		var prev := _target as Player
		if prev.moved.is_connected(_on_player_moved):
			prev.moved.disconnect(_on_player_moved)

	_target = target
	_has_target = target != null

	if target is Player:
		(target as Player).moved.connect(_on_player_moved)

	if not _has_target:
		return

	var cfg := _ensure_config()
	_desired_position = target.global_position + cfg.target_offset

	if snap:
		snap_to_target()


func snap_to_target() -> void:
	if not _has_target:
		return
	var cfg := _ensure_config()
	_desired_position = _target.global_position + cfg.target_offset
	global_position = _desired_position
	reset_smoothing()


func is_view_mode() -> bool:
	return _mode == Mode.VIEW


func set_pan_input(dir: Vector2) -> void:
	_pan_input = dir


func enter_view_mode() -> void:
	if _mode == Mode.VIEW:
		return
	var cfg := _ensure_config()
	_saved_target = _target
	_has_target = false
	_desired_position = global_position
	_pan_input = Vector2.ZERO
	_mode = Mode.VIEW
	_tween_zoom(cfg.view_mode_zoom, cfg.zoom_transition_time)
	view_mode_changed.emit(true)


func exit_view_mode() -> void:
	if _mode == Mode.FOLLOW:
		return
	var cfg := _ensure_config()
	_pan_input = Vector2.ZERO
	_mode = Mode.FOLLOW
	_tween_zoom(cfg.default_zoom, cfg.zoom_transition_time)
	var resume_target := _saved_target
	_saved_target = null
	if resume_target != null and is_instance_valid(resume_target):
		set_target(resume_target, false)
	view_mode_changed.emit(false)


func force_exit_view_mode() -> void:
	if _mode == Mode.FOLLOW:
		return
	var cfg := _ensure_config()
	if _zoom_tween != null and _zoom_tween.is_running():
		_zoom_tween.kill()
	_zoom_tween = null
	zoom = cfg.default_zoom
	_pan_input = Vector2.ZERO
	_mode = Mode.FOLLOW
	var resume_target := _saved_target
	_saved_target = null
	if resume_target != null and is_instance_valid(resume_target):
		set_target(resume_target, true)
	view_mode_changed.emit(false)


func _process(delta: float) -> void:
	var cfg := _ensure_config()

	if _mode == Mode.VIEW:
		if _pan_input != Vector2.ZERO:
			var scale_x := zoom.x if zoom.x > 0.0 else 1.0
			global_position += _pan_input * cfg.view_pan_speed * delta / scale_x
		return

	if not _has_target:
		return

	var diff := _desired_position - global_position
	var snap := cfg.snap_distance
	if diff.length_squared() <= snap * snap:
		global_position = _desired_position
		return

	var t := 1.0 - exp(-cfg.smooth_speed * delta)
	global_position = global_position.lerp(_desired_position, t)


func _on_player_moved(_from: Vector2i, _to: Vector2i) -> void:
	if _target == null:
		return
	_desired_position = _target.global_position + _ensure_config().target_offset


func _tween_zoom(target_zoom: Vector2, duration: float) -> void:
	if _zoom_tween != null and _zoom_tween.is_running():
		_zoom_tween.kill()
	if duration <= 0.0:
		zoom = target_zoom
		_zoom_tween = null
		return
	_zoom_tween = create_tween()
	_zoom_tween.set_trans(Tween.TRANS_SINE)
	_zoom_tween.set_ease(Tween.EASE_IN_OUT)
	_zoom_tween.tween_property(self, "zoom", target_zoom, duration)


func _ensure_config() -> CameraConfig:
	if config != null:
		return config
	if ResourceLoader.exists(_DEFAULT_CAMERA_CONFIG_PATH):
		config = load(_DEFAULT_CAMERA_CONFIG_PATH) as CameraConfig
	if config == null:
		push_warning("FollowCamera %s: CameraConfig not set and default missing, using inline defaults" % name)
		config = CameraConfig.new()
	return config
