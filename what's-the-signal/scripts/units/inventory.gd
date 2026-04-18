class_name Inventory
extends Node

signal inventory_changed(artifacts: Array)

@export var capacity: int = 4

var _stats: UnitStats = null
var _artifacts: Array[Artifact] = []


func bind(stats: UnitStats) -> void:
	_stats = stats


func add_artifact(artifact: Artifact) -> bool:
	if artifact == null:
		return false
	if is_full():
		return false
	if _artifacts.has(artifact):
		return false
	_artifacts.append(artifact)
	if _stats != null:
		_stats.attach_artifact(artifact)
	inventory_changed.emit(get_artifacts())
	return true


func remove_artifact(artifact: Artifact) -> bool:
	if artifact == null:
		return false
	var idx := _artifacts.find(artifact)
	if idx < 0:
		return false
	_artifacts.remove_at(idx)
	if _stats != null:
		_stats.detach_artifact(artifact)
	inventory_changed.emit(get_artifacts())
	return true


func replace_artifact_at(slot: int, artifact: Artifact) -> bool:
	if artifact == null:
		return false
	if slot < 0 or slot >= _artifacts.size():
		return false
	if _artifacts.has(artifact) and _artifacts[slot] != artifact:
		return false
	var old := _artifacts[slot]
	if old == artifact:
		return false
	_artifacts[slot] = artifact
	if _stats != null:
		_stats.replace_artifact(old, artifact)
	inventory_changed.emit(get_artifacts())
	return true


func get_artifacts() -> Array[Artifact]:
	return _artifacts.duplicate()


func slot_count() -> int:
	return _artifacts.size()


func is_full() -> bool:
	return _artifacts.size() >= capacity


func set_capacity(new_capacity: int) -> void:
	if new_capacity < 0:
		new_capacity = 0
	if new_capacity == capacity:
		return
	capacity = new_capacity
	# Shrink if necessary, detaching overflow from stats.
	var shrunk := false
	while _artifacts.size() > capacity:
		var dropped: Artifact = _artifacts.pop_back()
		if _stats != null:
			_stats.detach_artifact(dropped)
		shrunk = true
	if shrunk:
		inventory_changed.emit(get_artifacts())
