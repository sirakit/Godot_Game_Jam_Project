extends Node2D


@onready var player = $Player
@onready var ship = $Ship
@onready var tether_rope = $TetherRope

func _process(_delta):
	# วาดเส้นจาก ยาน ไปยัง ตัวละคร
	tether_rope.clear_points()
	tether_rope.add_point(ship.global_position)
	tether_rope.add_point(player.global_position)
