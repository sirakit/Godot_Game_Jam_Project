extends Node2D

@onready var ship: Node2D = $Ship
@onready var player: CharacterBody2D = $Player
@onready var rope_line: Line2D = $RopeLine

func _ready():
	player.set_ship_position(ship.global_position)
	rope_line.width = 3.0

func _process(_delta: float) -> void:
	rope_line.clear_points()
	rope_line.add_point(ship.global_position)
	rope_line.add_point(player.global_position)
