class_name UnitStats
extends Resource

signal stats_changed(stats: UnitStats)

enum Kind { MAX_HEALTH, DAMAGE, DEFENSE, ATTACK_SPEED }
enum Op { FLAT, PERCENT }

var current_health: int = 0

var _base: Dictionary = {
	Kind.MAX_HEALTH: 0.0,
	Kind.DAMAGE: 0.0,
	Kind.DEFENSE: 0.0,
	Kind.ATTACK_SPEED: 0.0,
}

# Each entry: { source: Artifact, kind: Kind, op: Op, value: float }
var _modifiers: Array = []

var _final_cache: Dictionary = {}


func configure_base(max_health: int, damage: int, defense: int, attack_speed: float) -> void:
	_base[Kind.MAX_HEALTH] = float(max_health)
	_base[Kind.DAMAGE] = float(damage)
	_base[Kind.DEFENSE] = float(defense)
	_base[Kind.ATTACK_SPEED] = attack_speed
	_recalc(false)
	current_health = get_final_int(Kind.MAX_HEALTH)
	stats_changed.emit(self)


func get_base(kind: Kind) -> float:
	return _base.get(kind, 0.0)


func set_base(kind: Kind, value: float) -> void:
	if _base.get(kind, 0.0) == value:
		return
	_base[kind] = value
	_recalc()


func get_final(kind: Kind) -> float:
	return _final_cache.get(kind, _base.get(kind, 0.0))


func get_final_int(kind: Kind) -> int:
	return int(floor(get_final(kind)))


func attach_artifact(artifact: Artifact, variant: ArtifactVariant) -> void:
	if artifact == null or variant == null:
		return
	_append_modifiers(artifact, variant)
	_recalc()


func detach_artifact(artifact: Artifact) -> void:
	if artifact == null:
		return
	if not _remove_modifiers(artifact):
		return
	_recalc()


func replace_artifact(old_artifact: Artifact, new_artifact: Artifact, new_variant: ArtifactVariant) -> void:
	var changed := false
	if old_artifact != null and _remove_modifiers(old_artifact):
		changed = true
	if new_artifact != null and new_variant != null:
		_append_modifiers(new_artifact, new_variant)
		changed = true
	if changed:
		_recalc()


func _append_modifiers(artifact: Artifact, variant: ArtifactVariant) -> void:
	for modifier in variant.modifiers:
		if modifier == null:
			continue
		_modifiers.append({
			"source": artifact,
			"kind": modifier.kind,
			"op": modifier.op,
			"value": modifier.value,
		})


func _remove_modifiers(artifact: Artifact) -> bool:
	var removed := false
	var i := _modifiers.size() - 1
	while i >= 0:
		if _modifiers[i].source == artifact:
			_modifiers.remove_at(i)
			removed = true
		i -= 1
	return removed


func _recalc(emit: bool = true) -> void:
	var new_cache: Dictionary = {}
	for kind in _base.keys():
		new_cache[kind] = _compute_final(kind)
	_final_cache = new_cache
	var new_max := get_final_int(Kind.MAX_HEALTH)
	if current_health > new_max:
		current_health = new_max
	if current_health < 0:
		current_health = 0
	if emit:
		stats_changed.emit(self)


func _compute_final(kind: Kind) -> float:
	var base: float = _base.get(kind, 0.0)
	var flat_sum := 0.0
	var percent_sum := 0.0
	for modifier in _modifiers:
		if modifier.kind != kind:
			continue
		match modifier.op:
			Op.FLAT:
				flat_sum += modifier.value
			Op.PERCENT:
				percent_sum += modifier.value
	return (base + flat_sum) * (1.0 + percent_sum / 100.0)
