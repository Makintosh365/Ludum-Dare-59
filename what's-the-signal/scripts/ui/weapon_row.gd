class_name WeaponRow
extends Panel

@onready var icon_button: Button = %IconButton
@onready var name_label: Label = %NameLabel
@onready var rarity_label: Label = %RarityLabel
@onready var upgrade_button: Button = %UpgradeButton

var weapon_id: StringName = &""


func set_border_color(color: Color) -> void:
	var style := get_theme_stylebox("panel") as StyleBoxFlat
	if style == null:
		return
	var dup := style.duplicate() as StyleBoxFlat
	dup.border_color = color
	add_theme_stylebox_override("panel", dup)
