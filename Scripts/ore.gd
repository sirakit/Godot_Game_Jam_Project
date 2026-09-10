extends Area2D


@export var ore_value: int = 1

func _ready():
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if body.name == "Player" and not body.is_returning:
		body.inventory_ore += ore_value
		queue_free() # ลบแร่ออกจากฉาก
