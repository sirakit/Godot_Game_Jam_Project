extends Node2D

@export var debris_scene: PackedScene
@export var spawn_distance: Vector2 = Vector2(850.0, 1100.0)   # เกิดนอกจอ รอบตัวผู้เล่น (ไม่ใช่รอบยานแล้ว)
@export var spawn_interval: Vector2 = Vector2(5.0, 9.0)
@export var speed_range: Vector2 = Vector2(220.0, 360.0)
@export var aim_spread_degrees: float = 12.0

@onready var player: CharacterBody2D = get_node("../Player")

var _timer: float = 0.0

func _ready() -> void:
	_reset_timer()

func _process(delta: float) -> void:
	if not Game.is_outside:
		return
	_timer -= delta
	if _timer <= 0.0:
		_spawn_one()
		_reset_timer()

func _reset_timer() -> void:
	_timer = randf_range(spawn_interval.x, spawn_interval.y)

func _spawn_one() -> void:
	var d := debris_scene.instantiate()
	var speed := randf_range(speed_range.x, speed_range.y)
	var dist := randf_range(spawn_distance.x, spawn_distance.y)
	var spawn_pos: Vector2 = player.global_position + Vector2.from_angle(randf_range(0.0, TAU)) * dist

	# เล็งนำหน้า: ทำนายว่าตอนเศษขยะไปถึง ผู้เล่นจะอยู่ตรงไหน
	var travel_time := dist / speed
	var predicted: Vector2 = player.global_position + player.velocity * travel_time
	var aim_angle: float = (predicted - spawn_pos).angle()
	aim_angle += deg_to_rad(randf_range(-aim_spread_degrees, aim_spread_degrees))

	d.direction = Vector2.from_angle(aim_angle)
	d.speed = speed
	d.target = player
	add_child(d)
	d.global_position = spawn_pos
