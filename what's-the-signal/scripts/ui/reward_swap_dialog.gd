class_name RewardSwapDialog
extends CanvasLayer

signal confirmed(target_slot_index: int)
signal cancelled

const _RARITY_COLORS := {
	0: Color(0.85, 0.85, 0.85),
	1: Color(0.45, 0.85, 0.45),
	2: Color(0.45, 0.65, 0.95),
	3: Color(0.75, 0.45, 0.95),
	4: Color(0.95, 0.75, 0.25),
}

var _new_item: Dictionary = {}
var _inventory: Inventory = null
var _weapon_target: int = -1


func _ready() -> void:
	var cancel_button := get_node_or_null("%CancelButton") as Button
	if cancel_button != null:
		cancel_button.pressed.connect(_on_cancel_pressed)
	var confirm_button := get_node_or_null("%ConfirmButton") as Button
	if confirm_button != null:
		confirm_button.pressed.connect(_on_confirm_pressed)
	AudioManager.register_buttons(self)


func configure_weapon(new_item: Dictionary, inventory: Inventory) -> void:
	_new_item = new_item
	_inventory = inventory
	var artifact: Artifact = new_item.get("artifact")
	var targets := inventory.find_compatible_slot_indices(artifact) if inventory != null and artifact != null else ([] as Array[int])
	if targets.is_empty():
		_weapon_target = -1
	else:
		_weapon_target = targets[0]

	_set_title("Replace your weapon?")
	_clear_previews()
	var previews := _get_previews_container()
	if previews != null and _weapon_target >= 0:
		previews.add_child(_build_tile(_current_slot_item(_weapon_target), "Current", false))
		previews.add_child(_build_arrow())
		previews.add_child(_build_tile(new_item, "New", false))

	_set_confirm_visible(true)
	_set_message_visible(false)


func configure_artifact(new_item: Dictionary, inventory: Inventory) -> void:
	_new_item = new_item
	_inventory = inventory
	_weapon_target = -1

	_set_title("Replace which slot?")
	_clear_previews()
	var header := _get_previews_container()
	if header != null:
		header.add_child(_build_tile(new_item, "New", false))

	_set_message_visible(true)
	var msg := get_node_or_null("%Message") as Label
	if msg != null:
		msg.text = "Pick a slot to replace:"

	var slots_container := get_node_or_null("%Slots") as HBoxContainer
	if slots_container != null:
		for child in slots_container.get_children():
			child.queue_free()
		var artifact: Artifact = new_item.get("artifact")
		var targets: Array[int] = []
		if inventory != null and artifact != null:
			for i in inventory.find_compatible_slot_indices(artifact):
				var slot := inventory.get_slot(i)
				if not slot.is_empty() and slot.artifact != null:
					targets.append(i)
		for index in targets:
			var tile := _build_clickable_tile(_current_slot_item(index), index)
			slots_container.add_child(tile)

	_set_confirm_visible(false)


func _on_slot_picked(index: int) -> void:
	confirmed.emit(index)


func _on_confirm_pressed() -> void:
	if _weapon_target < 0:
		cancelled.emit()
		return
	confirmed.emit(_weapon_target)


func _on_cancel_pressed() -> void:
	cancelled.emit()


func _set_title(text: String) -> void:
	var title := get_node_or_null("%Title") as Label
	if title != null:
		title.text = text


func _set_message_visible(v: bool) -> void:
	var msg := get_node_or_null("%Message") as Label
	if msg != null:
		msg.visible = v


func _set_confirm_visible(v: bool) -> void:
	var confirm_button := get_node_or_null("%ConfirmButton") as Button
	if confirm_button != null:
		confirm_button.visible = v


func _clear_previews() -> void:
	var container := _get_previews_container()
	if container == null:
		return
	for child in container.get_children():
		child.queue_free()


func _get_previews_container() -> HBoxContainer:
	return get_node_or_null("%Previews") as HBoxContainer


func _current_slot_item(index: int) -> Dictionary:
	if _inventory == null:
		return {}
	var slot := _inventory.get_slot(index)
	if slot.is_empty() or slot.artifact == null:
		return {}
	var artifact: Artifact = slot.artifact
	return {
		"artifact": artifact,
		"rarity": int(slot.rarity),
		"display_name": artifact.display_name,
		"slot_tag": artifact.slot_tag,
	}


func _build_tile(item: Dictionary, caption: String, clickable: bool) -> Control:
	var artifact: Artifact = item.get("artifact") if not item.is_empty() else null
	var rarity: int = int(item.get("rarity", -1)) if not item.is_empty() else -1

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(120, 160)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.1, 0.08, 0.95)
	style.border_color = _RARITY_COLORS.get(rarity, Color.WHITE)
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
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)

	if caption != "":
		var caption_label := Label.new()
		caption_label.text = caption
		caption_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption_label.modulate = Color(0.8, 0.8, 0.8)
		vbox.add_child(caption_label)

	var icon_rect := TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(80, 80)
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
	name_label.text = item.get("display_name", "-") if not item.is_empty() else "-"
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

	return panel


func _build_clickable_tile(item: Dictionary, index: int) -> Control:
	var button := Button.new()
	button.flat = true
	button.custom_minimum_size = Vector2(180, 240)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.clip_contents = true

	var tile := _build_tile(item, "", false)
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ignore_mouse_recursive(tile)
	tile.anchor_right = 1.0
	tile.anchor_bottom = 1.0
	button.add_child(tile)

	button.pressed.connect(_on_slot_picked.bind(index))
	AudioManager.wire_button(button)
	return button


func _ignore_mouse_recursive(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_mouse_recursive(child)


func _build_arrow() -> Control:
	var label := Label.new()
	label.text = "→"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 32)
	label.custom_minimum_size = Vector2(40, 80)
	return label
