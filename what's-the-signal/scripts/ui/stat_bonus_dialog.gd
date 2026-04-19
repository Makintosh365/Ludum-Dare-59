class_name StatBonusDialog
extends CanvasLayer

signal choice_made(kind: int, amount: float)

const _TITLE := "Stat Bonus"

var _hp_amount: int = 0
var _damage_amount: int = 0
var _armor_amount: int = 0


func configure(hp_amount: int, damage_amount: int, armor_amount: int) -> void:
	_hp_amount = hp_amount
	_damage_amount = damage_amount
	_armor_amount = armor_amount

	var title := get_node_or_null("%Title") as Label
	if title != null:
		title.text = _TITLE

	var hp_button := get_node_or_null("%HPButton") as Button
	if hp_button != null:
		hp_button.text = "+%d HP" % hp_amount
		if not hp_button.pressed.is_connected(_on_hp_pressed):
			hp_button.pressed.connect(_on_hp_pressed)

	var damage_button := get_node_or_null("%DamageButton") as Button
	if damage_button != null:
		damage_button.text = "+%d Damage" % damage_amount
		if not damage_button.pressed.is_connected(_on_damage_pressed):
			damage_button.pressed.connect(_on_damage_pressed)

	var armor_button := get_node_or_null("%ArmorButton") as Button
	if armor_button != null:
		armor_button.text = "+%d Armor" % armor_amount
		if not armor_button.pressed.is_connected(_on_armor_pressed):
			armor_button.pressed.connect(_on_armor_pressed)

	visible = true


func _on_hp_pressed() -> void:
	choice_made.emit(UnitStats.Kind.MAX_HEALTH, float(_hp_amount))


func _on_damage_pressed() -> void:
	choice_made.emit(UnitStats.Kind.DAMAGE, float(_damage_amount))


func _on_armor_pressed() -> void:
	choice_made.emit(UnitStats.Kind.DEFENSE, float(_armor_amount))
