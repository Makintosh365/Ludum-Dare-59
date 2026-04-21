class_name ToastNotification
extends CanvasLayer

const _DEFAULT_DURATION := 2.5
const _FADE_TIME := 0.35


static func show_toast(parent: Node, message: String, border_color: Color = Color(0.25, 0.95, 0.75), duration: float = _DEFAULT_DURATION) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var toast := ToastNotification.new()
	toast.layer = 200
	parent.add_child(toast)
	toast._display(message, border_color, duration)


func _display(message: String, border_color: Color, duration: float) -> void:
	var root := Control.new()
	root.anchor_left = 0.5
	root.anchor_right = 0.5
	root.anchor_top = 0.22
	root.anchor_bottom = 0.22
	root.offset_left = -220
	root.offset_right = 220
	root.offset_top = -60
	root.offset_bottom = 60
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var panel := PanelContainer.new()
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.10, 0.08, 0.92)
	style.border_color = border_color
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	panel.add_theme_stylebox_override("panel", style)
	root.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)

	var label := Label.new()
	label.text = message
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 32)
	label.add_theme_color_override("font_color", border_color)
	margin.add_child(label)

	root.modulate.a = 0.0
	var hold_time: float = maxf(0.1, duration - _FADE_TIME * 2.0)
	var tween := create_tween()
	tween.tween_property(root, "modulate:a", 1.0, _FADE_TIME)
	tween.tween_interval(hold_time)
	tween.tween_property(root, "modulate:a", 0.0, _FADE_TIME)
	tween.finished.connect(queue_free)
