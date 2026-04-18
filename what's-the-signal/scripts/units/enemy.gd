class_name Enemy
extends Unit

@export var body_color: Color = Color(1.0, 0.3, 0.3)
@export var coin_reward: int = 5
@export var loadout: UnitLoadout

const _DEFAULT_LOADOUT_PATH := "res://configs/enemies/default_enemy.tres"


func _ready() -> void:
	var cfg := _ensure_loadout()
	if cfg != null:
		base_max_health = cfg.max_health
		base_damage = cfg.damage
		base_defense = cfg.defense
		base_attack_speed = cfg.attack_speed
	super._ready()
	inventory.configure(cfg.inventory if cfg != null else null)


func _ensure_loadout() -> UnitLoadout:
	if loadout != null:
		return loadout
	if ResourceLoader.exists(_DEFAULT_LOADOUT_PATH):
		loadout = load(_DEFAULT_LOADOUT_PATH) as UnitLoadout
	if loadout == null:
		push_warning("Enemy %s: UnitLoadout not set and default missing, using unit defaults" % name)
	return loadout


func _draw() -> void:
	const half := 9.0
	var rect := Rect2(-half, -half, half * 2.0, half * 2.0)
	draw_rect(rect, body_color, true)
	draw_rect(rect, Color.WHITE, false)


func die(killer: Variant) -> void:
	if killer is Player:
		(killer as Player).add_coins(coin_reward)
	super.die(killer)
