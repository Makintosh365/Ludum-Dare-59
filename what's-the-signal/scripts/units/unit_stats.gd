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

# Each entry is a bundle produced by one attach_artifact call:
#   { source: Artifact, entries: Array of { kind: Kind, op: Op, value: float } }
# Duplicates of the same Artifact produce separate bundles so detaching one
# copy only removes its own contribution.
var _modifier_bundles: Array = []

# Parallel to _modifier_bundles: each entry is
#   { source: Artifact, entries: Array of { kind: Ability.Kind, value: float } }
var _ability_bundles: Array = []

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
	_append_bundle(artifact, variant)
	_append_ability_bundle(artifact, variant)
	_recalc()


func detach_artifact(artifact: Artifact) -> void:
	if artifact == null:
		return
	var removed_stats := _remove_last_bundle(artifact)
	var removed_abilities := _remove_last_ability_bundle(artifact)
	if not removed_stats and not removed_abilities:
		return
	_recalc()


func replace_artifact(old_artifact: Artifact, new_artifact: Artifact, new_variant: ArtifactVariant) -> void:
	var changed := false
	if old_artifact != null:
		if _remove_last_bundle(old_artifact):
			changed = true
		if _remove_last_ability_bundle(old_artifact):
			changed = true
	if new_artifact != null and new_variant != null:
		_append_bundle(new_artifact, new_variant)
		_append_ability_bundle(new_artifact, new_variant)
		changed = true
	if changed:
		_recalc()


func get_abilities_summary() -> Dictionary:
	var out: Dictionary = {}
	for bundle in _ability_bundles:
		for entry in bundle.entries:
			out[entry.kind] = float(out.get(entry.kind, 0.0)) + float(entry.value)
	if out.has(Ability.Kind.CRIT_CHANCE):
		out[Ability.Kind.CRIT_CHANCE] = clampf(out[Ability.Kind.CRIT_CHANCE], 0.0, 100.0)
	if out.has(Ability.Kind.EVASION):
		out[Ability.Kind.EVASION] = clampf(out[Ability.Kind.EVASION], 0.0, 100.0)
	return out


func _append_bundle(artifact: Artifact, variant: ArtifactVariant) -> void:
	var entries: Array = []
	for modifier in variant.modifiers:
		if modifier == null:
			continue
		entries.append({
			"kind": modifier.kind,
			"op": modifier.op,
			"value": modifier.value,
		})
	_modifier_bundles.append({
		"source": artifact,
		"entries": entries,
	})


func _append_ability_bundle(artifact: Artifact, variant: ArtifactVariant) -> void:
	var entries: Array = []
	for ability in variant.abilities:
		if ability == null:
			continue
		entries.append({
			"kind": ability.kind,
			"value": ability.value,
		})
	if entries.is_empty():
		return
	_ability_bundles.append({
		"source": artifact,
		"entries": entries,
	})


func _remove_last_bundle(artifact: Artifact) -> bool:
	var i := _modifier_bundles.size() - 1
	while i >= 0:
		if _modifier_bundles[i].source == artifact:
			_modifier_bundles.remove_at(i)
			return true
		i -= 1
	return false


func _remove_last_ability_bundle(artifact: Artifact) -> bool:
	var i := _ability_bundles.size() - 1
	while i >= 0:
		if _ability_bundles[i].source == artifact:
			_ability_bundles.remove_at(i)
			return true
		i -= 1
	return false


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
	for bundle in _modifier_bundles:
		for entry in bundle.entries:
			if entry.kind != kind:
				continue
			match entry.op:
				Op.FLAT:
					flat_sum += entry.value
				Op.PERCENT:
					percent_sum += entry.value
	return (base + flat_sum) * (1.0 + percent_sum / 100.0)
