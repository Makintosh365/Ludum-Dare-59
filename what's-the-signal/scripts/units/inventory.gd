class_name Inventory
extends Node

signal inventory_changed(artifacts: Array)
signal inventory_value_changed(new_value: float)

const ANY_TAG := &"any"
const _LOOT_CONFIG_PATH := "res://configs/default_loot.tres"

static var _loot_config_cache: LootConfig = null

var _stats: UnitStats = null
var _slots: Array = []
var _cached_value: float = 0.0


func bind(stats: UnitStats) -> void:
	_stats = stats


func configure(cfg: InventoryConfig) -> void:
	_clear_slots_detaching()
	if cfg == null:
		_emit_changed()
		return
	for i in range(maxi(0, cfg.normal_slot_count)):
		_slots.append(_make_slot(ANY_TAG, ""))
	for slot_cfg in cfg.special_slots:
		if slot_cfg == null:
			continue
		_slots.append(_make_slot(slot_cfg.tag, slot_cfg.display_name))
		if slot_cfg.starting_artifact != null:
			var index := _slots.size() - 1
			if not _place_in_slot_silent(slot_cfg.starting_artifact, index, -1):
				push_warning("Inventory: failed to place starting_artifact %s in slot %s" % [slot_cfg.starting_artifact.id, slot_cfg.tag])
	for artifact in cfg.starting_artifacts:
		if artifact == null:
			continue
		if _place_auto_silent(artifact, -1) < 0:
			push_warning("Inventory: no compatible slot/variant for starting artifact %s (tag=%s)" % [artifact.id, artifact.slot_tag])
	_emit_changed()


func add_slot(slot_cfg: SlotConfig) -> int:
	if slot_cfg == null:
		return -1
	_slots.append(_make_slot(slot_cfg.tag, slot_cfg.display_name))
	_emit_changed()
	return _slots.size() - 1


func place_in_slot(artifact: Artifact, index: int, rarity: int = -1) -> bool:
	if _place_in_slot_silent(artifact, index, rarity):
		_emit_changed()
		return true
	return false


func place_auto(artifact: Artifact, rarity: int = -1) -> int:
	var index := _place_auto_silent(artifact, rarity)
	if index >= 0:
		_emit_changed()
	return index


func replace_in_slot(artifact: Artifact, index: int, rarity: int = -1) -> bool:
	if artifact == null or not _index_valid(index):
		return false
	if not _is_compatible(_slots[index].tag, artifact.slot_tag):
		return false
	var variant := artifact.resolve_variant(rarity)
	if variant == null:
		return false
	var current: Artifact = _slots[index].artifact
	if current != null and _stats != null:
		_stats.detach_artifact(current)
	_slots[index].artifact = artifact
	_slots[index].rarity = variant.rarity
	if _stats != null:
		_stats.attach_artifact(artifact, variant)
	_emit_changed()
	return true


func find_empty_compatible_slot(artifact: Artifact) -> int:
	if artifact == null:
		return -1
	for i in range(_slots.size()):
		var slot: Dictionary = _slots[i]
		if slot.artifact != null:
			continue
		if _is_compatible(slot.tag, artifact.slot_tag):
			return i
	return -1


func find_compatible_slot_indices(artifact: Artifact) -> Array[int]:
	var out: Array[int] = []
	if artifact == null:
		return out
	for i in range(_slots.size()):
		if _is_compatible(_slots[i].tag, artifact.slot_tag):
			out.append(i)
	return out


func remove_from_slot(index: int) -> Artifact:
	if not _index_valid(index):
		return null
	var artifact: Artifact = _slots[index].artifact
	if artifact == null:
		return null
	_slots[index].artifact = null
	_slots[index].rarity = -1
	if _stats != null:
		_stats.detach_artifact(artifact)
	_emit_changed()
	return artifact


func move(from_index: int, to_index: int) -> bool:
	if from_index == to_index:
		return false
	if not _index_valid(from_index) or not _index_valid(to_index):
		return false
	var artifact: Artifact = _slots[from_index].artifact
	if artifact == null:
		return false
	if _slots[to_index].artifact != null:
		return false
	if not _is_compatible(_slots[to_index].tag, artifact.slot_tag):
		return false
	var rarity: int = _slots[from_index].rarity
	_slots[from_index].artifact = null
	_slots[from_index].rarity = -1
	_slots[to_index].artifact = artifact
	_slots[to_index].rarity = rarity
	_emit_changed()
	return true


func get_inventory_value() -> float:
	return _cached_value


func _compute_value() -> float:
	var cfg := _get_loot_config()
	var total := 0.0
	for slot in _slots:
		var artifact: Artifact = slot.artifact
		if artifact == null:
			continue
		var multiplier: float = 1.0
		if cfg != null:
			multiplier = cfg.rarity_value_multiplier(int(slot.rarity))
		total += artifact.value * multiplier
	return total


func _emit_changed() -> void:
	inventory_changed.emit(get_artifacts())
	var new_value := _compute_value()
	if not is_equal_approx(new_value, _cached_value):
		_cached_value = new_value
		inventory_value_changed.emit(_cached_value)


static func _get_loot_config() -> LootConfig:
	if _loot_config_cache != null:
		return _loot_config_cache
	if not ResourceLoader.exists(_LOOT_CONFIG_PATH):
		return null
	_loot_config_cache = load(_LOOT_CONFIG_PATH) as LootConfig
	return _loot_config_cache


func get_artifacts() -> Array[Artifact]:
	var out: Array[Artifact] = []
	for slot in _slots:
		if slot.artifact != null:
			out.append(slot.artifact)
	return out


func get_slot(index: int) -> Dictionary:
	if not _index_valid(index):
		return {}
	return _slots[index].duplicate()


func get_slots() -> Array:
	var out: Array = []
	for slot in _slots:
		out.append(slot.duplicate())
	return out


func slot_count() -> int:
	return _slots.size()


func is_compatible(index: int, artifact: Artifact) -> bool:
	if artifact == null or not _index_valid(index):
		return false
	return _is_compatible(_slots[index].tag, artifact.slot_tag)


func _make_slot(tag: StringName, display_name: String) -> Dictionary:
	return {
		"tag": tag,
		"display_name": display_name,
		"artifact": null,
		"rarity": -1,
	}


func _is_compatible(slot_tag: StringName, artifact_tag: StringName) -> bool:
	return slot_tag == artifact_tag


func _index_valid(index: int) -> bool:
	return index >= 0 and index < _slots.size()


func _place_in_slot_silent(artifact: Artifact, index: int, rarity: int) -> bool:
	if artifact == null or not _index_valid(index):
		return false
	if _slots[index].artifact != null:
		return false
	if not _is_compatible(_slots[index].tag, artifact.slot_tag):
		return false
	var variant := artifact.resolve_variant(rarity)
	if variant == null:
		return false
	_slots[index].artifact = artifact
	_slots[index].rarity = variant.rarity
	if _stats != null:
		_stats.attach_artifact(artifact, variant)
	return true


func _place_auto_silent(artifact: Artifact, rarity: int) -> int:
	if artifact == null:
		return -1
	var variant := artifact.resolve_variant(rarity)
	if variant == null:
		return -1
	for i in range(_slots.size()):
		var slot: Dictionary = _slots[i]
		if slot.artifact != null:
			continue
		if not _is_compatible(slot.tag, artifact.slot_tag):
			continue
		slot.artifact = artifact
		slot.rarity = variant.rarity
		if _stats != null:
			_stats.attach_artifact(artifact, variant)
		return i
	return -1


func _clear_slots_detaching() -> void:
	if _stats != null:
		for slot in _slots:
			if slot.artifact != null:
				_stats.detach_artifact(slot.artifact)
	_slots.clear()
