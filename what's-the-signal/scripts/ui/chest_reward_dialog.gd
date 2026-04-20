class_name RewardChoiceDialog
extends CanvasLayer

signal item_selected(index: int)
signal skipped

const _TITLE := "Treasure Chest"
const _RARITY_COLORS := {
	0: Color(0.85, 0.85, 0.85),
	1: Color(0.45, 0.85, 0.45),
	2: Color(0.45, 0.65, 0.95),
	3: Color(0.75, 0.45, 0.95),
	4: Color(0.95, 0.75, 0.25),
}

var _inventory: Inventory = null


func set_options(reward: Dictionary, inventory: Inventory) -> void:
	_inventory = inventory
	AudioManager.register_buttons(self)
	var items: Array = reward.get("items", [])

	var title := get_node_or_null("%Title") as Label
	if title != null:
		title.text = _TITLE

	var coins_label := get_node_or_null("%CoinsLabel") as Label
	if coins_label != null:
		var coins: int = int(reward.get("coins", 0))
		coins_label.text = "+ %d coins" % coins
		coins_label.visible = coins > 0

	_clear_slots()
	var slots_container := get_node_or_null("%Slots") as HBoxContainer
	if slots_container == null:
		return

	for i in range(items.size()):
		var slot := _build_slot(i, items[i])
		slots_container.add_child(slot)

	_configure_skip_button()

	visible = true


func _configure_skip_button() -> void:
	var skip_button := get_node_or_null("%SkipButton") as Button
	if skip_button == null:
		return
	var cfg := RewardGenerator.get_loot_config()
	if cfg != null:
		var lo: int = maxi(0, cfg.skip_coins_min)
		var hi: int = maxi(lo, cfg.skip_coins_max)
		if lo == hi:
			skip_button.text = "Skip (+%d coins)" % lo
		else:
			skip_button.text = "Skip (+%d-%d coins)" % [lo, hi]
	else:
		skip_button.text = "Skip"
	if not skip_button.pressed.is_connected(_on_skip_pressed):
		skip_button.pressed.connect(_on_skip_pressed)


func _clear_slots() -> void:
	var slots_container := get_node_or_null("%Slots") as HBoxContainer
	if slots_container == null:
		return
	for child in slots_container.get_children():
		child.queue_free()


func _build_slot(index: int, item: Dictionary) -> Control:
	var artifact: Artifact = item.get("artifact")
	var rarity: int = int(item.get("rarity", -1))
	var has_compatible_slot: bool = _inventory != null \
		and artifact != null \
		and not _inventory.find_compatible_slot_indices(artifact).is_empty()

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(140, 200)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.1, 0.08, 0.95)
	style.border_color = _RARITY_COLORS.get(rarity, Color.WHITE) if has_compatible_slot else Color(0.5, 0.2, 0.2)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	panel.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	var icon_rect := TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(96, 96)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if artifact != null:
		var variant := artifact.resolve_variant(rarity)
		if variant != null and variant.icon != null:
			icon_rect.texture = variant.icon
	vbox.add_child(icon_rect)

	var name_label := Label.new()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	name_label.text = item.get("display_name", "?")
	vbox.add_child(name_label)

	if artifact != null:
		var variant := artifact.resolve_variant(rarity)
		if variant != null:
			for ability in variant.abilities:
				if ability == null:
					continue
				var ability_label := Label.new()
				ability_label.text = ability.display_name if ability.display_name != "" else Ability.kind_name(ability.kind)
				ability_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				ability_label.add_theme_font_size_override("font_size", 11)
				ability_label.modulate = Color(0.7, 0.9, 1.0)
				vbox.add_child(ability_label)

	var pick_button := Button.new()
	pick_button.text = "Pick" if has_compatible_slot else "No slot"
	pick_button.disabled = not has_compatible_slot
	pick_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if has_compatible_slot:
		pick_button.pressed.connect(_on_pick_pressed.bind(index))
	AudioManager.wire_button(pick_button)
	vbox.add_child(pick_button)

	return panel


func _on_pick_pressed(index: int) -> void:
	AudioManager.play_reward()
	item_selected.emit(index)


func _on_skip_pressed() -> void:
	AudioManager.play_reward()
	skipped.emit()
