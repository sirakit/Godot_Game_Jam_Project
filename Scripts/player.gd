extends CharacterBody2D

@export var speed: float = 200.0
@export var max_out_time: float = 10.0 # เวลาที่ให้ออกไปนอกยาน (วินาที)

var time_left: float
var is_returning: bool = false
var ship_position: Vector2 = Vector2.ZERO
var inventory_ore: int = 0

signal returned_to_ship

func _ready():
	time_left = max_out_time

func _physics_process(delta):
	if is_returning:
		# ถูกสายดึงกลับยานอัตโนมัติ
		global_position = global_position.move_toward(ship_position, speed * 2.5 * delta)
		if global_position.distance_to(ship_position) < 10.0:
			_on_reach_ship()
	else:
		# เดินบังคับปกติ
		var input_vec = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		velocity = input_vec * speed
		move_and_slide()

		# นับถอยหลังเวลาออกนอกยาน
		time_left -= delta
		if time_left <= 0:
			start_pull_back()

func start_pull_back():
	is_returning = true

func _on_reach_ship():
	is_returning = false
	time_left = max_out_time
	returned_to_ship.emit()
