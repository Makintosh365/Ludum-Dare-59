extends CanvasLayer

const _UPGRADE_SCREEN_SCENE := preload("res://scenes/ui/upgrade_shop_screen.tscn")


func _ready() -> void:
	var player := get_tree().root.find_child("Player", true, false) as Player
	if player != null:
		player.reset_to_base()
	var shop_button := get_node_or_null("%ShopButton") as Button
	if shop_button != null:
		shop_button.pressed.connect(_on_shop_pressed)
	AudioManager.register_buttons(self)


func _on_shop_pressed() -> void:
	var player := get_tree().root.find_child("Player", true, false) as Player
	if player == null:
		GameManager.restart_level()
		return
	var screen := _UPGRADE_SCREEN_SCENE.instantiate() as UpgradeShopScreen
	if screen == null:
		GameManager.restart_level()
		return
	add_child(screen)
	screen.bind(player)
	screen.closed.connect(_on_shop_closed.bind(screen))


func _on_shop_closed(screen: UpgradeShopScreen) -> void:
	if screen != null and is_instance_valid(screen):
		screen.queue_free()
	GameManager.restart_level()
