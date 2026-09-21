extends Node2D

@onready var ship: Node2D = $Ship
@onready var player: CharacterBody2D = $Player
@onready var rope_line: Line2D = $RopeLine

func _ready() -> void:
	player.set_ship_position(ship.global_position)
	rope_line.width = 3.0

func _process(_delta: float) -> void:
	rope_line.visible = Game.is_outside
	rope_line.clear_points()
	rope_line.add_point(ship.global_position)
	rope_line.add_point(player.global_position)
	var t: float = 1.0 - (Game.tether_remaining / max(1.0, Game.tether_length_max))
	rope_line.default_color = Color(1.0, 1.0 - t * 0.85, 1.0 - t * 0.9)   # ขาว → แดงเมื่อใกล้สุด

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		Game.reset_all()
		get_tree().reload_current_scene()
