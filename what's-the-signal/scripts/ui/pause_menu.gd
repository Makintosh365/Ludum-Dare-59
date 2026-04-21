extends CanvasLayer


func _ready() -> void:
	(get_node("%ResumeButton") as Button).pressed.connect(func(): GameManager.change_state(GameManager.State.GAMEPLAY))
	(get_node("%RestartButton") as Button).pressed.connect(GameManager.restart_level)
	(get_node("%MainMenuButton") as Button).pressed.connect(GameManager.load_main_menu)
	FullscreenToggle.attach_to_button(get_node_or_null("%FullscreenButton") as Button)
	var slider := get_node_or_null("%VolumeSlider") as HSlider
	if slider != null:
		slider.value = AudioManager.get_master_volume()
		slider.value_changed.connect(AudioManager.set_master_volume)
	AudioManager.register_buttons(self)
