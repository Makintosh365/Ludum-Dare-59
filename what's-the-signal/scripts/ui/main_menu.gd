extends Control


func _ready() -> void:
	GameManager.report_ready("MainMenu")
	(get_node("%StartButton") as Button).pressed.connect(func():
		print("MainMenu: Start pressed")
		GameManager.load_level()
	)
	(get_node("%QuitButton") as Button).pressed.connect(func():
		print("MainMenu: Quit pressed")
		GameManager.quit_game()
	)
