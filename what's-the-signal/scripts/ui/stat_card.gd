class_name StatCard
extends PanelContainer

@onready var title_label: Label = %TitleLabel
@onready var icon_rect: TextureRect = %IconRect
@onready var value_label: Label = %ValueLabel
@onready var cost_button: Button = %CostButton


func set_border_color(color: Color) -> void:
	var style := get_theme_stylebox("panel") as StyleBoxFlat
	if style == null:
		return
	var dup := style.duplicate() as StyleBoxFlat
	dup.border_color = color
	add_theme_stylebox_override("panel", dup)
