extends Node2D

@export var debris_scene: PackedScene
@export var spawn_distance: Vector2 = Vector2(850.0, 1100.0)   # เกิดนอกจอ รอบตัวผู้เล่น (ไม่ใช่รอบยานแล้ว)
@export var spawn_interval: Vector2 = Vector2(5.0, 9.0)
@export var speed_range: Vector2 = Vector2(220.0, 360.0)
@export var aim_spread_degrees: float = 12.0

@export_group("Secret Attack")
@export var attack_interval: Vector2 = Vector2(3.0, 4.5)       # seconds between volleys
@export var attack_first_delay: float = 3.0
@export var attack_count: Vector2i = Vector2i(2, 2)            # debris per volley
@export var attack_spawn_distance: Vector2 = Vector2(650.0, 800.0)   # just off screen, like normal debris
@export var attack_speed: Vector2 = Vector2(260.0, 340.0)      # same range as normal debris
@export var attack_oxygen_damage: float = 25.0                 # same as normal debris
@export var attack_warning_radius: float = 80.0                # red circle size (px)

@onready var player: CharacterBody2D = get_node("../Player")

var _timer: float = 0.0
var _attack_mode: bool = false

func _ready() -> void:
	_reset_timer()

func _process(delta: float) -> void:
	if not Game.is_outside:
		return
	var attacking: bool = Game.secret_phase == 1
	if attacking != _attack_mode:
		_attack_mode = attacking
		if attacking:
			_timer = attack_first_delay
		else:
			_reset_timer()
	_timer -= delta
	if _timer <= 0.0:
		if _attack_mode:
			_spawn_volley()
			_timer = randf_range(attack_interval.x, attack_interval.y)
		else:
			_spawn_one()
			_reset_timer()

func _reset_timer() -> void:
	_timer = randf_range(spawn_interval.x, spawn_interval.y)

# Locks onto where the player is RIGHT NOW, marks it with a red circle, and sends a couple of normal
# debris straight at that point (no homing). Move out of the circle before they arrive.
func _spawn_volley() -> void:
	var lock_pos: Vector2 = player.global_position
	var count: int = randi_range(attack_count.x, attack_count.y)
	var offset: float = randf() * TAU
	var longest_travel: float = 0.0
	for i in count:
		var ang: float = offset + TAU * float(i) / float(count) + randf_range(-0.4, 0.4)
		var dist: float = randf_range(attack_spawn_distance.x, attack_spawn_distance.y)
		var spd: float = randf_range(attack_speed.x, attack_speed.y)
		var spawn_pos: Vector2 = lock_pos + Vector2.from_angle(ang) * dist
		var travel: float = dist / spd
		var d := debris_scene.instantiate()
		d.direction = (lock_pos - spawn_pos).normalized()
		d.speed = spd
		d.homing_time = 0.0
		d.oxygen_damage = attack_oxygen_damage
		d.lifetime = travel + 1.5
		add_child(d)
		d.global_position = spawn_pos
		longest_travel = maxf(longest_travel, travel)
	_spawn_warning(lock_pos, longest_travel)

# Red danger circle that closes in on the locked point, then fades
func _spawn_warning(pos: Vector2, duration: float) -> void:
	var root := Node2D.new()
	root.z_index = 1
	add_child(root)
	root.global_position = pos

	var pts := PackedVector2Array()
	for i in 32:
		pts.append(Vector2.from_angle(TAU * float(i) / 32.0) * attack_warning_radius)

	var disc := Polygon2D.new()
	disc.polygon = pts
	disc.color = Color(1.0, 0.2, 0.15, 0.18)
	root.add_child(disc)

	var ring := Line2D.new()
	ring.points = pts
	ring.closed = true
	ring.width = 4.0
	ring.default_color = Color(1.0, 0.25, 0.2, 0.95)
	root.add_child(ring)

	root.scale = Vector2.ONE * 1.5
	var tw: Tween = root.create_tween()
	tw.tween_property(root, "scale", Vector2.ONE, duration)
	tw.tween_property(root, "modulate:a", 0.0, 0.2)
	tw.tween_callback(root.queue_free)

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
