class_name ChestRewardDialog
extends CanvasLayer

signal closed

const _TITLE := "Treasure Chest"
const _RARITY_COLORS := {
	0: Color(0.85, 0.85, 0.85),
	1: Color(0.45, 0.85, 0.45),
	2: Color(0.45, 0.65, 0.95),
	3: Color(0.75, 0.45, 0.95),
	4: Color(0.95, 0.75, 0.25),
}


func _ready() -> void:
	var close_button := get_node_or_null("%CloseButton") as Button
	if close_button != null:
		close_button.pressed.connect(_on_close_pressed)


func show_reward(reward: Dictionary) -> void:
	_clear_slots()
	var title := get_node_or_null("%Title") as Label
	if title != null:
		title.text = _TITLE

	var coins_label := get_node_or_null("%CoinsLabel") as Label
	if coins_label != null:
		var coins: int = int(reward.get("coins", 0))
		coins_label.text = "+ %d coins" % coins
		coins_label.visible = coins > 0

	var items: Array = reward.get("items", [])
	var slots_container := get_node_or_null("%Slots") as HBoxContainer
	if slots_container == null:
		return

	for item in items:
		var slot := _build_slot(item)
		slots_container.add_child(slot)

	visible = true


func _clear_slots() -> void:
	var slots_container := get_node_or_null("%Slots") as HBoxContainer
	if slots_container == null:
		return
	for child in slots_container.get_children():
		child.queue_free()


func _build_slot(item: Dictionary) -> Control:
	var artifact: Artifact = item.get("artifact")
	var rarity: int = int(item.get("rarity", -1))
	var placed: bool = item.get("placed", true)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(120, 140)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.1, 0.08, 0.95)
	style.border_color = _RARITY_COLORS.get(rarity, Color.WHITE) if placed else Color(0.5, 0.2, 0.2)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

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

	if not placed:
		var note := Label.new()
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		note.modulate = Color(1, 0.6, 0.6)
		note.text = "(slot full)"
		vbox.add_child(note)

	return panel


func _on_close_pressed() -> void:
	closed.emit()
	queue_free()
