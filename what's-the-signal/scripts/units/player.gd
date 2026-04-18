class_name Player
extends Unit

enum InputDuringStep { IGNORE, BUFFER_ONE }

signal coins_changed(new_total: int)
signal move_blocked(target_cell: Vector2i, reason: String)

@export var body_color: Color = Color(0.3, 0.7, 1.0)
@export_range(0.01, 2.0, 0.01) var step_duration: float = 0.15
@export var step_transition: Tween.TransitionType = Tween.TRANS_SINE
@export var step_ease: Tween.EaseType = Tween.EASE_IN_OUT
@export var buffering_mode: InputDuringStep = InputDuringStep.BUFFER_ONE
@export var sight_config: SightConfig
@export var loadout: UnitLoadout

const _DEFAULT_SIGHT_CONFIG_PATH := "res://configs/default_sight.tres"
const _DEFAULT_LOADOUT_PATH := "res://configs/default_player.tres"

var coins: int = 0

var _is_animating: bool = false
var _has_buffered_direction: bool = false
var _buffered_direction: Vector2i = Vector2i.ZERO


func _ready() -> void:
	var cfg := _ensure_loadout()
	if cfg != null:
		base_max_health = cfg.max_health
		base_damage = cfg.damage
		base_defense = cfg.defense
		base_attack_speed = cfg.attack_speed
	super._ready()
	inventory.configure(cfg.inventory if cfg != null else null)


func _ensure_loadout() -> UnitLoadout:
	if loadout != null:
		return loadout
	if ResourceLoader.exists(_DEFAULT_LOADOUT_PATH):
		loadout = load(_DEFAULT_LOADOUT_PATH) as UnitLoadout
	if loadout == null:
		push_warning("Player %s: UnitLoadout not set and default missing, using unit defaults" % name)
	return loadout


func add_coins(amount: int) -> void:
	if amount <= 0:
		return
	coins += amount
	coins_changed.emit(coins)


func _on_placed(p_coords: Vector2i) -> void:
	var cfg := _ensure_sight_config()
	if grid != null:
		grid.update_visibility_from(p_coords, cfg.bright_radius, cfg.dim_radius, cfg.reveal_all_cells)
	visible = true


func _ensure_sight_config() -> SightConfig:
	if sight_config != null:
		return sight_config
	if ResourceLoader.exists(_DEFAULT_SIGHT_CONFIG_PATH):
		sight_config = load(_DEFAULT_SIGHT_CONFIG_PATH) as SightConfig
	if sight_config == null:
		push_warning("Player %s: SightConfig not set and default missing, using inline defaults" % name)
		sight_config = SightConfig.new()
	return sight_config


func _unhandled_input(event: InputEvent) -> void:
	if not is_alive() or grid == null:
		return
	var direction: Vector2i
	if event.is_action_pressed("move_up"):
		direction = Vector2i(0, -1)
	elif event.is_action_pressed("move_down"):
		direction = Vector2i(0, 1)
	elif event.is_action_pressed("move_left"):
		direction = Vector2i(-1, 0)
	elif event.is_action_pressed("move_right"):
		direction = Vector2i(1, 0)
	else:
		return
	get_viewport().set_input_as_handled()
	request_step(direction)


func request_step(direction: Vector2i) -> void:
	if grid == null or direction == Vector2i.ZERO:
		return

	if _is_animating:
		if buffering_mode == InputDuringStep.BUFFER_ONE:
			_buffered_direction = direction
			_has_buffered_direction = true
		return

	var target := coords + direction

	if not grid.in_bounds(target):
		move_blocked.emit(target, "out_of_bounds")
		return

	var destination := grid.get_cell(target)
	if not destination.is_walkable:
		move_blocked.emit(target, "not_walkable")
		return
	if destination.contents != null:
		move_blocked.emit(target, "occupied")
		return

	var from_coords := coords
	grid.get_cell(from_coords).contents = null
	destination.contents = self
	coords = target
	var sight := _ensure_sight_config()
	grid.update_visibility_from(target, sight.bright_radius, sight.dim_radius, sight.reveal_all_cells)

	_is_animating = true
	var tween := create_tween()
	tween.set_trans(step_transition)
	tween.set_ease(step_ease)
	tween.tween_property(self, "position", grid.cell_to_world(target), step_duration)
	tween.finished.connect(func(): _on_step_finished(from_coords, target))


func _on_step_finished(from_coords: Vector2i, to_coords: Vector2i) -> void:
	_is_animating = false
	moved.emit(from_coords, to_coords)

	if _has_buffered_direction:
		var next := _buffered_direction
		_has_buffered_direction = false
		request_step(next)


func _draw() -> void:
	const radius := 10.0
	draw_circle(Vector2.ZERO, radius, body_color)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 24, Color.WHITE, 1.5)
