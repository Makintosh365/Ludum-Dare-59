class_name HUD
extends Control

const _WEAPON_TAG := &"weapon"
const _EMPTY_TEXT := "—"
const _ITEM_SLOT_TEXTURE := preload("res://assets/Hud/ItemSlot.png")
const _ARTIFACT_SLOT_SIZE := Vector2(104, 72)
const _BOSS_SEG_LIT := Color(1.0, 0.78, 0.26)
const _BOSS_SEG_DIM := Color(0.33, 0.22, 0.55)
const _BOSS_SEG_SIZE := Vector2(48, 12)
const _BOSS_CURSOR_COLOR := Color(1.0, 1.0, 1.0)
const _BOSS_CURSOR_SIZE := Vector2(10, 8)

var _player: Player = null
var _boss_killed: int = 0
var _boss_total: int = 0
var _weapon_view: Dictionary = {}
var _artifact_views: Array[Dictionary] = []
var _artifact_container: GridContainer = null


func _ready() -> void:
	_weapon_view = {
		"root": get_node_or_null("%WeaponSlot"),
		"icon": get_node_or_null("%WeaponSlotIcon") as TextureRect,
		"fallback": get_node_or_null("%WeaponSlotFallback") as ColorRect,
	}
	_artifact_container = get_node_or_null("%QuickSlots") as GridContainer
	_reset_labels()
	_paint_inventory_slot(_weapon_view, {})
	_rebuild_artifact_slots(0)
	_rebuild_boss_progress()


func _exit_tree() -> void:
	_disconnect_player()


func bind_player(player: Player) -> void:
	if _player == player:
		return
	_disconnect_player()
	_player = player
	if _player == null:
		_reset_labels()
		_paint_inventory_slot(_weapon_view, {})
		_rebuild_artifact_slots(0)
		return
	_player.stats_changed.connect(_on_stats_changed)
	_player.damaged.connect(_on_damaged)
	_player.coins_changed.connect(_on_coins_changed)
	_player.died.connect(_on_player_died)
	_player.inventory.inventory_changed.connect(_on_inventory_changed)
	_on_stats_changed(_player.stats)
	_on_coins_changed(_player.coins)
	_on_inventory_changed(_player.inventory.get_artifacts())


func set_boss_progress(killed: int, total: int) -> void:
	_boss_total = maxi(0, total)
	_boss_killed = clampi(killed, 0, _boss_total)
	_rebuild_boss_progress()


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
	_set_label("%HealthValue", _EMPTY_TEXT)
	_set_label("%ArmorValue", "0")
	_set_label("%AttackValue", "0")
	_set_label("%SpeedValue", "0.0")
	_set_label("%CoinsValue", "0")


func _on_stats_changed(stats: UnitStats) -> void:
	if stats == null:
		return
	var max_hp := stats.get_final_int(UnitStats.Kind.MAX_HEALTH)
	_set_label("%HealthValue", "%d/%d" % [stats.current_health, max_hp])
	_set_label("%AttackValue", "%d" % stats.get_final_int(UnitStats.Kind.DAMAGE))
	_set_label("%ArmorValue", "%d" % stats.get_final_int(UnitStats.Kind.DEFENSE))
	_set_label("%SpeedValue", "%.1f" % stats.get_final(UnitStats.Kind.ATTACK_SPEED))


func _on_damaged(_amount: int, _health_after: int) -> void:
	if _player != null:
		_on_stats_changed(_player.stats)


func _on_coins_changed(total: int) -> void:
	_set_label("%CoinsValue", "%d" % total)


func _on_player_died() -> void:
	_set_label("%HealthValue", "0/0")


func _on_inventory_changed(_artifacts: Array) -> void:
	if _player == null or _player.inventory == null:
		_paint_inventory_slot(_weapon_view, {})
		_rebuild_artifact_slots(0)
		return
	var slots := _player.inventory.get_slots()
	var weapon_slot := _find_slot_by_tag(slots, _WEAPON_TAG)
	_paint_inventory_slot(_weapon_view, _slot_to_entry(weapon_slot))
	var any_entries := _collect_any_entries(slots)
	_rebuild_artifact_slots(any_entries.size())
	for i in range(_artifact_views.size()):
		var entry: Dictionary = any_entries[i] if i < any_entries.size() else {}
		_paint_inventory_slot(_artifact_views[i], entry)


func _find_slot_by_tag(slots: Array, tag: StringName) -> Dictionary:
	for slot in slots:
		if slot.get("tag") == tag:
			return slot
	return {}


func _collect_any_entries(slots: Array) -> Array:
	var out: Array = []
	for slot in slots:
		if slot.get("tag") == Inventory.ANY_TAG:
			out.append(_slot_to_entry(slot))
	return out


func _slot_to_entry(slot: Dictionary) -> Dictionary:
	if slot.is_empty():
		return {}
	var artifact: Artifact = slot.get("artifact")
	if artifact == null:
		return {}
	var rarity: int = slot.get("rarity", -1)
	var variant := artifact.resolve_variant(rarity)
	return {
		"artifact": artifact,
		"icon": variant.icon if variant != null else null,
	}


func _rebuild_artifact_slots(count: int) -> void:
	if _artifact_container == null:
		return
	if _artifact_views.size() == count:
		return
	for child in _artifact_container.get_children():
		child.queue_free()
	_artifact_views.clear()
	for i in range(count):
		var view := _make_artifact_slot(i + 1)
		_artifact_container.add_child(view["root"])
		_artifact_views.append(view)


func _make_artifact_slot(index: int) -> Dictionary:
	var slot := TextureRect.new()
	slot.name = "ArtifactSlot%d" % index
	slot.custom_minimum_size = _ARTIFACT_SLOT_SIZE
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


func _set_label(node_path: String, value: String) -> void:
	var label := get_node_or_null(node_path) as Label
	if label != null:
		label.text = value


func _rebuild_boss_progress() -> void:
	var container := get_node_or_null("%BossProgress") as HBoxContainer
	if container == null:
		return
	var skull := container.get_node_or_null("Skull") as TextureRect
	for child in container.get_children():
		if child != skull:
			child.queue_free()
	for i in range(_boss_total):
		var seg := ColorRect.new()
		seg.custom_minimum_size = _BOSS_SEG_SIZE
		seg.color = _BOSS_SEG_LIT if i < _boss_killed else _BOSS_SEG_DIM
		container.add_child(seg)
		if skull != null:
			container.move_child(skull, -1)
	_update_boss_cursor()


func _update_boss_cursor() -> void:
	var cursor_root := get_node_or_null("%BossCursor") as Control
	if cursor_root == null:
		return
	for child in cursor_root.get_children():
		child.queue_free()
	if _boss_total <= 0:
		return
	var container := get_node_or_null("%BossProgress") as HBoxContainer
	if container == null:
		return
	var progress: float = float(_boss_killed) / float(_boss_total)
	var segments_width: float = _BOSS_SEG_SIZE.x * float(_boss_total) + container.get_theme_constant(&"separation") * maxf(0.0, float(_boss_total - 1))
	var triangle := Polygon2D.new()
	var half: float = _BOSS_CURSOR_SIZE.x * 0.5
	triangle.polygon = PackedVector2Array([
		Vector2(-half, _BOSS_CURSOR_SIZE.y),
		Vector2(half, _BOSS_CURSOR_SIZE.y),
		Vector2(0.0, 0.0),
	])
	triangle.color = _BOSS_CURSOR_COLOR
	triangle.position = Vector2(segments_width * progress, 0.0)
	cursor_root.add_child(triangle)
