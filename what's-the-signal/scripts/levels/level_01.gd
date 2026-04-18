class_name Level01
extends Node2D

var _grid: Grid
var _player: Player
var _enemy: Enemy
var _camera: FollowCamera
var _hud: HUD
var _alive_enemies: int = 0


func _ready() -> void:
	_hud = $UI/HUD as HUD
	(_hud.get_node("DevButtons/VictoryButton") as Button).pressed.connect(GameManager.trigger_victory)
	(_hud.get_node("DevButtons/DefeatButton") as Button).pressed.connect(GameManager.trigger_defeat)
	GameManager.state_changed.connect(_on_state_changed)

	_grid = $Grid as Grid
	_camera = $Camera as FollowCamera
	var generator := $MapGenerator as MapGenerator
	generator.map_generated.connect(_on_map_generated)
	generator.generate(_grid)

	GameManager.report_ready("Level01", "seed=%d, start=%s, end=%s" % [_grid.get_seed(), _grid.start, _grid.end])


func _exit_tree() -> void:
	if GameManager.state_changed.is_connected(_on_state_changed):
		GameManager.state_changed.disconnect(_on_state_changed)


func _on_state_changed(previous: int, current: int) -> void:
	print("Level01: state_changed %s -> %s" % [GameManager.State.keys()[previous], GameManager.State.keys()[current]])


func _on_map_generated(start: Vector2i, end: Vector2i, path_length: int) -> void:
	print("Level01: map_generated start=%s end=%s pathLength=%d" % [start, end, path_length])

	_player = Player.new()
	_player.name = "Player"
	add_child(_player)
	_player.place_on(_grid, start)
	_camera.set_target(_player, true)
	_player.move_blocked.connect(func(target, reason): print("Level01: player move_blocked target=%s reason=%s" % [target, reason]))
	_player.died.connect(func(): print("Level01: player died"))

	if _hud != null:
		_hud.bind_player(_player)

	_enemy = Enemy.new()
	_enemy.name = "Enemy"
	add_child(_enemy)
	_enemy.place_on(_grid, end)
	_enemy.died.connect(_on_enemy_died)
	_alive_enemies = 1
	if _hud != null:
		_hud.set_enemy_count(_alive_enemies)

	var contents_ok: bool = _grid.get_cell(start).contents == _player \
			and _grid.get_cell(end).contents == _enemy
	print("Level01: contents ok" if contents_ok else "Level01: contents MISMATCH")


func _on_enemy_died() -> void:
	print("Level01: enemy died")
	_alive_enemies = maxi(0, _alive_enemies - 1)
	if _hud != null:
		_hud.set_enemy_count(_alive_enemies)
