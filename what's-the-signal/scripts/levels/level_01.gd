class_name Level01
extends Node2D

const _CHEST_DIALOG_SCENE := preload("res://scenes/ui/chest_reward_dialog.tscn")
const _SWAP_DIALOG_SCENE := preload("res://scenes/ui/reward_swap_dialog.tscn")
const _STAT_BONUS_DIALOG_SCENE := preload("res://scenes/ui/stat_bonus_dialog.tscn")
const _VIEW_MODE_MARKER_SCRIPT := preload("res://scripts/camera/view_mode_marker.gd")
const _WEAPON_SLOT_TAG := &"weapon"

var _grid: Grid
var _player: Player
var _enemies: Array[Enemy] = []
var _bosses: Array[Boss] = []
var _chests: Array[Chest] = []
var _stat_bonuses: Array[StatBonusCell] = []
var _camera: FollowCamera
var _hud: HUD
var _spawner: EnemySpawner
var _boss_spawner: BossSpawner
var _chest_spawner: ChestSpawner
var _stat_bonus_spawner: StatBonusSpawner
var _alive_enemies: int = 0
var _alive_bosses: int = 0
var _total_bosses: int = 0
var _view_marker: Node2D = null

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
	_boss_spawner = $BossSpawner as BossSpawner
	_chest_spawner = $ChestSpawner as ChestSpawner
	_chest_spawner.chest_opened.connect(_on_chest_opened)
	_stat_bonus_spawner = $StatBonusSpawner as StatBonusSpawner
	var generator := $MapGenerator as MapGenerator
	generator.map_generated.connect(_on_map_generated)
	generator.generate(_grid)

	GameManager.report_ready("Level01", "seed=%d, start=%s, end=%s" % [_grid.get_seed(), _grid.start, _grid.end])


func _exit_tree() -> void:
	if GameManager.state_changed.is_connected(_on_state_changed):
		GameManager.state_changed.disconnect(_on_state_changed)
	if GameManager.battle_resolved.is_connected(_on_battle_resolved):
		GameManager.battle_resolved.disconnect(_on_battle_resolved)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("camera_toggle_view"):
		return
	if _player == null or _camera == null:
		return
	if GameManager.current_state() != GameManager.State.GAMEPLAY:
		return
	get_viewport().set_input_as_handled()
	_toggle_view_mode()


func _process(_delta: float) -> void:
	if _camera != null and _camera.is_view_mode():
		var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		_camera.set_pan_input(dir)


func _toggle_view_mode() -> void:
	if _camera == null:
		return
	if _camera.is_view_mode():
		_exit_view_mode()
	else:
		_enter_view_mode()


func _enter_view_mode() -> void:
	if _player != null:
		_player.set_input_enabled(false)
	_camera.enter_view_mode()
	_spawn_view_marker()


func _exit_view_mode() -> void:
	_despawn_view_marker()
	_camera.exit_view_mode()
	if _player != null:
		_player.set_input_enabled(true)


func _spawn_view_marker() -> void:
	if _view_marker != null and is_instance_valid(_view_marker):
		return
	if _player == null:
		return
	var marker := Node2D.new()
	marker.set_script(_VIEW_MODE_MARKER_SCRIPT)
	marker.set("target", _player)
	marker.global_position = _player.global_position
	add_child(marker)
	_view_marker = marker


func _despawn_view_marker() -> void:
	if _view_marker != null and is_instance_valid(_view_marker):
		_view_marker.queue_free()
	_view_marker = null


func _on_state_changed(previous: int, current: int) -> void:
	print("Level01: state_changed %s -> %s" % [GameManager.State.keys()[previous], GameManager.State.keys()[current]])
	if _camera != null and _camera.is_view_mode() and current != GameManager.State.GAMEPLAY:
		_despawn_view_marker()
		_camera.force_exit_view_mode()
		if _player != null:
			_player.set_input_enabled(true)


func _on_map_generated(start: Vector2i, end: Vector2i, path_length: int) -> void:
	print("Level01: map_generated start=%s end=%s pathLength=%d" % [start, end, path_length])

	_player = Player.new()
	_player.name = "Player"
	add_child(_player)
	_player.place_on(_grid, start)
	_camera.set_target(_player, true)
	_player.move_blocked.connect(func(target, reason): print("Level01: player move_blocked target=%s reason=%s" % [target, reason]))
	_player.battle_requested.connect(_on_battle_requested)
	_player.moved.connect(_on_player_moved)
	_player.died.connect(func(): print("Level01: player died"))

	if _hud != null:
		_hud.bind_player(_player)

	_bosses = _boss_spawner.spawn(_grid, _player.coords, self)
	_alive_bosses = _bosses.size()
	_total_bosses = _bosses.size()
	for boss in _bosses:
		boss.died.connect(_on_boss_died)
	if _hud != null:
		_hud.set_boss_progress(_total_bosses - _alive_bosses, _total_bosses)

	_enemies = _spawner.spawn(_grid, _player.coords, self)
	_alive_enemies = _enemies.size()
	for enemy in _enemies:
		enemy.died.connect(_on_enemy_died)

	_chests = _chest_spawner.spawn(_grid, _player.coords, self)

	_stat_bonuses = _stat_bonus_spawner.spawn(_grid, _player.coords, self)

	var player_ok: bool = _grid.get_cell(start).contents == _player
	var end_clear: bool = _grid.get_cell(end).contents == null and not _grid.get_cell(end).has_enemy
	print("Level01: contents ok" if player_ok and end_clear else "Level01: contents MISMATCH")


func _on_enemy_died() -> void:
	print("Level01: enemy died")
	_alive_enemies = maxi(0, _alive_enemies - 1)


func _on_boss_died() -> void:
	print("Level01: boss died")
	_alive_bosses = maxi(0, _alive_bosses - 1)
	if _hud != null:
		_hud.set_boss_progress(_total_bosses - _alive_bosses, _total_bosses)
	if _alive_bosses == 0 and _bosses.size() > 0:
		print("Level01: all bosses defeated — triggering victory")
		GameManager.trigger_victory()


func _on_player_moved(_from: Vector2i, to: Vector2i) -> void:
	if _grid == null:
		return
	var cell := _grid.get_cell(to)
	if cell == null:
		return
	if cell.has_chest and not cell.chest_opened and cell.chest is Chest:
		(cell.chest as Chest).open(_player)
	if cell.has_stat_bonus and not cell.stat_bonus_opened and cell.stat_bonus is StatBonusCell:
		_open_stat_bonus(cell.stat_bonus as StatBonusCell)


func _open_stat_bonus(bonus: StatBonusCell) -> void:
	if bonus == null:
		return
	bonus.open()
	var dialog := _STAT_BONUS_DIALOG_SCENE.instantiate() as StatBonusDialog
	if dialog == null:
		return
	add_child(dialog)
	var cfg: StatBonusSpawnConfig = bonus.config
	var hp_amount: int = cfg.hp_bonus if cfg != null else 0
	var damage_amount: int = cfg.damage_bonus if cfg != null else 0
	var armor_amount: int = cfg.armor_bonus if cfg != null else 0
	dialog.configure(hp_amount, damage_amount, armor_amount)
	dialog.choice_made.connect(_on_stat_bonus_choice.bind(dialog, bonus))


func _on_stat_bonus_choice(kind: int, amount: float, dialog: StatBonusDialog, bonus: StatBonusCell) -> void:
	if bonus != null:
		bonus.apply_choice(_player, kind, amount)
	if dialog != null and is_instance_valid(dialog):
		dialog.queue_free()


func _on_chest_opened(coords: Vector2i, reward: Dictionary) -> void:
	print("Level01: chest_opened at %s reward=%s" % [coords, reward])
	var dialog := _CHEST_DIALOG_SCENE.instantiate() as RewardChoiceDialog
	if dialog == null:
		return
	add_child(dialog)
	dialog.set_options(reward, _player.inventory)
	dialog.item_selected.connect(_on_reward_item_selected.bind(dialog, reward))
	dialog.skipped.connect(_on_reward_skipped.bind(dialog))


func _on_reward_item_selected(index: int, dialog: RewardChoiceDialog, reward: Dictionary) -> void:
	var items: Array = reward.get("items", [])
	if index < 0 or index >= items.size():
		return
	var item: Dictionary = items[index]
	var artifact: Artifact = item.get("artifact")
	if _player == null or _player.inventory == null or artifact == null:
		dialog.queue_free()
		return
	var inventory: Inventory = _player.inventory
	var empty := inventory.find_empty_compatible_slot(artifact)
	if empty >= 0:
		RewardGenerator.apply_item(_player, item)
		dialog.queue_free()
		return

	var swap := _SWAP_DIALOG_SCENE.instantiate() as RewardSwapDialog
	if swap == null:
		dialog.queue_free()
		return
	add_child(swap)
	if artifact.slot_tag == _WEAPON_SLOT_TAG:
		swap.configure_weapon(item, inventory)
	else:
		swap.configure_artifact(item, inventory)
	swap.confirmed.connect(_on_swap_confirmed.bind(swap, dialog, item))
	swap.cancelled.connect(_on_swap_cancelled.bind(swap))


func _on_swap_confirmed(target: int, swap: RewardSwapDialog, dialog: RewardChoiceDialog, item: Dictionary) -> void:
	RewardGenerator.apply_item(_player, item, target)
	if swap != null and is_instance_valid(swap):
		swap.queue_free()
	if dialog != null and is_instance_valid(dialog):
		dialog.queue_free()


func _on_swap_cancelled(swap: RewardSwapDialog) -> void:
	if swap != null and is_instance_valid(swap):
		swap.queue_free()


func _on_reward_skipped(dialog: RewardChoiceDialog) -> void:
	var rng: RandomNumberGenerator = _grid.rng if _grid != null else null
	RewardGenerator.apply_skip_bonus(_player, rng)
	if dialog != null and is_instance_valid(dialog):
		dialog.queue_free()


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
