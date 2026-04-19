class_name BattleScreen
extends CanvasLayer

signal battle_finished(winner_index: int)

const _DEFAULT_CONFIG_PATH := "res://configs/default_battle.tres"
const _STAT_GLYPH_HP := "♥"
const _STAT_GLYPH_ATK := "/"
const _STAT_GLYPH_DEF := "▽"
const _STAT_GLYPH_SPD := "»"

@export var config: BattleConfig

var _log: BattleLog = null
var _event_index: int = 0
var _elapsed_in_event: float = 0.0
var _playing: bool = true
var _speed_index: int = 0
var _finished: bool = false
var _end_hold_remaining: float = 0.0
var _finish_emitted: bool = false

var _hp_current: Array[int] = [0, 0]

var _root: Control = null
var _arena_center: Control = null
var _unit_a: Dictionary = {}
var _unit_b: Dictionary = {}

var _pause_button: Button = null
var _speed_buttons: Array[Button] = []

var _inventory_weapon_view: Dictionary = {}
var _inventory_quick_views: Array[Dictionary] = []
var _enemy_title_label: Label = null
var _enemy_description_label: Label = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	_ensure_config()
	_build_ui()
	_speed_index = config.get_default_speed_index()
	if _log != null:
		_populate_units()
		_refresh_hp_labels()
	_refresh_controls_visual()


func setup(battle_log: BattleLog) -> void:
	_log = battle_log
	_event_index = 0
	_elapsed_in_event = 0.0
	_playing = true
	_finished = false
	_finish_emitted = false
	_end_hold_remaining = 0.0
	if _log == null:
		push_warning("BattleScreen: setup called with null log")
		return
	_hp_current = [
		int(_log.unit_a_snapshot.get("current_hp", 0)),
		int(_log.unit_b_snapshot.get("current_hp", 0)),
	]
	if is_inside_tree():
		_populate_units()
		_refresh_hp_labels()
		_refresh_controls_visual()


func _ensure_config() -> void:
	if config != null:
		return
	if ResourceLoader.exists(_DEFAULT_CONFIG_PATH):
		config = load(_DEFAULT_CONFIG_PATH) as BattleConfig
	if config == null:
		push_warning("BattleScreen: BattleConfig not set and default missing, using inline defaults")
		config = BattleConfig.new()


func _process(delta: float) -> void:
	if _log == null:
		return

	var speed: float = config.get_speed(_speed_index)

	if _finished:
		if _finish_emitted:
			return
		_end_hold_remaining = maxf(0.0, _end_hold_remaining - delta * speed)
		if _end_hold_remaining <= 0.0:
			_emit_finished()
		return

	if not _playing:
		return

	_elapsed_in_event += delta * speed

	while _playing and not _finished and _elapsed_in_event >= config.event_duration:
		_elapsed_in_event -= config.event_duration
		_advance_one_event()


func _advance_one_event() -> void:
	if _log == null or _event_index >= _log.events.size():
		return
	var event := _log.events[_event_index]
	_event_index += 1
	_apply_event(event)
	if event.kind == BattleEvent.Kind.END:
		_on_battle_end(event.winner_index)


func _apply_event(event: BattleEvent) -> void:
	match event.kind:
		BattleEvent.Kind.ATTACK:
			_on_attack_event(event)
		BattleEvent.Kind.DEATH:
			_on_death_event(event)
		BattleEvent.Kind.ABILITY:
			_on_ability_event(event)
		BattleEvent.Kind.END:
			pass


func _on_attack_event(event: BattleEvent) -> void:
	if event.target_index < 0 or event.target_index > 1:
		return
	_hp_current[event.target_index] = event.target_hp_after
	_refresh_hp_labels()
	_flash_actor(event.actor_index)
	_spawn_damage_number(event.target_index, event.damage_dealt, event.crit_multiplier)


func _on_death_event(event: BattleEvent) -> void:
	if event.target_index < 0 or event.target_index > 1:
		return
	_fade_unit(event.target_index)


func _on_ability_event(event: BattleEvent) -> void:
	var actor_index := event.actor_index
	if actor_index < 0 or actor_index > 1:
		return
	match event.ability_kind:
		Ability.Kind.LIFESTEAL, Ability.Kind.REGEN:
			_hp_current[actor_index] = event.actor_hp_after
			_refresh_hp_labels()
		Ability.Kind.THORNS:
			_hp_current[event.target_index] = event.actor_hp_after
			_refresh_hp_labels()
	_spawn_ability_label(actor_index, Ability.kind_name(event.ability_kind))


func _on_battle_end(_winner_index: int) -> void:
	_finished = true
	_playing = false
	_end_hold_remaining = config.end_hold_duration
	_refresh_controls_visual()


func _emit_finished() -> void:
	if _finish_emitted:
		return
	_finish_emitted = true
	var winner: int = _log.winner_index if _log != null else -1
	battle_finished.emit(winner)


# ---------- UI construction ----------

func _build_ui() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.anchor_right = 1.0
	_root.anchor_bottom = 1.0
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var background := ColorRect.new()
	background.name = "Background"
	background.anchor_right = 1.0
	background.anchor_bottom = 1.0
	background.color = Color(0.07, 0.04, 0.07, 1.0)
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(background)

	_arena_center = Control.new()
	_arena_center.name = "Arena"
	_arena_center.anchor_right = 1.0
	_arena_center.anchor_bottom = 1.0
	_arena_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_arena_center)

	_unit_a = _build_unit_view("UnitA", true)
	_unit_b = _build_unit_view("UnitB", false)

	_build_inventory_panel()
	_build_enemy_info_panel()
	_build_controls()


func _build_unit_view(node_name: String, is_left: bool) -> Dictionary:
	var panel := Control.new()
	panel.name = node_name
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_top = -180.0
	panel.offset_bottom = 180.0
	if is_left:
		panel.anchor_left = 0.38
		panel.anchor_right = 0.38
	else:
		panel.anchor_left = 0.62
		panel.anchor_right = 0.62
	panel.offset_left = -95.0
	panel.offset_right = 95.0
	_arena_center.add_child(panel)

	var icon_holder := Control.new()
	icon_holder.name = "IconHolder"
	icon_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_holder.anchor_right = 1.0
	icon_holder.offset_top = 0.0
	icon_holder.offset_bottom = float(config.unit_icon_size)
	panel.add_child(icon_holder)

	var half := float(config.unit_icon_size) * 0.5

	var color_rect := ColorRect.new()
	color_rect.name = "Fallback"
	color_rect.anchor_left = 0.5
	color_rect.anchor_right = 0.5
	color_rect.offset_left = -half
	color_rect.offset_right = half
	color_rect.offset_top = 0.0
	color_rect.offset_bottom = float(config.unit_icon_size)
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_holder.add_child(color_rect)

	var texture_rect := TextureRect.new()
	texture_rect.name = "Icon"
	texture_rect.anchor_left = 0.5
	texture_rect.anchor_right = 0.5
	texture_rect.offset_left = -half
	texture_rect.offset_right = half
	texture_rect.offset_top = 0.0
	texture_rect.offset_bottom = float(config.unit_icon_size)
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_rect.visible = false
	texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_holder.add_child(texture_rect)

	var damage_holder := Control.new()
	damage_holder.name = "DamageNumbers"
	damage_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	damage_holder.anchor_right = 1.0
	damage_holder.anchor_bottom = 1.0
	panel.add_child(damage_holder)

	var stats_box := VBoxContainer.new()
	stats_box.name = "Stats"
	stats_box.anchor_left = 0.5
	stats_box.anchor_right = 0.5
	stats_box.offset_left = -70.0
	stats_box.offset_right = 70.0
	stats_box.offset_top = float(config.unit_icon_size) + 16.0
	stats_box.offset_bottom = stats_box.offset_top + 132.0
	stats_box.add_theme_constant_override("separation", 4)
	stats_box.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(stats_box)

	var hp_row := _build_stat_row(_STAT_GLYPH_HP, config.hp_color, config.hp_icon)
	var atk_row := _build_stat_row(_STAT_GLYPH_ATK, config.damage_color, config.damage_icon)
	var def_row := _build_stat_row(_STAT_GLYPH_DEF, config.defense_color, config.defense_icon)
	var spd_row := _build_stat_row(_STAT_GLYPH_SPD, config.speed_color, config.speed_icon)
	stats_box.add_child(hp_row["row"])
	stats_box.add_child(atk_row["row"])
	stats_box.add_child(def_row["row"])
	stats_box.add_child(spd_row["row"])

	return {
		"panel": panel,
		"icon_rect": texture_rect,
		"color_rect": color_rect,
		"damage_holder": damage_holder,
		"hp_value": hp_row["value"] as Label,
		"atk_value": atk_row["value"] as Label,
		"def_value": def_row["value"] as Label,
		"spd_value": spd_row["value"] as Label,
	}


func _build_stat_row(glyph: String, tint: Color, texture: Texture2D) -> Dictionary:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER

	var icon := _build_stat_icon(glyph, tint, texture)
	row.add_child(icon)

	var value := Label.new()
	value.text = "-"
	value.add_theme_font_size_override("font_size", 20)
	value.add_theme_color_override("font_color", tint)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value.custom_minimum_size = Vector2(72, 28)
	row.add_child(value)

	return {"row": row, "value": value}


func _build_stat_icon(glyph: String, tint: Color, texture: Texture2D) -> Control:
	var box := Control.new()
	box.custom_minimum_size = Vector2(28, 28)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var frame := ColorRect.new()
	frame.anchor_right = 1.0
	frame.anchor_bottom = 1.0
	frame.color = tint
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(frame)

	var inner := ColorRect.new()
	inner.anchor_right = 1.0
	inner.anchor_bottom = 1.0
	inner.offset_left = 2.0
	inner.offset_top = 2.0
	inner.offset_right = -2.0
	inner.offset_bottom = -2.0
	inner.color = Color(0.05, 0.05, 0.08, 1.0)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(inner)

	if texture != null:
		var tex_rect := TextureRect.new()
		tex_rect.anchor_right = 1.0
		tex_rect.anchor_bottom = 1.0
		tex_rect.offset_left = 3.0
		tex_rect.offset_top = 3.0
		tex_rect.offset_right = -3.0
		tex_rect.offset_bottom = -3.0
		tex_rect.texture = texture
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.modulate = tint
		tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(tex_rect)
	else:
		var letter := Label.new()
		letter.text = glyph
		letter.anchor_right = 1.0
		letter.anchor_bottom = 1.0
		letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		letter.add_theme_font_size_override("font_size", 16)
		letter.add_theme_color_override("font_color", tint)
		letter.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(letter)

	return box


func _build_inventory_panel() -> void:
	var panel := PanelContainer.new()
	panel.name = "InventoryPanel"
	panel.anchor_left = 0.0
	panel.anchor_right = 0.0
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = 24.0
	panel.offset_right = 248.0
	panel.offset_top = -200.0
	panel.offset_bottom = 200.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "Inventory"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.88, 0.86, 0.75))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var weapon_header := Label.new()
	weapon_header.text = "Weapon"
	weapon_header.add_theme_font_size_override("font_size", 13)
	weapon_header.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(weapon_header)

	_inventory_weapon_view = _build_inventory_slot_view(72)
	vbox.add_child(_inventory_weapon_view["root"])

	var quick_header := Label.new()
	quick_header.text = "Quick Slots"
	quick_header.add_theme_font_size_override("font_size", 13)
	quick_header.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(quick_header)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	vbox.add_child(grid)

	_inventory_quick_views.clear()
	for i in range(4):
		var slot := _build_inventory_slot_view(58)
		grid.add_child(slot["root"])
		_inventory_quick_views.append(slot)


func _build_inventory_slot_view(size_px: int) -> Dictionary:
	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(size_px * 2 + 10, size_px)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	box.add_child(hbox)

	var icon_holder := Control.new()
	icon_holder.custom_minimum_size = Vector2(size_px - 12, size_px - 12)
	icon_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(icon_holder)

	var icon_rect := TextureRect.new()
	icon_rect.anchor_right = 1.0
	icon_rect.anchor_bottom = 1.0
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.visible = false
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_holder.add_child(icon_rect)

	var name_label := Label.new()
	name_label.text = "—"
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(name_label)

	return {
		"root": box,
		"icon": icon_rect,
		"name": name_label,
	}


func _build_enemy_info_panel() -> void:
	var panel := PanelContainer.new()
	panel.name = "EnemyInfo"
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -272.0
	panel.offset_right = -24.0
	panel.offset_top = -160.0
	panel.offset_bottom = 160.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	_enemy_title_label = Label.new()
	_enemy_title_label.text = "—"
	_enemy_title_label.add_theme_font_size_override("font_size", 22)
	_enemy_title_label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.8))
	_enemy_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_enemy_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_enemy_title_label)

	_enemy_description_label = Label.new()
	_enemy_description_label.text = ""
	_enemy_description_label.add_theme_font_size_override("font_size", 14)
	_enemy_description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_enemy_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_enemy_description_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_enemy_description_label)


func _build_controls() -> void:
	var bar := HBoxContainer.new()
	bar.name = "Controls"
	bar.anchor_left = 0.5
	bar.anchor_right = 0.5
	bar.anchor_top = 0.0
	bar.anchor_bottom = 0.0
	bar.offset_top = 52.0
	bar.offset_bottom = 96.0
	bar.offset_left = -220.0
	bar.offset_right = 220.0
	bar.add_theme_constant_override("separation", 10)
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	_root.add_child(bar)

	_pause_button = _make_control_button("| |", _on_pause_pressed)
	bar.add_child(_pause_button)

	_speed_buttons.clear()
	for i in range(config.playback_speeds.size()):
		var glyph := _speed_glyph_for(i)
		var btn := _make_control_button(glyph, _on_speed_button_pressed.bind(i))
		bar.add_child(btn)
		_speed_buttons.append(btn)


func _make_control_button(text: String, callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.focus_mode = Control.FOCUS_NONE
	btn.flat = true
	btn.custom_minimum_size = Vector2(44, 36)
	btn.add_theme_font_size_override("font_size", 22)
	btn.pressed.connect(callback)
	return btn


func _speed_glyph_for(index: int) -> String:
	var count: int = clampi(index + 1, 1, 6)
	var glyph := ""
	for i in range(count):
		glyph += ">"
	return glyph


# ---------- UI population ----------

func _populate_units() -> void:
	if _log == null:
		return
	_populate_unit(_unit_a, _log.unit_a_snapshot, config.player_fallback_color)
	_populate_unit(_unit_b, _log.unit_b_snapshot, config.enemy_fallback_color)
	_populate_inventory(_log.unit_a_snapshot)
	_populate_enemy_info(_log.unit_b_snapshot)


func _populate_inventory(snap: Dictionary) -> void:
	var entries: Array = snap.get("inventory", [])
	var weapon_entry := _find_inventory_entry(entries, "weapon")
	_paint_inventory_slot(_inventory_weapon_view, weapon_entry)

	var quick_entries: Array = _collect_quick_entries(entries)
	for i in range(_inventory_quick_views.size()):
		var entry: Dictionary = quick_entries[i] if i < quick_entries.size() else {}
		_paint_inventory_slot(_inventory_quick_views[i], entry)


func _find_inventory_entry(entries: Array, tag: String) -> Dictionary:
	var want_tag := StringName(tag)
	for entry in entries:
		if entry.get("tag") == want_tag:
			return entry
	return {}


func _collect_quick_entries(entries: Array) -> Array:
	var out: Array = []
	var any_tag := StringName("any")
	for entry in entries:
		if entry.get("tag") == any_tag:
			out.append(entry)
	return out


func _paint_inventory_slot(view: Dictionary, entry: Dictionary) -> void:
	if view.is_empty():
		return
	var icon_rect: TextureRect = view.get("icon")
	var name_label: Label = view.get("name")
	var icon: Texture2D = entry.get("icon") if not entry.is_empty() else null
	if icon_rect != null:
		icon_rect.texture = icon
		icon_rect.visible = icon != null
	if name_label != null:
		if entry.is_empty():
			name_label.text = "—"
		else:
			var artifact_name: String = entry.get("artifact_name", "")
			if artifact_name != "":
				name_label.text = artifact_name
			elif entry.get("display_name", "") != "":
				name_label.text = entry.get("display_name")
			else:
				name_label.text = "—"


func _populate_enemy_info(snap: Dictionary) -> void:
	if _enemy_title_label != null:
		var title: String = snap.get("display_name", "")
		if title == "":
			title = snap.get("name", "?")
		_enemy_title_label.text = title
	if _enemy_description_label != null:
		_enemy_description_label.text = snap.get("description", "")


func _populate_unit(view: Dictionary, snap: Dictionary, fallback_color: Color) -> void:
	if view.is_empty():
		return
	var icon_rect: TextureRect = view.get("icon_rect")
	var color_rect: ColorRect = view.get("color_rect")
	var panel: Control = view.get("panel")
	if panel != null:
		panel.modulate = Color(1, 1, 1, 1)

	var icon: Texture2D = snap.get("icon")
	if icon_rect != null:
		icon_rect.texture = icon
		icon_rect.visible = icon != null
	if color_rect != null:
		var c: Color = snap.get("color", fallback_color)
		color_rect.color = c
		color_rect.visible = icon == null

	var atk_label: Label = view.get("atk_value")
	var def_label: Label = view.get("def_value")
	var spd_label: Label = view.get("spd_value")
	if atk_label != null:
		atk_label.text = "%d" % int(snap.get("damage", 0))
	if def_label != null:
		def_label.text = "%d" % int(snap.get("defense", 0))
	if spd_label != null:
		spd_label.text = "%s" % _format_float(float(snap.get("attack_speed", 1.0)))


func _refresh_hp_labels() -> void:
	if _log == null:
		return
	_write_hp_label(_unit_a, _hp_current[0], int(_log.unit_a_snapshot.get("max_hp", 0)))
	_write_hp_label(_unit_b, _hp_current[1], int(_log.unit_b_snapshot.get("max_hp", 0)))


func _write_hp_label(view: Dictionary, current_hp: int, max_hp: int) -> void:
	if view.is_empty():
		return
	var hp_label: Label = view.get("hp_value")
	if hp_label == null:
		return
	hp_label.text = "%d/%d" % [maxi(0, current_hp), maxi(0, max_hp)]


func _format_float(value: float) -> String:
	if abs(value - round(value)) < 0.01:
		return "%d" % int(round(value))
	return "%.2f" % value


func _refresh_controls_visual() -> void:
	if _pause_button != null:
		var pause_active: bool = not _playing and not _finished
		_pause_button.modulate = config.controls_active_color if pause_active else config.controls_idle_color
	for i in range(_speed_buttons.size()):
		var btn := _speed_buttons[i]
		if btn == null:
			continue
		var active: bool = _playing and i == _speed_index and not _finished
		btn.modulate = config.controls_active_color if active else config.controls_idle_color


func _view_for(index: int) -> Dictionary:
	if index == 0:
		return _unit_a
	if index == 1:
		return _unit_b
	return {}


func _flash_actor(actor_index: int) -> void:
	var view := _view_for(actor_index)
	if view.is_empty():
		return
	var panel: Control = view.get("panel")
	if panel == null:
		return
	var original := panel.modulate
	var bright := Color(1.3, 1.3, 1.3, original.a)
	var tween := create_tween()
	tween.tween_property(panel, "modulate", bright, 0.06)
	tween.tween_property(panel, "modulate", original, 0.14)


func _fade_unit(index: int) -> void:
	var view := _view_for(index)
	if view.is_empty():
		return
	var panel: Control = view.get("panel")
	if panel == null:
		return
	var target := Color(panel.modulate.r, panel.modulate.g, panel.modulate.b, 0.25)
	var tween := create_tween()
	tween.tween_property(panel, "modulate", target, 0.25)


func _spawn_ability_label(actor_index: int, text: String) -> void:
	var view := _view_for(actor_index)
	if view.is_empty():
		return
	var holder: Control = view.get("damage_holder")
	if holder == null:
		return
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0.8, 0.95, 1.0))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.anchor_left = 0.5
	label.anchor_right = 0.5
	label.offset_left = -80.0
	label.offset_right = 80.0
	label.offset_top = -20.0
	label.offset_bottom = 12.0
	holder.add_child(label)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "offset_top", -60.0, 0.8)
	tween.tween_property(label, "offset_bottom", -28.0, 0.8)
	tween.tween_property(label, "modulate", Color(0.8, 0.95, 1.0, 0.0), 0.8)
	tween.chain().tween_callback(label.queue_free)


func _spawn_damage_number(target_index: int, amount: int, crit_mult: int = 1) -> void:
	if amount <= 0:
		return
	var view := _view_for(target_index)
	if view.is_empty():
		return
	var holder: Control = view.get("damage_holder")
	if holder == null:
		return
	var color := _damage_number_color_for(crit_mult)
	var font_size: int = 28 if crit_mult <= 1 else 34
	var label := Label.new()
	label.text = "-%d" % amount
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.anchor_left = 0.5
	label.anchor_right = 0.5
	label.offset_left = -60.0
	label.offset_right = 60.0
	label.offset_top = 10.0
	label.offset_bottom = 44.0
	holder.add_child(label)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "offset_top", -float(config.damage_number_rise), config.damage_number_lifetime)
	tween.tween_property(label, "offset_bottom", -float(config.damage_number_rise) + 34.0, config.damage_number_lifetime)
	tween.tween_property(label, "modulate", Color(color.r, color.g, color.b, 0.0), config.damage_number_lifetime)
	tween.chain().tween_callback(label.queue_free)


func _damage_number_color_for(crit_mult: int) -> Color:
	match crit_mult:
		2: return config.crit_color_tier_2
		3: return config.crit_color_tier_3
		_:
			if crit_mult >= 4:
				return config.crit_color_tier_4_plus
			return config.damage_number_color


# ---------- Input & control handlers ----------

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if not _finished:
			_on_pause_pressed()
			get_viewport().set_input_as_handled()


func _on_pause_pressed() -> void:
	if _finished:
		return
	_playing = not _playing
	_elapsed_in_event = 0.0
	_refresh_controls_visual()


func _on_speed_button_pressed(index: int) -> void:
	if _finished:
		return
	_speed_index = clampi(index, 0, maxi(0, config.playback_speeds.size() - 1))
	_playing = true
	_elapsed_in_event = 0.0
	_refresh_controls_visual()
