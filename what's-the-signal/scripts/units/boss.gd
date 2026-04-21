class_name Boss
extends Enemy

const _BOSS_LOADOUT_PATH := "res://configs/enemies/boss_1.tres"

var _pulse: _BossPulse = null


func _ensure_loadout() -> UnitLoadout:
	if loadout != null:
		return loadout
	if ResourceLoader.exists(_BOSS_LOADOUT_PATH):
		loadout = load(_BOSS_LOADOUT_PATH) as UnitLoadout
	if loadout == null:
		push_warning("Boss %s: UnitLoadout not set and boss default missing, falling back to enemy defaults" % name)
		return super._ensure_loadout()
	return loadout


func _on_placed(p_coords: Vector2i) -> void:
	super._on_placed(p_coords)
	visible = true
	if _pulse == null:
		_setup_pulse()


func _setup_pulse() -> void:
	_pulse = _BossPulse.new()
	var base_radius := 16.0
	if grid != null and grid.cell_size > 0:
		base_radius = float(grid.cell_size) * 0.55
	_pulse.radius = base_radius
	add_child(_pulse)
	var tween := create_tween().set_loops()
	tween.tween_property(_pulse, "scale", Vector2(2.0, 2.0), 1.0).from(Vector2(0.55, 0.55))
	tween.parallel().tween_property(_pulse, "modulate:a", 0.0, 1.0).from(0.95)


func die(killer: Variant) -> void:
	if grid != null:
		var cell := grid.get_cell(coords)
		if cell != null:
			cell.has_boss = false
	super.die(killer)


class _BossPulse extends Node2D:
	var radius: float = 16.0

	func _draw() -> void:
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(1, 1, 1, 1), 3.0, true)
