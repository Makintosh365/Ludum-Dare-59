class_name BattleScreen
extends CanvasLayer

signal battle_finished(winner_index: int)

const _DEFAULT_CONFIG_PATH := "res://configs/default_battle.tres"
const _ITEM_SLOT_TEXTURE := preload("res://assets/Hud/ItemSlot.png")

@export var config: BattleConfig

@export_group("Floating Numbers")
## Font size for regular damage and heal numbers.
@export_range(8, 96, 1) var damage_number_font_size: int = 28
## Font size used when crit_multiplier > 1.
@export_range(8, 96, 1) var damage_number_crit_font_size: int = 34
## Width of the floating-number row (icon + text).
@export var damage_number_row_width: float = 144.0

var _log: BattleLog = null
var _event_index: int = 0
var _elapsed_in_event: float = 0.0
var _playing: bool = true
var _speed_index: int = 0
var _finished: bool = false
var _end_hold_remaining: float = 0.0
var _finish_emitted: bool = false

var _hp_current: Array[int] = [0, 0]

var _unit_a: Dictionary = {}
var _unit_b: Dictionary = {}

var _pause_button: Button = null
var _speed_buttons: Array[Button] = []

var _inventory_weapon_view: Dictionary = {}
var _inventory_quick_views: Array[Dictionary] = []
var _artifact_container: Container = null
var _enemy_title_label: Label = null
var _enemy_description_label: Label = null

var _attack_fire_times: Array = [[], []]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	_ensure_config()
	_cache_scene_nodes()
	_build_controls()
	_speed_index = config.get_default_speed_index()
	if _log != null:
		_compute_attack_schedule()
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
	_compute_attack_schedule()
	if is_inside_tree():
		_populate_units()
		_refresh_hp_labels()
		_refresh_controls_visual()


func _compute_attack_schedule() -> void:
	_attack_fire_times = [[], []]
	if _log == null:
		return
	for i in range(_log.events.size()):
		var event: BattleEvent = _log.events[i]
		if event.kind != BattleEvent.Kind.ATTACK:
			continue
		if event.actor_index < 0 or event.actor_index > 1:
			continue
		# An attack "fires" the moment we finish playing its event; that happens
		# when playback time crosses event_index + 1.
		_attack_fire_times[event.actor_index].append(float(i + 1))


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
		_update_cooldowns()
		if _finish_emitted:
			return
		_end_hold_remaining = maxf(0.0, _end_hold_remaining - delta * speed)
		if _end_hold_remaining <= 0.0:
			_emit_finished()
		return

	if not _playing:
		_update_cooldowns()
		return

	_elapsed_in_event += delta * speed

	while _playing and not _finished and _elapsed_in_event >= config.event_duration:
		_elapsed_in_event -= config.event_duration
		_advance_one_event()

	_update_cooldowns()


func _update_cooldowns() -> void:
	if _log == null:
		return
	var event_duration: float = maxf(0.0001, config.event_duration)
	var fraction: float = clampf(_elapsed_in_event / event_duration, 0.0, 1.0)
	var playback: float = float(_event_index) + fraction
	for actor in range(2):
		var view := _view_for(actor)
		var bar: TextureProgressBar = view.get("cooldown") if not view.is_empty() else null
		if bar == null:
			continue
		var fires: Array = _attack_fire_times[actor]
		if fires.is_empty():
			bar.value = 0.0
			continue
		var last_t: float = 0.0
		var next_t: float = -1.0
		for ft in fires:
			var t: float = float(ft)
			if t <= playback:
				last_t = t
			else:
				next_t = t
				break
		if next_t < 0.0:
			bar.value = 100.0
			continue
		var span: float = next_t - last_t
		if span <= 0.0:
			bar.value = 0.0
			continue
		bar.value = clampf((playback - last_t) / span, 0.0, 1.0) * 100.0


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
	_dash_actor(event.actor_index)
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
			_spawn_heal_number(actor_index, int(event.ability_value))
		Ability.Kind.THORNS:
			_hp_current[event.target_index] = event.actor_hp_after
			_refresh_hp_labels()
			_spawn_damage_number(event.target_index, int(event.ability_value))
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


# ---------- Scene-node caching ----------

func _cache_scene_nodes() -> void:
	_unit_a = _build_unit_view("UnitA", true)
	_unit_b = _build_unit_view("UnitB", false)
	_inventory_weapon_view = {
		"root": get_node_or_null("%WeaponSlot"),
		"icon": get_node_or_null("%WeaponSlotIcon") as TextureRect,
		"fallback": get_node_or_null("%WeaponSlotFallback") as ColorRect,
	}
	_artifact_container = get_node_or_null("%ArtifactContainer") as Container
	_inventory_quick_views.clear()
	_enemy_title_label = get_node_or_null("%EnemyTitle") as Label
	_enemy_description_label = get_node_or_null("%EnemyDescription") as Label


func _build_unit_view(unit_name: String, is_left: bool) -> Dictionary:
	var suffix: String = "A" if is_left else "B"
	var panel := get_node_or_null("%" + unit_name) as Control
	if panel == null:
		push_warning("BattleScreen: %s panel missing from scene" % unit_name)
		return {}
	return {
		"panel": panel,
		"icon_holder": panel.get_node_or_null("IconHolder") as Control,
		"icon_rect": panel.get_node_or_null("IconHolder/Icon") as TextureRect,
		"color_rect": panel.get_node_or_null("IconHolder/Fallback") as ColorRect,
		"damage_holder": panel.get_node_or_null("DamageHolder") as Control,
		"cooldown": panel.get_node_or_null("Cooldown") as TextureProgressBar,
		"hp_value": get_node_or_null("%HpValue" + suffix) as Label,
		"atk_value": get_node_or_null("%AtkValue" + suffix) as Label,
		"def_value": get_node_or_null("%DefValue" + suffix) as Label,
		"spd_value": get_node_or_null("%SpdValue" + suffix) as Label,
		"dash_direction": 1 if is_left else -1,
	}


func _build_controls() -> void:
	var bar := get_node_or_null("%ControlsBar") as HBoxContainer
	if bar == null:
		push_warning("BattleScreen: ControlsBar missing from scene")
		return
	for child in bar.get_children():
		child.queue_free()
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
	_rebuild_artifact_slots(quick_entries.size())
	for i in range(_inventory_quick_views.size()):
		var entry: Dictionary = quick_entries[i] if i < quick_entries.size() else {}
		_paint_inventory_slot(_inventory_quick_views[i], entry)


func _rebuild_artifact_slots(count: int) -> void:
	if _artifact_container == null:
		return
	if _inventory_quick_views.size() == count:
		return
	for child in _artifact_container.get_children():
		child.queue_free()
	_inventory_quick_views.clear()
	for i in range(count):
		var slot := _make_artifact_slot(i + 1)
		_artifact_container.add_child(slot["root"])
		_inventory_quick_views.append(slot)


func _make_artifact_slot(index: int) -> Dictionary:
	var slot := TextureRect.new()
	slot.name = "ArtifactSlot%d" % index
	slot.custom_minimum_size = Vector2(160, 160)
	slot.texture = _ITEM_SLOT_TEXTURE
	slot.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	slot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	slot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var content := AspectRatioContainer.new()
	content.name = "Content"
	content.anchor_left = 0.15
	content.anchor_top = 0.15
	content.anchor_right = 0.85
	content.anchor_bottom = 0.85
	content.ratio = 1.0
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(content)

	var fallback := ColorRect.new()
	fallback.name = "Fallback"
	fallback.color = Color(1, 1, 1, 1)
	fallback.visible = false
	fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(fallback)

	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.visible = false
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(icon)

	return {
		"root": slot,
		"icon": icon,
		"fallback": fallback,
	}


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
	var fallback: ColorRect = view.get("fallback")
	var has_entry: bool = not entry.is_empty()
	var icon: Texture2D = entry.get("icon") if has_entry else null
	if icon_rect != null:
		icon_rect.texture = icon
		icon_rect.visible = icon != null
	if fallback != null:
		fallback.visible = has_entry and icon == null


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


func _dash_actor(actor_index: int) -> void:
	var view := _view_for(actor_index)
	if view.is_empty():
		return
	var icon_holder: Control = view.get("icon_holder")
	if icon_holder == null:
		return
	var direction: int = int(view.get("dash_direction", 0))
	if direction == 0:
		return
	var dash_px: float = float(config.unit_icon_size) * 0.18 * float(direction)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(icon_holder, "position:x", dash_px, 0.08).set_ease(Tween.EASE_OUT)
	tween.tween_property(icon_holder, "position:x", 0.0, 0.16).set_ease(Tween.EASE_IN)


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
	tween.tween_property(label, "offset_top", -80.0, 1.8)
	tween.tween_property(label, "offset_bottom", -48.0, 1.8)
	tween.tween_property(label, "modulate", Color(0.8, 0.95, 1.0, 0.0), 1.8).set_delay(0.6)
	tween.chain().tween_callback(label.queue_free)


func _spawn_damage_number(target_index: int, amount: int, crit_mult: int = 1) -> void:
	if amount <= 0:
		return
	var color := _damage_number_color_for(crit_mult)
	_spawn_floating_stat(target_index, "-%d" % amount, color, config.hp_icon, crit_mult > 1)


func _spawn_heal_number(actor_index: int, amount: int) -> void:
	if amount <= 0:
		return
	_spawn_floating_stat(actor_index, "+%d" % amount, config.hp_color, config.hp_icon, false)


func _spawn_floating_stat(target_index: int, text: String, color: Color, icon: Texture2D, big: bool) -> void:
	var view := _view_for(target_index)
	if view.is_empty():
		return
	var holder: Control = view.get("damage_holder")
	if holder == null:
		return
	var font_size: int = damage_number_crit_font_size if big else damage_number_font_size
	var icon_size: int = font_size

	var row := HBoxContainer.new()
	row.anchor_left = 0.5
	row.anchor_right = 0.5
	row.offset_left = -damage_number_row_width * 0.5
	row.offset_right = damage_number_row_width * 0.5
	row.offset_top = 10.0
	row.offset_bottom = 10.0 + float(icon_size) + 6.0
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.modulate = color

	if icon != null:
		var icon_rect := TextureRect.new()
		icon_rect.texture = icon
		icon_rect.custom_minimum_size = Vector2(icon_size, icon_size)
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon_rect)

	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)

	holder.add_child(row)

	var tween := create_tween()
	tween.set_parallel(true)
	var final_top: float = -float(config.damage_number_rise)
	tween.tween_property(row, "offset_top", final_top, config.damage_number_lifetime)
	tween.tween_property(row, "offset_bottom", final_top + float(icon_size) + 6.0, config.damage_number_lifetime)
	tween.tween_property(row, "modulate", Color(color.r, color.g, color.b, 0.0), config.damage_number_lifetime)
	tween.chain().tween_callback(row.queue_free)


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
