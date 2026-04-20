extends RefCounted
class_name FullscreenToggle

const _GOLD := Color(0.95, 0.8, 0.2)
const _GOLD_HOVER := Color(1.0, 0.92, 0.45)
const _GOLD_PRESSED := Color(0.7, 0.55, 0.1)


static func is_supported() -> bool:
	return OS.has_feature("web")


static func is_fullscreen() -> bool:
	var mode := DisplayServer.window_get_mode()
	return mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN


static func toggle() -> void:
	if is_fullscreen():
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


static func attach_to_button(button: Button) -> void:
	if button == null:
		return
	if not is_supported():
		button.visible = false
		return
	button.visible = true
	_apply_gold(button)
	_refresh_label(button)
	if not button.pressed.is_connected(_on_pressed):
		button.pressed.connect(_on_pressed.bind(button))


static func _apply_gold(button: Button) -> void:
	button.add_theme_color_override("font_color", _GOLD)
	button.add_theme_color_override("font_hover_color", _GOLD_HOVER)
	button.add_theme_color_override("font_focus_color", _GOLD_HOVER)
	button.add_theme_color_override("font_pressed_color", _GOLD_PRESSED)


static func _on_pressed(button: Button) -> void:
	toggle()
	_refresh_label(button)


static func _refresh_label(button: Button) -> void:
	button.text = "Exit Fullscreen" if is_fullscreen() else "Fullscreen"
