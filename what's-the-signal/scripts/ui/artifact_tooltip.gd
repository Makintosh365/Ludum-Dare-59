extends CanvasLayer

const _RARITY_COLORS := {
	0: Color(0.85, 0.85, 0.85),
	1: Color(0.45, 0.85, 0.45),
	2: Color(0.45, 0.65, 0.95),
	3: Color(0.75, 0.45, 0.95),
	4: Color(0.95, 0.75, 0.25),
}

const _STAT_NAMES := {
	UnitStats.Kind.MAX_HEALTH: "HP",
	UnitStats.Kind.DAMAGE: "DMG",
	UnitStats.Kind.DEFENSE: "DEF",
	UnitStats.Kind.ATTACK_SPEED: "ATK SPD",
	UnitStats.Kind.LUCK: "LUCK",
}

const _STAT_ICONS := {
	UnitStats.Kind.MAX_HEALTH: preload("res://assets/Hud/MainIcon/IconHealth.png"),
	UnitStats.Kind.DAMAGE: preload("res://assets/Hud/MainIcon/IconAttack.png"),
	UnitStats.Kind.DEFENSE: preload("res://assets/Hud/MainIcon/IcnoShild.png"),
	UnitStats.Kind.ATTACK_SPEED: preload("res://assets/Hud/MainIcon/IconSpeed.png"),
	UnitStats.Kind.LUCK: preload("res://assets/Hud/MainIcon/IconGold.png"),
}

const _STAT_COLORS := {
	UnitStats.Kind.MAX_HEALTH: Color(0.2196, 1.0, 0.6549),
	UnitStats.Kind.DAMAGE: Color(0.8863, 0.3373, 0.3333),
	UnitStats.Kind.DEFENSE: Color(0.4392, 0.9137, 1.0),
	UnitStats.Kind.ATTACK_SPEED: Color(1.0, 0.7137, 0.0),
	UnitStats.Kind.LUCK: Color(0.7255, 0.4588, 1.0),
}

const _ABILITY_NUMBER_COLOR := "#ffd24a"

const _ABILITY_NAME_DEFAULT := Color(0.7, 0.9, 1.0)
const _ABILITY_COLORS := {
	Ability.Kind.LIFESTEAL: Color(0.95, 0.45, 0.6),
	Ability.Kind.THORNS: Color(0.6, 0.85, 0.45),
	Ability.Kind.CRIT_CHANCE: Color(1.0, 0.75, 0.2),
	Ability.Kind.FIRST_STRIKE: Color(1.0, 0.85, 0.35),
	Ability.Kind.REGEN: Color(0.4, 0.95, 0.6),
	Ability.Kind.ARMOR_PIERCE: Color(0.85, 0.7, 0.95),
	Ability.Kind.EVASION: Color(0.55, 0.85, 0.95),
	Ability.Kind.EXECUTE: Color(0.95, 0.35, 0.35),
	Ability.Kind.BERSERK: Color(1.0, 0.5, 0.25),
	Ability.Kind.SHIELD: Color(0.55, 0.75, 1.0),
	Ability.Kind.LAST_STAND: Color(1.0, 0.95, 0.55),
}

var _panel: PanelContainer = null
var _vbox: VBoxContainer = null
var _style: StyleBoxFlat = null
var _anchor_rect: Rect2 = Rect2()


func _ready() -> void:
	layer = 128
	_panel = PanelContainer.new()
	_panel.visible = false
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.custom_minimum_size = Vector2(0, 0)
	_panel.top_level = true
	_style = StyleBoxFlat.new()
	_style.bg_color = Color("001a12", 0.97)
	_style.border_width_left = 2
	_style.border_width_right = 2
	_style.border_width_top = 2
	_style.border_width_bottom = 2
	_style.corner_radius_top_left = 4
	_style.corner_radius_top_right = 4
	_style.corner_radius_bottom_left = 4
	_style.corner_radius_bottom_right = 4
	_style.content_margin_left = 14
	_style.content_margin_right = 14
	_style.content_margin_top = 12
	_style.content_margin_bottom = 12
	_panel.add_theme_stylebox_override("panel", _style)
	add_child(_panel)


func show_for(artifact: Artifact, rarity: int = -1, display_name: String = "", anchor_rect: Rect2 = Rect2()) -> void:
	if artifact == null or _panel == null:
		return
	var variant := artifact.resolve_variant(rarity)
	var name_text: String = display_name if display_name != "" else artifact.display_name
	if name_text == "":
		name_text = String(artifact.id)
	_anchor_rect = anchor_rect
	_build_content(artifact, variant, rarity, name_text)
	_style.border_color = _RARITY_COLORS.get(rarity, Color.WHITE)
	_panel.visible = true
	_panel.size = Vector2.ZERO
	_panel.reset_size()
	_update_position()
	_shrink_to_content()


func _shrink_to_content() -> void:
	await get_tree().process_frame
	if _panel == null or not _panel.visible:
		return
	_panel.size = Vector2.ZERO
	_panel.reset_size()
	_update_position()


func show_item(item: Dictionary, anchor_rect: Rect2 = Rect2()) -> void:
	var artifact: Artifact = item.get("artifact")
	if artifact == null:
		return
	var rarity: int = int(item.get("rarity", -1))
	var display_name: String = item.get("display_name", "")
	show_for(artifact, rarity, display_name, anchor_rect)


func hide_tooltip() -> void:
	if _panel != null:
		_panel.visible = false


func _update_position() -> void:
	if _panel == null:
		return
	var viewport := get_viewport()
	if viewport == null:
		return
	var screen_size: Vector2 = viewport.get_visible_rect().size
	var size := _panel.size
	var pos: Vector2
	if _anchor_rect.size != Vector2.ZERO:
		var center := _anchor_rect.position + _anchor_rect.size * 0.5
		pos = Vector2(center.x - size.x * 0.5, _anchor_rect.position.y + _anchor_rect.size.y + 8)
		if pos.y + size.y + 4 > screen_size.y:
			pos.y = _anchor_rect.position.y - size.y - 8
	else:
		var mouse_pos := viewport.get_mouse_position()
		pos = mouse_pos + Vector2(16, 16)
		if pos.x + size.x + 4 > screen_size.x:
			pos.x = mouse_pos.x - size.x - 16
		if pos.y + size.y + 4 > screen_size.y:
			pos.y = mouse_pos.y - size.y - 16
	pos.x = clampf(pos.x, 4.0, maxf(4.0, screen_size.x - size.x - 4.0))
	pos.y = clampf(pos.y, 4.0, maxf(4.0, screen_size.y - size.y - 4.0))
	_panel.position = pos


func _build_content(artifact: Artifact, variant: ArtifactVariant, rarity: int, name_text: String) -> void:
	if _vbox != null and is_instance_valid(_vbox):
		_panel.remove_child(_vbox)
		_vbox.queue_free()
	_vbox = VBoxContainer.new()
	_vbox.add_theme_constant_override("separation", 6)
	_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_vbox)

	var name_label := Label.new()
	name_label.text = name_text
	name_label.add_theme_font_size_override("font_size", 28)
	name_label.modulate = _RARITY_COLORS.get(rarity, Color.WHITE)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vbox.add_child(name_label)

	if variant != null and not variant.modifiers.is_empty():
		_vbox.add_child(_make_separator())
		_vbox.add_child(_make_header("Stats", Color(1.0, 0.9, 0.55)))
		for modifier in variant.modifiers:
			if modifier == null:
				continue
			_vbox.add_child(_make_stat_row(modifier))

	if variant != null and not variant.abilities.is_empty():
		_vbox.add_child(_make_separator())
		_vbox.add_child(_make_header("Abilities", Color(0.7, 0.9, 1.0)))
		for ability in variant.abilities:
			if ability == null:
				continue
			var abil_name := Label.new()
			abil_name.text = ability.display_name if ability.display_name != "" else Ability.kind_name(ability.kind)
			abil_name.add_theme_font_size_override("font_size", 22)
			abil_name.add_theme_color_override("font_color", _ABILITY_COLORS.get(ability.kind, _ABILITY_NAME_DEFAULT))
			abil_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_vbox.add_child(abil_name)
			var abil_desc_text: String = Ability.format_description(ability.kind, ability.value)
			if abil_desc_text != "":
				var abil_desc := RichTextLabel.new()
				abil_desc.bbcode_enabled = true
				abil_desc.fit_content = true
				abil_desc.scroll_active = false
				abil_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				abil_desc.custom_minimum_size = Vector2(280, 0)
				abil_desc.add_theme_font_size_override("normal_font_size", 18)
				abil_desc.add_theme_color_override("default_color", Color(0.75, 0.85, 0.75))
				abil_desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
				abil_desc.text = _colorize_numbers(abil_desc_text, _ABILITY_NUMBER_COLOR)
				_vbox.add_child(abil_desc)


func _make_separator() -> Control:
	var sep := HSeparator.new()
	sep.modulate = Color(1, 1, 1, 0.25)
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return sep


func _make_header(text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 22)
	label.modulate = color
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _make_stat_row(modifier: StatModifier) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var icon_texture: Texture2D = _STAT_ICONS.get(modifier.kind, null)
	if icon_texture != null:
		var icon_rect := TextureRect.new()
		icon_rect.texture = icon_texture
		icon_rect.custom_minimum_size = Vector2(26, 26)
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon_rect)

	var stat_label := Label.new()
	stat_label.text = _format_modifier(modifier)
	stat_label.add_theme_font_size_override("font_size", 22)
	stat_label.add_theme_color_override("font_color", _STAT_COLORS.get(modifier.kind, Color(0.8, 0.95, 0.8)))
	stat_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stat_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(stat_label)
	return row


func _colorize_numbers(text: String, hex: String) -> String:
	var regex := RegEx.new()
	regex.compile("\\d+(?:\\.\\d+)?%?")
	var result := ""
	var cursor := 0
	for m in regex.search_all(text):
		var start: int = m.get_start()
		var end: int = m.get_end()
		if start > cursor:
			result += text.substr(cursor, start - cursor)
		result += "[color=%s]%s[/color]" % [hex, text.substr(start, end - start)]
		cursor = end
	if cursor < text.length():
		result += text.substr(cursor, text.length() - cursor)
	return result


func _format_modifier(modifier: StatModifier) -> String:
	var stat_name: String = _STAT_NAMES.get(modifier.kind, "STAT")
	var value := modifier.value
	var sign_str := "+" if value >= 0.0 else ""
	var suffix := "%" if modifier.op == UnitStats.Op.PERCENT else ""
	var value_str: String
	if value == floor(value):
		value_str = "%d" % int(value)
	else:
		value_str = "%.1f" % value
	return "%s%s%s %s" % [sign_str, value_str, suffix, stat_name]
