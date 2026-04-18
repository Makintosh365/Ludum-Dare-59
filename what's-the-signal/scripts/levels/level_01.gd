class_name Level01
extends Node2D

var _grid: Grid
var _player: Player
var _enemy: Enemy
var _camera: FollowCamera


func _ready() -> void:
	(get_node("%VictoryButton") as Button).pressed.connect(GameManager.trigger_victory)
	(get_node("%DefeatButton") as Button).pressed.connect(GameManager.trigger_defeat)
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
	_player.moved.connect(func(from, to): print("Level01: player moved %s -> %s" % [from, to]))
	_player.move_blocked.connect(func(target, reason): print("Level01: player move_blocked target=%s reason=%s" % [target, reason]))
	_player.damaged.connect(func(amt, hp): print("Level01: player damaged %d hp=%d" % [amt, hp]))
	_player.died.connect(func(): print("Level01: player died"))
	_player.coins_changed.connect(func(total): print("Level01: player coins=%d" % total))
	_player.stats_changed.connect(_on_player_stats_changed)
	_player.inventory.inventory_changed.connect(_on_player_inventory_changed)
	_on_player_stats_changed(_player.stats)
	_on_player_inventory_changed(_player.inventory.get_artifacts())

	_enemy = Enemy.new()
	_enemy.name = "Enemy"
	_enemy.base_max_health = 3
	_enemy.coin_reward = 5
	add_child(_enemy)
	_enemy.place_on(_grid, end)
	_enemy.died.connect(func(): print("Level01: enemy died"))

	var contents_ok: bool = _grid.get_cell(start).contents == _player \
			and _grid.get_cell(end).contents == _enemy
	print("Level01: contents ok" if contents_ok else "Level01: contents MISMATCH")


func _on_player_stats_changed(stats: UnitStats) -> void:
	print("Level01: player stats max_hp=%d dmg=%d def=%d hp=%d" % [
		stats.get_final_int(UnitStats.Kind.MAX_HEALTH),
		stats.get_final_int(UnitStats.Kind.DAMAGE),
		stats.get_final_int(UnitStats.Kind.DEFENSE),
		stats.current_health,
	])


func _on_player_inventory_changed(artifacts: Array) -> void:
	var names: Array = []
	for a in artifacts:
		names.append(a.display_name)
	print("Level01: player inventory=%s" % [names])
