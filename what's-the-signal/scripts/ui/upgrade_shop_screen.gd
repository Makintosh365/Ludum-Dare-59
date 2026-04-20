class_name UpgradeShopScreen
extends CanvasLayer

signal closed

@export var upgrade_config: UpgradeConfig

const _DEFAULT_CONFIG_PATH := "res://configs/default_upgrade.tres"

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

const _PANEL_GOLD := Color(0.95, 0.85, 0.25)
const _PANEL_HP := Color(0.45, 0.85, 0.45)
const _PANEL_DAMAGE := Color(0.95, 0.35, 0.35)
const _PANEL_ARMOR := Color(0.45, 0.75, 0.95)
const _PANEL_LUCK := Color(0.75, 0.45, 0.95)
const _PANEL_WEAPONS := Color(0.95, 0.45, 0.85)

const _ICON_HEALTH := preload("res://assets/Hud/MainIcon/IconHealth.png")
const _ICON_DAMAGE := preload("res://assets/Hud/MainIcon/IconAttack.png")
const _ICON_ARMOR := preload("res://assets/Hud/MainIcon/IcnoShild.png")
const _ICON_LUCK := preload("res://assets/Hud/MainIcon/IconSpeed.png")

const _KIND_MAX_HEALTH := 0
const _KIND_DAMAGE := 1
const _KIND_DEFENSE := 2
const _KIND_LUCK := 4

var _player: Player = null
var _config: UpgradeConfig = null
var _weapon_artifacts: Array = []

var _stat_cards: Dictionary = {}
var _gold_label: Label = null
var _stats_row: HBoxContainer = null
var _weapons_list: VBoxContainer = null
var _equipped_icon: TextureRect = null


func _ready() -> void:
	_build_layout()
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
	_build_stat_cards()
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


func _build_layout() -> void:
	var root := Control.new()
	root.name = "Root"
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	var dim := ColorRect.new()
	dim.anchor_right = 1.0
	dim.anchor_bottom = 1.0
	dim.color = Color(0, 0.05, 0, 0.92)
	root.add_child(dim)

	var margin := MarginContainer.new()
	margin.anchor_right = 1.0
	margin.anchor_bottom = 1.0
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	root.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)

	var gold_panel := PanelContainer.new()
	gold_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_style_panel(gold_panel, _PANEL_GOLD)
	vbox.add_child(gold_panel)

	var gold_margin := MarginContainer.new()
	gold_margin.add_theme_constant_override("margin_left", 14)
	gold_margin.add_theme_constant_override("margin_right", 14)
	gold_margin.add_theme_constant_override("margin_top", 8)
	gold_margin.add_theme_constant_override("margin_bottom", 8)
	gold_panel.add_child(gold_margin)

	var gold_hbox := HBoxContainer.new()
	gold_hbox.add_theme_constant_override("separation", 8)
	gold_margin.add_child(gold_hbox)

	var gold_icon := ColorRect.new()
	gold_icon.custom_minimum_size = Vector2(24, 24)
	gold_icon.color = Color(0.95, 0.8, 0.2)
	gold_hbox.add_child(gold_icon)

	_gold_label = Label.new()
	_gold_label.text = "0"
	_gold_label.add_theme_font_size_override("font_size", 22)
	gold_hbox.add_child(_gold_label)

	var body := HBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	vbox.add_child(body)

	_stats_row = HBoxContainer.new()
	_stats_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stats_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_stats_row.add_theme_constant_override("separation", 12)
	body.add_child(_stats_row)

	var weapons_panel := PanelContainer.new()
	weapons_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_style_panel(weapons_panel, _PANEL_WEAPONS)
	body.add_child(weapons_panel)

	var weapons_margin := MarginContainer.new()
	weapons_margin.add_theme_constant_override("margin_left", 12)
	weapons_margin.add_theme_constant_override("margin_right", 12)
	weapons_margin.add_theme_constant_override("margin_top", 12)
	weapons_margin.add_theme_constant_override("margin_bottom", 12)
	weapons_panel.add_child(weapons_margin)

	var weapons_vbox := VBoxContainer.new()
	weapons_vbox.add_theme_constant_override("separation", 8)
	weapons_margin.add_child(weapons_vbox)

	_weapons_list = VBoxContainer.new()
	_weapons_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_weapons_list.add_theme_constant_override("separation", 6)
	weapons_vbox.add_child(_weapons_list)

	weapons_vbox.add_child(HSeparator.new())

	var equipped_row := HBoxContainer.new()
	equipped_row.add_theme_constant_override("separation", 8)
	weapons_vbox.add_child(equipped_row)

	var equipped_label := Label.new()
	equipped_label.text = "Equipped:"
	equipped_row.add_child(equipped_label)

	_equipped_icon = TextureRect.new()
	_equipped_icon.custom_minimum_size = Vector2(64, 64)
	_equipped_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_equipped_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	equipped_row.add_child(_equipped_icon)

	var bottom_row := HBoxContainer.new()
	bottom_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(bottom_row)

	var to_battle := Button.new()
	to_battle.text = "To Battle"
	to_battle.custom_minimum_size = Vector2(390, 90)
	to_battle.add_theme_font_size_override("font_size", 36)
	to_battle.pressed.connect(_on_to_battle_pressed)
	AudioManager.wire_button(to_battle)
	bottom_row.add_child(to_battle)


func _collect_weapons() -> void:
	_weapon_artifacts.clear()
	var loot_cfg := RewardGenerator.get_loot_config()
	if loot_cfg == null or loot_cfg.weapon_pool == null:
		return
	for a in loot_cfg.weapon_pool.artifacts:
		if a is Artifact:
			_weapon_artifacts.append(a)


func _build_stat_cards() -> void:
	if _stats_row == null:
		return
	for child in _stats_row.get_children():
		child.queue_free()
	_stat_cards.clear()
	_stat_cards[_KIND_MAX_HEALTH] = _make_stat_card(_stats_row, _KIND_MAX_HEALTH, "HP", _ICON_HEALTH, _PANEL_HP)
	_stat_cards[_KIND_DAMAGE] = _make_stat_card(_stats_row, _KIND_DAMAGE, "Damage", _ICON_DAMAGE, _PANEL_DAMAGE)
	_stat_cards[_KIND_DEFENSE] = _make_stat_card(_stats_row, _KIND_DEFENSE, "Armor", _ICON_ARMOR, _PANEL_ARMOR)
	_stat_cards[_KIND_LUCK] = _make_stat_card(_stats_row, _KIND_LUCK, "Luck", _ICON_LUCK, _PANEL_LUCK)


func _make_stat_card(parent: Control, kind: int, title: String, icon: Texture2D, border: Color) -> Dictionary:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(150, 240)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_style_panel(panel, border)
	parent.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	var title_label := Label.new()
	title_label.text = title
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(title_label)

	var icon_rect := TextureRect.new()
	icon_rect.texture = icon
	icon_rect.custom_minimum_size = Vector2(64, 64)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	vbox.add_child(icon_rect)

	var value_label := Label.new()
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(value_label)

	var cost_label := Label.new()
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_label.add_theme_font_size_override("font_size", 12)
	cost_label.modulate = Color(0.9, 0.85, 0.4)
	vbox.add_child(cost_label)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	var button := Button.new()
	button.text = "Upgrade"
	button.add_theme_color_override("font_color", border)
	button.pressed.connect(_on_stat_upgrade_pressed.bind(kind))
	AudioManager.wire_button(button)
	vbox.add_child(button)

	return {
		"panel": panel,
		"value": value_label,
		"cost": cost_label,
		"button": button,
	}


func _build_weapon_rows() -> void:
	if _weapons_list == null:
		return
	for child in _weapons_list.get_children():
		child.queue_free()
	for weapon in _weapon_artifacts:
		_weapons_list.add_child(_make_weapon_row(weapon))


func _make_weapon_row(weapon: Artifact) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(260, 76)
	panel.set_meta("weapon_id", weapon.id)
	_style_panel(panel, Color.WHITE)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	margin.add_child(hbox)

	var icon_button := Button.new()
	icon_button.custom_minimum_size = Vector2(84, 84)
	icon_button.expand_icon = true
	icon_button.set_meta("role", "icon_button")
	icon_button.pressed.connect(_on_weapon_equip_pressed.bind(weapon))
	AudioManager.wire_button(icon_button)
	hbox.add_child(icon_button)

	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info_vbox)

	var name_label := Label.new()
	var display_name: String = weapon.display_name if weapon.display_name != "" else String(weapon.id)
	name_label.text = display_name
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.set_meta("role", "name")
	info_vbox.add_child(name_label)

	var rarity_label := Label.new()
	rarity_label.add_theme_font_size_override("font_size", 11)
	rarity_label.set_meta("role", "rarity")
	info_vbox.add_child(rarity_label)

	var upgrade_button := Button.new()
	upgrade_button.text = "Upgrade"
	upgrade_button.set_meta("role", "upgrade")
	upgrade_button.pressed.connect(_on_weapon_upgrade_pressed.bind(weapon))
	AudioManager.wire_button(upgrade_button)
	hbox.add_child(upgrade_button)

	return panel


func _refresh() -> void:
	if _player == null or _config == null:
		return
	if _gold_label != null:
		_gold_label.text = "%d" % _player.coins
	_refresh_stat_cards()
	_refresh_weapon_rows()
	_refresh_equipped_preview()


func _refresh_stat_cards() -> void:
	for kind in _stat_cards.keys():
		var card: Dictionary = _stat_cards[kind]
		var level: int = _player.get_stat_upgrade_level(kind)
		var current: int = _player.stats.get_final_int(kind)
		var increment: int = _config.stat_increment(kind)
		var next_value: int = current + increment
		var cost: int = _config.stat_cost(kind, level)
		var value_label := card["value"] as Label
		var cost_label := card["cost"] as Label
		var button := card["button"] as Button
		value_label.text = "%d -> %d" % [current, next_value]
		cost_label.text = "Cost: %d" % cost
		button.disabled = _player.coins < cost


func _refresh_weapon_rows() -> void:
	if _weapons_list == null:
		return
	var equipped_id: StringName = _equipped_weapon_id()
	for row in _weapons_list.get_children():
		if not (row is PanelContainer):
			continue
		var panel := row as PanelContainer
		var weapon_id: StringName = panel.get_meta("weapon_id", StringName())
		var weapon := _find_weapon_by_id(weapon_id)
		if weapon == null:
			continue
		var rarity: int = _player.get_weapon_rarity(weapon)
		_style_panel(panel, _RARITY_COLORS.get(rarity, Color.WHITE))

		var icon_button := _find_child_by_role(panel, "icon_button") as Button
		var name_label := _find_child_by_role(panel, "name") as Label
		var rarity_label := _find_child_by_role(panel, "rarity") as Label
		var upgrade_button := _find_child_by_role(panel, "upgrade") as Button

		var variant := weapon.resolve_variant(rarity)
		var texture: Texture2D = variant.icon if variant != null else null
		if icon_button != null:
			icon_button.icon = texture
			icon_button.disabled = (weapon_id == equipped_id)
		if name_label != null:
			name_label.text = weapon.display_name if weapon.display_name != "" else String(weapon.id)
		if rarity_label != null:
			rarity_label.text = _RARITY_NAMES.get(rarity, "?")
			rarity_label.modulate = _RARITY_COLORS.get(rarity, Color.WHITE)
		if upgrade_button != null:
			var cost: int = _config.weapon_upgrade_cost(rarity)
			if cost < 0 or not weapon.has_rarity(rarity + 1):
				upgrade_button.disabled = true
				upgrade_button.text = "Max"
			else:
				upgrade_button.disabled = _player.coins < cost
				upgrade_button.text = "Upgrade (%d)" % cost


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


func _find_child_by_role(root: Node, role: String) -> Node:
	for child in root.get_children():
		if child.has_meta("role") and String(child.get_meta("role")) == role:
			return child
		var found := _find_child_by_role(child, role)
		if found != null:
			return found
	return null


func _style_panel(panel: PanelContainer, border: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.08, 0.92)
	style.border_color = border
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	panel.add_theme_stylebox_override("panel", style)


func _on_stat_upgrade_pressed(kind: int) -> void:
	if _player == null or _config == null:
		return
	_player.apply_stat_upgrade(kind, _config)


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
