extends CanvasLayer


func _ready() -> void:
	(get_node("%RestartButton") as Button).pressed.connect(GameManager.restart_level)
	(get_node("%MainMenuButton") as Button).pressed.connect(GameManager.load_main_menu)
