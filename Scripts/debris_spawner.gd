extends Node2D

@export var debris_scene: PackedScene       # ลาก Scenes/debris.tscn มาใส่
@export var spawn_radius: float = 1600.0
@export var spawn_interval: Vector2 = Vector2(4.0, 9.0)
@export var speed_range: Vector2 = Vector2(200.0, 340.0)
@export var aim_spread_degrees: float = 35.0   # ยิงเฉียดๆ ไม่ตรงเป้าตลอด จะได้พอหลบได้

@onready var ship: Node2D = get_node("../Ship")

var _timer: float = 0.0

func _ready() -> void:
	_reset_timer()

func _process(delta: float) -> void:
	if not Game.is_outside:
		return   # อยู่ในยานไม่มีเศษขยะมากวน
	_timer -= delta
	if _timer <= 0.0:
		_spawn_one()
		_reset_timer()

func _reset_timer() -> void:
	_timer = randf_range(spawn_interval.x, spawn_interval.y)

func _spawn_one() -> void:
	var d := debris_scene.instantiate()
	var spawn_angle := randf_range(0.0, TAU)
	d.global_position = ship.global_position + Vector2(cos(spawn_angle), sin(spawn_angle)) * spawn_radius

	var aim_angle: float = (ship.global_position - d.global_position).angle()
	aim_angle += deg_to_rad(randf_range(-aim_spread_degrees, aim_spread_degrees))
	d.direction = Vector2.RIGHT.rotated(aim_angle)
	d.speed = randf_range(speed_range.x, speed_range.y)

	add_child(d)
