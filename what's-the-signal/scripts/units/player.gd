class_name Player
extends Unit

enum InputDuringStep { IGNORE, BUFFER_ONE }

signal coins_changed(new_total: int)
signal move_blocked(target_cell: Vector2i, reason: String)
signal battle_requested(target_cell: Vector2i, enemy: Enemy)
signal upgrades_changed

@export var body_color: Color = Color(0.3, 0.7, 1.0)
@export_range(0.01, 2.0, 0.01) var step_duration: float = 0.15
@export var step_transition: Tween.TransitionType = Tween.TRANS_SINE
@export var step_ease: Tween.EaseType = Tween.EASE_IN_OUT
@export var buffering_mode: InputDuringStep = InputDuringStep.BUFFER_ONE
@export var sight_config: SightConfig
@export var loadout: UnitLoadout

const _DEFAULT_SIGHT_CONFIG_PATH := "res://configs/default_sight.tres"
const _DEFAULT_LOADOUT_PATH := "res://configs/default_player.tres"
const _DEFAULT_UPGRADE_CONFIG_PATH := "res://configs/default_upgrade.tres"

# Persistent across level restarts within the same game session. Populated by
# shop purchases; Player._ready() reads them back onto each fresh instance so
# permanent upgrades survive death.
static var _persistent_stat_levels: Dictionary = {
	UnitStats.Kind.MAX_HEALTH: 0,
	UnitStats.Kind.DAMAGE: 0,
	UnitStats.Kind.DEFENSE: 0,
	UnitStats.Kind.ATTACK_SPEED: 0,
	UnitStats.Kind.LUCK: 0,
}
static var _persistent_weapon_rarities: Dictionary = {}
static var _persistent_coins: int = 0
static var _persistent_slots_unlocked: int = 0
static var _persistent_equipped_weapon_id: StringName = &""

var coins: int = 0

var stat_upgrade_levels: Dictionary = {
	UnitStats.Kind.MAX_HEALTH: 0,
	UnitStats.Kind.DAMAGE: 0,
	UnitStats.Kind.DEFENSE: 0,
	UnitStats.Kind.ATTACK_SPEED: 0,
	UnitStats.Kind.LUCK: 0,
}
# StringName(weapon.id) -> int rarity (0..4)
var weapon_rarity_levels: Dictionary = {}
var slots_unlocked: int = 0
var run_slots_granted: int = 0
var _stat_loadout_base: Dictionary = {}

var _is_animating: bool = false
var _has_buffered_direction: bool = false
var _buffered_direction: Vector2i = Vector2i.ZERO
var _input_enabled: bool = true


func set_input_enabled(enabled: bool) -> void:
	_input_enabled = enabled
	if not enabled:
		_has_buffered_direction = false
		_buffered_direction = Vector2i.ZERO


func _ready() -> void:
	var cfg := _ensure_loadout()
	if cfg != null:
		base_max_health = cfg.max_health
		base_damage = cfg.damage
		base_defense = cfg.defense
		base_attack_speed = cfg.attack_speed
		base_crit_chance = cfg.crit_chance
	super._ready()
	z_as_relative = false
	z_index = 100
	inventory.configure(cfg.inventory if cfg != null else null)
	_stat_loadout_base = {
		UnitStats.Kind.MAX_HEALTH: stats.get_base(UnitStats.Kind.MAX_HEALTH),
		UnitStats.Kind.DAMAGE: stats.get_base(UnitStats.Kind.DAMAGE),
		UnitStats.Kind.DEFENSE: stats.get_base(UnitStats.Kind.DEFENSE),
		UnitStats.Kind.ATTACK_SPEED: stats.get_base(UnitStats.Kind.ATTACK_SPEED),
		UnitStats.Kind.LUCK: stats.get_base(UnitStats.Kind.LUCK),
	}
	_seed_weapon_rarity_levels()
	_restore_persistent_progression()
	stats.current_health = stats.get_final_int(UnitStats.Kind.MAX_HEALTH)
	queue_redraw()


func _seed_weapon_rarity_levels() -> void:
	var loot_cfg := RewardGenerator.get_loot_config()
	if loot_cfg != null and loot_cfg.weapon_pool != null:
		for a in loot_cfg.weapon_pool.artifacts:
			if a is Artifact:
				weapon_rarity_levels[a.id] = 0
	for slot in inventory.get_slots():
		var artifact: Artifact = slot.get("artifact")
		if artifact == null:
			continue
		if slot.get("tag", StringName()) == &"weapon":
			weapon_rarity_levels[artifact.id] = int(slot.get("rarity", 0))


func _restore_persistent_progression() -> void:
	stat_upgrade_levels = _persistent_stat_levels.duplicate()
	for id in _persistent_weapon_rarities.keys():
		weapon_rarity_levels[id] = int(_persistent_weapon_rarities[id])
	coins = _persistent_coins
	if coins > 0:
		coins_changed.emit(coins)
	_apply_persistent_stat_upgrades()
	_reequip_persisted_weapon()
	slots_unlocked = _persistent_slots_unlocked
	for _i in range(slots_unlocked):
		_append_any_slot()
	if not stat_upgrade_levels.is_empty() or not _persistent_weapon_rarities.is_empty() or slots_unlocked > 0:
		upgrades_changed.emit()


func _append_any_slot() -> void:
	if inventory == null:
		return
	var cfg := SlotConfig.new()
	cfg.tag = Inventory.ANY_TAG
	cfg.display_name = ""
	inventory.add_slot(cfg)


func _apply_persistent_stat_upgrades() -> void:
	var config := _load_default_upgrade_config()
	if config == null:
		return
	for kind in stat_upgrade_levels.keys():
		var level: int = int(stat_upgrade_levels.get(kind, 0))
		if level <= 0:
			continue
		var stat_kind := kind as UnitStats.Kind
		var increment: float = config.stat_increment(kind)
		var base_value: float = float(_stat_loadout_base.get(kind, stats.get_base(stat_kind)))
		stats.set_base(stat_kind, base_value + increment * float(level))


func _reequip_persisted_weapon() -> void:
	var slot_index := _find_weapon_slot_index()
	if slot_index < 0:
		return
	var slot := inventory.get_slot(slot_index)
	var target_weapon: Artifact = null
	if _persistent_equipped_weapon_id != &"":
		target_weapon = _find_weapon_in_pool(_persistent_equipped_weapon_id)
	if target_weapon == null:
		target_weapon = slot.get("artifact")
	if target_weapon == null:
		return
	var desired_rarity: int = int(_persistent_weapon_rarities.get(target_weapon.id, -1))
	if desired_rarity < 0:
		desired_rarity = int(slot.get("rarity", 0))
	var current_artifact: Artifact = slot.get("artifact")
	var current_rarity: int = int(slot.get("rarity", -1))
	var same_weapon: bool = current_artifact != null and current_artifact.id == target_weapon.id
	if same_weapon and current_rarity == desired_rarity:
		return
	inventory.replace_in_slot(target_weapon, slot_index, desired_rarity)


func _find_weapon_in_pool(id: StringName) -> Artifact:
	var loot_cfg := RewardGenerator.get_loot_config()
	if loot_cfg == null or loot_cfg.weapon_pool == null:
		return null
	for a in loot_cfg.weapon_pool.artifacts:
		if a is Artifact and a.id == id:
			return a
	return null


func _load_default_upgrade_config() -> UpgradeConfig:
	if not ResourceLoader.exists(_DEFAULT_UPGRADE_CONFIG_PATH):
		return null
	return load(_DEFAULT_UPGRADE_CONFIG_PATH) as UpgradeConfig


static func reset_progression() -> void:
	_persistent_stat_levels = {
		UnitStats.Kind.MAX_HEALTH: 0,
		UnitStats.Kind.DAMAGE: 0,
		UnitStats.Kind.DEFENSE: 0,
		UnitStats.Kind.LUCK: 0,
	}
	_persistent_weapon_rarities = {}
	_persistent_coins = 0
	_persistent_slots_unlocked = 0
	_persistent_equipped_weapon_id = &""


func reset_to_base() -> void:
	var cfg := _ensure_loadout()
	if cfg == null:
		return
	inventory.configure(cfg.inventory)
	stats.set_base(UnitStats.Kind.MAX_HEALTH, float(cfg.max_health))
	stats.set_base(UnitStats.Kind.DAMAGE, float(cfg.damage))
	stats.set_base(UnitStats.Kind.DEFENSE, float(cfg.defense))
	stats.set_base(UnitStats.Kind.ATTACK_SPEED, cfg.attack_speed)
	stats.set_base(UnitStats.Kind.LUCK, 0.0)
	_stat_loadout_base = {
		UnitStats.Kind.MAX_HEALTH: float(cfg.max_health),
		UnitStats.Kind.DAMAGE: float(cfg.damage),
		UnitStats.Kind.DEFENSE: float(cfg.defense),
		UnitStats.Kind.LUCK: 0.0,
	}
	_apply_persistent_stat_upgrades()
	_reequip_persisted_weapon()
	run_slots_granted = 0
	for _i in range(slots_unlocked):
		_append_any_slot()
	stats.current_health = stats.get_final_int(UnitStats.Kind.MAX_HEALTH)
	stats.stats_changed.emit(stats)
	upgrades_changed.emit()


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
	_persistent_coins = coins
	coins_changed.emit(coins)


func spend_coins(amount: int) -> bool:
	if amount <= 0 or coins < amount:
		return false
	coins -= amount
	_persistent_coins = coins
	coins_changed.emit(coins)
	return true


func get_stat_upgrade_level(kind: int) -> int:
	return int(stat_upgrade_levels.get(kind, 0))


func apply_stat_upgrade(kind: int, config: UpgradeConfig) -> bool:
	if config == null or not stat_upgrade_levels.has(kind):
		return false
	var level: int = get_stat_upgrade_level(kind)
	var cost: int = config.stat_cost(kind, level)
	if cost <= 0 or not spend_coins(cost):
		return false
	stat_upgrade_levels[kind] = level + 1
	_persistent_stat_levels[kind] = level + 1
	var increment: float = config.stat_increment(kind)
	var stat_kind := kind as UnitStats.Kind
	var base_value: float = float(_stat_loadout_base.get(kind, stats.get_base(stat_kind)))
	var new_base: float = base_value + increment * float(level + 1)
	if stat_kind == UnitStats.Kind.MAX_HEALTH:
		var before := stats.get_final_int(UnitStats.Kind.MAX_HEALTH)
		stats.set_base(stat_kind, new_base)
		var after := stats.get_final_int(UnitStats.Kind.MAX_HEALTH)
		if after > before:
			stats.heal(after - before)
	else:
		stats.set_base(stat_kind, new_base)
	upgrades_changed.emit()
	return true


func get_weapon_rarity(weapon: Artifact) -> int:
	if weapon == null:
		return 0
	return int(weapon_rarity_levels.get(weapon.id, 0))


func get_slots_unlocked() -> int:
	return slots_unlocked


func apply_slot_unlock(config: UpgradeConfig) -> bool:
	if config == null:
		return false
	var cost: int = config.slot_unlock_cost(slots_unlocked)
	if cost <= 0:
		return false
	if not spend_coins(cost):
		return false
	_append_any_slot()
	slots_unlocked += 1
	_persistent_slots_unlocked = slots_unlocked
	upgrades_changed.emit()
	return true


func grant_run_slot() -> void:
	_append_any_slot()
	run_slots_granted += 1
	upgrades_changed.emit()


func apply_weapon_rarity_upgrade(weapon: Artifact, config: UpgradeConfig) -> bool:
	if weapon == null or config == null:
		return false
	var current: int = get_weapon_rarity(weapon)
	var cost: int = config.weapon_upgrade_cost(current)
	if cost <= 0:
		return false
	if not weapon.has_rarity(current + 1):
		return false
	if not spend_coins(cost):
		return false
	weapon_rarity_levels[weapon.id] = current + 1
	_persistent_weapon_rarities[weapon.id] = current + 1
	if _is_weapon_equipped(weapon):
		equip_weapon(weapon, current + 1)
	upgrades_changed.emit()
	return true


func equip_weapon(weapon: Artifact, rarity: int) -> bool:
	if weapon == null or inventory == null:
		return false
	var slot_index := _find_weapon_slot_index()
	if slot_index < 0:
		return false
	var ok := inventory.replace_in_slot(weapon, slot_index, rarity)
	if ok:
		_persistent_equipped_weapon_id = weapon.id
		upgrades_changed.emit()
	return ok


func get_equipped_weapon() -> Dictionary:
	var slot_index := _find_weapon_slot_index()
	if slot_index < 0:
		return {}
	return inventory.get_slot(slot_index)


func _find_weapon_slot_index() -> int:
	if inventory == null:
		return -1
	for i in range(inventory.slot_count()):
		var slot := inventory.get_slot(i)
		if slot.get("tag", StringName()) == &"weapon":
			return i
	return -1


func _is_weapon_equipped(weapon: Artifact) -> bool:
	if weapon == null:
		return false
	var slot := get_equipped_weapon()
	var equipped: Artifact = slot.get("artifact")
	return equipped != null and equipped.id == weapon.id


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
	if not _input_enabled or not is_alive() or grid == null:
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
		if destination.contents is Enemy:
			battle_requested.emit(target, destination.contents as Enemy)
			return
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


func advance_to(target: Vector2i) -> void:
	if grid == null or not grid.in_bounds(target):
		return
	if _is_animating:
		return
	var destination := grid.get_cell(target)
	if destination == null:
		return
	var from_coords := coords
	var from_cell := grid.get_cell(from_coords)
	if from_cell != null and from_cell.contents == self:
		from_cell.contents = null
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
	AudioManager.play_step()
	moved.emit(from_coords, to_coords)

	if _has_buffered_direction:
		var next := _buffered_direction
		_has_buffered_direction = false
		request_step(next)


func _draw() -> void:
	if loadout != null and loadout.map_icon != null:
		var tex := loadout.map_icon
		var size: float = float(grid.cell_size) if grid != null and grid.cell_size > 0 else maxf(tex.get_width(), tex.get_height())
		draw_texture_rect(tex, Rect2(-size * 0.5, -size * 0.5, size, size), false)
		return
	const radius := 10.0
	draw_circle(Vector2.ZERO, radius, body_color)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 24, Color.WHITE, 1.5)
