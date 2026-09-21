extends Control

func _ready() -> void:
	$VBoxContainer/BtnStart.pressed.connect(_start)
	$VBoxContainer/BtnQuit.pressed.connect(get_tree().quit)

func _start() -> void:
	Game.reset_all()
	get_tree().change_scene_to_file("res://Scenes/space.tscn")
