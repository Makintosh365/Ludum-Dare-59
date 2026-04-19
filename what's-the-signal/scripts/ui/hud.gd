class_name HUD
extends Control

const _QUICK_SLOT_COUNT := 4
const _WEAPON_TAG := &"weapon"
const _EMPTY_TEXT := "—"

var _player: Player = null


func _ready() -> void:
	_reset_labels()


func _exit_tree() -> void:
	_disconnect_player()


func bind_player(player: Player) -> void:
	if _player == player:
		return
	_disconnect_player()
	_player = player
	if _player == null:
		_reset_labels()
		return
	_player.stats_changed.connect(_on_stats_changed)
	_player.damaged.connect(_on_damaged)
	_player.coins_changed.connect(_on_coins_changed)
	_player.died.connect(_on_player_died)
	_player.inventory.inventory_changed.connect(_on_inventory_changed)
	_on_stats_changed(_player.stats)
	_on_coins_changed(_player.coins)
	_on_inventory_changed(_player.inventory.get_artifacts())


func set_enemy_count(count: int) -> void:
	var label := get_node_or_null("%EnemyCounter") as Label
	if label != null:
		label.text = "TAB  x%d" % maxi(0, count)


func set_boss_count(count: int) -> void:
	var label := get_node_or_null("%BossCounter") as Label
	if label != null:
		label.text = "BOSS  x%d" % maxi(0, count)


func _disconnect_player() -> void:
	if _player == null:
		return
	if not is_instance_valid(_player):
		_player = null
		return
	if _player.stats_changed.is_connected(_on_stats_changed):
		_player.stats_changed.disconnect(_on_stats_changed)
	if _player.damaged.is_connected(_on_damaged):
		_player.damaged.disconnect(_on_damaged)
	if _player.coins_changed.is_connected(_on_coins_changed):
		_player.coins_changed.disconnect(_on_coins_changed)
	if _player.died.is_connected(_on_player_died):
		_player.died.disconnect(_on_player_died)
	if _player.inventory != null and is_instance_valid(_player.inventory) and _player.inventory.inventory_changed.is_connected(_on_inventory_changed):
		_player.inventory.inventory_changed.disconnect(_on_inventory_changed)
	_player = null


func _reset_labels() -> void:
	_set_label("%HealthLabel", "HP " + _EMPTY_TEXT)
	_set_label("%CoinsLabel", "$ 0")
	_set_label("%DamageLabel", "ATK 0")
	_set_label("%DefenseLabel", "DEF 0")
	_set_label("%SpeedLabel", "SPD 0.0")
	_set_label("%EnemyCounter", "TAB  x0")
	_set_label("%BossCounter", "BOSS  x0")
	_clear_slot("%WeaponSlot")
	for i in range(_QUICK_SLOT_COUNT):
		_clear_slot("%QuickSlot%d" % (i + 1))


func _on_stats_changed(stats: UnitStats) -> void:
	if stats == null:
		return
	var max_hp := stats.get_final_int(UnitStats.Kind.MAX_HEALTH)
	_set_label("%HealthLabel", "HP %d/%d" % [stats.current_health, max_hp])
	_set_label("%DamageLabel", "ATK %d" % stats.get_final_int(UnitStats.Kind.DAMAGE))
	_set_label("%DefenseLabel", "DEF %d" % stats.get_final_int(UnitStats.Kind.DEFENSE))
	_set_label("%SpeedLabel", "SPD %.1f" % stats.get_final(UnitStats.Kind.ATTACK_SPEED))


func _on_damaged(_amount: int, _health_after: int) -> void:
	if _player != null:
		_on_stats_changed(_player.stats)


func _on_coins_changed(total: int) -> void:
	_set_label("%CoinsLabel", "$ %d" % total)


func _on_player_died() -> void:
	_set_label("%HealthLabel", "HP 0/0")


func _on_inventory_changed(_artifacts: Array) -> void:
	if _player == null or _player.inventory == null:
		return
	var slots := _player.inventory.get_slots()
	var quick_index := 0
	_clear_slot("%WeaponSlot")
	for i in range(_QUICK_SLOT_COUNT):
		_clear_slot("%QuickSlot%d" % (i + 1))
	for slot in slots:
		var tag: StringName = slot.get("tag", StringName())
		var artifact: Artifact = slot.get("artifact")
		var rarity: int = slot.get("rarity", -1)
		if tag == _WEAPON_TAG:
			_paint_slot("%WeaponSlot", artifact, rarity)
		elif tag == Inventory.ANY_TAG and quick_index < _QUICK_SLOT_COUNT:
			_paint_slot("%QuickSlot%d" % (quick_index + 1), artifact, rarity)
			quick_index += 1


func _paint_slot(node_path: String, artifact: Artifact, rarity: int) -> void:
	var slot_root := get_node_or_null(node_path)
	if slot_root == null:
		return
	var icon_rect := slot_root.find_child("Icon", true, false) as TextureRect
	var name_label := slot_root.find_child("Name", true, false) as Label
	if artifact == null:
		if icon_rect != null:
			icon_rect.texture = null
			icon_rect.visible = false
		if name_label != null:
			name_label.text = _EMPTY_TEXT
		return
	var variant := artifact.resolve_variant(rarity)
	var icon: Texture2D = variant.icon if variant != null else null
	if icon_rect != null:
		icon_rect.texture = icon
		icon_rect.visible = icon != null
	if name_label != null:
		name_label.text = artifact.display_name if artifact.display_name != "" else String(artifact.id)


func _clear_slot(node_path: String) -> void:
	_paint_slot(node_path, null, -1)


func _set_label(node_path: String, value: String) -> void:
	var label := get_node_or_null(node_path) as Label
	if label != null:
		label.text = value
