extends Node

signal state_changed(previous: int, current: int)

enum State { BOOT, MAIN_MENU, LOADING, GAMEPLAY, PAUSED, VICTORY, DEFEAT }

@export var main_menu_scene: PackedScene
@export var gameplay_scene: PackedScene
@export var pause_menu_scene: PackedScene
@export var victory_screen_scene: PackedScene
@export var defeat_screen_scene: PackedScene

const _VALID_TRANSITIONS := {
	State.BOOT: [State.MAIN_MENU, State.LOADING],
	State.MAIN_MENU: [State.LOADING],
	State.LOADING: [State.GAMEPLAY, State.MAIN_MENU],
	State.GAMEPLAY: [State.PAUSED, State.VICTORY, State.DEFEAT, State.LOADING, State.MAIN_MENU],
	State.PAUSED: [State.GAMEPLAY, State.LOADING, State.MAIN_MENU],
	State.VICTORY: [State.LOADING, State.MAIN_MENU],
	State.DEFEAT: [State.LOADING, State.MAIN_MENU],
}

var _state: State = State.BOOT
var _overlay: Node = null


func current_state() -> State:
	return _state


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("GameManager: === INIT === autoload up, state=Boot")


func report_ready(system: String, detail: String = "") -> void:
	var tail := "" if detail.is_empty() else " (%s)" % detail
	print("GameManager: ready <- %s%s [phase=%s]" % [system, tail, State.keys()[_state]])


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		toggle_pause()


func load_level() -> void:
	if gameplay_scene == null:
		push_warning("GameManager: GameplayScene is not set")
		return

	print("GameManager: LoadLevel — switching to gameplay scene")
	if not change_state(State.LOADING):
		return

	await get_tree().process_frame
	get_tree().change_scene_to_packed(gameplay_scene)
	await get_tree().process_frame
	change_state(State.GAMEPLAY)


func toggle_pause() -> void:
	match _state:
		State.GAMEPLAY:
			change_state(State.PAUSED)
		State.PAUSED:
			change_state(State.GAMEPLAY)


func trigger_victory() -> void:
	change_state(State.VICTORY)


func trigger_defeat() -> void:
	change_state(State.DEFEAT)


func restart_level() -> void:
	load_level()


func load_main_menu() -> void:
	if main_menu_scene == null:
		push_warning("GameManager: MainMenuScene is not set")
		return
	if not change_state(State.MAIN_MENU):
		return
	get_tree().change_scene_to_packed(main_menu_scene)


func quit_game() -> void:
	get_tree().quit()


func change_state(new_state: State) -> bool:
	if new_state == _state:
		return false
	if not _VALID_TRANSITIONS.has(_state) or not (new_state in _VALID_TRANSITIONS[_state]):
		push_warning("GameManager: invalid transition %s -> %s" % [State.keys()[_state], State.keys()[new_state]])
		return false
	var previous := _state
	_state = new_state
	print("GameManager: === PHASE %s === (prev=%s)" % [State.keys()[new_state], State.keys()[previous]])
	state_changed.emit(previous, new_state)
	_apply_state(previous, new_state)
	return true


func _apply_state(previous: State, current: State) -> void:
	if previous == State.PAUSED or previous == State.VICTORY or previous == State.DEFEAT:
		_clear_overlay()
		if current != State.PAUSED and current != State.VICTORY and current != State.DEFEAT:
			get_tree().paused = false

	match current:
		State.PAUSED:
			get_tree().paused = true
			_show_overlay(pause_menu_scene)
		State.VICTORY:
			get_tree().paused = true
			_show_overlay(victory_screen_scene)
		State.DEFEAT:
			get_tree().paused = true
			_show_overlay(defeat_screen_scene)
		State.GAMEPLAY:
			get_tree().paused = false


func _show_overlay(scene: PackedScene) -> void:
	if scene == null:
		push_warning("GameManager: overlay scene is not set")
		return

	_clear_overlay()
	_overlay = scene.instantiate()
	get_tree().root.add_child(_overlay)


func _clear_overlay() -> void:
	if is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = null
