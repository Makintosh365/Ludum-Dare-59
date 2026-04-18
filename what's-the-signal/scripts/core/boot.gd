extends Node


func _ready() -> void:
	GameManager.report_ready("Boot", "handing off to MainMenu")
	GameManager.change_state(GameManager.State.MAIN_MENU)
	if GameManager.main_menu_scene != null:
		get_tree().change_scene_to_packed(GameManager.main_menu_scene)
	else:
		push_warning("Boot: GameManager.MainMenuScene is not set")
