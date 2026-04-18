class_name FollowCamera
extends Camera2D

@export var config: CameraConfig

const _DEFAULT_CAMERA_CONFIG_PATH := "res://configs/default_camera.tres"

var _target: Node2D = null
var _desired_position: Vector2 = Vector2.ZERO
var _has_target: bool = false


func _ready() -> void:
	make_current()
	_ensure_config()


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


func _process(delta: float) -> void:
	if not _has_target or config == null:
		return

	var diff := _desired_position - global_position
	var snap := config.snap_distance
	if diff.length_squared() <= snap * snap:
		global_position = _desired_position
		return

	var t := 1.0 - exp(-config.smooth_speed * delta)
	global_position = global_position.lerp(_desired_position, t)


func _on_player_moved(_from: Vector2i, _to: Vector2i) -> void:
	if _target == null:
		return
	_desired_position = _target.global_position + _ensure_config().target_offset


func _ensure_config() -> CameraConfig:
	if config != null:
		return config
	if ResourceLoader.exists(_DEFAULT_CAMERA_CONFIG_PATH):
		config = load(_DEFAULT_CAMERA_CONFIG_PATH) as CameraConfig
	if config == null:
		push_warning("FollowCamera %s: CameraConfig not set and default missing, using inline defaults" % name)
		config = CameraConfig.new()
	return config
