class_name Level01
extends Node2D

var _grid: Grid
var _player: Player
var _enemies: Array[Enemy] = []
var _camera: FollowCamera
var _hud: HUD
var _spawner: EnemySpawner
var _alive_enemies: int = 0

var _pending_battle_target: Vector2i = Vector2i.ZERO
var _pending_battle_enemy: Enemy = null
var _pending_battle_log: BattleLog = null


func _ready() -> void:
	_hud = $UI/HUD as HUD
	(_hud.get_node("DevButtons/VictoryButton") as Button).pressed.connect(GameManager.trigger_victory)
	(_hud.get_node("DevButtons/DefeatButton") as Button).pressed.connect(GameManager.trigger_defeat)
	GameManager.state_changed.connect(_on_state_changed)
	GameManager.battle_resolved.connect(_on_battle_resolved)

	_grid = $Grid as Grid
	_camera = $Camera as FollowCamera
	_spawner = $EnemySpawner as EnemySpawner
	var generator := $MapGenerator as MapGenerator
	generator.map_generated.connect(_on_map_generated)
	generator.generate(_grid)

	GameManager.report_ready("Level01", "seed=%d, start=%s, end=%s" % [_grid.get_seed(), _grid.start, _grid.end])


func _exit_tree() -> void:
	if GameManager.state_changed.is_connected(_on_state_changed):
		GameManager.state_changed.disconnect(_on_state_changed)
	if GameManager.battle_resolved.is_connected(_on_battle_resolved):
		GameManager.battle_resolved.disconnect(_on_battle_resolved)


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
	_player.battle_requested.connect(_on_battle_requested)
	_player.died.connect(func(): print("Level01: player died"))

	if _hud != null:
		_hud.bind_player(_player)

	_enemies = _spawner.spawn(_grid, _player.coords, self)
	_alive_enemies = _enemies.size()
	for enemy in _enemies:
		enemy.died.connect(_on_enemy_died)
	if _hud != null:
		_hud.set_enemy_count(_alive_enemies)

	var player_ok: bool = _grid.get_cell(start).contents == _player
	var end_clear: bool = _grid.get_cell(end).contents == null and not _grid.get_cell(end).has_enemy
	print("Level01: contents ok" if player_ok and end_clear else "Level01: contents MISMATCH")


func _on_enemy_died() -> void:
	print("Level01: enemy died")
	_alive_enemies = maxi(0, _alive_enemies - 1)
	if _hud != null:
		_hud.set_enemy_count(_alive_enemies)


func _on_battle_requested(target: Vector2i, enemy: Enemy) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	if _pending_battle_enemy != null:
		return
	var grid_seed: int = _grid.get_seed() if _grid != null else 0
	var battle_seed: int = grid_seed ^ (target.x * 73856093) ^ (target.y * 19349663)
	var battle_log := BattleResolver.resolve(_player, enemy, battle_seed)
	print("Level01: starting battle at %s (events=%d, winner=%d)" % [target, battle_log.event_count(), battle_log.winner_index])
	_pending_battle_target = target
	_pending_battle_enemy = enemy
	_pending_battle_log = battle_log
	if not GameManager.start_battle(battle_log):
		push_warning("Level01: GameManager refused battle start")
		_pending_battle_enemy = null
		_pending_battle_log = null


func _on_battle_resolved(winner_index: int) -> void:
	var target := _pending_battle_target
	var enemy := _pending_battle_enemy
	var battle_log := _pending_battle_log
	_pending_battle_enemy = null
	_pending_battle_log = null
	if battle_log == null:
		return
	print("Level01: battle resolved winner=%d" % winner_index)
	if winner_index == 0:
		_apply_player_victory(target, enemy, battle_log)
	else:
		_apply_player_defeat(battle_log)


func _apply_player_victory(target: Vector2i, enemy: Enemy, battle_log: BattleLog) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var final_hp: int = int(battle_log.unit_a_snapshot.get("final_hp", _player.stats.current_health))
	_player.stats.current_health = maxi(1, final_hp)
	_player.stats_changed.emit(_player.stats)

	if enemy != null and is_instance_valid(enemy):
		enemy.die(_player)

	if not GameManager.change_state(GameManager.State.GAMEPLAY):
		push_warning("Level01: could not return to GAMEPLAY from BATTLE")
		return
	if _grid != null and _grid.in_bounds(target):
		_player.advance_to(target)


func _apply_player_defeat(battle_log: BattleLog) -> void:
	if _player != null and is_instance_valid(_player):
		_player.stats.current_health = 0
		_player.stats_changed.emit(_player.stats)
	GameManager.trigger_defeat()
