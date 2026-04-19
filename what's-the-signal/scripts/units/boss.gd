class_name Boss
extends Enemy

const _BOSS_LOADOUT_PATH := "res://configs/enemies/boss.tres"


func _ensure_loadout() -> UnitLoadout:
	if loadout != null:
		return loadout
	if ResourceLoader.exists(_BOSS_LOADOUT_PATH):
		loadout = load(_BOSS_LOADOUT_PATH) as UnitLoadout
	if loadout == null:
		push_warning("Boss %s: UnitLoadout not set and boss default missing, falling back to enemy defaults" % name)
		return super._ensure_loadout()
	return loadout


func die(killer: Variant) -> void:
	if grid != null:
		var cell := grid.get_cell(coords)
		if cell != null:
			cell.has_boss = false
	super.die(killer)
