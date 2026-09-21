extends Node2D

@onready var dock_area: Area2D = $DockArea

func _ready() -> void:
	dock_area.body_entered.connect(_on_enter)
	dock_area.body_exited.connect(_on_exit)

func _on_enter(body: Node2D) -> void:
	if body.is_in_group("player"):
		body.near_ship = true

func _on_exit(body: Node2D) -> void:
	if body.is_in_group("player"):
		body.near_ship = false
