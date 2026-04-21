class_name UpgradeShopScreen
extends CanvasLayer

signal closed

@export var upgrade_config: UpgradeConfig

const _DEFAULT_CONFIG_PATH := "res://configs/default_upgrade.tres"
const _WEAPON_ROW_SCENE := preload("res://scenes/ui/weapon_row.tscn")

const _RARITY_COLORS := {
	0: Color(0.85, 0.85, 0.85),
	1: Color(0.45, 0.85, 0.45),
	2: Color(0.45, 0.65, 0.95),
	3: Color(0.75, 0.45, 0.95),
	4: Color(0.95, 0.75, 0.25),
}

const _RARITY_NAMES := {
	0: "Common",
	1: "Uncommon",
	2: "Rare",
	3: "Epic",
	4: "Legendary",
}

const _PANEL_HP := Color(0.2196, 1.0, 0.6549)
const _PANEL_DAMAGE := Color(0.8863, 0.3373, 0.3333)
const _PANEL_ARMOR := Color(0.4392, 0.9137, 1.0)
const _PANEL_LUCK := Color(0.7255, 0.4588, 1.0)
const _PANEL_SPEED := Color(1.0, 0.7137, 0.0)
const _PANEL_SLOT := Color(0.25, 0.95, 0.75)

const _ICON_HEALTH := preload("res://assets/Hud/MainIcon/IconHealth.png")
const _ICON_DAMAGE := preload("res://assets/Hud/MainIcon/IconAttack.png")
const _ICON_ARMOR := preload("res://assets/Hud/MainIcon/IcnoShild.png")
const _ICON_LUCK := preload("res://assets/Hud/MainIcon/IcnoLuck.png")
const _ICON_SPEED := preload("res://assets/Hud/MainIcon/IconSpeed.png")
const _ICON_GOLD := preload("res://assets/Hud/MainIcon/IconGold.png")
const _ICON_SLOT := preload("res://assets/Hud/MainIcon/IconArtefactAdd.png")

const _KIND_MAX_HEALTH := 0
const _KIND_DAMAGE := 1
const _KIND_DEFENSE := 2
const _KIND_ATTACK_SPEED := 3
const _KIND_LUCK := 4

@onready var _hp_card: StatCard = %HPCard
@onready var _damage_card: StatCard = %DamageCard
@onready var _armor_card: StatCard = %ArmorCard
@onready var _luck_card: StatCard = %LuckCard
@onready var _speed_card: StatCard = %SpeedCard
@onready var _slot_card: StatCard = %SlotCard
@onready var _weapons_list: VBoxContainer = %WeaponsList
@onready var _equipped_icon: TextureRect = %EquippedIcon
@onready var _gold_label: Label = %GoldLabel
@onready var _to_battle_button: Button = %ToBattleButton

var _player: Player = null
var _config: UpgradeConfig = null
var _weapon_artifacts: Array = []
var _stat_cards_order: Array = []


func _ready() -> void:
	_configure_stat_card(_hp_card, "HP", _ICON_HEALTH, _PANEL_HP, _KIND_MAX_HEALTH)
	_configure_stat_card(_damage_card, "Damage", _ICON_DAMAGE, _PANEL_DAMAGE, _KIND_DAMAGE)
	_configure_stat_card(_armor_card, "Armor", _ICON_ARMOR, _PANEL_ARMOR, _KIND_DEFENSE)
	_configure_stat_card(_luck_card, "Luck", _ICON_LUCK, _PANEL_LUCK, _KIND_LUCK)
	_configure_stat_card(_speed_card, "Speed", _ICON_SPEED, _PANEL_SPEED, _KIND_ATTACK_SPEED)
	_configure_slot_card(_slot_card)

	_stat_cards_order = [
		{"card": _hp_card, "kind": _KIND_MAX_HEALTH},
		{"card": _damage_card, "kind": _KIND_DAMAGE},
		{"card": _armor_card, "kind": _KIND_DEFENSE},
		{"card": _luck_card, "kind": _KIND_LUCK},
		{"card": _speed_card, "kind": _KIND_ATTACK_SPEED},
	]

	_to_battle_button.pressed.connect(_on_to_battle_pressed)
	AudioManager.wire_button(_to_battle_button)
	AudioManager.register_buttons(self)


func bind(player: Player, config: UpgradeConfig = null) -> void:
	_player = player
	_config = config
	if _config == null:
		_config = upgrade_config
	if _config == null and ResourceLoader.exists(_DEFAULT_CONFIG_PATH):
		_config = load(_DEFAULT_CONFIG_PATH) as UpgradeConfig
	if _config == null:
		_config = UpgradeConfig.new()

	_collect_weapons()
	_build_weapon_rows()

	if _player != null:
		if not _player.coins_changed.is_connected(_on_player_changed_int):
			_player.coins_changed.connect(_on_player_changed_int)
		if not _player.upgrades_changed.is_connected(_refresh):
			_player.upgrades_changed.connect(_refresh)
		if _player.stats != null and not _player.stats.stats_changed.is_connected(_on_stats_changed):
			_player.stats.stats_changed.connect(_on_stats_changed)
	_refresh()


func _exit_tree() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	if _player.coins_changed.is_connected(_on_player_changed_int):
		_player.coins_changed.disconnect(_on_player_changed_int)
	if _player.upgrades_changed.is_connected(_refresh):
		_player.upgrades_changed.disconnect(_refresh)
	if _player.stats != null and _player.stats.stats_changed.is_connected(_on_stats_changed):
		_player.stats.stats_changed.disconnect(_on_stats_changed)


func _on_player_changed_int(_total: int) -> void:
	_refresh()


func _on_stats_changed(_stats: UnitStats) -> void:
	_refresh()


func _collect_weapons() -> void:
	_weapon_artifacts.clear()
	var loot_cfg := RewardGenerator.get_loot_config()
	if loot_cfg == null or loot_cfg.weapon_pool == null:
		return
	for a in loot_cfg.weapon_pool.artifacts:
		if a is Artifact:
			_weapon_artifacts.append(a)


func _configure_stat_card(card: StatCard, title: String, icon: Texture2D, border: Color, kind: int) -> void:
	_apply_card_visuals(card, title, icon, border)
	card.cost_button.pressed.connect(_on_stat_upgrade_pressed.bind(kind))
	AudioManager.wire_button(card.cost_button)


func _configure_slot_card(card: StatCard) -> void:
	_apply_card_visuals(card, "Artifact Slot", _ICON_SLOT, _PANEL_SLOT)
	card.cost_button.pressed.connect(_on_slot_unlock_pressed)
	AudioManager.wire_button(card.cost_button)


func _apply_card_visuals(card: StatCard, title: String, icon: Texture2D, border: Color) -> void:
	card.title_label.text = title
	card.title_label.add_theme_color_override("font_color", border)
	card.value_label.add_theme_color_override("font_color", border)
	card.icon_rect.texture = icon
	card.set_border_color(border)
	card.cost_button.icon = _ICON_GOLD


func _build_weapon_rows() -> void:
	if _weapons_list == null:
		return
	for child in _weapons_list.get_children():
		child.queue_free()
	for weapon in _weapon_artifacts:
		_make_weapon_row(weapon)


func _make_weapon_row(weapon: Artifact) -> WeaponRow:
	var row: WeaponRow = _WEAPON_ROW_SCENE.instantiate()
	row.weapon_id = weapon.id
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.mouse_entered.connect(_on_weapon_row_hovered.bind(weapon, row))
	row.mouse_exited.connect(_on_weapon_row_unhovered)
	row.tree_exiting.connect(_on_weapon_row_unhovered)
	_weapons_list.add_child(row)
	row.icon_button.pressed.connect(_on_weapon_equip_pressed.bind(weapon))
	row.upgrade_button.pressed.connect(_on_weapon_upgrade_pressed.bind(weapon))
	AudioManager.wire_button(row.icon_button)
	AudioManager.wire_button(row.upgrade_button)
	return row


func _refresh() -> void:
	if _player == null or _config == null:
		return
	if _gold_label != null:
		_gold_label.text = "%d" % _player.coins
	_refresh_stat_cards()
	_refresh_slot_card()
	_refresh_weapon_rows()
	_refresh_equipped_preview()


func _refresh_stat_cards() -> void:
	for entry in _stat_cards_order:
		var card: StatCard = entry["card"]
		var kind: int = entry["kind"]
		var stat_kind := kind as UnitStats.Kind
		var level: int = _player.get_stat_upgrade_level(kind)
		var current: float = _player.stats.get_final(stat_kind)
		var increment: float = _config.stat_increment(kind)
		var next_value: float = current + increment
		var cost: int = _config.stat_cost(kind, level)
		card.value_label.text = "%s -> %s" % [_format_stat_value(kind, current), _format_stat_value(kind, next_value)]
		card.cost_button.text = "%d" % cost
		card.cost_button.icon = _ICON_GOLD
		card.cost_button.disabled = _player.coins < cost


func _format_stat_value(kind: int, value: float) -> String:
	if kind == _KIND_ATTACK_SPEED:
		return "%.1f" % value
	return "%d" % int(value)


func _refresh_slot_card() -> void:
	var any_count: int = 0
	for slot in _player.inventory.get_slots():
		if slot.get("tag") == Inventory.ANY_TAG:
			any_count += 1
	var purchased: int = _player.get_slots_unlocked()
	var cost: int = _config.slot_unlock_cost(purchased)
	if cost <= 0 or purchased >= _config.max_slot_unlocks():
		_slot_card.value_label.text = "%d" % any_count
		_slot_card.cost_button.text = "Max"
		_slot_card.cost_button.icon = null
		_slot_card.cost_button.disabled = true
	else:
		_slot_card.value_label.text = "%d -> %d" % [any_count, any_count + 1]
		_slot_card.cost_button.text = "%d" % cost
		_slot_card.cost_button.icon = _ICON_GOLD
		_slot_card.cost_button.disabled = _player.coins < cost


func _refresh_weapon_rows() -> void:
	if _weapons_list == null:
		return
	var equipped_id: StringName = _equipped_weapon_id()
	for row in _weapons_list.get_children():
		if not (row is WeaponRow):
			continue
		var weapon_row := row as WeaponRow
		var weapon := _find_weapon_by_id(weapon_row.weapon_id)
		if weapon == null:
			continue
		var rarity: int = _player.get_weapon_rarity(weapon)
		weapon_row.set_border_color(_RARITY_COLORS.get(rarity, Color.WHITE))

		var variant := weapon.resolve_variant(rarity)
		var texture: Texture2D = variant.icon if variant != null else null
		weapon_row.icon_button.icon = texture
		weapon_row.icon_button.disabled = (weapon_row.weapon_id == equipped_id)
		weapon_row.name_label.text = weapon.short_label()
		weapon_row.rarity_label.text = _RARITY_NAMES.get(rarity, "?")
		weapon_row.rarity_label.add_theme_color_override("font_color", _RARITY_COLORS.get(rarity, Color.WHITE))

		var cost: int = _config.weapon_upgrade_cost(rarity)
		if cost < 0 or not weapon.has_rarity(rarity + 1):
			weapon_row.upgrade_button.disabled = true
			weapon_row.upgrade_button.text = "Max"
		else:
			weapon_row.upgrade_button.disabled = _player.coins < cost
			weapon_row.upgrade_button.text = "Upgrade (%d)" % cost


func _refresh_equipped_preview() -> void:
	if _equipped_icon == null:
		return
	var slot := _player.get_equipped_weapon()
	var weapon: Artifact = slot.get("artifact")
	if weapon == null:
		_equipped_icon.texture = null
		return
	var rarity: int = int(slot.get("rarity", 0))
	var variant := weapon.resolve_variant(rarity)
	_equipped_icon.texture = variant.icon if variant != null else null


func _equipped_weapon_id() -> StringName:
	var slot := _player.get_equipped_weapon()
	var weapon: Artifact = slot.get("artifact")
	if weapon == null:
		return StringName()
	return weapon.id


func _find_weapon_by_id(id: StringName) -> Artifact:
	for weapon in _weapon_artifacts:
		if weapon.id == id:
			return weapon
	return null


func _on_stat_upgrade_pressed(kind: int) -> void:
	if _player == null or _config == null:
		return
	_player.apply_stat_upgrade(kind, _config)


func _on_slot_unlock_pressed() -> void:
	if _player == null or _config == null:
		return
	_player.apply_slot_unlock(_config)


func _on_weapon_upgrade_pressed(weapon: Artifact) -> void:
	if _player == null or _config == null:
		return
	_player.apply_weapon_rarity_upgrade(weapon, _config)


func _on_weapon_equip_pressed(weapon: Artifact) -> void:
	if _player == null:
		return
	var rarity := _player.get_weapon_rarity(weapon)
	_player.equip_weapon(weapon, rarity)


func _on_to_battle_pressed() -> void:
	closed.emit()


func _on_weapon_row_hovered(weapon: Artifact, row: Control) -> void:
	if weapon == null:
		return
	var rarity: int = _player.get_weapon_rarity(weapon) if _player != null else -1
	var anchor_rect := row.get_global_rect() if row != null and is_instance_valid(row) else Rect2()
	ArtifactTooltip.show_for(weapon, rarity, "", anchor_rect)


func _on_weapon_row_unhovered() -> void:
	ArtifactTooltip.hide_tooltip()
