extends Control


func _ready() -> void:
	GameManager.report_ready("MainMenu")
	(get_node("%StartButton") as Button).pressed.connect(func():
		print("MainMenu: Start pressed")
		GameManager.load_level()
	)
	FullscreenToggle.attach_to_button(get_node_or_null("%FullscreenButton") as Button)
	var slider := get_node_or_null("%VolumeSlider") as HSlider
	if slider != null:
		slider.value = AudioManager.get_master_volume()
		slider.value_changed.connect(AudioManager.set_master_volume)
	AudioManager.register_buttons(self)
