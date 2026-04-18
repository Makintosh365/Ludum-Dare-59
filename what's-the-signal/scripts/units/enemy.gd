class_name Enemy
extends Unit

@export var body_color: Color = Color(1.0, 0.3, 0.3)
@export var coin_reward: int = 1


func _draw() -> void:
	const half := 9.0
	var rect := Rect2(-half, -half, half * 2.0, half * 2.0)
	draw_rect(rect, body_color, true)
	draw_rect(rect, Color.WHITE, false)


func die(killer: Variant) -> void:
	if killer is Player:
		(killer as Player).add_coins(coin_reward)
	super.die(killer)
